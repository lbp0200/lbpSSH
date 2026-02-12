use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// 认证方式
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum AuthType {
    Password,
    Key,
    KeyWithPassword,
    SshConfig,
}

/// 跳板机配置
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct JumpHostConfig {
    pub host: String,
    pub port: u16,
    pub username: String,
    pub auth_type: AuthType,
    pub password: Option<String>,
    pub private_key_path: Option<String>,
}

impl Default for JumpHostConfig {
    fn default() -> Self {
        Self {
            host: String::new(),
            port: 22,
            username: String::new(),
            auth_type: AuthType::Password,
            password: None,
            private_key_path: None,
        }
    }
}

/// SOCKS5 代理配置
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Socks5ProxyConfig {
    pub host: String,
    pub port: u16,
    pub username: Option<String>,
    pub password: Option<String>,
}

impl Default for Socks5ProxyConfig {
    fn default() -> Self {
        Self {
            host: String::new(),
            port: 1080,
            username: None,
            password: None,
        }
    }
}

/// SSH 连接配置
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct SshConnection {
    pub id: String,
    pub name: String,
    pub host: String,
    pub port: u16,
    pub username: String,
    pub auth_type: AuthType,
    pub password: Option<String>,
    pub private_key_path: Option<String>,
    pub private_key_content: Option<String>,
    pub key_passphrase: Option<String>,
    pub jump_host: Option<JumpHostConfig>,
    pub socks5_proxy: Option<Socks5ProxyConfig>,
    pub ssh_config_host: Option<String>,
    pub notes: Option<String>,
    pub group: Option<String>,
    pub color: Option<String>,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub updated_at: chrono::DateTime<chrono::Utc>,
    pub version: i32,
}

impl SshConnection {
    pub fn new(name: String) -> Self {
        let now = chrono::Utc::now();
        Self {
            id: Uuid::new_v4().to_string(),
            name,
            host: String::new(),
            port: 22,
            username: String::new(),
            auth_type: AuthType::Password,
            password: None,
            private_key_path: None,
            private_key_content: None,
            key_passphrase: None,
            jump_host: None,
            socks5_proxy: None,
            ssh_config_host: None,
            notes: None,
            group: None,
            color: None,
            created_at: now,
            updated_at: now,
            version: 1,
        }
    }
}

impl Default for SshConnection {
    fn default() -> Self {
        Self::new(String::new())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// 测试 AuthType 的序列化
    #[test]
    fn test_auth_type_serialization() {
        let auth_types = vec![
            AuthType::Password,
            AuthType::Key,
            AuthType::KeyWithPassword,
            AuthType::SshConfig,
        ];

        for auth_type in auth_types {
            let serialized = serde_json::to_string(&auth_type).expect("序列化失败");
            let deserialized: AuthType = serde_json::from_str(&serialized).expect("反序列化失败");
            assert_eq!(auth_type, deserialized);
        }
    }

    /// 测试 JumpHostConfig 的默认值
    #[test]
    fn test_jump_host_config_default() {
        let default = JumpHostConfig::default();

        assert!(default.host.is_empty());
        assert_eq!(default.port, 22);
        assert!(default.username.is_empty());
        assert_eq!(default.auth_type, AuthType::Password);
        assert!(default.password.is_none());
        assert!(default.private_key_path.is_none());
    }

    /// 测试 Socks5ProxyConfig 的默认值
    #[test]
    fn test_socks5_proxy_config_default() {
        let default = Socks5ProxyConfig::default();

        assert!(default.host.is_empty());
        assert_eq!(default.port, 1080);
        assert!(default.username.is_none());
        assert!(default.password.is_none());
    }

    /// 测试 SshConnection::new
    #[test]
    fn test_ssh_connection_new() {
        let conn = SshConnection::new("测试服务器".to_string());

        assert!(!conn.id.is_empty());
        assert_eq!(conn.name, "测试服务器");
        assert!(conn.host.is_empty());
        assert_eq!(conn.port, 22);
        assert_eq!(conn.version, 1);
    }

    /// 测试带跳板机的 SSH 连接
    #[test]
    fn test_ssh_connection_with_jump_host() {
        let jump_host = JumpHostConfig {
            host: "jump.example.com".to_string(),
            port: 22,
            username: "admin".to_string(),
            auth_type: AuthType::Key,
            password: None,
            private_key_path: Some("/home/user/.ssh/id_rsa".to_string()),
        };

        let conn = SshConnection {
            id: "test-id".to_string(),
            name: "目标服务器".to_string(),
            host: "192.168.1.100".to_string(),
            port: 22,
            username: "root".to_string(),
            auth_type: AuthType::Password,
            password: Some("secret".to_string()),
            private_key_path: None,
            private_key_content: None,
            key_passphrase: None,
            jump_host: Some(jump_host),
            socks5_proxy: None,
            ssh_config_host: None,
            notes: None,
            group: None,
            color: None,
            created_at: chrono::Utc::now(),
            updated_at: chrono::Utc::now(),
            version: 1,
        };

        assert!(conn.jump_host.is_some());
        let jh = conn.jump_host.unwrap();
        assert_eq!(jh.host, "jump.example.com");
        assert_eq!(jh.auth_type, AuthType::Key);
    }

    /// 测试带 SOCKS5 代理的 SSH 连接
    #[test]
    fn test_ssh_connection_with_socks5_proxy() {
        let proxy = Socks5ProxyConfig {
            host: "socks5-proxy.example.com".to_string(),
            port: 1080,
            username: Some("proxy_user".to_string()),
            password: Some("proxy_pass".to_string()),
        };

        let conn = SshConnection {
            id: "test-id".to_string(),
            name: "代理服务器".to_string(),
            host: "192.168.1.200".to_string(),
            port: 22,
            username: "admin".to_string(),
            auth_type: AuthType::Password,
            password: Some("secret".to_string()),
            private_key_path: None,
            private_key_content: None,
            key_passphrase: None,
            jump_host: None,
            socks5_proxy: Some(proxy),
            ssh_config_host: None,
            notes: None,
            group: None,
            color: None,
            created_at: chrono::Utc::now(),
            updated_at: chrono::Utc::now(),
            version: 1,
        };

        assert!(conn.socks5_proxy.is_some());
        let sp = conn.socks5_proxy.unwrap();
        assert_eq!(sp.host, "socks5-proxy.example.com");
        assert_eq!(sp.port, 1080);
    }
}
