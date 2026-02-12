use dioxus::prelude::*;
use crate::models::connection::SshConnection;

/// 设置标签页类型
#[derive(Clone, Copy, PartialEq, Debug)]
pub enum SettingsTab {
    Terminal,
    Connections,
    ImportExport,
    Sync,
}

/// 设置界面组件 - Flutter 风格
#[component]
pub fn Settings(
    connections: Vec<SshConnection>,
    on_close: EventHandler<()>,
    on_edit_connection: EventHandler<String>,
    on_delete_connection: EventHandler<String>,
    on_add_connection: EventHandler<()>,
) -> Element {
    let mut selected_tab = use_signal(|| SettingsTab::Terminal);

    rsx! {
        div {
            class: "modal-overlay",
            onclick: move |_| on_close.call(()),
            div {
                class: "settings-modal",
                onclick: move |e| e.stop_propagation(),
                div {
                    class: "settings-header",
                    h2 { "设置" },
                    button {
                        class: "close-btn",
                        onclick: move |_| on_close.call(()),
                        "×"
                    }
                },
                div {
                    class: "settings-body",
                    div {
                        class: "settings-nav",
                        div {
                            class: if *selected_tab.read() == SettingsTab::Terminal { "nav-item active" } else { "nav-item" },
                            onclick: move |_| selected_tab.set(SettingsTab::Terminal),
                            "终端设置"
                        },
                        div {
                            class: if *selected_tab.read() == SettingsTab::Connections { "nav-item active" } else { "nav-item" },
                            onclick: move |_| selected_tab.set(SettingsTab::Connections),
                            "连接管理"
                        },
                        div {
                            class: if *selected_tab.read() == SettingsTab::ImportExport { "nav-item active" } else { "nav-item" },
                            onclick: move |_| selected_tab.set(SettingsTab::ImportExport),
                            "导入导出"
                        },
                        div {
                            class: if *selected_tab.read() == SettingsTab::Sync { "nav-item active" } else { "nav-item" },
                            onclick: move |_| selected_tab.set(SettingsTab::Sync),
                            "同步设置"
                        }
                    },
                    div {
                        class: "settings-content",
                        if *selected_tab.read() == SettingsTab::Terminal {
                            TerminalSettings {}
                        } else if *selected_tab.read() == SettingsTab::Connections {
                            ConnectionManagement {
                                connections: connections.clone(),
                                on_edit: on_edit_connection.clone(),
                                on_delete: on_delete_connection.clone(),
                                on_add: on_add_connection.clone(),
                            }
                        } else if *selected_tab.read() == SettingsTab::ImportExport {
                            ImportExportSettings {}
                        } else if *selected_tab.read() == SettingsTab::Sync {
                            SyncSettings {}
                        }
                    }
                }
            }
        }
    }
}

/// 终端设置
#[component]
fn TerminalSettings() -> Element {
    let mut font_size = use_signal(|| "14".to_string());
    let mut font_family = use_signal(|| "Menlo".to_string());
    let mut foreground_color = use_signal(|| "#CCCCCC".to_string());
    let mut background_color = use_signal(|| "#1E1E1E".to_string());

    rsx! {
        div {
            class: "settings-section",
            h3 { "终端显示设置" },
            div {
                class: "form-group",
                label { "字体大小" },
                input {
                    class: "form-input",
                    type: "text",
                    value: "{*font_size.read()}",
                    oninput: move |e| font_size.set(e.value()),
                }
            },
            div {
                class: "form-group",
                label { "字体" },
                input {
                    class: "form-input",
                    type: "text",
                    value: "{*font_family.read()}",
                    oninput: move |e| font_family.set(e.value()),
                }
            },
            div {
                class: "form-row",
                div {
                    class: "form-group",
                    label { "前景色" },
                    input {
                        class: "form-input",
                        type: "color",
                        value: "{*foreground_color.read()}",
                        oninput: move |e| foreground_color.set(e.value()),
                    }
                },
                div {
                    class: "form-group",
                    label { "背景色" },
                    input {
                        class: "form-input",
                        type: "color",
                        value: "{*background_color.read()}",
                        oninput: move |e| background_color.set(e.value()),
                    }
                }
            }
        }
    }
}

/// 连接项组件
#[component]
fn ConnectionItem(
    conn: SshConnection,
    on_edit: EventHandler<String>,
    on_delete: EventHandler<String>,
) -> Element {
    let conn_id = conn.id.clone();
    let conn_name = conn.name.clone();
    let conn_host = conn.host.clone();
    let conn_port = conn.port;
    let conn_username = conn.username.clone();

    // 为每个按钮创建独立的事件处理程序
    let on_edit_clone = on_edit.clone();
    let on_delete_clone = on_delete.clone();

    let edit_id = conn_id.clone();
    let delete_id = conn_id;

    rsx! {
        div {
            class: "connection-item-simple",
            div {
                class: "connection-info",
                div {
                    class: "connection-name",
                    "{conn_name}"
                },
                div {
                    class: "connection-host",
                    "{conn_host}:{conn_port} @{conn_username}"
                }
            },
            div {
                class: "connection-actions",
                button {
                    class: "action-btn",
                    onclick: move |_| {
                        on_edit_clone.call(edit_id.clone());
                    },
                    "编辑"
                },
                button {
                    class: "action-btn danger",
                    onclick: move |_| {
                        on_delete_clone.call(delete_id.clone());
                    },
                    "删除"
                }
            }
        }
    }
}

/// 连接管理
#[component]
pub fn ConnectionManagement(
    connections: Vec<SshConnection>,
    on_edit: EventHandler<String>,
    on_delete: EventHandler<String>,
    on_add: EventHandler<()>,
) -> Element {
    rsx! {
        div {
            class: "settings-section",
            div {
                class: "section-header",
                h3 { "已保存的连接" },
                button {
                    class: "btn btn-primary",
                    onclick: move |_| on_add.call(()),
                    "添加连接"
                }
            },
            if connections.is_empty() {
                div {
                    class: "empty-state-small",
                    "暂无保存的连接"
                }
            } else {
                div {
                    class: "connection-list-simple",
                    for conn in connections {
                        ConnectionItem {
                            conn: conn,
                            on_edit: on_edit.clone(),
                            on_delete: on_delete.clone(),
                        }
                    }
                }
            }
        }
    }
}

/// 导入导出设置
#[component]
fn ImportExportSettings() -> Element {
    rsx! {
        div {
            class: "settings-section",
            h3 { "导入导出" },
            p {
                class: "settings-description",
                "导出或导入连接配置"
            },
            div {
                class: "import-export-buttons",
                button {
                    class: "btn btn-primary",
                    onclick: move |_| {},
                    "导出配置"
                },
                button {
                    class: "btn btn-secondary",
                    onclick: move |_| {},
                    "导入配置"
                }
            }
        }
    }
}

/// 同步设置
#[component]
fn SyncSettings() -> Element {
    rsx! {
        div {
            class: "settings-section",
            h3 { "同步设置" },
            p {
                class: "settings-description",
                "配置 Gitee Gist 同步"
            },
            div {
                class: "form-group",
                label { "Gist ID" },
                input {
                    class: "form-input",
                    type: "text",
                    placeholder: "输入 Gist ID",
                }
            }
        }
    }
}
