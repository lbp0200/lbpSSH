use std::io::Write;
use std::sync::atomic::{AtomicU8, Ordering};
use std::sync::Arc;
use tokio::net::TcpStream;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use ssh2::{Session, Channel};

use crate::models::connection::{AuthType, SshConnection};

/// SSH 连接状态
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum SshSessionState {
    Disconnected,
    Connecting,
    Connected,
    Error(String),
}

/// SSH 错误
#[derive(Debug, thiserror::Error)]
pub enum SshError {
    #[error("连接失败: {0}")]
    ConnectionFailed(String),

    #[error("认证失败: {0}")]
    AuthenticationFailed(String),

    #[error("会话建立失败: {0}")]
    SessionFailed(String),

    #[error("IO 错误: {0}")]
    IoError(#[from] std::io::Error),

    #[error("SSH 错误: {0}")]
    SshError(#[from] ssh2::Error),

    #[error("SOCKS5 代理错误: {0}")]
    Socks5Error(String),

    #[error("跳板机错误: {0}")]
    JumpHostError(String),
}

/// SOCKS5 代理连接器
struct Socks5ProxyConnector {
    proxy_host: String,
    proxy_port: u16,
    target_host: String,
    target_port: u16,
    username: Option<String>,
    password: Option<String>,
}

impl Socks5ProxyConnector {
    fn new(
        proxy_host: String,
        proxy_port: u16,
        target_host: String,
        target_port: u16,
        username: Option<String>,
        password: Option<String>,
    ) -> Self {
        Self {
            proxy_host,
            proxy_port,
            target_host,
            target_port,
            username,
            password,
        }
    }

    async fn connect(&self) -> Result<TcpStream, SshError> {
        let mut socket = TcpStream::connect((self.proxy_host.as_str(), self.proxy_port))
            .await
            .map_err(|e| SshError::Socks5Error(format!("Failed to connect to proxy: {}", e)))?;
        socket.set_nodelay(true)?;

        // SOCKS5 握手
        let mut handshake = vec![0x05u8];
        if self.username.is_some() && self.password.is_some() {
            handshake.push(0x02);
        } else {
            handshake.push(0x01);
        }
        socket.write_all(&handshake).await
            .map_err(|e| SshError::Socks5Error(format!("Failed to send handshake: {}", e)))?;

        let mut response = [0u8; 2];
        socket.read_exact(&mut response).await
            .map_err(|e| SshError::Socks5Error(format!("Failed to read handshake response: {}", e)))?;

        if response[0] != 0x05 {
            return Err(SshError::Socks5Error("Invalid SOCKS5 protocol version".to_string()));
        }

        // 用户名密码认证
        if response[1] == 0x02 {
            let (username, password) = match (&self.username, &self.password) {
                (Some(u), Some(p)) => (u.clone(), p.clone()),
                _ => {
                    return Err(SshError::Socks5Error("Proxy requires username/password auth".to_string()));
                }
            };

            let mut auth_request = vec![0x01u8];
            auth_request.push(username.len() as u8);
            auth_request.extend_from_slice(username.as_bytes());
            auth_request.push(password.len() as u8);
            auth_request.extend_from_slice(password.as_bytes());
            socket.write_all(&auth_request).await
                .map_err(|e| SshError::Socks5Error(format!("Failed to send auth request: {}", e)))?;

            let mut auth_response = [0u8; 2];
            socket.read_exact(&mut auth_response).await
                .map_err(|e| SshError::Socks5Error(format!("Failed to read auth response: {}", e)))?;

            if auth_response[1] != 0x00 {
                return Err(SshError::Socks5Error("SOCKS5 username/password auth failed".to_string()));
            }
        }

        // 发送连接请求
        let mut connect_request = vec![0x05u8, 0x01, 0x00, 0x03];
        connect_request.push(self.target_host.len() as u8);
        connect_request.extend_from_slice(self.target_host.as_bytes());
        connect_request.push((self.target_port >> 8) as u8);
        connect_request.push((self.target_port & 0xFF) as u8);
        socket.write_all(&connect_request).await
            .map_err(|e| SshError::Socks5Error(format!("Failed to send connect request: {}", e)))?;

        let mut conn_response = [0u8; 10];
        socket.read_exact(&mut conn_response).await
            .map_err(|e| SshError::Socks5Error(format!("Failed to read connect response: {}", e)))?;

        if conn_response[0] != 0x05 {
            return Err(SshError::Socks5Error("Invalid SOCKS5 response version".to_string()));
        }

        if conn_response[1] != 0x00 {
            let error_msg = match conn_response[1] {
                0x01 => "SOCKS5 general failure",
                0x02 => "SOCKS5 connection refused",
                0x03 => "SOCKS5 network unreachable",
                0x04 => "SOCKS5 host unreachable",
                0x05 => "SOCKS5 connection refused",
                0x06 => "SOCKS5 TTL expired",
                0x07 => "SOCKS5 command not supported",
                0x08 => "SOCKS5 address type not supported",
                _ => "SOCKS5 unknown error",
            };
            return Err(SshError::Socks5Error(error_msg.to_string()));
        }

        Ok(socket)
    }
}

/// SSH 会话
pub struct SshSession {
    state: Arc<AtomicU8>,
    session: Option<Session>,
    channel: Option<Channel>,
}

impl SshSession {
    pub fn new() -> Self {
        Self {
            state: Arc::new(AtomicU8::new(0)),
            session: None,
            channel: None,
        }
    }

    pub fn state(&self) -> SshSessionState {
        match self.state.load(Ordering::SeqCst) {
            0 => SshSessionState::Disconnected,
            1 => SshSessionState::Connecting,
            2 => SshSessionState::Connected,
            _ => SshSessionState::Error("Unknown error".to_string()),
        }
    }

    pub async fn connect(&mut self, connection: &SshConnection) -> Result<(), SshError> {
        self.state.store(1, Ordering::SeqCst);

        let target_host = connection.host.clone();
        let target_port = connection.port;

        let tcp_stream: TcpStream = if let Some(ref proxy) = connection.socks5_proxy {
            let connector = Socks5ProxyConnector::new(
                proxy.host.clone(),
                proxy.port,
                target_host.clone(),
                target_port,
                proxy.username.clone(),
                proxy.password.clone(),
            );
            connector.connect().await?
        } else {
            let stream = TcpStream::connect((target_host.as_str(), target_port)).await
                .map_err(|e| SshError::ConnectionFailed(format!("Connection failed: {}", e)))?;
            stream.set_nodelay(true)?;
            stream
        };

        let mut session = Session::new()
            .expect("Failed to create SSH session");
        session.set_tcp_stream(tcp_stream);

        session.handshake()
            .map_err(|e| SshError::ConnectionFailed(format!("Handshake failed: {}", e)))?;

        self.authenticate(&mut session, connection)?;
        self.spawn_shell(&mut session).await?;

        self.session = Some(session);
        self.state.store(2, Ordering::SeqCst);
        Ok(())
    }

    fn authenticate(&self, session: &mut Session, connection: &SshConnection) -> Result<(), SshError> {
        match connection.auth_type {
            AuthType::Password => {
                let password = connection.password.as_ref()
                    .ok_or_else(|| SshError::AuthenticationFailed("Password not set".to_string()))?;
                session.userauth_password(&connection.username, password)
                    .map_err(|e| SshError::AuthenticationFailed(format!("Password auth failed: {}", e)))?;
            }
            AuthType::Key => {
                let key_content = connection.private_key_content.as_ref()
                    .ok_or_else(|| SshError::AuthenticationFailed("Private key not set".to_string()))?;
                session.userauth_pubkey_memory(&connection.username, None, key_content, None)
                    .map_err(|e| SshError::AuthenticationFailed(format!("Key auth failed: {}", e)))?;
            }
            AuthType::KeyWithPassword => {
                let key_content = connection.private_key_content.as_ref()
                    .ok_or_else(|| SshError::AuthenticationFailed("Private key not set".to_string()))?;
                let passphrase = connection.key_passphrase.as_ref().map(|s| s.as_str());
                session.userauth_pubkey_memory(&connection.username, None, key_content, passphrase)
                    .map_err(|e| SshError::AuthenticationFailed(format!("Key+passphrase auth failed: {}", e)))?;
            }
            AuthType::SshConfig => {
                self.authenticate_with_ssh_config(session, connection)?;
            }
        }
        Ok(())
    }

    fn authenticate_with_ssh_config(&self, session: &mut Session, connection: &SshConnection) -> Result<(), SshError> {
        let ssh_config_host = connection.ssh_config_host.as_ref()
            .ok_or_else(|| SshError::AuthenticationFailed("SSH Config host not set".to_string()))?;

        let config_path = std::path::PathBuf::from(std::env::var("HOME").unwrap_or_default()).join(".ssh/config");
        if !config_path.exists() {
            return Err(SshError::AuthenticationFailed("SSH config file not found".to_string()));
        }

        let config_content = std::fs::read_to_string(&config_path)
            .map_err(|e| SshError::AuthenticationFailed(format!("Failed to read SSH config: {}", e)))?;

        let entry = Self::parse_ssh_config(&config_content, ssh_config_host)
            .ok_or_else(|| SshError::AuthenticationFailed(format!("Host '{}' not found in SSH config", ssh_config_host)))?;

        let username = entry.user.unwrap_or_else(|| connection.username.clone());

        if let Some(identity_files) = &entry.identity_files {
            for identity_file in identity_files {
                let expanded_path = if identity_file.starts_with("~") {
                    std::path::PathBuf::from(std::env::var("HOME").unwrap_or_default())
                        .join(&identity_file[1..])
                } else {
                    std::path::PathBuf::from(identity_file)
                };

                if expanded_path.exists() {
                    let key_content = std::fs::read_to_string(&expanded_path)
                        .map_err(|e| SshError::AuthenticationFailed(format!("Failed to read key file: {}", e)))?;
                    match session.userauth_pubkey_memory(&username, None, &key_content, None) {
                        Ok(_) => return Ok(()),
                        Err(_) => continue,
                    }
                }
            }
        }

        if let Some(password) = &connection.password {
            session.userauth_password(&username, password)
                .map_err(|e| SshError::AuthenticationFailed(format!("Password auth failed: {}", e)))?;
        } else {
            return Err(SshError::AuthenticationFailed("No valid auth method found".to_string()));
        }

        Ok(())
    }

    fn parse_ssh_config(content: &str, target_host: &str) -> Option<SshConfigEntry> {
        let mut current_host: Option<String> = None;
        let mut current_config: std::collections::HashMap<String, Vec<String>> = std::collections::HashMap::new();

        for line in content.lines() {
            let trimmed = line.trim();
            if trimmed.is_empty() || trimmed.starts_with('#') {
                continue;
            }

            let parts: Vec<&str> = trimmed.split_whitespace().collect();
            if parts.len() >= 2 {
                let key = parts[0].to_lowercase();
                let value = parts[1..].join(" ");

                if key == "host" {
                    if let Some(host) = &current_host {
                        if host == target_host {
                            return Some(Self::create_entry(host, &current_config));
                        }
                    }
                    current_host = Some(value);
                    current_config.clear();
                } else if let Some(_) = &current_host {
                    current_config.entry(key).or_insert_with(Vec::new).push(value);
                }
            }
        }

        if let Some(host) = &current_host {
            if host == target_host {
                return Some(Self::create_entry(host, &current_config));
            }
        }

        None
    }

    fn create_entry(host: &str, config: &std::collections::HashMap<String, Vec<String>>) -> SshConfigEntry {
        SshConfigEntry {
            host_name: host.to_string(),
            actual_host: config.get("hostname").and_then(|v| v.first().cloned()),
            port: config.get("port").and_then(|v| v.first().and_then(|p| p.parse().ok())).unwrap_or(22),
            user: config.get("user").and_then(|v| v.first().cloned()),
            identity_files: config.get("identityfile").cloned(),
        }
    }

    async fn spawn_shell(&mut self, session: &mut Session) -> Result<(), SshError> {
        let mut channel = session.channel_session()
            .map_err(|e| SshError::SessionFailed(format!("Failed to create channel: {}", e)))?;

        channel.request_pty_size(80, 24, None, None)
            .map_err(|e| SshError::SessionFailed(format!("Failed to request PTY: {}", e)))?;

        channel.shell()
            .map_err(|e| SshError::SessionFailed(format!("Failed to start shell: {}", e)))?;

        self.channel = Some(channel);
        Ok(())
    }

    pub fn write_input(&mut self, data: &[u8]) -> Result<(), std::io::Error> {
        if let Some(ref mut channel) = self.channel {
            channel.write_all(data)?;
            channel.flush()?;
        }
        Ok(())
    }

    pub fn close(&mut self) {
        if let Some(mut channel) = self.channel.take() {
            channel.send_eof().ok();
            channel.wait_close().ok();
            channel.close().ok();
        }
        if let Some(session) = self.session.take() {
            session.disconnect(Some(ssh2::DisconnectCode::ByApplication), "Goodbye", None);
        }
        self.state.store(0, Ordering::SeqCst);
    }
}

impl Drop for SshSession {
    fn drop(&mut self) {
        self.close();
    }
}

struct SshConfigEntry {
    host_name: String,
    actual_host: Option<String>,
    port: u16,
    user: Option<String>,
    identity_files: Option<Vec<String>>,
}
