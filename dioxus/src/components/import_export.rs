use dioxus::prelude::*;
use std::sync::Arc;
use std::sync::RwLock;
use crate::models::config::ConfigModel;
use crate::models::connection::SshConnection;
use chrono::Utc;

/// 导入导出设置组件
#[component]
pub fn ImportExport(on_close: EventHandler<()>) -> Element {
    let _config = use_context::<Arc<RwLock<ConfigModel>>>();
    let mut import_format = use_signal(|| "json".to_string());
    let mut export_format = use_signal(|| "json".to_string());
    let mut message = use_signal(|| None::<String>);
    let mut message_type = use_signal(|| "info".to_string());

    let on_import = move |_| {
        // 模拟导入功能
        message.set(Some("Import feature - select a file to import connections".to_string()));
        message_type.set("info".to_string());
    };

    let on_export = move |_| {
        // 模拟导出功能
        message.set(Some("Export feature - connections will be exported to selected format".to_string()));
        message_type.set("info".to_string());
    };

    let on_import_sample = move |_| {
        // 导入示例连接
        let now = Utc::now();
        let sample_connections = vec![
            SshConnection {
                id: "sample-1".to_string(),
                name: "Sample Server".to_string(),
                host: "192.168.1.100".to_string(),
                port: 22,
                username: "admin".to_string(),
                auth_type: crate::models::connection::AuthType::Password,
                password: Some("password123".to_string()),
                private_key_content: None,
                key_passphrase: None,
                ssh_config_host: None,
                socks5_proxy: None,
                jump_host: None,
                notes: None,
                created_at: now,
                updated_at: now,
                version: 1,
                private_key_path: None,
            },
        ];
        message.set(Some(format!("Sample connection imported: {}", sample_connections[0].name)));
        message_type.set("success".to_string());
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
                width: "500px",
                padding: "20px",
                onclick: move |e| e.stop_propagation(),
                h2 {
                    color: "#FFFFFF",
                    font_size: "18px",
                    font_weight: "600",
                    margin_bottom: "20px",
                    "Import / Export"
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
                    button {
                        class: "btn btn-primary",
                        padding: "8px 16px",
                        border_radius: "4px",
                        border: "none",
                        background_color: "#007ACC",
                        color: "#FFFFFF",
                        font_size: "13px",
                        cursor: "pointer",
                        margin_right: "8px",
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
                        onclick: on_import_sample,
                        "Import Sample"
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

/// 导入导出设置按钮
#[component]
pub fn ImportExportButton(on_click: EventHandler<()>) -> Element {
    rsx! {
        button {
            class: "toolbar-btn",
            padding: "6px 12px",
            border: "1px solid #3C3C3C",
            background: "transparent",
            color: "#CCCCCC",
            border_radius: "4px",
            cursor: "pointer",
            font_size: "13px",
            onclick: move |_| on_click.call(()),
            "Import/Export"
        }
    }
}
