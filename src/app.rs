use dioxus::prelude::*;
use std::sync::Arc;
use std::sync::RwLock;
use crate::models::connection::SshConnection;
use crate::models::config::ConfigModel;
use crate::ssh::session_manager::get_session_manager;
use crate::components::terminal_settings::TerminalSettings;
use crate::components::import_export::ImportExport;
use crate::components::sync_settings::SyncSettings;

/// Tab 信息
#[derive(Clone, PartialEq, Debug)]
pub struct TabInfo {
    pub id: String,
    pub name: String,
    pub connection: Option<SshConnection>,
}

/// App 组件 - 采用 Flutter 版布局
#[component]
pub fn App() -> Element {
    let config = use_context::<Arc<RwLock<ConfigModel>>>();
    let config_clone1 = config.clone();
    let config_clone2 = config.clone();
    let initial_connections: Vec<SshConnection> = {
        let config_guard = config.read().ok().expect("Failed to lock config");
        let path = config_guard.connections_path.clone();
        drop(config_guard);
        if path.exists() {
            std::fs::read_to_string(&path)
                .ok()
                .and_then(|content| serde_json::from_str(&content).ok())
                .unwrap_or_default()
        } else {
            Vec::new()
        }
    };
    let mut connections = use_signal(|| initial_connections);
    let mut tabs = use_signal(|| Vec::<TabInfo>::new());
    let mut active_tab_id = use_signal(|| None::<String>);
    let mut show_form = use_signal(|| false);
    let mut editing_connection = use_signal(|| None::<Option<SshConnection>>);
    let mut show_settings = use_signal(|| false);
    let mut success_message = use_signal(|| None::<String>);
    let mut show_connection_dropdown = use_signal(|| false);

    let active_tab = if let Some(active_id) = active_tab_id.read().clone() {
        tabs.read().iter().find(|t| t.id == active_id).cloned()
    } else {
        None
    };

    let connection_status = if let Some(ref tab) = active_tab {
        if let Some(ref conn) = tab.connection {
            let session_manager = get_session_manager();
            if session_manager.is_connected(&conn.id) {
                "● 已连接".to_string()
            } else {
                "○ 未连接".to_string()
            }
        } else {
            "● 本地终端".to_string()
        }
    } else {
        "".to_string()
    };

    rsx! {
        div {
            class: "app",
            width: "100vw",
            height: "100vh",
            display: "flex",
            flex_direction: "column",
            background_color: "#1E1E1E",
            color: "#CCCCCC",
            div {
                class: "tabs-container",
                TopBarComponent {
                    tabs: tabs.read().clone(),
                    active_tab_id: active_tab_id.read().clone(),
                    show_dropdown: *show_connection_dropdown.read(),
                    dropdown_connections: connections.read().clone(),
                    on_settings_click: move |_| show_settings.set(true),
                    on_add_click: move |_| {
                        let current = *show_connection_dropdown.read();
                        show_connection_dropdown.set(!current);
                    },
                    on_local_terminal_click: move |_| {
                        // 创建本地终端 Tab
                        let tab_id = uuid::Uuid::new_v4().to_string();
                        let new_tab = TabInfo {
                            id: tab_id.clone(),
                            name: "本地终端".to_string(),
                            connection: None,
                        };
                        let mut tabs_vec = tabs.read().clone();
                        tabs_vec.push(new_tab);
                        tabs.set(tabs_vec);
                        active_tab_id.set(Some(tab_id));
                        show_connection_dropdown.set(false);
                    },
                    on_connection_click: move |conn: SshConnection| {
                        // 创建连接 Tab
                        let tab_id = conn.id.clone();
                        let new_tab = TabInfo {
                            id: tab_id.clone(),
                            name: conn.name.clone(),
                            connection: Some(conn),
                        };
                        let mut tabs_vec = tabs.read().clone();
                        tabs_vec.push(new_tab);
                        tabs.set(tabs_vec);
                        active_tab_id.set(Some(tab_id));
                        show_connection_dropdown.set(false);
                    },
                    on_add_new_connection_click: move |_| {
                        editing_connection.set(None);
                        show_form.set(true);
                        show_connection_dropdown.set(false);
                    },
                },
            },
            div {
                class: "main-content",
                flex: "1",
                display: "flex",
                flex_direction: "column",
                overflow: "hidden",
                if let Some(active_tab_info) = active_tab.clone() {
                    div {
                        class: "terminal-header",
                        div {
                            div {
                                font_size: "13px",
                                color: "#FFFFFF",
                                "{active_tab_info.name}"
                            },
                            if let Some(conn) = &active_tab_info.connection {
                                div {
                                    font_size: "11px",
                                    color: "#858585",
                                    "{conn.host}:{conn.port} @{conn.username}"
                                }
                            }
                        },
                        div {
                            font_size: "11px",
                            color: "#4CAF50",
                            "{connection_status}"
                        }
                    },
                    TerminalComponent {
                        tab_id: active_tab_info.id.clone(),
                        tab_name: active_tab_info.name.clone(),
                        connection: active_tab_info.connection.clone(),
                    }
                } else {
                    div {
                        class: "empty-state",
                        div { font_size: "64px", "🖥️" },
                        div { font_size: "18px", margin_top: "16px", "点击右上角 + 按钮创建终端" },
                        div { font_size: "14px", margin_top: "8px", color: "#6A6A6A", "选择本地终端或 SSH 连接" },
                    }
                }
            },
            if *show_settings.read() {
                SettingsComponent {
                    connections: connections.read().clone(),
                    on_close: move |_| show_settings.set(false),
                    on_edit_connection: move |id: String| {
                        let conn = connections.read().iter().find(|c| c.id == id).cloned();
                        editing_connection.set(Some(conn));
                        show_form.set(true);
                        show_settings.set(false);
                    },
                    on_delete_connection: move |id: String| {
                        let session_manager = get_session_manager();
                        session_manager.disconnect(&id);
                        let mut conns = connections.read().clone();
                        conns.retain(|c| c.id != id);
                        connections.set(conns.clone());
                        if let Ok(config_guard) = config_clone1.read() {
                            let connections_path = config_guard.connections_path.clone();
                            drop(config_guard);
                            if let Some(parent) = connections_path.parent() {
                                std::fs::create_dir_all(parent).ok();
                            }
                            if let Ok(content) = serde_json::to_string_pretty(&conns) {
                                std::fs::write(&connections_path, content).ok();
                            }
                        }
                        success_message.set(Some("连接已删除".to_string()));
                    },
                    on_add_connection: move |_| {
                        editing_connection.set(None);
                        show_form.set(true);
                    },
                }
            },
            if *show_form.read() {
                ConnectionFormModal {
                    editing_connection: editing_connection.read().clone().flatten(),
                    on_close: move |_| {
                        show_form.set(false);
                        editing_connection.set(None);
                    },
                    on_save: move |conn: SshConnection| {
                        let mut conns = connections.read().clone();
                        let conn_id = conn.id.clone();
                        let conn_name = conn.name.clone();
                        let existing_idx = conns.iter().position(|c| c.id == conn.id);
                        if let Some(idx) = existing_idx {
                            conns[idx] = conn.clone();
                        } else {
                            conns.push(conn.clone());
                        }
                        connections.set(conns.clone());
                        if let Ok(config_guard) = config_clone2.read() {
                            let connections_path = config_guard.connections_path.clone();
                            drop(config_guard);
                            if let Some(parent) = connections_path.parent() {
                                std::fs::create_dir_all(parent).ok();
                            }
                            if let Ok(content) = serde_json::to_string_pretty(&conns) {
                                std::fs::write(&connections_path, content).ok();
                            }
                        }
                        show_form.set(false);
                        editing_connection.set(None);
                        success_message.set(Some(format!("连接 \"{}\" 已保存", conn_name)));
                        if existing_idx.is_none() {
                            let new_tab = TabInfo {
                                id: conn_id.clone(),
                                name: conn_name,
                                connection: Some(conn),
                            };
                            let mut tabs_vec = tabs.read().clone();
                            tabs_vec.push(new_tab);
                            tabs.set(tabs_vec);
                            active_tab_id.set(Some(conn_id));
                        }
                    },
                }
            },
            if let Some(msg) = success_message.read().clone() {
                div {
                    class: "toast success",
                    onclick: move |_| success_message.set(None),
                    "{msg}"
                }
            }
        }
    }
}

