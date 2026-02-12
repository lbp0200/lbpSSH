use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use confy;

const APP_NAME: &str = "lbpssh";
const CONFIG_FILENAME: &str = "config";

/// 窗口配置
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct WindowConfig {
    pub width: u32,
    pub height: u32,
    pub maximized: bool,
}

impl Default for WindowConfig {
    fn default() -> Self {
        Self {
            width: 900,
            height: 600,
            maximized: false,
        }
    }
}

/// 终端配置
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct TerminalConfig {
    pub font_size: u16,
    pub font_family: String,
    pub font_weight: u16,
    pub letter_spacing: f64,
    pub line_height: f64,
    pub foreground_color: String,
    pub background_color: String,
    pub cursor_color: String,
    pub shell_path: String,
    pub opacity: u8,
    pub enable_bell: bool,
    pub enable_blinking_cursor: bool,
}

impl Default for TerminalConfig {
    fn default() -> Self {
        Self {
            font_size: 14,
            font_family: String::from("Menlo"),
            font_weight: 400,
            letter_spacing: 0.0,
            line_height: 1.2,
            foreground_color: String::from("#CCCCCC"),
            background_color: String::from("#1E1E1E"),
            cursor_color: String::from("#FFFFFF"),
            shell_path: String::new(),
            opacity: 100,
            enable_bell: true,
            enable_blinking_cursor: true,
        }
    }
}

impl TerminalConfig {
    /// 检测默认 shell 路径
    pub fn detect_default_shell() -> String {
        std::env::var("SHELL").unwrap_or_else(|_| {
            #[cfg(target_os = "macos")]
            {
                "/bin/zsh".to_string()
            }
            #[cfg(target_os = "linux")]
            {
                if std::path::Path::new("/bin/bash").exists() {
                    "/bin/bash".to_string()
                } else if std::path::Path::new("/bin/sh").exists() {
                    "/bin/sh".to_string()
                } else {
                    "/bin/bash".to_string()
                }
            }
            #[cfg(target_os = "windows")]
            {
                "powershell.exe".to_string()
            }
        })
    }
}

/// 同步平台类型
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum SyncPlatform {
    GithubGist,
    GiteeGist,
    Custom,
}

/// 同步配置
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct SyncConfig {
    pub enabled: bool,
    pub platform: SyncPlatform,
    pub server_url: String,
    pub api_key: String,
    pub gist_id: String,
    pub sync_interval_minutes: u32,
    pub auto_sync: bool,
    pub last_sync_time: Option<String>,
    pub sync_on_startup: bool,
}

impl Default for SyncConfig {
    fn default() -> Self {
        Self {
            enabled: false,
            platform: SyncPlatform::GithubGist,
            server_url: String::new(),
            api_key: String::new(),
            gist_id: String::new(),
            sync_interval_minutes: 30,
            auto_sync: false,
            last_sync_time: None,
            sync_on_startup: false,
        }
    }
}

/// 应用配置
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ConfigModel {
    pub terminal: TerminalConfig,
    pub connections_path: PathBuf,
    pub theme: String,
    pub sync: SyncConfig,
    pub window: WindowConfig,
}

impl Default for ConfigModel {
    fn default() -> Self {
        Self {
            terminal: TerminalConfig::default(),
            connections_path: Self::default_connections_path(),
            theme: String::from("dark"),
            sync: SyncConfig::default(),
            window: WindowConfig::default(),
        }
    }
}

impl ConfigModel {
    fn default_connections_path() -> PathBuf {
        #[cfg(target_os = "linux")]
        let base = std::env::var("XDG_CONFIG_HOME")
            .map(PathBuf::from)
            .unwrap_or_else(|_| PathBuf::from(std::env::var("HOME").unwrap_or_default()));
        #[cfg(target_os = "macos")]
        let base = PathBuf::from(
            std::env::var("HOME").unwrap_or_else(|_| String::from("~/Library/Application Support")),
        );
        #[cfg(target_os = "windows")]
        let base = PathBuf::from(
            std::env::var("APPDATA").unwrap_or_else(|_| String::from("C:\\Users\\AppData\\Roaming")),
        );

        base.join(APP_NAME).join("connections.json")
    }

    pub fn load() -> Result<Self, confy::ConfyError> {
        confy::load(APP_NAME, CONFIG_FILENAME)
    }

