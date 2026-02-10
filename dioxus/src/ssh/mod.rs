mod session;
pub use session::{SshSession, SshError};

mod sync_state;
pub use sync_state::{SyncState, SyncStateService, get_sync_state_service};

pub mod session_manager {
    use super::*;
    use std::collections::HashMap;
    use std::sync::{Arc, Mutex};

    #[derive(Clone)]
    pub struct SessionManager {
        sessions: Arc<Mutex<HashMap<String, SshSession>>>,
        active_session: Arc<Mutex<Option<String>>>,
    }

    impl Default for SessionManager {
        fn default() -> Self {
            Self {
                sessions: Arc::new(Mutex::new(HashMap::new())),
                active_session: Arc::new(Mutex::new(None)),
            }
        }
    }

    impl SessionManager {
        /// 设置活动会话
        pub fn set_active_session(&self, id: &str) {
            let mut guard = self.active_session.lock().unwrap();
            *guard = Some(id.to_string());
        }

        /// 获取活动会话 ID
        pub fn get_active_session(&self) -> Option<String> {
            let guard = self.active_session.lock().unwrap();
            guard.clone()
        }

        /// 连接到 SSH 服务器
        pub async fn connect(&self, connection: &crate::models::connection::SshConnection) -> Result<(), SshError> {
            let mut session = SshSession::new();
            session.connect(connection).await?;
            let mut guard = self.sessions.lock().unwrap();
            guard.insert(connection.id.clone(), session);
            Ok(())
        }

        /// 断开连接
        pub fn disconnect(&self, id: &str) {
            let mut guard = self.sessions.lock().unwrap();
            guard.remove(id);

            let active = self.active_session.lock().unwrap();
            if active.as_ref() == Some(&id.to_string()) {
                drop(active);
                let mut active = self.active_session.lock().unwrap();
                *active = None;
            }
        }

        /// 检查会话是否已连接
        pub fn is_connected(&self, id: &str) -> bool {
            let guard = self.sessions.lock().unwrap();
            guard.contains_key(id)
        }

        /// 写入输入
        pub fn write_input(&self, id: &str, data: &[u8]) -> Result<(), std::io::Error> {
            let mut guard = self.sessions.lock().unwrap();
            if let Some(session) = guard.get_mut(id) {
                session.write_input(data)
            } else {
                Ok(())
            }
        }
    }

    // 全局会话管理器
    pub static SESSION_MANAGER: std::sync::OnceLock<SessionManager> = std::sync::OnceLock::new();

    pub fn get_session_manager() -> &'static SessionManager {
        SESSION_MANAGER.get_or_init(|| SessionManager::default())
    }
}
