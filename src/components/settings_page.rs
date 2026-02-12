use dioxus::prelude::*;
use crate::components::TerminalSettings;

/// 设置页面标签
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum SettingsTab {
    Terminal,
    Connections,
    ImportExport,
    Sync,
}

/// 设置页面组件
#[component]
pub fn SettingsPage(on_close: EventHandler<()>) -> Element {
    let mut active_tab = use_signal(|| SettingsTab::Terminal);

    let tabs = vec![
        (SettingsTab::Terminal, "Terminal", "terminal"),
        (SettingsTab::Connections, "Connections", "connections"),
        (SettingsTab::ImportExport, "Import/Export", "import-export"),
        (SettingsTab::Sync, "Sync", "sync"),
    ];

    rsx! {
        div {
            class: "settings-page-modal",
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
                class: "settings-page",
                background_color: "#1E1E1E",
                border_radius: "8px",
                width: "900px",
                height: "600px",
                display: "flex",
                overflow: "hidden",
                box_shadow: "0 4px 20px rgba(0, 0, 0, 0.4)",
                onclick: move |e| e.stop_propagation(),
                // 左侧导航栏
                div {
                    class: "settings-navigation",
                    background_color: "#252526",
                    width: "200px",
                    display: "flex",
                    flex_direction: "column",
                    border_right: "1px solid #3C3C3C",
                    div {
                        class: "settings-header",
                        padding: "20px 16px",
                        border_bottom: "1px solid #3C3C3C",
                        h2 {
                            margin: "0",
                            font_size: "16px",
                            color: "#FFFFFF",
                            "Settings"
                        }
                    },
                    div {
                        class: "settings-tabs",
                        padding: "8px",
                        for (tab, label, icon) in tabs {
                            button {
                                class: if *active_tab.read() == tab {
                                    "settings-tab active"
                                } else {
                                    "settings-tab"
                                },
                                display: "flex",
                                align_items: "center",
                                gap: "10px",
                                width: "100%",
                                padding: "12px 16px",
                                border: "none",
                                border_radius: "6px",
                                background_color: if *active_tab.read() == tab { "#2D2D2D" } else { "transparent" },
                                color: if *active_tab.read() == tab { "#FFFFFF" } else { "#AAAAAA" },
                                font_size: "14px",
                                cursor: "pointer",
                                text_align: "left",
                                onclick: move |_| active_tab.set(tab),
                                // 图标占位
                                span {
                                    class: "tab-icon",
                                    font_size: "16px",
                                    match icon {
                                        "terminal" => "Terminal",
                                        "connections" => "Connections",
                                        "import-export" => "Import/Export",
                                        "sync" => "Sync",
                                        _ => "",
                                    }
                                },
                                "{label}"
                            }
                        }
                    }
                },
                // 右侧内容区域
                div {
                    class: "settings-content",
                    flex: "1",
                    padding: "24px",
                    overflow_y: "auto",
                    background_color: "#1E1E1E",
                    match *active_tab.read() {
                        SettingsTab::Terminal => {
                            rsx! {
                                TerminalSettingsContent { on_close: on_close.clone() }
                            }
                        }
                        SettingsTab::Connections => {
                            rsx! {
                                ConnectionManagementContent { on_close: on_close.clone() }
                            }
                        }
                        SettingsTab::ImportExport => {
                            rsx! {
                                ImportExportContent { on_close: on_close.clone() }
                            }
                        }
                        SettingsTab::Sync => {
                            rsx! {
                                SyncContent { on_close: on_close.clone() }
                            }
                        }
                    }
                }
            }
        }
    }
}

/// 终端设置内容
#[component]
fn TerminalSettingsContent(on_close: EventHandler<()>) -> Element {
    rsx! {
        div {
            h3 {
                color: "#FFFFFF",
                font_size: "20px",
                font_weight: "600",
                margin_bottom: "24px",
                "Terminal Settings"
            },
            // 这里嵌入现有的 TerminalSettings 组件
            TerminalSettings { on_close: on_close }
        }
    }
}

/// 连接管理内容
#[component]
fn ConnectionManagementContent(on_close: EventHandler<()>) -> Element {
    let _connections = use_context::<std::sync::Arc<std::sync::RwLock<crate::models::config::ConfigModel>>>();

    rsx! {
        div {
            h3 {
                color: "#FFFFFF",
                font_size: "20px",
                font_weight: "600",
                margin_bottom: "24px",
                "Connection Management"
            },
            div {
                class: "connection-list",
                padding: "12px",
                background_color: "#252526",
                border_radius: "6px",
                border: "1px solid #3C3C3C",
                color: "#AAAAAA",
                font_size: "14px",
                "Connection management interface - manage all saved connections here.\n\nFeatures:\n- View all connections\n- Edit connection settings\n- Delete connections\n- Organize with groups\n- Filter and search",
            }
        }
    }
}