    pub fn save(&self) -> Result<(), confy::ConfyError> {
        confy::store(APP_NAME, CONFIG_FILENAME, self)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// 测试 TerminalConfig 默认值
    #[test]
    fn test_terminal_config_default() {
        let config = TerminalConfig::default();

        assert_eq!(config.font_size, 14);
        assert_eq!(config.font_family, "Menlo");
        assert_eq!(config.font_weight, 400);
        assert_eq!(config.letter_spacing, 0.0);
        assert_eq!(config.line_height, 1.2);
        assert_eq!(config.foreground_color, "#CCCCCC");
        assert_eq!(config.background_color, "#1E1E1E");
        assert_eq!(config.cursor_color, "#FFFFFF");
        assert!(config.shell_path.is_empty());
        assert_eq!(config.opacity, 100);
        assert!(config.enable_bell);
        assert!(config.enable_blinking_cursor);
    }

    /// 测试 TerminalConfig 的 JSON 序列化
    #[test]
    fn test_terminal_config_serialization() {
        let config = TerminalConfig {
            font_size: 18,
            font_family: "JetBrains Mono".to_string(),
            font_weight: 600,
            letter_spacing: 1.0,
            line_height: 1.8,
            foreground_color: "#ABB2BF".to_string(),
            background_color: "#282C34".to_string(),
            cursor_color: "#528BFF".to_string(),
            shell_path: "/usr/bin/zsh".to_string(),
            opacity: 85,
            enable_bell: true,
            enable_blinking_cursor: false,
        };

        let serialized = serde_json::to_string(&config).expect("序列化失败");
        let deserialized: TerminalConfig = serde_json::from_str(&serialized).expect("反序列化失败");

        assert_eq!(config.font_size, deserialized.font_size);
        assert_eq!(config.font_family, deserialized.font_family);
        assert_eq!(config.font_weight, deserialized.font_weight);
    }

    /// 测试 SyncConfig 默认值
    #[test]
    fn test_sync_config_default() {
        let config = SyncConfig::default();

        assert!(!config.enabled);
        assert!(config.server_url.is_empty());
        assert_eq!(config.sync_interval_minutes, 30);
        assert!(!config.auto_sync);
        assert!(config.last_sync_time.is_none());
        assert!(!config.sync_on_startup);
    }

    /// 测试 ConfigModel 默认值
    #[test]
    fn test_config_model_default() {
        let model = ConfigModel::default();

        assert_eq!(model.terminal.font_size, 14);
        assert_eq!(model.theme, "dark");
        assert!(!model.sync.enabled);
        assert!(model.connections_path.to_string_lossy().contains("lbpssh"));
    }

    /// 测试字重范围
    #[test]
    fn test_font_weight_range() {
        let config = TerminalConfig::default();
        assert!(config.font_weight >= 100);
        assert!(config.font_weight <= 900);
    }

    /// 测试透明度范围
    #[test]
    fn test_opacity_range() {
        let config = TerminalConfig::default();
        assert!(config.opacity <= 100);
    }

    /// 测试有效的颜色格式
    #[test]
    fn test_valid_color_format() {
        let config = TerminalConfig::default();

        assert!(config.foreground_color.starts_with('#'));
        assert_eq!(config.foreground_color.len(), 7);
        assert!(config.background_color.starts_with('#'));
        assert_eq!(config.background_color.len(), 7);
    }

    /// 测试 WindowConfig 默认值
    #[test]
    fn test_window_config_default() {
        let config = WindowConfig::default();

        assert_eq!(config.width, 900);
        assert_eq!(config.height, 600);
        assert!(!config.maximized);
    }

    /// 测试 WindowConfig 序列化
    #[test]
    fn test_window_config_serialization() {
        let config = WindowConfig {
            width: 1024,
            height: 768,
            maximized: true,
        };

        let serialized = serde_json::to_string(&config).expect("序列化失败");
        let deserialized: WindowConfig = serde_json::from_str(&serialized).expect("反序列化失败");

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

    /// 测试 ConfigModel 包含窗口配置
    #[test]
    fn test_config_model_has_window_config() {
        let model = ConfigModel::default();

        assert_eq!(model.window.width, 900);
        assert_eq!(model.window.height, 600);
        assert!(!model.window.maximized);
    }
}
