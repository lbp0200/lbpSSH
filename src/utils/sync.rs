use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;

/// 同步状态
#[derive(Debug, Clone, PartialEq)]
pub enum SyncStatus {
    Idle,
    Syncing,
    Success,
    Error(String),
}

/// 同步配置
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SyncConfig {
    pub enabled: bool,
    pub server_url: String,
    pub api_key: String,
    pub sync_interval_minutes: u32,
    pub last_sync_time: Option<String>,
    pub auto_sync: bool,
}

impl Default for SyncConfig {
    fn default() -> Self {
        Self {
            enabled: false,
            server_url: String::new(),
            api_key: String::new(),
            sync_interval_minutes: 30,
            last_sync_time: None,
            auto_sync: false,
        }
    }
}

/// 同步服务
pub struct SyncService {
    connections_path: PathBuf,
    sync_config_path: PathBuf,
}

impl SyncService {
    pub fn new(connections_path: PathBuf, config_dir: PathBuf) -> Self {
        let sync_config_path = config_dir.join("sync_config.json");
        Self {
            connections_path,
            sync_config_path,
        }
    }

    /// 加载同步配置
    pub fn load_config(&self) -> SyncConfig {
        if self.sync_config_path.exists() {
            if let Ok(content) = fs::read_to_string(&self.sync_config_path) {
                if let Ok(config) = serde_json::from_str(&content) {
                    return config;
                }
            }
        }
        SyncConfig::default()
    }

    /// 保存同步配置
    pub fn save_config(&self, config: &SyncConfig) -> Result<(), String> {
        if let Some(parent) = self.sync_config_path.parent() {
            fs::create_dir_all(parent)
                .map_err(|e| format!("创建配置目录失败: {}", e))?;
        }

        let content = serde_json::to_string_pretty(config)
            .map_err(|e| format!("序列化配置失败: {}", e))?;
        fs::write(&self.sync_config_path, content)
            .map_err(|e| format!("写入配置失败: {}", e))?;

        Ok(())
    }

    /// 同步到服务器
    pub async fn sync_to_server(&self, config: &SyncConfig) -> Result<SyncResult, String> {
        if !config.enabled || config.server_url.is_empty() {
            return Err("同步未配置".to_string());
        }

        // 读取本地连接
        let connections: Vec<crate::models::connection::SshConnection> = if self.connections_path.exists() {
            let content = fs::read_to_string(&self.connections_path)
                .map_err(|e| format!("读取连接文件失败: {}", e))?;
            serde_json::from_str(&content)
                .map_err(|e| format!("解析连接文件失败: {}", e))?
        } else {
            Vec::new()
        };

        // 准备同步数据
        let sync_data = SyncData {
            timestamp: chrono::Utc::now().to_rfc3339(),
            connections: connections.clone(),
            version: 1,
        };

        // 发送到服务器（这里使用 HTTP 客户端）
        let client = reqwest::Client::new();
        let response = client
            .post(&format!("{}/api/sync", config.server_url))
            .header("Authorization", format!("Bearer {}", config.api_key))
            .json(&sync_data)
            .send()
            .await
            .map_err(|e| format!("网络请求失败: {}", e))?;

        if !response.status().is_success() {
            return Err(format!("服务器响应错误: {}", response.status()));
        }

        // 更新最后同步时间
        let timestamp = chrono::Utc::now().to_rfc3339();
        let mut config = self.load_config();
        config.last_sync_time = Some(timestamp.clone());
        self.save_config(&config)?;

        Ok(SyncResult {
            uploaded: connections.len(),
            downloaded: 0,
            timestamp,
        })
    }

