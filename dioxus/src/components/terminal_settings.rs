use dioxus::prelude::*;
use std::sync::Arc;
use std::sync::RwLock;
use crate::models::config::ConfigModel;

/// 终端设置组件
#[component]
pub fn TerminalSettings(on_close: EventHandler<()>) -> Element {
    let config = use_context::<Arc<RwLock<ConfigModel>>>();

    let config_guard = config.read().ok().expect("Failed to lock config");
    let initial_font_size = config_guard.terminal.font_size.to_string();
    let initial_font_family = config_guard.terminal.font_family.clone();
    let initial_background_color = config_guard.terminal.background_color.clone();
    let initial_foreground_color = config_guard.terminal.foreground_color.clone();
    let initial_cursor_color = config_guard.terminal.cursor_color.clone();
    let initial_opacity = config_guard.terminal.opacity.to_string();
    let initial_enable_bell = config_guard.terminal.enable_bell;
    let initial_enable_blinking_cursor = config_guard.terminal.enable_blinking_cursor;
    drop(config_guard); // Release guard before closures

    let mut font_size = use_signal(|| initial_font_size);
    let mut font_family = use_signal(|| initial_font_family);
    let mut background_color = use_signal(|| initial_background_color);
    let mut foreground_color = use_signal(|| initial_foreground_color);
    let mut cursor_color = use_signal(|| initial_cursor_color);
    let mut opacity = use_signal(|| initial_opacity);
    let mut enable_bell = use_signal(|| initial_enable_bell);
    let mut enable_blinking_cursor = use_signal(|| initial_enable_blinking_cursor);

    let on_save = move |_| {
        let mut config_guard = config.write().ok().unwrap();
        config_guard.terminal.font_size = font_size.read().parse().unwrap_or(14);
        config_guard.terminal.font_family = font_family.read().clone();
        config_guard.terminal.background_color = background_color.read().clone();
        config_guard.terminal.foreground_color = foreground_color.read().clone();
        config_guard.terminal.cursor_color = cursor_color.read().clone();
        config_guard.terminal.opacity = opacity.read().parse().unwrap_or(100);
        config_guard.terminal.enable_bell = *enable_bell.read();
        config_guard.terminal.enable_blinking_cursor = *enable_blinking_cursor.read();
        let _ = config_guard.save();
        on_close.call(());
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
                width: "500px",
                padding: "20px",
                max_height: "80vh",
                overflow_y: "auto",
                onclick: move |e| e.stop_propagation(),
                h2 {
                    color: "#FFFFFF",
                    font_size: "18px",
                    font_weight: "600",
                    margin_bottom: "20px",
                    "Terminal Settings"
                },
                // 字体设置
                div {
                    margin_bottom: "16px",
                    label {
                        display: "block",
                        color: "#AAAAAA",
                        font_size: "12px",
                        margin_bottom: "4px",
                        "Font Family"
                    },
                    input {
                        type: "text",
                        value: "{*font_family.read()}",
                        placeholder: "Menlo, Monaco, 'Courier New', monospace",
                        width: "100%",
                        padding: "8px",
                        border_radius: "4px",
                        border: "1px solid #3C3C3C",
                        background_color: "#1E1E1E",
                        color: "#FFFFFF",
                        font_size: "13px",
                        oninput: move |e| {
                            font_family.set(e.value());
                        }
                    }
                },
                // 字体大小
                div {
                    margin_bottom: "16px",
                    label {
                        display: "block",
                        color: "#AAAAAA",
                        font_size: "12px",
                        margin_bottom: "4px",
                        "Font Size (px)"
                    },
                    input {
                        type: "number",
                        value: "{*font_size.read()}",
                        min: "10",
                        max: "32",
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
                },
                // 背景颜色
                div {
                    margin_bottom: "16px",
                    label {
                        display: "block",
                        color: "#AAAAAA",
                        font_size: "12px",
                        margin_bottom: "4px",
                        "Background Color"
                    },
                    div {
                        display: "flex",
                        gap: "8px",
                        align_items: "center",
                        input {
                            type: "color",
                            value: "{*background_color.read()}",
                            width: "40px",
                            height: "32px",
                            border_radius: "4px",
                            border: "1px solid #3C3C3C",
                            cursor: "pointer",
                            oninput: move |e| {
                                background_color.set(e.value());
                            }
                        },
                        input {
                            type: "text",
                            value: "{*background_color.read()}",
                            width: "100px",
                            padding: "8px",
                            border_radius: "4px",
                            border: "1px solid #3C3C3C",
                            background_color: "#1E1E1E",
                            color: "#FFFFFF",
                            font_size: "13px",
                            oninput: move |e| {
                                background_color.set(e.value());
                            }
                        }
                    }
                },
                // 前景颜色
                div {
                    margin_bottom: "16px",
                    label {
                        display: "block",
                        color: "#AAAAAA",
                        font_size: "12px",
                        margin_bottom: "4px",
                        "Foreground Color"
                    },
                    div {
                        display: "flex",
                        gap: "8px",
                        align_items: "center",
                        input {
                            type: "color",
                            value: "{*foreground_color.read()}",
                            width: "40px",
                            height: "32px",
                            border_radius: "4px",
                            border: "1px solid #3C3C3C",
                            cursor: "pointer",
                            oninput: move |e| {
                                foreground_color.set(e.value());
                            }
                        },
                        input {
                            type: "text",
                            value: "{*foreground_color.read()}",
                            width: "100px",
                            padding: "8px",
                            border_radius: "4px",
                            border: "1px solid #3C3C3C",
                            background_color: "#1E1E1E",
                            color: "#FFFFFF",
                            font_size: "13px",
                            oninput: move |e| {
                                foreground_color.set(e.value());
                            }
                        }
                    }
                },
                // 光标颜色
                div {
                    margin_bottom: "16px",
                    label {
                        display: "block",
                        color: "#AAAAAA",
                        font_size: "12px",
                        margin_bottom: "4px",
                        "Cursor Color"
                    },
                    div {
                        display: "flex",
                        gap: "8px",
                        align_items: "center",
                        input {
                            type: "color",
                            value: "{*cursor_color.read()}",
                            width: "40px",
                            height: "32px",
                            border_radius: "4px",
                            border: "1px solid #3C3C3C",
                            cursor: "pointer",
                            oninput: move |e| {
                                cursor_color.set(e.value());
                            }
                        },
                        input {
                            type: "text",
                            value: "{*cursor_color.read()}",
                            width: "100px",
                            padding: "8px",
                            border_radius: "4px",
                            border: "1px solid #3C3C3C",
                            background_color: "#1E1E1E",
                            color: "#FFFFFF",
                            font_size: "13px",
                            oninput: move |e| {
                                cursor_color.set(e.value());
                            }
                        }
                    }
                },
                // 透明度
                div {
                    margin_bottom: "16px",
                    label {
                        display: "block",
                        color: "#AAAAAA",
                        font_size: "12px",
                        margin_bottom: "4px",
                        "Opacity (%)"
                    },
                    input {
                        type: "range",
                        min: "50",
                        max: "100",
                        value: "{*opacity.read()}",
                        width: "200px",
                        oninput: move |e| {
                            opacity.set(e.value());
                        }
                    },
                    span {
                        color: "#CCCCCC",
                        font_size: "13px",
                        margin_left: "8px",
                        "{*opacity.read()}%"
                    }
                },
                // 启用铃声
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
                            checked: *enable_bell.read(),
                            oninput: move |e| {
                                enable_bell.set(e.value().parse().unwrap_or(false));
                            }
                        },
                        "Enable Bell"
                    }
                },
                // 启用闪烁光标
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
                            checked: *enable_blinking_cursor.read(),
                            oninput: move |e| {
                                enable_blinking_cursor.set(e.value().parse().unwrap_or(false));
                            }
                        },
                        "Blinking Cursor"
                    }
                },
                // 预设主题
                div {
                    margin_bottom: "20px",
                    label {
                        display: "block",
                        color: "#AAAAAA",
                        font_size: "12px",
                        margin_bottom: "8px",
                        "Color Presets"
                    },
                    div {
                        display: "flex",
                        gap: "8px",
                        flex_wrap: "wrap",
                        button {
                            padding: "8px 12px",
                            border_radius: "4px",
                            border: "1px solid #3C3C3C",
                            background_color: "#1E1E1E",
                            color: "#CCCCCC",
                            font_size: "12px",
                            cursor: "pointer",
                            onclick: move |_| {
                                background_color.set("#1E1E1E".to_string());
                                foreground_color.set("#CCCCCC".to_string());
                                cursor_color.set("#CCCCCC".to_string());
                            },
                            "Default"
                        },
                        button {
                            padding: "8px 12px",
                            border_radius: "4px",
                            border: "1px solid #3C3C3C",
                            background_color: "#000000",
                            color: "#00FF00",
                            font_size: "12px",
                            cursor: "pointer",
                            onclick: move |_| {
                                background_color.set("#000000".to_string());
                                foreground_color.set("#00FF00".to_string());
                                cursor_color.set("#00FF00".to_string());
                            },
                            "Terminal Green"
                        },
                        button {
                            padding: "8px 12px",
                            border_radius: "4px",
                            border: "1px solid #3C3C3C",
                            background_color: "#282C34",
                            color: "#ABB2BF",
                            font_size: "12px",
                            cursor: "pointer",
                            onclick: move |_| {
                                background_color.set("#282C34".to_string());
                                foreground_color.set("#ABB2BF".to_string());
                                cursor_color.set("#528BFF".to_string());
                            },
                            "One Dark"
                        },
                        button {
                            padding: "8px 12px",
                            border_radius: "4px",
                            border: "1px solid #3C3C3C",
                            background_color: "#002B36",
                            color: "#839496",
                            font_size: "12px",
                            cursor: "pointer",
                            onclick: move |_| {
                                background_color.set("#002B36".to_string());
                                foreground_color.set("#839496".to_string());
                                cursor_color.set("#2AA198".to_string());
                            },
                            "Solarized"
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
                        class: "btn btn-primary",
                        padding: "8px 16px",
                        border_radius: "4px",
                        border: "none",
                        background_color: "#007ACC",
                        color: "#FFFFFF",
                        font_size: "13px",
                        cursor: "pointer",
                        onclick: on_save,
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

/// 终端设置按钮
#[component]
pub fn TerminalSettingsButton(on_click: EventHandler<()>) -> Element {
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
            "Terminal"
        }
    }
}