/// 导入导出内容
#[component]
fn ImportExportContent(on_close: EventHandler<()>) -> Element {
    rsx! {
        div {
            h3 {
                color: "#FFFFFF",
                font_size: "20px",
                font_weight: "600",
                margin_bottom: "24px",
                "Import / Export"
            },
            div {
                class: "import-export-stats",
                display: "grid",
                grid_template_columns: "repeat(4, 1fr)",
                gap: "16px",
                margin_bottom: "24px",
                // 统计卡片
                div {
                    class: "stat-card",
                    padding: "16px",
                    background_color: "#252526",
                    border_radius: "6px",
                    border: "1px solid #3C3C3C",
                    h4 {
                        margin: "0 0 8px 0",
                        color: "#888888",
                        font_size: "12px",
                        font_weight: "normal",
                        "Total Connections"
                    },
                    span {
                        color: "#FFFFFF",
                        font_size: "24px",
                        font_weight: "600",
                        "0"
                    }
                },
                div {
                    class: "stat-card",
                    padding: "16px",
                    background_color: "#252526",
                    border_radius: "6px",
                    border: "1px solid #3C3C3C",
                    h4 {
                        margin: "0 0 8px 0",
                        color: "#888888",
                        font_size: "12px",
                        font_weight: "normal",
                        "Password Auth"
                    },
                    span {
                        color: "#4CAF50",
                        font_size: "24px",
                        font_weight: "600",
                        "0"
                    }
                },
                div {
                    class: "stat-card",
                    padding: "16px",
                    background_color: "#252526",
                    border_radius: "6px",
                    border: "1px solid #3C3C3C",
                    h4 {
                        margin: "0 0 8px 0",
                        color: "#888888",
                        font_size: "12px",
                        font_weight: "normal",
                        "Key Auth"
                    },
                    span {
                        color: "#2196F3",
                        font_size: "24px",
                        font_weight: "600",
                        "0"
                    }
                },
                div {
                    class: "stat-card",
                    padding: "16px",
                    background_color: "#252526",
                    border_radius: "6px",
                    border: "1px solid #3C3C3C",
                    h4 {
                        margin: "0 0 8px 0",
                        color: "#888888",
                        font_size: "12px",
                        font_weight: "normal",
                        "Jump Hosts"
                    },
                    span {
                        color: "#FF9800",
                        font_size: "24px",
                        font_weight: "600",
                        "0"
                    }
                }
            },
            div {
                class: "import-export-content",
                padding: "12px",
                background_color: "#252526",
                border_radius: "6px",
                border: "1px solid #3C3C3C",
                color: "#AAAAAA",
                font_size: "14px",
                "Import/Export interface - import connections from files or export to various formats.",
            }
        }
    }
}

/// 同步内容
#[component]
fn SyncContent(on_close: EventHandler<()>) -> Element {
    let config = use_context::<std::sync::Arc<std::sync::RwLock<crate::models::config::ConfigModel>>>();
    let config_guard = config.read().ok().unwrap();
    let sync_enabled = config_guard.sync.enabled;
    drop(config_guard);

    rsx! {
        div {
            h3 {
                color: "#FFFFFF",
                font_size: "20px",
                font_weight: "600",
                margin_bottom: "24px",
                "Cloud Sync"
            },
            // 同步状态卡片
            div {
                class: "sync-status-card",
                padding: "20px",
                background_color: "#252526",
                border_radius: "6px",
                border: "1px solid #3C3C3C",
                margin_bottom: "24px",
                div {
                    display: "flex",
                    justify_content: "space-between",
                    align_items: "center",
                    margin_bottom: "16px",
                    h4 {
                        margin: "0",
                        color: "#FFFFFF",
                        font_size: "16px",
                        "Sync Status"
                    },
                    span {
                        padding: "4px 12px",
                        border_radius: "12px",
                        background_color: if sync_enabled { "#2E7D32" } else { "#616161" },
                        color: "#FFFFFF",
                        font_size: "12px",
                        if sync_enabled { "Enabled" } else { "Disabled" }
                    }
                },
                div {
                    color: "#AAAAAA",
                    font_size: "14px",
                    "Configure cloud synchronization for your connections across devices."
                }
            },
            div {
                class: "sync-content",
                padding: "12px",
                background_color: "#252526",
                border_radius: "6px",
                border: "1px solid #3C3C3C",
                color: "#AAAAAA",
                font_size: "14px",
                "Sync settings interface - configure GitHub Gist, Gitee Gist, or custom server synchronization.",
            }
        }
    }
}

/// 设置页面按钮
#[component]
pub fn SettingsPageButton(on_click: EventHandler<()>) -> Element {
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
            "Settings"
        }
    }
}
