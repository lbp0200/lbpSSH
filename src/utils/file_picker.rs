use std::path::PathBuf;

/// 导出格式
#[derive(Debug, Clone, PartialEq)]
pub enum ExportFormat {
    Json,
    Csv,
    SshConfig,
}

/// 文件选择器封装
pub struct FilePicker;

impl FilePicker {
    /// 选择要导入的文件
    pub fn select_file() -> Option<PathBuf> {
        let dialog = rfd::FileDialog::new()
            .add_filter("JSON", &["json"])
            .add_filter("CSV", &["csv"])
            .add_filter("SSH Config", &["conf", "config"])
            .add_filter("All Files", &["*"]);

        #[cfg(target_os = "windows")]
        {
            // Windows: 使用独立的文件选择器窗口
            dialog.pick_file()
        }

        #[cfg(target_os = "macos")]
        {
            dialog.pick_file()
        }

        #[cfg(target_os = "linux")]
        {
            dialog.pick_file()
        }
    }

    /// 选择保存文件的路径
    pub fn save_file(default_name: &str) -> Option<PathBuf> {
        let dialog = rfd::FileDialog::new()
            .set_file_name(default_name)
            .add_filter("JSON", &["json"])
            .add_filter("CSV", &["csv"])
            .add_filter("SSH Config", &["conf", "config"]);

        dialog.save_file()
    }

    /// 选择目录
    pub fn select_directory() -> Option<PathBuf> {
        rfd::FileDialog::new().pick_folder()
    }

    /// 根据格式获取文件扩展名
    pub fn get_extension(format: &ExportFormat) -> &'static str {
        match format {
            ExportFormat::Json => "json",
            ExportFormat::Csv => "csv",
            ExportFormat::SshConfig => "conf",
        }
    }

    /// 根据文件名推断格式
    pub fn infer_format(path: &PathBuf) -> Option<ExportFormat> {
        let ext = path.extension()?.to_str()?.to_lowercase();
        match ext.as_str() {
            "json" => Some(ExportFormat::Json),
            "csv" => Some(ExportFormat::Csv),
            "conf" | "config" => Some(ExportFormat::SshConfig),
            _ => None,
        }
    }
}