/// 顶部导航栏组件
#[component]
fn TopBarComponent(
    tabs: Vec<TabInfo>,
    active_tab_id: Option<String>,
    show_dropdown: bool,
    dropdown_connections: Vec<SshConnection>,
    on_settings_click: EventHandler<()>,
    on_add_click: EventHandler<()>,
    on_local_terminal_click: EventHandler<()>,
    on_connection_click: EventHandler<SshConnection>,
    on_add_new_connection_click: EventHandler<()>,
) -> Element {
    rsx! {
        div {
            class: "tabs-bar",
            button {
                class: "tabs-settings-btn",
                onclick: move |_| on_settings_click.call(()),
                "⚙️"
            },
            div {
                class: "tabs-list",
                for tab in tabs {
                    div {
                        class: if active_tab_id.as_ref() == Some(&tab.id) { "tab-item active" } else { "tab-item" },
                        "{tab.name}"
                    }
                }
            },
            div {
                class: "tabs-add-dropdown",
                button {
                    class: "tabs-add-btn",
                    onclick: move |_| on_add_click.call(()),
                    "+"
                },
                if show_dropdown {
                    div {
                        class: "dropdown-menu",
                        div {
                            class: "dropdown-item",
                            onclick: move |_| on_local_terminal_click.call(()),
                            "🖥️ 本地终端"
                        },
                        div { class: "dropdown-divider" },
                        if dropdown_connections.is_empty() {
                            div { class: "dropdown-item disabled", "暂无保存的连接" }
                        } else {
                            for conn in dropdown_connections {
                                div {
                                    class: "dropdown-item",
                                    onclick: move |_| on_connection_click.call(conn.clone()),
                                    "🔑 {conn.name}"
                                }
                            }
                        },
                        div { class: "dropdown-divider" },
                        div {
                            class: "dropdown-item",
                            onclick: move |_| on_add_new_connection_click.call(()),
                            "➕ 添加新连接"
                        }
                    }
                }
            }
        }
    }
}

