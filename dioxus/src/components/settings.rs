use dioxus::prelude::*;

/// 设置界面组件
#[component]
pub fn Settings(on_close: EventHandler<()>) -> Element {
    // 显示设置
    let mut dark_mode = use_signal(|| true);
    let mut font_size = use_signal(|| "14".to_string());

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
                width: "400px",
                padding: "20px",
                onclick: move |e| e.stop_propagation(),
                h2 {
                    color: "#FFFFFF",
                    margin_bottom: "20px",
                    font_size: "18px",
                    font_weight: "600",
                    "设置"
                },
                // 显示设置
                div {
                    margin_bottom: "20px",
                    h3 {
                        color: "#FFFFFF",
                        font_size: "14px",
                        margin_bottom: "12px",
                        "显示设置"
                    },
                    label {
                        display: "flex",
                        align_items: "center",
                        gap: "8px",
                        color: "#CCCCCC",
                        font_size: "13px",
                        cursor: "pointer",
                        input {
                            type: "checkbox",
                            checked: *dark_mode.read(),
                            oninput: move |e| {
                                dark_mode.set(e.value().parse().unwrap_or(false));
                            }
                        },
                        "深色模式"
                    },
                    div {
                        margin_top: "12px",
                        label {
                            display: "block",
                            color: "#AAAAAA",
                            font_size: "12px",
                            margin_bottom: "4px",
                            "字体大小"
                        },
                        input {
                            type: "text",
                            value: "{*font_size.read()}",
                            width: "100px",
                            padding: "8px",
                            border_radius: "4px",
                            border: "1px solid #3C3C3C",
                            background_color: "#1E1E1E",
                            color: "#FFFFFF",
                            font_size: "13px",
                            oninput: move |e| {
                                font_size.set(e.value());
                            }
                        }
                    }
                },
                // 按钮
                div {
                    display: "flex",
                    justify_content: "flex-end",
                    gap: "12px",
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
                        "取消"
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
                        onclick: move |_| on_close.call(()),
                        "保存"
                    }
                }
            }
        }
    }
}

/// 打开设置对话框
#[component]
pub fn SettingsButton(on_click: EventHandler<()>) -> Element {
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
            "设置"
        }
    }
}
