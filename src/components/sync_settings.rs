use dioxus::prelude::*;
use std::sync::Arc;
use std::sync::RwLock;
use crate::models::config::{ConfigModel, SyncPlatform};

/// 同步设置组件
#[component]
pub fn SyncSettings(on_close: EventHandler<()>) -> Element {
    let config = use_context::<Arc<RwLock<ConfigModel>>>();

    let config_guard = config.read().ok().expect("Failed to lock config");
    let initial_enabled = config_guard.sync.enabled;
    let initial_platform = config_guard.sync.platform.clone();
    let initial_server_url = config_guard.sync.server_url.clone();
    let initial_api_key = config_guard.sync.api_key.clone();
    let initial_gist_id = config_guard.sync.gist_id.clone();
    let initial_sync_interval = config_guard.sync.sync_interval_minutes.to_string();
    let initial_auto_sync = config_guard.sync.auto_sync;
    let initial_sync_on_startup = config_guard.sync.sync_on_startup;
    drop(config_guard);

    let mut enabled = use_signal(|| initial_enabled);
    let mut platform = use_signal(|| initial_platform);
    let mut server_url = use_signal(|| initial_server_url);
    let mut api_key = use_signal(|| initial_api_key);
    let mut gist_id = use_signal(|| initial_gist_id);
    let mut sync_interval = use_signal(|| initial_sync_interval);
    let mut auto_sync = use_signal(|| initial_auto_sync);
    let mut sync_on_startup = use_signal(|| initial_sync_on_startup);

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
                width: "550px",
                padding: "20px",
                max_height: "85vh",
                overflow_y: "auto",
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
                    // 平台选择
                    div {
                        margin_bottom: "16px",
                        label {
                            display: "block",
                            color: "#AAAAAA",
                            font_size: "12px",
                            margin_bottom: "4px",
                            "Sync Platform"
                        },
                        div {
                            display: "flex",
                            gap: "8px",
                            margin_bottom: "8px",
                            button {
                                class: if *platform.read() == SyncPlatform::GithubGist {
                                    "platform-btn active"
                                } else {
                                    "platform-btn"
                                },
                                padding: "8px 16px",
                                border_radius: "4px",
                                border: "1px solid #3C3C3C",
                                background_color: if *platform.read() == SyncPlatform::GithubGist { "#007ACC" } else { "#1E1E1E" },
                                color: "#FFFFFF",
                                font_size: "13px",
                                cursor: "pointer",
                                onclick: move |_| {
                                    platform.set(SyncPlatform::GithubGist);
                                    server_url.set("https://api.github.com".to_string());
                                },
                                "GitHub Gist"
                            },
                            button {
                                class: if *platform.read() == SyncPlatform::GiteeGist {
                                    "platform-btn active"
                                } else {
                                    "platform-btn"
                                },
                                padding: "8px 16px",
                                border_radius: "4px",
                                border: "1px solid #3C3C3C",
                                background_color: if *platform.read() == SyncPlatform::GiteeGist { "#007ACC" } else { "#1E1E1E" },
                                color: "#FFFFFF",
                                font_size: "13px",
                                cursor: "pointer",
                                onclick: move |_| {
                                    platform.set(SyncPlatform::GiteeGist);
                                    server_url.set("https://gitee.com".to_string());
                                },
                                "Gitee Gist"
                            }
                        }
                    },
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
                            placeholder: match *platform.read() {
                                SyncPlatform::GithubGist => "https://api.github.com",
                                SyncPlatform::GiteeGist => "https://gitee.com",
                                SyncPlatform::Custom => "https://example.com/api/sync",
                            },
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
                    // API Key / Token
                    div {
                        margin_bottom: "16px",
                        label {
                            display: "block",
                            color: "#AAAAAA",
                            font_size: "12px",
                            margin_bottom: "4px",
                            "Personal Access Token"
                        },
                        input {
                            type: "password",
                            value: "{*api_key.read()}",
                            placeholder: "ghp_xxxxxxxxxxxx",
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
                    // Gist ID
                    div {
                        margin_bottom: "16px",
                        label {
                            display: "block",
                            color: "#AAAAAA",
                            font_size: "12px",
                            margin_bottom: "4px",
                            "Gist ID (leave empty to create new)"
                        },
                        input {
                            type: "text",
                            value: "{*gist_id.read()}",
                            placeholder: "1234567890abcdef...",
                            width: "100%",
                            padding: "8px",
                            border_radius: "4px",
                            border: "1px solid #3C3C3C",
                            background_color: "#1E1E1E",
                            color: "#FFFFFF",
                            font_size: "13px",
                            oninput: move |e| {
                                gist_id.set(e.value());
                            }
                        }
                    },
                    // 同步选项
                    div {
                        margin_bottom: "16px",
                        label {
                            display: "flex",
                            align_items: "center",
                            gap: "8px",
                            color: "#CCCCCC",
                            font_size: "14px",
                            cursor: "pointer",
                            margin_bottom: "8px",
                            input {
                                type: "checkbox",
                                checked: *auto_sync.read(),
                                oninput: move |e| {
                                    auto_sync.set(e.value().parse().unwrap_or(false));
                                }
                            },
                            "Auto sync"
                        },
                        label {
                            display: "flex",
                            align_items: "center",
                            gap: "8px",
                            color: "#CCCCCC",
                            font_size: "14px",
                            cursor: "pointer",
                            input {
                                type: "checkbox",
                                checked: *sync_on_startup.read(),
                                oninput: move |e| {
                                    sync_on_startup.set(e.value().parse().unwrap_or(false));
                                }
                            },
                            "Sync on startup"
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
                            config_guard.sync.platform = platform.read().clone();
                            config_guard.sync.server_url = server_url.read().clone();
                            config_guard.sync.api_key = api_key.read().clone();
                            config_guard.sync.gist_id = gist_id.read().clone();
                            config_guard.sync.sync_interval_minutes = sync_interval.read().parse().unwrap_or(30);
                            config_guard.sync.auto_sync = *auto_sync.read();
                            config_guard.sync.sync_on_startup = *sync_on_startup.read();
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
