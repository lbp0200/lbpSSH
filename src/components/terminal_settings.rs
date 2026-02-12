use dioxus::prelude::*;
use std::sync::Arc;
use std::sync::RwLock;
use crate::models::config::ConfigModel;

/// 可用的Shell列表
const AVAILABLE_SHELLS: &[&str] = &["/bin/bash", "/bin/zsh", "/bin/fish", "/usr/bin/zsh", "/usr/local/bin/fish", "powershell"];

/// 可用的编程字体列表
const AVAILABLE_FONTS: &[&str] = &[
    "Menlo",
    "Monaco",
    "Consolas",
    "Courier New",
    "Fira Code",
    "JetBrains Mono",
    "Source Code Pro",
    "Hack",
    "Inconsolata",
    "Roboto Mono",
    "Ubuntu Mono",
    "Cascadia Code",
    "Cascadia Mono",
    "SF Mono",
    "Meslo LG M",
    "Iosevka",
    "Droid Sans Mono",
    "ProggyClean",
    "Terminus",
    "Victor Mono",
    "Space Mono",
    "Nerd Font",
    "Noto Sans Mono",
    "MPlus Code",
    "IBM Plex Mono",
];

/// 可用字体大小预设
const FONT_SIZE_PRESETS: &[u16] = &[10, 12, 14, 16, 18, 20, 24, 28, 32];

/// 终端预览组件
#[component]
fn TerminalPreview(
    font_family: String,
    font_size: u16,
    font_weight: u16,
    letter_spacing: f64,
    line_height: f64,
    foreground_color: String,
    background_color: String,
) -> Element {
    rsx! {
        div {
            class: "terminal-preview",
            background_color: "{background_color}",
            padding: "16px",
            border_radius: "6px",
            border: "1px solid #3C3C3C",
            margin_bottom: "16px",
            div {
                class: "preview-title",
                color: "#888888",
                font_size: "12px",
                margin_bottom: "8px",
                "终端预览"
            },
            div {
                font_family: "{font_family}",
                font_size: "{font_size}px",
                font_weight: "{font_weight}",
                letter_spacing: "{letter_spacing}px",
                line_height: "{line_height}",
                color: "{foreground_color}",
                white_space: "pre-wrap",
                "user@hostname:~$ ls -la\ntotal 24\ndrwxr-xr-x  5 user  staff  170 Feb 12 10:30 Documents\ndrwxr-xr-x  5 user  staff  170 Feb 12 10:30 Downloads\n-rw-r--r--  1 user  staff  221 Feb 12 10:25 README.md\nuser@hostname:~$ echo 'Hello, Terminal!'\nHello, Terminal!\nuser@hostname:~$ "
            }
        }
    }
}

