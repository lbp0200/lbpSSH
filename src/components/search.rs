use dioxus::prelude::*;

/// 搜索过滤组件
#[component]
pub fn ConnectionSearch(
    on_search: EventHandler<String>,
) -> Element {
    let mut search_text = use_signal(|| "".to_string());

    rsx! {
        div {
            class: "search-container",
            padding: "12px 16px",
            background_color: "#252526",
            border_bottom: "1px solid #3C3C3C",
            input {
                type: "text",
                placeholder: "Search connections...",
                width: "100%",
                padding: "8px 12px",
                border_radius: "4px",
                border: "1px solid #3C3C3C",
                background_color: "#1E1E1E",
                color: "#FFFFFF",
                font_size: "13px",
                value: "{*search_text.read()}",
                oninput: move |e| {
                    search_text.set(e.value());
                    on_search.call(e.value());
                }
            }
        }
    }
}

/// 分组过滤器组件
#[component]
pub fn GroupFilter(
    groups: Vec<String>,
    selected_group: String,
    on_select: EventHandler<String>,
) -> Element {
    rsx! {
        div {
            class: "filter-container",
            padding: "8px 16px",
            background_color: "#1E1E1E",
            border_bottom: "1px solid #3C3C3C",
            display: "flex",
            gap: "8px",
            overflow_x: "auto",
            button {
                class: "filter-btn",
                padding: "4px 12px",
                border_radius: "12px",
                border: if selected_group == "all" { "1px solid #007ACC" } else { "1px solid #3C3C3C" },
                background: if selected_group == "all" { "#007ACC" } else { "transparent" },
                color: if selected_group == "all" { "#FFFFFF" } else { "#CCCCCC" },
                font_size: "12px",
                cursor: "pointer",
                white_space: "nowrap",
                onclick: move |_| on_select.call("all".to_string()),
                "All"
            },
            for group in groups {
                button {
                    class: "filter-btn",
                    padding: "4px 12px",
                    border_radius: "12px",
                    border: if selected_group == group { "1px solid #007ACC" } else { "1px solid #3C3C3C" },
                    background: if selected_group == group { "#007ACC" } else { "transparent" },
                    color: if selected_group == group { "#FFFFFF" } else { "#CCCCCC" },
                    font_size: "12px",
                    cursor: "pointer",
                    white_space: "nowrap",
                    onclick: move |_| on_select.call(group.clone()),
                    "{group}"
                }
            }
        }
    }
}