/// 终端组件
#[component]
fn TerminalComponent(
    tab_id: String,
    tab_name: String,
    connection: Option<SshConnection>,
) -> Element {
    let tab_id_clone = tab_id.clone();
    let on_keydown = move |event: dioxus::events::KeyboardEvent| {
        let key = event.key();
        let key_str = key.to_string();
        let key_data: Vec<u8> = match key_str.as_str() {
            "Enter" => vec![0x0D, 0x0A],
            "Backspace" => vec![0x08],
            "Tab" => vec![0x09],
            "ArrowUp" => vec![0x1B, 0x5B, 0x41],
            "ArrowDown" => vec![0x1B, 0x5B, 0x42],
            "ArrowLeft" => vec![0x1B, 0x5B, 0x44],
            "ArrowRight" => vec![0x1B, 0x5B, 0x43],
            "Escape" => vec![0x1B],
            _ => {
                if key_str.len() == 1 {
                    key_str.as_bytes().to_vec()
                } else {
                    return;
                }
            }
        };
        let session_manager = get_session_manager();
        let _ = session_manager.write_input(&tab_id_clone, &key_data);
    };
    let prompt = if let Some(ref conn) = connection {
        format!("{}@{}:~$", conn.username, conn.host)
    } else {
        format!("~ $")
    };
    rsx! {
        div {
            class: "terminal-container",
            flex: "1",
            display: "flex",
            flex_direction: "column",
            background_color: "#1E1E1E",
            div {
                class: "terminal",
                flex: "1",
                background_color: "#1E1E1E",
                color: "#CCCCCC",
                font_family: "Menlo, Monaco, 'Courier New', monospace",
                font_size: "14px",
                line_height: "1.5",
                white_space: "pre-wrap",
                word_break: "break-all",
                overflow: "auto",
                padding: "12px",
                tabindex: "0",
                onkeydown: on_keydown,
                div {
                    class: "terminal-line",
                    span {
                        color: "#4CAF50",
                        "{prompt} "
                    },
                    span { class: "cursor", " " }
                }
            }
        }
    }
}

/// 设置组件
#[component]
fn SettingsComponent(
    connections: Vec<SshConnection>,
    on_close: EventHandler<()>,
    on_edit_connection: EventHandler<String>,
    on_delete_connection: EventHandler<String>,
    on_add_connection: EventHandler<()>,
) -> Element {
    let mut selected_tab = use_signal(|| 0i32);
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
                            class: if *selected_tab.read() == 0 { "nav-item active" } else { "nav-item" },
                            onclick: move |_| selected_tab.set(0),
                            "终端设置"
                        },
                        div {
                            class: if *selected_tab.read() == 1 { "nav-item active" } else { "nav-item" },
                            onclick: move |_| selected_tab.set(1),
                            "连接管理"
                        },
                        div {
                            class: if *selected_tab.read() == 2 { "nav-item active" } else { "nav-item" },
                            onclick: move |_| selected_tab.set(2),
                            "导入导出"
                        },
                        div {
                            class: if *selected_tab.read() == 3 { "nav-item active" } else { "nav-item" },
                            onclick: move |_| selected_tab.set(3),
                            "同步设置"
                        }
                    },
                    div {
                        class: "settings-content",
                        if *selected_tab.read() == 0 {
                            TerminalSettings {
                                on_close: move |_| on_close.call(()),
                            }
                        } else if *selected_tab.read() == 1 {
                            ConnectionManagement {
                                connections: connections,
                                on_edit: on_edit_connection,
                                on_delete: on_delete_connection,
                                on_add: on_add_connection,
                            }
                        } else if *selected_tab.read() == 2 {
                            ImportExport {
                                on_close: move |_| on_close.call(()),
                            }
                        } else if *selected_tab.read() == 3 {
                            SyncSettings {
                                on_close: move |_| on_close.call(()),
                            }
                        }
                    }
                }
            }
        }
    }
}