    /// 从服务器同步
    pub async fn sync_from_server(&self, config: &SyncConfig) -> Result<SyncResult, String> {
        if !config.enabled || config.server_url.is_empty() {
            return Err("同步未配置".to_string());
        }

        // 从服务器获取数据
        let client = reqwest::Client::new();
        let response = client
            .get(&format!("{}/api/sync", config.server_url))
            .header("Authorization", format!("Bearer {}", config.api_key))
            .send()
            .await
            .map_err(|e| format!("网络请求失败: {}", e))?;

        if !response.status().is_success() {
            return Err(format!("服务器响应错误: {}", response.status()));
        }

        let sync_data: SyncData = response
            .json()
            .await
            .map_err(|e| format!("解析响应失败: {}", e))?;

        // 保存到本地
        if let Some(parent) = self.connections_path.parent() {
            fs::create_dir_all(parent)
                .map_err(|e| format!("创建目录失败: {}", e))?;
        }

        let content = serde_json::to_string_pretty(&sync_data.connections)
            .map_err(|e| format!("序列化失败: {}", e))?;
        fs::write(&self.connections_path, content)
            .map_err(|e| format!("写入文件失败: {}", e))?;

        // 更新最后同步时间
        let timestamp = chrono::Utc::now().to_rfc3339();
        let mut config = self.load_config();
        config.last_sync_time = Some(timestamp.clone());
        self.save_config(&config)?;

        Ok(SyncResult {
            uploaded: 0,
            downloaded: sync_data.connections.len(),
            timestamp,
        })
    }

    /// 双向同步
    pub async fn sync_bidirectional(&self, config: &SyncConfig) -> Result<SyncResult, String> {
        if !config.enabled || config.server_url.is_empty() {
            return Err("同步未配置".to_string());
        }

        // 先从服务器获取最新数据
        let from_server = self.sync_from_server(config).await?;

        // 读取本地数据
        let local_connections: Vec<crate::models::connection::SshConnection> = if self.connections_path.exists() {
            let content = fs::read_to_string(&self.connections_path)
                .map_err(|e| format!("读取连接文件失败: {}", e))?;
            serde_json::from_str(&content)
                .map_err(|e| format!("解析连接文件失败: {}", e))?
        } else {
            Vec::new()
        };

        // 发送到服务器
        let local_conn_len = local_connections.len();
        let sync_data = SyncData {
            timestamp: chrono::Utc::now().to_rfc3339(),
            connections: local_connections,
            version: 1,
        };

        let client = reqwest::Client::new();
        let _response = client
            .post(&format!("{}/api/sync", config.server_url))
            .header("Authorization", format!("Bearer {}", config.api_key))
            .json(&sync_data)
            .send()
            .await
            .map_err(|e| format!("网络请求失败: {}", e))?;

        Ok(SyncResult {
            uploaded: local_conn_len,
            downloaded: from_server.downloaded,
            timestamp: from_server.timestamp,
        })
    }

    /// 获取最后同步时间
    pub fn get_last_sync_time(&self) -> Option<String> {
        let config = self.load_config();
        config.last_sync_time
    }

    /// 检查是否需要同步
    pub fn needs_sync(&self, config: &SyncConfig) -> bool {
        if !config.enabled || !config.auto_sync {
            return false;
        }

        if let Some(last_sync) = &config.last_sync_time {
            if let Ok(last_time) = chrono::DateTime::parse_from_rfc3339(last_sync) {
                let now = chrono::Utc::now();
                let duration = now.signed_duration_since(last_time);
                return duration.num_minutes() >= config.sync_interval_minutes as i64;
            }
        }

        true
    }
}

/// 同步数据
#[derive(Debug, Serialize, Deserialize)]
pub struct SyncData {
    pub timestamp: String,
    pub connections: Vec<crate::models::connection::SshConnection>,
    pub version: u32,
}

/// 同步结果
pub struct SyncResult {
    pub uploaded: usize,
    pub downloaded: usize,
    pub timestamp: String,
}

#[cfg(test)]
mod tests {
    use super::*;

    /// 测试 SyncStatus 枚举
    #[test]
    fn test_sync_status_variants() {
        assert_eq!(SyncStatus::Idle, SyncStatus::Idle);
        assert_eq!(SyncStatus::Syncing, SyncStatus::Syncing);
        assert_eq!(SyncStatus::Success, SyncStatus::Success);
        assert_eq!(SyncStatus::Error("test".to_string()), SyncStatus::Error("test".to_string()));
    }

