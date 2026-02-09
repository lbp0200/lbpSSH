use dioxus::prelude::*;
use crate::models::connection::SshConnection;

/// 连接列表组件
#[component]
pub fn ConnectionList(
    connections: Vec<SshConnection>,
    on_select: EventHandler<String>,
    on_edit: EventHandler<String>,
    on_delete: EventHandler<String>,
) -> Element {
    let selected_id = use_signal(|| None::<String>);
    let is_empty = connections.is_empty();

    // Generate connection items
    let items: Vec<_> = connections.into_iter().map(|conn| {
        let conn_id = conn.id.clone();
        let is_sel = selected_id.read().as_ref() == Some(&conn_id);
        let on_select_cb = on_select.clone();
        let on_edit_cb = on_edit.clone();
        let on_delete_cb = on_delete.clone();
        let conn_id_for_edit = conn_id.clone();
        let conn_id_for_delete = conn_id.clone();
        let conn_id_for_select1 = conn_id.clone();
        let conn_id_for_select2 = conn_id.clone();
        let connection_name = conn.name.clone();
        let connection_host = conn.host.clone();

        rsx! {
            div {
                class: if is_sel { "connection-item selected" } else { "connection-item" },
                onmousedown: move |_| {},
                onclick: move |_| {
                    on_select_cb.call(conn_id_for_select1.clone());
                },
                ondoubleclick: move |_| {
                    on_select_cb.call(conn_id_for_select2.clone());
                },
                div {
                    class: "item-icon",
                    margin_right: "8px",
                    "🔐"
                },
                div {
                    class: "item-info",
                    flex: "1",
                    div {
                        class: "item-name",
                        font_size: "13px",
                        font_weight: "500",
                        color: "#FFFFFF",
                        "{connection_name}"
                    },
                    div {
                        class: "item-host",
                        font_size: "11px",
                        color: "#858585",
                        "{connection_host}:{conn.port}"
                    }
                },
                div {
                    class: "item-actions",
                    opacity: if is_sel { "1" } else { "0" },
                    transition: "opacity 0.2s",
                    button {
                        class: "action-btn",
                        border: "none",
                        background: "transparent",
                        cursor: "pointer",
                        font_size: "14px",
                        padding: "4px",
                        onmousedown: move |e| {
                            e.stop_propagation();
                        },
                        onclick: move |_| {
                            on_edit_cb.call(conn_id_for_edit.clone());
                        },
                        "✏️"
                    },
                    button {
                        class: "action-btn",
                        border: "none",
                        background: "transparent",
                        cursor: "pointer",
                        font_size: "14px",
                        padding: "4px",
                        onmousedown: move |e| {
                            e.stop_propagation();
                        },
                        onclick: move |_| {
                            on_delete_cb.call(conn_id_for_delete.clone());
                        },
                        "🗑️"
                    }
                }
            }
        }
    }).collect();

    // Return early with the rendered content
    if is_empty {
        return rsx! {
            div {
                class: "connection-list",
                width: "250px",
                height: "100%",
                background_color: "#252526",
                border_right: "1px solid #3C3C3C",
                display: "flex",
                flex_direction: "column",
                div {
                    class: "list-header",
                    padding: "12px",
                    border_bottom: "1px solid #3C3C3C",
                    display: "flex",
                    justify_content: "space-between",
                    align_items: "center",
                    h3 {
                        margin: "0",
                        font_size: "14px",
                        color: "#CCCCCC",
                        "连接"
                    }
                },
                div {
                    class: "list-content",
                    flex: "1",
                    overflow_y: "auto",
                    div {
                        class: "empty-state",
                        padding: "20px",
                        text_align: "center",
                        color: "#6A6A6A",
                        font_size: "13px",
                        "暂无保存的连接"
                    }
                }
            }
        };
    }

    rsx! {
        div {
            class: "connection-list",
            width: "250px",
            height: "100%",
            background_color: "#252526",
            border_right: "1px solid #3C3C3C",
            display: "flex",
            flex_direction: "column",
            div {
                class: "list-header",
                padding: "12px",
                border_bottom: "1px solid #3C3C3C",
                display: "flex",
                justify_content: "space-between",
                align_items: "center",
                h3 {
                    margin: "0",
                    font_size: "14px",
                    color: "#CCCCCC",
                    "连接"
                }
            },
            div {
                class: "list-content",
                flex: "1",
                overflow_y: "auto",
                for item in items {
                    {item}
                }
            }
        }
    }
}
