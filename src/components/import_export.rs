use dioxus::prelude::*;
use std::sync::Arc;
use std::sync::RwLock;
use crate::models::config::ConfigModel;
use crate::models::connection::{SshConnection, AuthType};
use crate::utils::file_picker::FilePicker;

/// 导入导出设置组件
#[component]
pub fn ImportExport(on_close: EventHandler<()>) -> Element {
    let config = use_context::<Arc<RwLock<ConfigModel>>>();

    // 计算连接统计
    let config_guard = config.read().ok().unwrap();
    let connections_path = config_guard.connections_path.clone();
    drop(config_guard);

    let mut total_count = use_signal(|| 0);
    let mut password_count = use_signal(|| 0);
    let mut key_count = use_signal(|| 0);
    let mut jump_host_count = use_signal(|| 0);

    // 读取连接文件
    let connections_content = std::fs::read_to_string(&connections_path);
    if let Ok(content) = connections_content {
        let parsed: Result<Vec<SshConnection>, _> = serde_json::from_str(&content);
        if let Ok(connections) = parsed {
            total_count.set(connections.len());
            password_count.set(connections.iter().filter(|c| c.auth_type == AuthType::Password).count());
            key_count.set(connections.iter().filter(|c| c.auth_type == AuthType::Key || c.auth_type == AuthType::KeyWithPassword).count());
            jump_host_count.set(connections.iter().filter(|c| c.jump_host.is_some()).count());
        }
    }

    let mut import_format = use_signal(|| "json".to_string());
    let mut export_format = use_signal(|| "json".to_string());
    let mut message = use_signal(|| None::<String>);
    let mut message_type = use_signal(|| "info".to_string());
    let mut show_preview = use_signal(|| false);
    let mut preview_content = use_signal(|| String::new());

    let on_import = move |_| {
        if let Some(file_path) = FilePicker::select_file() {
            message.set(Some(format!("Import from: {}", file_path.display())));
            message_type.set("info".to_string());
        } else {
            message.set(Some("No file selected".to_string()));
            message_type.set("info".to_string());
        }
    };

    let on_export = move |_| {
        let format = export_format.read().clone();
        let default_name = match format.as_str() {
            "csv" => "connections.csv",
            "ssh_config" => "ssh_config",
            _ => "connections.json",
        };

        if let Some(output_path) = FilePicker::save_file(default_name) {
            message.set(Some(format!("Export to: {}", output_path.display())));
            message_type.set("success".to_string());
        } else {
            message.set(Some("No save location selected".to_string()));
            message_type.set("info".to_string());
        }
    };

    let on_preview = move |_| {
        preview_content.set(r#"{
  "connections": [
    {
      "id": "sample-1",
      "name": "Example Server",
      "host": "192.168.1.100",
      "port": 22,
      "username": "admin",
      "auth_type": "Password"
    }
  ]
}"#.to_string());
        show_preview.set(true);
    };

    rsx! {
        div {
            class: "modal-overlay",
            position: "fixed",
            top: "0",
            left: "0",
            right: "0",
            bottom: "0",
            background_color: "rgba(0, 0, 0, 0.5)",
            display: "flex",
            justify_content: "center",
            align_items: "center",
            z_index: "1000",
            onclick: move |_| on_close.call(()),
            div {
                class: "settings-modal",
                background_color: "#2D2D2D",
                border_radius: "8px",
                width: "600px",
                padding: "20px",
                max_height: "85vh",
                overflow_y: "auto",
                onclick: move |e| e.stop_propagation(),
                h2 {
                    color: "#FFFFFF",
                    font_size: "18px",
                    font_weight: "600",
                    margin_bottom: "20px",
                    "Import / Export"
                },
                // 连接统计卡片
                div {
                    class: "stats-grid",
                    display: "grid",
                    grid_template_columns: "repeat(4, 1fr)",
                    gap: "12px",
                    margin_bottom: "24px",
                    div {
                        class: "stat-card",
                        padding: "12px",
                        background_color: "#1E1E1E",
                        border_radius: "6px",
                        text_align: "center",
                        h4 {
                            margin: "0 0 4px 0",
                            color: "#888888",
                            font_size: "11px",
                            font_weight: "normal",
                            "Total"
                        },
                        span {
                            color: "#FFFFFF",
                            font_size: "20px",
                            font_weight: "600",
                            "{total_count.read()}"
                        }
                    },
                    div {
                        class: "stat-card",
                        padding: "12px",
                        background_color: "#1E1E1E",
                        border_radius: "6px",
                        text_align: "center",
                        h4 {
                            margin: "0 0 4px 0",
                            color: "#888888",
                            font_size: "11px",
                            font_weight: "normal",
                            "Password"
                        },
                        span {
                            color: "#4CAF50",
                            font_size: "20px",
                            font_weight: "600",
                            "{password_count.read()}"
                        }
                    },
                    div {
                        class: "stat-card",
                        padding: "12px",
                        background_color: "#1E1E1E",
                        border_radius: "6px",
                        text_align: "center",
                        h4 {
                            margin: "0 0 4px 0",
                            color: "#888888",
                            font_size: "11px",
                            font_weight: "normal",
                            "Key"
                        },
                        span {
                            color: "#2196F3",
                            font_size: "20px",
                            font_weight: "600",
                            "{key_count.read()}"
                        }
                    },
                    div {
                        class: "stat-card",
                        padding: "12px",
                        background_color: "#1E1E1E",
                        border_radius: "6px",
                        text_align: "center",
                        h4 {
                            margin: "0 0 4px 0",
                            color: "#888888",
                            font_size: "11px",
                            font_weight: "normal",
                            "Jump Host"
                        },
                        span {
                            color: "#FF9800",
                            font_size: "20px",
                            font_weight: "600",
                            "{jump_host_count.read()}"
                        }
                    }
                },
                // 消息显示
                if let Some(msg) = message.read().as_ref() {
                    div {
                        margin_bottom: "16px",
                        padding: "12px",
                        border_radius: "4px",
                        background_color: if message_type.read().as_str() == "success" { "#2E7D32" } else if message_type.read().as_str() == "error" { "#C62828" } else { "#1565C0" },
                        color: "#FFFFFF",
                        font_size: "13px",
                        "{msg}"
                    }
                },
                // 导入部分
                div {
                    margin_bottom: "24px",
                    h3 {
                        color: "#FFFFFF",
                        font_size: "14px",
                        font_weight: "500",
                        margin_bottom: "12px",
                        "Import Connections"
                    },
                    div {
                        margin_bottom: "12px",
                        label {
                            display: "block",
                            color: "#AAAAAA",
                            font_size: "12px",
                            margin_bottom: "4px",
                            "Import Format"
                        },
                        select {
                            width: "100%",
                            padding: "8px",
                            border_radius: "4px",
                            border: "1px solid #3C3C3C",
                            background_color: "#1E1E1E",
                            color: "#FFFFFF",
                            font_size: "13px",
                            onchange: move |e| {
                                import_format.set(e.value());
                            },
                            option { value: "json", "JSON" },
                            option { value: "csv", "CSV" },
                            option { value: "ssh_config", "SSH Config" },
                        }
                    },
                    div {
                        display: "flex",
                        gap: "8px",
                        flex_wrap: "wrap",
                        button {
                            class: "btn btn-primary",
                            padding: "8px 16px",
                            border_radius: "4px",
                            border: "none",
                            background_color: "#007ACC",
                            color: "#FFFFFF",
                            font_size: "13px",
                            cursor: "pointer",
                            onclick: on_import,
                            "Select File"
                        },
                        button {
                            class: "btn btn-secondary",
                            padding: "8px 16px",
                            border_radius: "4px",
                            border: "1px solid #3C3C3C",
                            background: "transparent",
                            color: "#CCCCCC",
                            font_size: "13px",
                            cursor: "pointer",
                            onclick: on_preview,
                            "Preview"
                        }
                    }
                },
                // 预览区域
                if *show_preview.read() {
                    div {
                        margin_bottom: "24px",
                        h3 {
                            color: "#FFFFFF",
                            font_size: "14px",
                            font_weight: "500",
                            margin_bottom: "8px",
                            "Preview"
                        },
                        div {
                            class: "preview-area",
                            padding: "12px",
                            background_color: "#1E1E1E",
                            border_radius: "4px",
                            border: "1px solid #3C3C3C",
                            max_height: "200px",
                            overflow_y: "auto",
                            pre {
                                margin: "0",
                                font_size: "12px",
                                color: "#CCCCCC",
                                white_space: "pre-wrap",
                                font_family: "monospace",
                                "{preview_content.read()}"
                            }
                        },
                        button {
                            class: "btn btn-secondary",
                            padding: "6px 12px",
                            border_radius: "4px",
                            border: "1px solid #3C3C3C",
                            background: "transparent",
                            color: "#AAAAAA",
                            font_size: "12px",
                            cursor: "pointer",
                            margin_top: "8px",
                            onclick: move |_| show_preview.set(false),
                            "Close Preview"
                        }
                    }
                },
                // 导出部分
                div {
                    margin_bottom: "24px",
                    h3 {
                        color: "#FFFFFF",
                        font_size: "14px",
                        font_weight: "500",
                        margin_bottom: "12px",
                        "Export Connections"
                    },
                    div {
                        margin_bottom: "12px",
                        label {
                            display: "block",
                            color: "#AAAAAA",
                            font_size: "12px",
                            margin_bottom: "4px",
                            "Export Format"
                        },
                        select {
                            width: "100%",
                            padding: "8px",
                            border_radius: "4px",
                            border: "1px solid #3C3C3C",
                            background_color: "#1E1E1E",
                            color: "#FFFFFF",
                            font_size: "13px",
                            onchange: move |e| {
                                export_format.set(e.value());
                            },
                            option { value: "json", "JSON" },
                            option { value: "csv", "CSV" },
                            option { value: "ssh_config", "SSH Config" },
                        }
                    },
                    button {
                        class: "btn btn-primary",
                        padding: "8px 16px",
                        border_radius: "4px",
                        border: "none",
                        background_color: "#007ACC",
                        color: "#FFFFFF",
                        font_size: "13px",
                        cursor: "pointer",
                        onclick: on_export,
                        "Export All"
                    }
                },
                // 按钮
                div {
                    display: "flex",
                    justify_content: "flex-end",
                    gap: "12px",
                    margin_top: "20px",
                    button {
                        class: "btn btn-secondary",
                        padding: "8px 16px",
                        border_radius: "4px",
                        border: "none",
                        background_color: "#3C3C3C",
                        color: "#FFFFFF",
                        font_size: "13px",
                        cursor: "pointer",
                        onclick: move |_| on_close.call(()),
                        "Close"
                    }
                }
            }
        }
    }
}
