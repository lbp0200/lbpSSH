use std::sync::{Arc, Mutex};
use crate::models::config::ConfigModel;

/// 同步服务状态
#[derive(Clone, Debug)]
pub enum SyncServiceState {
    Idle,
    Syncing,
    Error(String),
    Success(String),
}

/// 同步服务
#[derive(Clone)]
pub struct SyncService {
    state: Arc<Mutex<SyncServiceState>>,
}

impl SyncService {
    pub fn new() -> Self {
        Self {
            state: Arc::new(Mutex::new(SyncServiceState::Idle)),
        }
    }

    /// 获取当前状态
    pub fn state(&self) -> SyncServiceState {
        self.state.lock().unwrap().clone()
    }

    /// 设置状态
    pub fn set_state(&self, new_state: SyncServiceState) {
        *self.state.lock().unwrap() = new_state;
    }

    /// 手动触发同步
    pub async fn sync_now(&self, config: Arc<ConfigModel>) -> Result<String, String> {
        self.set_state(SyncServiceState::Syncing);

        match Self::perform_sync(&config).await {
            Ok(msg) => {
                self.set_state(SyncServiceState::Success(msg.clone()));
                Ok(msg)
            }
            Err(e) => {
                self.set_state(SyncServiceState::Error(e.clone()));
                Err(e)
            }
        }
    }

    /// 执行同步操作
    async fn perform_sync(config: &ConfigModel) -> Result<String, String> {
        if config.sync.server_url.is_empty() {
            return Err("Server URL not configured".to_string());
        }

        if config.sync.api_key.is_empty() {
            return Err("API key not configured".to_string());
        }

        // 模拟同步操作
        // 实际实现应该：
        // 1. 从服务器获取远程连接列表
        // 2. 与本地连接合并
        // 3. 处理冲突
        // 4. 保存到本地
        // 5. 上传本地更改到服务器

        Ok("Sync completed successfully".to_string())
    }
}

impl Default for SyncService {
    fn default() -> Self {
        Self::new()
    }
}

/// 全局同步服务
pub static SYNC_SERVICE: std::sync::OnceLock<SyncService> = std::sync::OnceLock::new();

pub fn get_sync_service() -> &'static SyncService {
    SYNC_SERVICE.get_or_init(|| SyncService::new())
}
