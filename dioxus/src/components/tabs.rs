use dioxus::prelude::*;
use crate::models::connection::SshConnection;

/// Tab 信息
#[derive(Clone, PartialEq)]
pub struct TabInfo {
    pub id: String,
    pub name: String,
    pub connection: Option<SshConnection>,
}

/// 标签页组件
#[component]
pub fn Tabs(
    tabs: Vec<TabInfo>,
    active_tab_id: Option<String>,
    on_select: EventHandler<String>,
    on_close: EventHandler<String>,
) -> Element {
    let active_id = active_tab_id.clone();

    // Pre-compute items before rsx!
    let items: Vec<_> = tabs.into_iter().map(|tab| {
        let tab_id = tab.id.clone();
        let is_active = active_id.as_ref() == Some(&tab_id);
        let on_select_cb = on_select.clone();
        let on_close_cb = on_close.clone();
        let tab_id_for_close = tab_id.clone();
        let tab_name = tab.name.clone();

        rsx! {
            div {
                class: if is_active { "tab-item active" } else { "tab-item" },
                display: "flex",
                align_items: "center",
                height: "100%",
                padding: "0 12px",
                border_right: "1px solid #3C3C3C",
                cursor: "pointer",
                background_color: if is_active { "#1E1E1E" } else { "transparent" },
                color: if is_active { "#FFFFFF" } else { "#858585" },
                onclick: move |_| {
                    on_select_cb.call(tab_id.clone());
                },
                span {
                    class: "tab-name",
                    font_size: "13px",
                    margin_right: "8px",
                    "{tab_name}"
                },
                span {
                    class: "tab-close",
                    font_size: "14px",
                    color: "#858585",
                    padding: "2px",
                    border_radius: "4px",
                    onclick: move |e| {
                        e.stop_propagation();
                        on_close_cb.call(tab_id_for_close.clone());
                    },
                    "×"
                }
            }
        }
    }).collect();

    rsx! {
        div {
            class: "tabs-bar",
            height: "36px",
            background_color: "#252526",
            border_bottom: "1px solid #3C3C3C",
            display: "flex",
            align_items: "center",
            div {
                class: "add-tab-btn",
                padding: "6px 12px",
                cursor: "pointer",
                color: "#858585",
                font_size: "16px",
                "+"
            },
            for item in items {
                {item}
            }
        }
    }
}
