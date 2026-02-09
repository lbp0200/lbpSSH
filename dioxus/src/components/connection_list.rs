use dioxus::prelude::*;
use crate::models::connection::SshConnection;
use crate::ssh::session_manager::get_session_manager;

/// 连接项组件
#[component]
pub fn ConnectionItem(
    conn: SshConnection,
    is_selected: bool,
    on_select: EventHandler<String>,
    on_edit: EventHandler<String>,
    on_delete: EventHandler<String>,
    on_connect: EventHandler<String>,
) -> Element {
    let session_manager = get_session_manager();
    let is_connected = session_manager.is_connected(&conn.id);

    let conn_id = conn.id.clone();
    let conn_id_for_edit = conn.id.clone();
    let conn_id_for_delete = conn.id.clone();
    let conn_id_for_connect = conn.id.clone();

    let connection_color = conn.color.clone().unwrap_or_else(|| "#007ACC".to_string());

    let auth_icon = match conn.auth_type {
        crate::models::connection::AuthType::Password => "🔑",
        crate::models::connection::AuthType::Key => "🔐",
        crate::models::connection::AuthType::KeyWithPassword => "🔒",
        crate::models::connection::AuthType::SshConfig => "⚙️",
    };

    rsx! {
        div {
            class: if is_selected { "connection-item selected" } else { "connection-item" },
            onclick: move |_| {
                on_select.call(conn_id.clone());
            },
            // 颜色指示器
            div {
                class: "color-indicator",
                background_color: "{connection_color}",
            },
            // 连接状态指示器
            if is_connected {
                div {
                    class: "status-indicator connected",
                }
            },
            div {
                class: "item-icon",
                "{auth_icon}"
            },
            div {
                class: "item-info",
                div {
                    class: "item-name",
                    "{conn.name}"
                },
                div {
                    class: "item-host",
                    "{conn.host}:{conn.port}"
                }
            },
            // 悬停时显示快捷操作
            div {
                class: "item-quick-actions",
                button {
                    class: "quick-action-btn",
                    onmousedown: move |e| e.stop_propagation(),
                    onclick: move |_| {
                        on_connect.call(conn_id_for_connect.clone());
                    },
                    if is_connected { "Disconnect" } else { "Connect" }
                }
            }
        }
    }
}

/// 连接列表组件
#[component]
pub fn ConnectionList(
    connections: Vec<SshConnection>,
    on_select: EventHandler<String>,
    on_edit: EventHandler<String>,
    on_delete: EventHandler<String>,
    on_connect: EventHandler<String>,
) -> Element {
    let mut selected_id = use_signal(|| None::<String>);
    let is_empty = connections.is_empty();

    let connections_clone = connections.clone();
    let on_select_cb = on_select.clone();
    let on_edit_cb = on_edit.clone();
    let on_delete_cb = on_delete.clone();
    let on_connect_cb = on_connect.clone();

    // Generate connection items
    let items: Vec<_> = connections.into_iter().map(|conn| {
        let conn_id = conn.id.clone();
        let is_sel = selected_id.read().as_ref() == Some(&conn_id);
        let on_select_cb_inner = on_select_cb.clone();
        let on_edit_cb_inner = on_edit_cb.clone();
        let on_delete_cb_inner = on_delete_cb.clone();
        let on_connect_cb_inner = on_connect_cb.clone();

        rsx! {
            ConnectionItem {
                conn: conn,
                is_selected: is_sel,
                on_select: move |id: String| {
                    selected_id.set(Some(id.clone()));
                    on_select_cb_inner.call(id);
                },
                on_edit: move |id: String| {
                    on_edit_cb_inner.call(id);
                },
                on_delete: move |id: String| {
                    on_delete_cb_inner.call(id);
                },
                on_connect: move |id: String| {
                    on_connect_cb_inner.call(id);
                },
            }
        }
    }).collect();

    let connection_count = connections_clone.len();

    // Return early with the rendered content
    if is_empty {
        return rsx! {
            div {
                class: "connection-list",
                div {
                    class: "list-header",
                    h3 {
                        "Connections"
                    }
                },
                div {
                    class: "list-content",
                    div {
                        class: "empty-state",
                        "No saved connections"
                    }
                }
            }
        };
    }

    rsx! {
        div {
            class: "connection-list",
            div {
                class: "list-header",
                h3 {
                    "Connections"
                },
                span {
                    class: "connection-count",
                    "{connection_count} items"
                }
            },
            div {
                class: "list-content",
                for item in items {
                    {item}
                }
            }
        }
    }
}
