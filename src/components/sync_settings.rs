use dioxus::prelude::*;
use std::sync::Arc;
use std::sync::RwLock;
use crate::models::config::{ConfigModel, SyncPlatform};
use crate::utils::github_gist_sync::GitHubGistSyncService;
use crate::utils::gitee_gist_sync::GiteeGistSyncService;

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
    let connections_path = config_guard.connections_path.clone();
    drop(config_guard);

    let mut enabled = use_signal(|| initial_enabled);
    let mut platform = use_signal(|| initial_platform);
    let mut server_url = use_signal(|| initial_server_url);
    let mut api_key = use_signal(|| initial_api_key);
    let mut gist_id = use_signal(|| initial_gist_id);
    let mut sync_interval = use_signal(|| initial_sync_interval);
    let mut auto_sync = use_signal(|| initial_auto_sync);
    let mut sync_on_startup = use_signal(|| initial_sync_on_startup);
    let mut sync_status = use_signal(|| "Idle".to_string());
    let mut syncing = use_signal(|| false);
    let mut testing = use_signal(|| false);

    // 创建同步服务实例
    let github_service = useMemo(|| {
        let config_dir = connections_path.parent().unwrap_or(&std::path::PathBuf::from(".")).to_path_buf();
        GitHubGistSyncService::new(connections_path.clone(), config_dir)
    });

    let gitee_service = useMemo(|| {
        let config_dir = connections_path.parent().unwrap_or(&std::path::PathBuf::from(".")).to_path_buf();
        GiteeGistSyncService::new(connections_path.clone(), config_dir)
    });

    let on_test = move |_| {
        if !*enabled.read() {
            return;
        }
        testing.set(true);
        sync_status.set("Testing connection...".to_string());

        let platform_val = platform.read().clone();
        let api_key_val = api_key.read().clone();
        let gist_id_val = gist_id.read().clone();

        let fut = async move {
            let result = match platform_val {
                SyncPlatform::GithubGist => {
                    let config = crate::utils::github_gist_sync::GitHubGistConfig {
                        enabled: true,
                        gist_id: gist_id_val.clone(),
                        personal_access_token: api_key_val.clone(),
                        last_sync_time: None,
                        auto_sync: false,
                        sync_on_startup: false,
                        file_name: "connections.json".to_string(),
                    };
                    github_service.read().fetch_remote_gist(&config).await
                }
                SyncPlatform::GiteeGist => {
                    let config = crate::utils::gitee_gist_sync::GiteeGistConfig {
                        enabled: true,
                        gist_id: gist_id_val.clone(),
                        personal_access_token: api_key_val.clone(),
                        last_sync_time: None,
                        auto_sync: false,
                        sync_on_startup: false,
                        file_name: "connections.json".to_string(),
                    };
                    gitee_service.read().fetch_remote_gist(&config).await
                }
                SyncPlatform::Custom => {
                    Err("Custom sync not implemented".to_string())
                }
            };

            match result {
                Ok(Some(_)) => {
                    sync_status.set("Connection successful!".to_string());
                }
                Ok(None) => {
                    sync_status.set("Gist not found, please create one first".to_string());
                }
                Err(e) => {
                    sync_status.set(format!("Connection failed: {}", e));
                }
            }

            testing.set(false);
        };

        let rt = tokio::runtime::Runtime::new().unwrap();
        rt.block_on(fut);
    };

    let on_upload = move |_| {
        if !*enabled.read() {
            return;
        }
        syncing.set(true);
        sync_status.set("Uploading...".to_string());

        let platform_val = platform.read().clone();
        let api_key_val = api_key.read().clone();
        let gist_id_val = gist_id.read().clone();

        let fut = async move {
            let result = match platform_val {
                SyncPlatform::GithubGist => {
                    let config = crate::utils::github_gist_sync::GitHubGistConfig {
                        enabled: true,
                        gist_id: gist_id_val.clone(),
                        personal_access_token: api_key_val.clone(),
                        last_sync_time: None,
                        auto_sync: false,
                        sync_on_startup: false,
                        file_name: "connections.json".to_string(),
                    };
                    github_service.read().upload_to_gist(&config).await
                }
                SyncPlatform::GiteeGist => {
                    let config = crate::utils::gitee_gist_sync::GiteeGistConfig {
                        enabled: true,
                        gist_id: gist_id_val.clone(),
                        personal_access_token: api_key_val.clone(),
                        last_sync_time: None,
                        auto_sync: false,
                        sync_on_startup: false,
                        file_name: "connections.json".to_string(),
                    };
                    gitee_service.read().upload_to_gist(&config).await
                }
                SyncPlatform::Custom => {
                    Err("Custom sync not implemented".to_string())
                }
            };

            match result {
                Ok(result) => {
                    sync_status.set(format!("Upload successful! {} connections uploaded", result.uploaded));
                }
                Err(e) => {
                    sync_status.set(format!("Upload failed: {}", e));
                }
            }

            syncing.set(false);
        };

        let rt = tokio::runtime::Runtime::new().unwrap();
        rt.block_on(fut);
    };

    let on_download = move |_| {
        if !*enabled.read() {
            return;
        }
        syncing.set(true);
        sync_status.set("Downloading...".to_string());

        let platform_val = platform.read().clone();
        let api_key_val = api_key.read().clone();
        let gist_id_val = gist_id.read().clone();

        let fut = async move {
            let result = match platform_val {
                SyncPlatform::GithubGist => {
                    let config = crate::utils::github_gist_sync::GitHubGistConfig {
                        enabled: true,
                        gist_id: gist_id_val.clone(),
                        personal_access_token: api_key_val.clone(),
                        last_sync_time: None,
                        auto_sync: false,
                        sync_on_startup: false,
                        file_name: "connections.json".to_string(),
                    };
                    github_service.read().download_from_gist(&config).await
                }
                SyncPlatform::GiteeGist => {
                    let config = crate::utils::gitee_gist_sync::GiteeGistConfig {
                        enabled: true,
                        gist_id: gist_id_val.clone(),
                        personal_access_token: api_key_val.clone(),
                        last_sync_time: None,
                        auto_sync: false,
                        sync_on_startup: false,
                        file_name: "connections.json".to_string(),
                    };
                    gitee_service.read().download_from_gist(&config).await
                }
                SyncPlatform::Custom => {
                    Err("Custom sync not implemented".to_string())
                }
            };

            match result {
                Ok(result) => {
                    sync_status.set(format!("Download successful! {} connections downloaded", result.downloaded));
                }
                Err(e) => {
                    sync_status.set(format!("Download failed: {}", e));
                }
            }

            syncing.set(false);
        };

        let rt = tokio::runtime::Runtime::new().unwrap();
        rt.block_on(fut);
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
                            },
                            button {
                                class: if *platform.read() == SyncPlatform::Custom {
                                    "platform-btn active"
                                } else {
                                    "platform-btn"
                                },
                                padding: "8px 16px",
                                border_radius: "4px",
                                border: "1px solid #3C3C3C",
                                background_color: if *platform.read() == SyncPlatform::Custom { "#007ACC" } else { "#1E1E1E" },
                                color: "#FFFFFF",
                                font_size: "13px",
                                cursor: "pointer",
                                onclick: move |_| {
                                    platform.set(SyncPlatform::Custom);
                                },
                                "Custom"
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
                            if *platform.read() == SyncPlatform::GithubGist {
                                "Personal Access Token"
                            } else if *platform.read() == SyncPlatform::GiteeGist {
                                "Personal Access Token"
                            } else {
                                "API Key"
                            }
                        },
                        input {
                            type: "password",
                            value: "{*api_key.read()}",
                            placeholder: if *platform.read() == SyncPlatform::GithubGist {
                                "ghp_xxxxxxxxxxxx"
                            } else {
                                "your-api-token"
                            },
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
                            placeholder: if *platform.read() == SyncPlatform::GithubGist {
                                "1234567890abcdef..."
                            } else {
                                "your-gist-id"
                            },
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
                    // 手动操作按钮
                    div {
                        margin_bottom: "20px",
                        display: "flex",
                        gap: "8px",
                        flex_wrap: "wrap",
                        button {
                            class: "btn btn-secondary",
                            padding: "8px 16px",
                            border_radius: "4px",
                            border: "1px solid #3C3C3C",
                            background: "transparent",
                            color: "#CCCCCC",
                            font_size: "13px",
                            cursor: "pointer",
                            disabled: *testing.read() || server_url.read().is_empty(),
                            onclick: on_test,
                            if *testing.read() { "Testing..." } else { "Test Connection" }
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
                            disabled: *syncing.read() || api_key.read().is_empty(),
                            onclick: on_upload,
                            if *syncing.read() { "Uploading..." } else { "Upload" }
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
                            disabled: *syncing.read() || api_key.read().is_empty(),
                            onclick: on_download,
                            if *syncing.read() { "Downloading..." } else { "Download" }
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
                            disabled: *syncing.read(),
                            onclick: on_sync,
                            if *syncing.read() { "Syncing..." } else { "Sync Now" }
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
