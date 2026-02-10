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
