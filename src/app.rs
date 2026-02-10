use dioxus::prelude::*;
use std::sync::Arc;
use std::sync::RwLock;
use crate::models::connection::SshConnection;
use crate::models::config::ConfigModel;
use crate::components::{ConnectionList, ConnectionForm, Terminal, Tabs, TabInfo, Settings};
use crate::ssh::session_manager::get_session_manager;

/// App 组件
#[component]
pub fn App() -> Element {
    // 从上下文获取配置
    let config = use_context::<Arc<RwLock<ConfigModel>>>();

    // 连接列表 - 初始从文件加载
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

    // Tabs
    let mut tabs = use_signal(|| Vec::<TabInfo>::new());
    let mut active_tab_id = use_signal(|| None::<String>);

    // 表单状态
    let mut show_form = use_signal(|| false);
    let mut editing_connection = use_signal(|| None::<Option<SshConnection>>);

    // 设置状态
    let mut show_settings = use_signal(|| false);

    // 错误状态
    let mut error_message = use_signal(|| None::<String>);
    let mut _success_message = use_signal(|| None::<String>);

    // 查找当前活动的 tab
    let active_tab = if let Some(active_id) = active_tab_id.read().clone() {
        tabs.read().iter().find(|t| t.id == active_id).cloned()
    } else {
        None
    };

    // 终端内容
    let terminal_content = match active_tab {
        Some(t) => {
            let conn_info = t.connection.clone();
            let conn_id = t.id.clone();
            Some(rsx! {
                div {
                    class: "terminal-header",
                    padding: "8px 16px",
                    background_color: "#252526",
                    border_bottom: "1px solid #3C3C3C",
                    display: "flex",
                    justify_content: "space-between",
                    align_items: "center",
                    div {
                        div {
                            font_size: "13px",
                            color: "#FFFFFF",
                            "{t.name}"
                        },
                        if let Some(conn) = &conn_info {
                            div {
                                font_size: "11px",
                                color: "#858585",
                                "{conn.host}:{conn.port} @ {conn.username}"
                            }
                        }
                    },
                    div {
                        display: "flex",
                        gap: "8px",
                        button {
                            class: "tab-action-btn",
                            font_size: "11px",
                            padding: "4px 8px",
                            border_radius: "3px",
                            border: "1px solid #3C3C3C",
                            background: "transparent",
                            color: "#CCCCCC",
                            cursor: "pointer",
                            onclick: move |_| {
                                // 连接功能
                            },
                            "连接"
                        }
                    }
                },
                Terminal {}
            })
        }
        None => {
            Some(rsx! {
                div {
                    class: "no-session",
                    display: "flex",
                    justify_content: "center",
                    align_items: "center",
                    height: "100%",
                    color: "#6A6A6A",
                    font_size: "14px",
                    "选择一个连接打开终端"
                }
            })
        }
    };

    let has_tabs = !tabs.read().is_empty();

    rsx! {
        div {
            class: "app",
            width: "100vw",
            height: "100vh",
            display: "flex",
            flex_direction: "column",
            background_color: "#1E1E1E",
            color: "#CCCCCC",
            // 顶部标签栏
            if has_tabs {
                Tabs {
                    tabs: tabs.read().clone(),
                    active_tab_id: active_tab_id.read().clone(),
                    on_select: move |id: String| {
                        active_tab_id.set(Some(id));
                    },
                    on_close: move |id: String| {
                        let session_manager = get_session_manager();
                        session_manager.disconnect(&id);

                        let mut tabs_vec = tabs.read().clone();
                        tabs_vec.retain(|t| t.id != id);
                        tabs.set(tabs_vec.clone());
                        if active_tab_id.read().as_ref() == Some(&id) {
                            active_tab_id.set(tabs_vec.last().map(|t| t.id.clone()));
                        }
                    },
                }
            }
            // 主内容区
            div {
                class: "main-content",
                flex: "1",
                display: "flex",
                overflow: "hidden",
                // 连接列表
                ConnectionList {
                    connections: connections.read().clone(),
                    on_select: move |id: String| {
                        let conn = connections.read().iter().find(|c| c.id == id).cloned();
                        let conn_name = conn.as_ref().map(|c| c.name.clone()).unwrap_or_default();
                        let tab = TabInfo {
                            id: id.clone(),
                            name: conn_name,
                            connection: conn,
                        };
                        let mut tabs_vec = tabs.read().clone();
                        if !tabs_vec.iter().any(|t| t.id == id) {
                            tabs_vec.push(tab);
                        }
                        tabs.set(tabs_vec);
                        active_tab_id.set(Some(id.clone()));

                        // 如果已有连接，先断开
                        let session_manager = get_session_manager();
                        let is_connected = session_manager.is_connected(&id);
                        if is_connected {
                            session_manager.disconnect(&id);
                        }
                    },
                    on_edit: move |id: String| {
                        let conn = connections.read().iter().find(|c| c.id == id).cloned();
                        editing_connection.set(Some(conn));
                        show_form.set(true);
                    },
                    on_delete: move |id: String| {
                        // 断开连接
                        let session_manager = get_session_manager();
                        session_manager.disconnect(&id);

                        let mut conns = connections.read().clone();
                        conns.retain(|c| c.id != id);
                        connections.set(conns.clone());

                        // 关闭对应的 tab
                        let mut tabs_vec = tabs.read().clone();
                        tabs_vec.retain(|t| t.id != id);
                        tabs.set(tabs_vec.clone());
                        if active_tab_id.read().as_ref() == Some(&id) {
                            active_tab_id.set(tabs_vec.last().map(|t| t.id.clone()));
                        }
                    },
                    on_connect: move |id: String| {
                        let session_manager = get_session_manager();
                        let is_connected = session_manager.is_connected(&id);
                        if is_connected {
                            session_manager.disconnect(&id);
                        } else {
                            // 选择连接并打开标签页
                            let conn = connections.read().iter().find(|c| c.id == id).cloned();
                            let conn_name = conn.as_ref().map(|c| c.name.clone()).unwrap_or_default();
                            let tab = TabInfo {
                                id: id.clone(),
                                name: conn_name,
                                connection: conn,
                            };
                            let mut tabs_vec = tabs.read().clone();
                            if !tabs_vec.iter().any(|t| t.id == id) {
                                tabs_vec.push(tab);
                            }
                            tabs.set(tabs_vec);
                            active_tab_id.set(Some(id));
                        }
                    },
                }
                // 终端区域
                div {
                    class: "terminal-area",
                    flex: "1",
                    if let Some(content) = terminal_content {
                        {content}
                    }
                }
            }
            // 底部工具栏
            div {
                class: "toolbar",
                padding: "8px 16px",
                background_color: "#252526",
                border_top: "1px solid #3C3C3C",
                display: "flex",
                gap: "12px",
                button {
                    class: "toolbar-btn",
                    padding: "6px 12px",
                    border: "none",
                    background: "#007ACC",
                    color: "#FFFFFF",
                    border_radius: "4px",
                    cursor: "pointer",
                    font_size: "13px",
                    onclick: move |_| {
                        editing_connection.set(None);
                        show_form.set(true);
                    },
                    "+ 添加连接"
                },
                button {
                    class: "toolbar-btn",
                    padding: "6px 12px",
                    border: "1px solid #3C3C3C",
                    background: "transparent",
                    color: "#CCCCCC",
                    border_radius: "4px",
                    cursor: "pointer",
                    font_size: "13px",
                    onclick: move |_| {
                        show_settings.set(true);
                    },
                    "设置"
                }
            }
            // 连接表单弹窗
            if *show_form.read() {
                ConnectionForm {
                    connection: editing_connection.read().clone().flatten(),
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

                        // 保存到文件
                        let Ok(config_guard) = config.read() else {
                            show_form.set(false);
                            return;
                        };
                        let connections_path = config_guard.connections_path.clone();
                        drop(config_guard);
                        if let Some(parent) = connections_path.parent() {
                            std::fs::create_dir_all(parent).ok();
                        }
                        if let Ok(content) = serde_json::to_string_pretty(&conns) {
                            std::fs::write(&connections_path, content).ok();
                        }

                        show_form.set(false);
                        editing_connection.set(None);

                        // 如果是新建连接，自动打开
                        if existing_idx.is_none() {
                            let tab = TabInfo {
                                id: conn_id.clone(),
                                name: conn_name,
                                connection: Some(conn),
                            };
                            let mut tabs_vec = tabs.read().clone();
                            tabs_vec.push(tab);
                            tabs.set(tabs_vec);
                            active_tab_id.set(Some(conn_id));
                        }
                    },
                    on_cancel: move |_| {
                        show_form.set(false);
                        editing_connection.set(None);
                    },
                }
            }
            // 设置弹窗
            if *show_settings.read() {
                Settings {
                    on_close: move |_| {
                        show_settings.set(false);
                    }
                }
            }
            // 错误提示
            if let Some(err) = error_message.read().clone() {
                div {
                    class: "error-toast",
                    position: "fixed",
                    bottom: "60px",
                    left: "50%",
                    transform: "translateX(-50%)",
                    padding: "12px 20px",
                    background_color: "#F44336",
                    color: "#FFFFFF",
                    border_radius: "4px",
                    font_size: "13px",
                    onclick: move |_| error_message.set(None),
                    cursor: "pointer",
                    "{err}"
                }
            }
        }
    }
}
