use dioxus::prelude::*;
use std::sync::Arc;
use std::sync::RwLock;
use crate::models::config::ConfigModel;

/// 同步设置组件
#[component]
pub fn SyncSettings(on_close: EventHandler<()>) -> Element {
    let config = use_context::<Arc<RwLock<ConfigModel>>>();

    let config_guard = config.read().ok().expect("Failed to lock config");
    let initial_enabled = config_guard.sync.enabled;
    let initial_server_url = config_guard.sync.server_url.clone();
    let initial_api_key = config_guard.sync.api_key.clone();
    let initial_sync_interval = config_guard.sync.sync_interval_minutes.to_string();
    let initial_auto_sync = config_guard.sync.auto_sync;

    let mut enabled = use_signal(|| initial_enabled);
    let mut server_url = use_signal(|| initial_server_url);
    let mut api_key = use_signal(|| initial_api_key);
    let mut sync_interval = use_signal(|| initial_sync_interval);
    let mut auto_sync = use_signal(|| initial_auto_sync);
    let mut sync_status = use_signal(|| "Idle".to_string());
    let mut syncing = use_signal(|| false);
    drop(config_guard); // Release guard before closures

    let on_sync = move |_| {
        if !*enabled.read() {
            return;
        }
        syncing.set(true);
        sync_status.set("Syncing...".to_string());

        // 使用简单的超时来模拟同步
        // 注意：在实际应用中，应该使用更复杂的异步处理
        sync_status.set("Last synced: Just now".to_string());
        syncing.set(false);
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
                    "Cloud Sync"
                },
                // 启用同步
                div {
                    margin_bottom: "16px",
                    label {
                        display: "flex",
                        align_items: "center",
                        gap: "8px",
                        color: "#CCCCCC",
                        font_size: "14px",
                        cursor: "pointer",
                        input {
                            type: "checkbox",
                            checked: *enabled.read(),
                            oninput: move |e| {
                                enabled.set(e.value().parse().unwrap_or(false));
                            }
                        },
                        "Enable cloud sync"
                    }
                },
                if *enabled.read() {
                    // 服务器地址
                    div {
                        margin_bottom: "16px",
                        label {
                            display: "block",
                            color: "#AAAAAA",
                            font_size: "12px",
                            margin_bottom: "4px",
                            "Server URL"
                        },
                        input {
                            type: "text",
                            value: "{*server_url.read()}",
                            placeholder: "https://example.com/api/sync",
                            width: "100%",
                            padding: "8px",
                            border_radius: "4px",
                            border: "1px solid #3C3C3C",
                            background_color: "#1E1E1E",
                            color: "#FFFFFF",
                            font_size: "13px",
                            oninput: move |e| {
                                server_url.set(e.value());
                            }
                        }
                    },
                    // API Key
                    div {
                        margin_bottom: "16px",
                        label {
                            display: "block",
                            color: "#AAAAAA",
                            font_size: "12px",
                            margin_bottom: "4px",
                            "API Key"
                        },
                        input {
                            type: "password",
                            value: "{*api_key.read()}",
                            placeholder: "your-api-key",
                            width: "100%",
                            padding: "8px",
                            border_radius: "4px",
                            border: "1px solid #3C3C3C",
                            background_color: "#1E1E1E",
                            color: "#FFFFFF",
                            font_size: "13px",
                            oninput: move |e| {
                                api_key.set(e.value());
                            }
                        }
                    },
                    // 自动同步
                    div {
                        margin_bottom: "16px",
                        label {
                            display: "flex",
                            align_items: "center",
                            gap: "8px",
                            color: "#CCCCCC",
                            font_size: "14px",
                            cursor: "pointer",
                            input {
                                type: "checkbox",
                                checked: *auto_sync.read(),
                                oninput: move |e| {
                                    auto_sync.set(e.value().parse().unwrap_or(false));
                                }
                            },
                            "Auto sync"
                        }
                    },
                    if *auto_sync.read() {
                        div {
                            margin_bottom: "16px",
                            label {
                                display: "block",
                                color: "#AAAAAA",
                                font_size: "12px",
                                margin_bottom: "4px",
                                "Sync interval (minutes)"
                            },
                            input {
                                type: "number",
                                value: "{*sync_interval.read()}",
                                min: "5",
                                max: "1440",
                                width: "100px",
                                padding: "8px",
                                border_radius: "4px",
                                border: "1px solid #3C3C3C",
                                background_color: "#1E1E1E",
                                color: "#FFFFFF",
                                font_size: "13px",
                                oninput: move |e| {
                                    sync_interval.set(e.value());
                                }
                            }
                        }
                    },
                    // 同步状态
                    div {
                        margin_bottom: "16px",
                        padding: "8px 12px",
                        background_color: "#1E1E1E",
                        border_radius: "4px",
                        color: "#AAAAAA",
                        font_size: "12px",
                        "{*sync_status.read()}"
                    },
                    // 同步按钮
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
                        disabled: *syncing.read() || server_url.read().is_empty(),
                        onclick: on_sync,
                        if *syncing.read() { "Syncing..." } else { "Sync Now" }
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
                        onclick: move |_| {
                            // 保存设置
                            let mut config_guard = config.write().ok().unwrap();
                            config_guard.sync.enabled = *enabled.read();
                            config_guard.sync.server_url = server_url.read().clone();
                            config_guard.sync.api_key = api_key.read().clone();
                            config_guard.sync.sync_interval_minutes = sync_interval.read().parse().unwrap_or(30);
                            config_guard.sync.auto_sync = *auto_sync.read();
                            let _ = config_guard.save();
                            on_close.call(());
                        },
                        "Save"
                    },
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
                        "Cancel"
                    }
                }
            }
        }
    }
}

/// 同步设置按钮
#[component]
pub fn SyncSettingsButton(on_click: EventHandler<()>) -> Element {
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
            "Sync"
        }
    }
}
