use dioxus::prelude::*;
use std::sync::Arc;
use std::sync::RwLock;
use crate::models::config::ConfigModel;
use crate::models::connection::{SshConnection, AuthType};
use crate::utils::file_picker::{FilePicker, ExportFormat};
use crate::utils::import_export::ImportExportService;
use chrono::Utc;

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
    let mut prefix = use_signal(|| String::new());
    let mut show_preview = use_signal(|| false);
    let mut preview_content = use_signal(|| String::new());
    let mut importing = use_signal(|| false);
    let mut exporting = use_signal(|| false);

    // 创建导入导出服务实例
    let import_export_service = useMemo(|| {
        ImportExportService::new(connections_path.clone())
    });

    let on_import = move |_| {
        if *importing.read() {
            return;
        }

        if let Some(file_path) = FilePicker::select_file() {
            importing.set(true);
            message.set(Some("Importing connections...".to_string()));
            message_type.set("info".to_string());

            let format = import_format.read().clone();
            let prefix_val = prefix.read().clone();
            let service = import_export_service.read().clone();
            let connections_path_clone = connections_path.clone();

            // 在后台任务中执行导入
            let fut = async move {
                let result = match format.as_str() {
                    "csv" => {
                        service.import_from_csv(&file_path)
                    }
                    "ssh_config" => {
                        message.set(Some("SSH Config import not yet implemented".to_string()));
                        message_type.set("error".to_string());
                        importing.set(false);
                        return;
                    }
                    _ => {
                        service.import_from_file(&file_path)
                    }
                };

                match result {
                    Ok(imported) => {
                        // 合并连接
                        let existing: Vec<SshConnection> = if connections_path_clone.exists() {
                            let content = std::fs::read_to_string(&connections_path_clone).unwrap_or_default();
                            serde_json::from_str(&content).unwrap_or_default()
                        } else {
                            Vec::new()
                        };

                        let merged = service.merge_imported_connections(
                            imported,
                            existing,
                            false,
                            !prefix_val.is_empty(),
                        ).unwrap_or(imported);

                        // 保存合并后的连接
                        let content = serde_json::to_string_pretty(&merged)
                            .unwrap_or_else(|_| "[]".to_string());
                        std::fs::write(&connections_path_clone, content)
                            .expect("Failed to write connections file");

                        message.set(Some(format!("Successfully imported {} connections", merged.len())));
                        message_type.set("success".to_string());
                    }
                    Err(e) => {
                        message.set(Some(format!("Import failed: {}", e)));
                        message_type.set("error".to_string());
                    }
                }

                importing.set(false);
            };

            // 使用 tokio 运行时执行
            let rt = tokio::runtime::Runtime::new().unwrap();
            rt.block_on(fut);
        } else {
            message.set(Some("No file selected".to_string()));
            message_type.set("info".to_string());
        }
    };

    let on_export = move |_| {
        if *exporting.read() {
            return;
        }

        let format = export_format.read().clone();
        let default_name = match format.as_str() {
            "csv" => "connections.csv",
            "ssh_config" => "ssh_config",
            _ => "connections.json",
        };

        if let Some(output_path) = FilePicker::save_file(default_name) {
            exporting.set(true);
            message.set(Some("Exporting connections...".to_string()));
            message_type.set("info".to_string());

            let service = import_export_service.read().clone();

            let fut = async move {
                let result = match format.as_str() {
                    "csv" => {
                        service.export_to_csv(&output_path)
                    }
                    "ssh_config" => {
                        service.export_to_ssh_config(&output_path)
                    }
                    _ => {
                        service.export_to_file(&output_path)
                    }
                };

                match result {
                    Ok(_) => {
                        message.set(Some(format!("Successfully exported to: {}", output_path.display())));
                        message_type.set("success".to_string());
                    }
                    Err(e) => {
                        message.set(Some(format!("Export failed: {}", e)));
                        message_type.set("error".to_string());
                    }
                }

                exporting.set(false);
            };

            let rt = tokio::runtime::Runtime::new().unwrap();
            rt.block_on(fut);
        } else {
            message.set(Some("No save location selected".to_string()));
            message_type.set("info".to_string());
        }
    };

    let on_preview = move |_| {
        // 模拟预览内容
        preview_content.set(r#"{
  "connections": [
    {
      "id": "sample-1",
      "name": "Example Server",
      "host": "192.168.1.100",
      "port": 22,
      "username": "admin",
      "auth_type": "Password",
      "password": null,
      "private_key_path": null,
      "jump_host": null,
      "socks5_proxy": null,
      "notes": "Sample connection"
    }
  ]
}"#.to_string());
        show_preview.set(true);
    };

    let on_import_sample = move |_| {
        let now = Utc::now();
        let sample_connections = vec![
            SshConnection {
                id: "sample-1".to_string(),
                name: "Sample Server".to_string(),
                host: "192.168.1.100".to_string(),
                port: 22,
                username: "admin".to_string(),
                auth_type: AuthType::Password,
                password: Some("password123".to_string()),
                private_key_content: None,
                key_passphrase: None,
                ssh_config_host: None,
                socks5_proxy: None,
                jump_host: None,
                notes: None,
                group: Some("Samples".to_string()),
                color: Some("#007ACC".to_string()),
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
                    // 前缀选项
                    div {
                        margin_bottom: "12px",
                        label {
                            display: "block",
                            color: "#AAAAAA",
                            font_size: "12px",
                            margin_bottom: "4px",
                            "Prefix (optional)"
                        },
                        input {
                            type: "text",
                            value: "{*prefix.read()}",
                            placeholder: "Add prefix to imported connection names",
                            width: "100%",
                            padding: "8px",
                            border_radius: "4px",
                            border: "1px solid #3C3C3C",
                            background_color: "#1E1E1E",
                            color: "#FFFFFF",
                            font_size: "13px",
                            oninput: move |e| prefix.set(e.value()),
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
                            disabled: *importing.read(),
                            onclick: on_import,
                            if *importing.read() { "Importing..." } else { "Select File" }
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
                        disabled: *exporting.read(),
                        onclick: on_export,
                        if *exporting.read() { "Exporting..." } else { "Export All" }
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