    /// 测试 SyncConfig 默认值
    #[test]
    fn test_sync_config_default() {
        let config = SyncConfig::default();

        assert!(!config.enabled);
        assert!(config.server_url.is_empty());
        assert!(config.api_key.is_empty());
        assert_eq!(config.sync_interval_minutes, 30);
        assert!(config.last_sync_time.is_none());
        assert!(!config.auto_sync);
    }

    /// 测试 SyncConfig 序列化
    #[test]
    fn test_sync_config_serialization() {
        let config = SyncConfig {
            enabled: true,
            server_url: "https://api.example.com".to_string(),
            api_key: "test-api-key".to_string(),
            sync_interval_minutes: 60,
            last_sync_time: Some("2024-01-01T00:00:00Z".to_string()),
            auto_sync: true,
        };

        let serialized = serde_json::to_string(&config).expect("序列化失败");
        let deserialized: SyncConfig = serde_json::from_str(&serialized).expect("反序列化失败");

        assert_eq!(config.enabled, deserialized.enabled);
        assert_eq!(config.server_url, deserialized.server_url);
        assert_eq!(config.sync_interval_minutes, deserialized.sync_interval_minutes);
    }

    /// 测试 SyncService 创建
    #[test]
    fn test_sync_service_new() {
        let connections_path = PathBuf::from("/test/connections.json");
        let config_dir = PathBuf::from("/test");
        let service = SyncService::new(connections_path.clone(), config_dir.clone());

        assert_eq!(service.connections_path, connections_path);
        assert_eq!(service.sync_config_path, config_dir.join("sync_config.json"));
    }

    /// 测试 SyncData 序列化
    #[test]
    fn test_sync_data_serialization() {
        let sync_data = SyncData {
            timestamp: "2024-01-01T00:00:00Z".to_string(),
            connections: Vec::new(),
            version: 1,
        };

        let serialized = serde_json::to_string(&sync_data).expect("序列化失败");
        let deserialized: SyncData = serde_json::from_str(&serialized).expect("反序列化失败");

        assert_eq!(sync_data.timestamp, deserialized.timestamp);
        assert_eq!(sync_data.version, deserialized.version);
    }

    /// 测试 SyncResult 结构
    #[test]
    fn test_sync_result() {
        let result = SyncResult {
            uploaded: 5,
            downloaded: 3,
            timestamp: "2024-01-01T00:00:00Z".to_string(),
        };

        assert_eq!(result.uploaded, 5);
        assert_eq!(result.downloaded, 3);
        assert!(!result.timestamp.is_empty());
    }

    /// 测试 needs_sync 未启用
    #[test]
    fn test_needs_sync_disabled() {
        let service = SyncService::new(
            PathBuf::from("/test/connections.json"),
            PathBuf::from("/test"),
        );

        let config = SyncConfig {
            enabled: false,
            auto_sync: true,
            last_sync_time: None,
            ..SyncConfig::default()
        };

        assert!(!service.needs_sync(&config));
    }

    /// 测试 needs_sync 未设置自动同步
    #[test]
    fn test_needs_sync_no_auto() {
        let service = SyncService::new(
            PathBuf::from("/test/connections.json"),
            PathBuf::from("/test"),
        );

        let config = SyncConfig {
            enabled: true,
            auto_sync: false,
            last_sync_time: None,
            ..SyncConfig::default()
        };

        assert!(!service.needs_sync(&config));
    }

    /// 测试 needs_sync 无最后同步时间
    #[test]
    fn test_needs_sync_no_last_sync() {
        let service = SyncService::new(
            PathBuf::from("/test/connections.json"),
            PathBuf::from("/test"),
        );

        let config = SyncConfig {
            enabled: true,
            auto_sync: true,
            last_sync_time: None,
            ..SyncConfig::default()
        };

        assert!(service.needs_sync(&config));
    }
}
