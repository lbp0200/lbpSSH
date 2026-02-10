use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use confy;

const APP_NAME: &str = "lbpssh";
const CONFIG_FILENAME: &str = "config";

/// 终端配置
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct TerminalConfig {
    pub font_size: u16,
    pub font_family: String,
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

/// 同步配置
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct SyncConfig {
    pub enabled: bool,
    pub server_url: String,
    pub api_key: String,
    pub sync_interval_minutes: u32,
    pub auto_sync: bool,
    pub last_sync_time: Option<String>,
    pub sync_on_startup: bool,
}

impl Default for SyncConfig {
    fn default() -> Self {
        Self {
            enabled: false,
            server_url: String::new(),
            api_key: String::new(),
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
}

impl Default for ConfigModel {
    fn default() -> Self {
        Self {
            terminal: TerminalConfig::default(),
            connections_path: Self::default_connections_path(),
            theme: String::from("dark"),
            sync: SyncConfig::default(),
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
