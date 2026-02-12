use dioxus_desktop::use_window;
use std::rc::Rc;
use crate::get_config;

/// 窗口状态管理器
#[derive(Clone)]
pub struct WindowStateManager {
    window: Rc<dioxus_desktop::DesktopService>,
}

impl WindowStateManager {
    /// 创建新的窗口状态管理器
    pub fn new() -> Self {
        Self {
            window: use_window(),
        }
    }

    /// 保存当前窗口状态到配置
    pub fn save_state(&self) {
        let size = self.window.inner_size();
        let maximized = self.window.is_maximized();

        if let Ok(mut cfg) = get_config().try_write() {
            // 只在非最大化状态下保存大小
            if !maximized {
                cfg.window.width = size.width;
                cfg.window.height = size.height;
            }
            cfg.window.maximized = maximized;
            let _ = cfg.save();
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::config::WindowConfig;

    /// 测试 WindowConfig 默认值
    #[test]
    fn test_window_config_default_values() {
        let config = WindowConfig::default();

        assert_eq!(config.width, 900);
        assert_eq!(config.height, 600);
        assert!(!config.maximized);
    }

    /// 测试 WindowConfig 自定义值
    #[test]
    fn test_window_config_custom_values() {
        let config = WindowConfig {
            width: 1920,
            height: 1080,
            maximized: true,
        };

        assert_eq!(config.width, 1920);
        assert_eq!(config.height, 1080);
        assert!(config.maximized);
    }

    /// 测试 WindowConfig 序列化
    #[test]
    fn test_window_config_serialization() {
        let config = WindowConfig {
            width: 1280,
            height: 720,
            maximized: false,
        };

        let json = serde_json::to_string(&config).expect("序列化失败");
        let deserialized: WindowConfig = serde_json::from_str(&json).expect("反序列化失败");

        assert_eq!(config.width, deserialized.width);
        assert_eq!(config.height, deserialized.height);
        assert_eq!(config.maximized, deserialized.maximized);
    }

    /// 测试 WindowConfig 相等性
    #[test]
    fn test_window_config_equality() {
        let config1 = WindowConfig {
            width: 800,
            height: 600,
            maximized: false,
        };
        let config2 = WindowConfig {
            width: 800,
            height: 600,
            maximized: false,
        };
        let config3 = WindowConfig {
            width: 1024,
            height: 768,
            maximized: true,
        };

        assert_eq!(config1, config2);
        assert_ne!(config1, config3);
    }

    /// 测试 WindowConfig 不相等
    #[test]
    fn test_window_config_inequality() {
        let config1 = WindowConfig {
            width: 800,
            height: 600,
            maximized: false,
        };
        let config2 = WindowConfig {
            width: 800,
            height: 600,
            maximized: true,  // 不同的 maximized 状态
        };

        assert_ne!(config1, config2);
    }
}