/// 连接管理
#[component]
fn ConnectionManagement(
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
                div { class: "empty-state-small", "暂无保存的连接" }
            } else {
                div {
                    class: "connection-list-simple",
                    for conn in connections {
                        div {
                            class: "connection-item-simple",
                            div {
                                class: "connection-info",
                                div { class: "connection-name", "{conn.name}" },
                                div { class: "connection-host", "{conn.host}:{conn.port} @{conn.username}" }
                            }
                        }
                    }
                }
            }
        }
    }
}

/// 连接表单弹窗
#[component]
fn ConnectionFormModal(
    editing_connection: Option<SshConnection>,
    on_close: EventHandler<()>,
    on_save: EventHandler<SshConnection>,
) -> Element {
    let mut name = use_signal(|| editing_connection.as_ref().map(|c| c.name.clone()).unwrap_or_default());
    let mut host = use_signal(|| editing_connection.as_ref().map(|c| c.host.clone()).unwrap_or_default());
    let mut port = use_signal(|| editing_connection.as_ref().map(|c| c.port.to_string()).unwrap_or_else(|| "22".to_string()));
    let mut username = use_signal(|| editing_connection.as_ref().map(|c| c.username.clone()).unwrap_or_default());
    let auth_type = use_signal(|| editing_connection.as_ref().map(|c| c.auth_type.clone()).unwrap_or(crate::models::connection::AuthType::Password));

    rsx! {
        div {
            class: "modal-overlay",
            onclick: move |_| on_close.call(()),
            div {
                class: "modal-content connection-form",
                onclick: move |e| e.stop_propagation(),
                div {
                    class: "form-header",
                    h2 {
                        if editing_connection.is_some() { "编辑连接" } else { "添加连接" }
                    },
                    button {
                        class: "close-btn",
                        onclick: move |_| on_close.call(()),
                        "×"
                    }
                },
                div {
                    class: "form-body",
                    div {
                        class: "form-section",
                        h3 { "基本信息" },
                        div {
                            class: "form-group",
                            label { "连接名称" },
                            input {
                                class: "form-input",
                                value: "{name}",
                                oninput: move |e| name.set(e.value().clone()),
                                placeholder: "例如：生产服务器",
                            }
                        },
                        div {
                            class: "form-row",
                            div {
                                class: "form-group flex-3",
                                label { "主机地址" },
                                input {
                                    class: "form-input",
                                    value: "{host}",
                                    oninput: move |e| host.set(e.value().clone()),
                                    placeholder: "例如：192.168.1.100",
                                }
                            },
                            div {
                                class: "form-group flex-1",
                                label { "端口" },
                                input {
                                    class: "form-input",
                                    value: "{port}",
                                    oninput: move |e| port.set(e.value().clone()),
                                }
                            }
                        },
                        div {
                            class: "form-group",
                            label { "用户名" },
                            input {
                                class: "form-input",
                                value: "{username}",
                                oninput: move |e| username.set(e.value().clone()),
                                placeholder: "例如：root",
                            }
                        }
                    },
                    div {
                        class: "form-section",
                        h3 { "认证方式" },
                        div {
                            class: "form-group",
                            select {
                                class: "form-select",
                                option { value: "password", "密码认证" },
                                option { value: "key", "密钥认证" },
                                option { value: "key_with_password", "密钥+密码认证" }
                            }
                        }
                    },
                    div {
                        class: "form-actions",
                        button {
                            class: "btn btn-secondary",
                            onclick: move |_| on_close.call(()),
                            "取消"
                        },
                        button {
                            class: "btn btn-primary",
                            onclick: move |_| {
                                let port_num = port.read().parse().unwrap_or(22);
                                let now = chrono::Utc::now();
                                let conn = SshConnection {
                                    id: editing_connection.as_ref().map(|c| c.id.clone()).unwrap_or_else(|| uuid::Uuid::new_v4().to_string()),
                                    name: name.read().clone(),
                                    host: host.read().clone(),
                                    port: port_num,
                                    username: username.read().clone(),
                                    auth_type: auth_type.read().clone(),
                                    password: None,
                                    private_key_path: None,
                                    private_key_content: None,
                                    key_passphrase: None,
                                    jump_host: None,
                                    socks5_proxy: None,
                                    ssh_config_host: None,
                                    notes: None,
                                    group: None,
                                    color: None,
                                    created_at: editing_connection.as_ref().map(|c| c.created_at).unwrap_or(now),
                                    updated_at: now,
                                    version: editing_connection.as_ref().map(|c| c.version).unwrap_or(1),
                                };
                                on_save.call(conn);
                            },
                            "保存"
                        }
                    }
                }
            }
        }
    }
}
