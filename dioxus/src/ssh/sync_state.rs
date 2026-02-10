use std::sync::{Arc, Mutex};
use crate::models::config::ConfigModel;

/// 同步状态
#[derive(Clone, Debug)]
pub enum SyncState {
    Idle,
    Syncing,
    Error(String),
    Success(String),
}

/// 同步状态管理（用于 UI）
#[derive(Clone)]
pub struct SyncStateService {
    state: Arc<Mutex<SyncState>>,
}

impl SyncStateService {
    pub fn new() -> Self {
        Self {
            state: Arc::new(Mutex::new(SyncState::Idle)),
        }
    }

    /// 获取当前状态
    pub fn state(&self) -> SyncState {
        self.state.lock().unwrap().clone()
    }

    /// 设置状态
    pub fn set_state(&self, new_state: SyncState) {
        *self.state.lock().unwrap() = new_state;
    }
}

impl Default for SyncStateService {
    fn default() -> Self {
        Self::new()
    }
}

/// 全局同步状态服务
pub static SYNC_STATE_SERVICE: std::sync::OnceLock<SyncStateService> = std::sync::OnceLock::new();

pub fn get_sync_state_service() -> &'static SyncStateService {
    SYNC_STATE_SERVICE.get_or_init(|| SyncStateService::new())
}