/// 终端设置组件
#[component]
pub fn TerminalSettings(on_close: EventHandler<()>) -> Element {
    let config = use_context::<Arc<RwLock<ConfigModel>>>();

    let config_guard = config.read().ok().expect("Failed to lock config");
    let initial_font_size = config_guard.terminal.font_size.to_string();
    let initial_font_family = config_guard.terminal.font_family.clone();
    let initial_font_weight = config_guard.terminal.font_weight.to_string();
    let initial_letter_spacing = config_guard.terminal.letter_spacing.to_string();
    let initial_line_height = config_guard.terminal.line_height.to_string();
    let initial_background_color = config_guard.terminal.background_color.clone();
    let initial_foreground_color = config_guard.terminal.foreground_color.clone();
    let initial_cursor_color = config_guard.terminal.cursor_color.clone();
    let initial_opacity = config_guard.terminal.opacity.to_string();
    let initial_shell_path = config_guard.terminal.shell_path.clone();
    let initial_enable_bell = config_guard.terminal.enable_bell;
    let initial_enable_blinking_cursor = config_guard.terminal.enable_blinking_cursor;
    drop(config_guard);

    let mut font_size = use_signal(|| initial_font_size);
    let mut font_family = use_signal(|| initial_font_family);
    let mut font_weight = use_signal(|| initial_font_weight);
    let mut letter_spacing = use_signal(|| initial_letter_spacing);
    let mut line_height = use_signal(|| initial_line_height);
    let mut background_color = use_signal(|| initial_background_color);
    let mut foreground_color = use_signal(|| initial_foreground_color);
    let mut cursor_color = use_signal(|| initial_cursor_color);
    let mut opacity = use_signal(|| initial_opacity);
    let mut shell_path = use_signal(|| initial_shell_path);
    let mut enable_bell = use_signal(|| initial_enable_bell);
    let mut enable_blinking_cursor = use_signal(|| initial_enable_blinking_cursor);

    let on_save = move |_| {
        let mut config_guard = config.write().ok().unwrap();
        config_guard.terminal.font_size = font_size.read().parse().unwrap_or(14);
        config_guard.terminal.font_family = font_family.read().clone();
        config_guard.terminal.font_weight = font_weight.read().parse().unwrap_or(400);
        config_guard.terminal.letter_spacing = letter_spacing.read().parse().unwrap_or(0.0);
        config_guard.terminal.line_height = line_height.read().parse().unwrap_or(1.2);
        config_guard.terminal.background_color = background_color.read().clone();
        config_guard.terminal.foreground_color = foreground_color.read().clone();
        config_guard.terminal.cursor_color = cursor_color.read().clone();
        config_guard.terminal.opacity = opacity.read().parse().unwrap_or(100);
        config_guard.terminal.shell_path = shell_path.read().clone();
        config_guard.terminal.enable_bell = *enable_bell.read();
        config_guard.terminal.enable_blinking_cursor = *enable_blinking_cursor.read();
        let _ = config_guard.save();
        on_close.call(());
    };

    let on_reset = move |_| {
        font_size.set("14".to_string());
        font_family.set("Menlo".to_string());
        font_weight.set("400".to_string());
        letter_spacing.set("0.0".to_string());
        line_height.set("1.2".to_string());
        background_color.set("#1E1E1E".to_string());
        foreground_color.set("#CCCCCC".to_string());
        cursor_color.set("#FFFFFF".to_string());
        opacity.set("100".to_string());
        shell_path.set(String::new());
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
                width: "600px",
                padding: "20px",
                max_height: "85vh",
                overflow_y: "auto",
                onclick: move |e| e.stop_propagation(),
                h2 {
                    color: "#FFFFFF",
                    font_size: "18px",
                    font_weight: "600",
                    margin_bottom: "20px",
                    "Terminal Settings"
                },
                // 终端预览
                TerminalPreview {
                    font_family: font_family.read().clone(),
                    font_size: font_size.read().parse().unwrap_or(14),
                    font_weight: font_weight.read().parse().unwrap_or(400),
                    letter_spacing: letter_spacing.read().parse().unwrap_or(0.0),
                    line_height: line_height.read().parse().unwrap_or(1.2),
                    foreground_color: foreground_color.read().clone(),
                    background_color: background_color.read().clone(),
                },
                // Shell 选择
                div {
                    margin_bottom: "16px",
                    label {
                        display: "block",
                        color: "#AAAAAA",
                        font_size: "12px",
                        margin_bottom: "4px",
                        "Shell"
                    },
                    select {
                        width: "100%",
                        padding: "8px",
                        border_radius: "4px",
                        border: "1px solid #3C3C3C",
                        background_color: "#1E1E1E",
                        color: "#FFFFFF",
                        font_size: "13px",
                        value: "{*shell_path.read()}",
                        oninput: move |e| shell_path.set(e.value()),
                        option { value: "", "系统默认Shell" },
                        for shell in AVAILABLE_SHELLS {
                            option { value: "{shell}", "{shell}" }
                        }
                    }
                },
                // 字体家族
                div {
                    margin_bottom: "16px",
                    label {
                        display: "block",
                        color: "#AAAAAA",
                        font_size: "12px",
                        margin_bottom: "4px",
                        "Font Family"
                    },
                    select {
                        width: "100%",
                        padding: "8px",
                        border_radius: "4px",
                        border: "1px solid #3C3C3C",
                        background_color: "#1E1E1E",
                        color: "#FFFFFF",
                        font_size: "13px",
                        value: "{*font_family.read()}",
                        oninput: move |e| font_family.set(e.value()),
                        for font in AVAILABLE_FONTS {
                            option { value: "{font}", "{font}" }
                        }
                    }
                },
                // 字体大小预设按钮
                div {
                    margin_bottom: "16px",
                    label {
                        display: "block",
                        color: "#AAAAAA",
                        font_size: "12px",
                        margin_bottom: "8px",
                        "Font Size Presets"
                    },
                    div {
                        display: "flex",
                        gap: "6px",
                        flex_wrap: "wrap",
                        for size in FONT_SIZE_PRESETS {
                            button {
                                padding: "6px 10px",
                                border_radius: "4px",
                                border: "1px solid #3C3C3C",
                                background_color: if *font_size.read() == size.to_string() { "#007ACC" } else { "#1E1E1E" },
                                color: "#FFFFFF",
                                font_size: "12px",
                                cursor: "pointer",
                                onclick: move |_| font_size.set(size.to_string()),
                                "{size}"
                            }
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
                        min: "8",
                        max: "48",
                        width: "100px",
                        padding: "8px",
                        border_radius: "4px",
                        border: "1px solid #3C3C3C",
                        background_color: "#1E1E1E",
                        color: "#FFFFFF",
                        font_size: "13px",
                        oninput: move |e| font_size.set(e.value()),
                    }
                },
                // 字重
                div {
                    margin_bottom: "16px",
                    label {
                        display: "block",
                        color: "#AAAAAA",
                        font_size: "12px",
                        margin_bottom: "4px",
                        "Font Weight ({font_weight.read()})"
                    },
                    input {
                        type: "range",
                        min: "100",
                        max: "900",
                        step: "100",
                        value: "{*font_weight.read()}",
                        width: "200px",
                        oninput: move |e| font_weight.set(e.value()),
                    },
                    div {
                        display: "flex",
                        justify_content: "space-between",
                        color: "#888888",
                        font_size: "11px",
                        width: "200px",
                        margin_top: "4px",
                        span { "Thin" }
                        span { "Bold" }
                    }
                },
                // 字母间距
                div {
                    margin_bottom: "16px",
                    label {
                        display: "block",
                        color: "#AAAAAA",
                        font_size: "12px",
                        margin_bottom: "4px",
                        "Letter Spacing (px)"
                    },
                    input {
                        type: "number",
                        step: "0.1",
                        value: "{*letter_spacing.read()}",
                        min: "0",
                        max: "10",
                        width: "100px",
                        padding: "8px",
                        border_radius: "4px",
                        border: "1px solid #3C3C3C",
                        background_color: "#1E1E1E",
                        color: "#FFFFFF",
                        font_size: "13px",
                        oninput: move |e| letter_spacing.set(e.value()),
                    }
                },
                // 行高
                div {
                    margin_bottom: "16px",
                    label {
                        display: "block",
                        color: "#AAAAAA",
                        font_size: "12px",
                        margin_bottom: "4px",
                        "Line Height"
                    },
                    input {
                        type: "number",
                        step: "0.1",
                        value: "{*line_height.read()}",
                        min: "0.8",
                        max: "3.0",
                        width: "100px",
                        padding: "8px",
                        border_radius: "4px",
                        border: "1px solid #3C3C3C",
                        background_color: "#1E1E1E",
                        color: "#FFFFFF",
                        font_size: "13px",
                        oninput: move |e| line_height.set(e.value()),
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
                            oninput: move |e| background_color.set(e.value()),
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
                            oninput: move |e| background_color.set(e.value()),
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
                            oninput: move |e| foreground_color.set(e.value()),
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
                            oninput: move |e| foreground_color.set(e.value()),
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
                            oninput: move |e| cursor_color.set(e.value()),
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
                            oninput: move |e| cursor_color.set(e.value()),
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
                        oninput: move |e| opacity.set(e.value()),
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
                    margin_bottom: "12px",
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
                            oninput: move |e| enable_bell.set(e.value().parse().unwrap_or(false)),
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
                            oninput: move |e| enable_blinking_cursor.set(e.value().parse().unwrap_or(false)),
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
                    justify_content: "space-between",
                    gap: "12px",
                    margin_top: "20px",
                    button {
                        class: "btn btn-secondary",
                        padding: "8px 16px",
                        border_radius: "4px",
                        border: "1px solid #3C3C3C",
                        background: "transparent",
                        color: "#CCCCCC",
                        font_size: "13px",
                        cursor: "pointer",
                        onclick: on_reset,
                        "Reset"
                    },
                    div {
                        display: "flex",
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
                            "Cancel"
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
                            onclick: on_save,
                            "Save"
                        }
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
