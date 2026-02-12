use dioxus::prelude::*;
use std::collections::VecDeque;
use crate::ssh::session_manager::get_session_manager;
use crate::models::connection::SshConnection;

/// 终端类型
#[allow(dead_code)]
#[derive(Clone, Debug, PartialEq)]
pub enum TerminalType {
    Ssh(String), // SSH connection id
    Local,       // Local terminal
}

/// 终端行
#[derive(Clone, Debug)]
pub struct TerminalLine {
    pub text: String,
}

/// 终端状态
#[derive(Clone)]
pub struct TerminalState {
    pub lines: VecDeque<TerminalLine>,
    pub is_connected: bool,
    pub terminal_type: TerminalType,
}

impl Default for TerminalState {
    fn default() -> Self {
        Self {
            lines: VecDeque::with_capacity(1000),
            is_connected: false,
            terminal_type: TerminalType::Local,
        }
    }
}

/// 终端组件 - Flutter 风格布局
#[component]
pub fn Terminal(
    tab_id: String,
    tab_name: String,
    connection: Option<SshConnection>,
) -> Element {
    let state = use_signal(|| TerminalState::default());

    // 克隆 tab_id 用于闭包
    let tab_id_for_keyboard = tab_id.clone();
    let tab_id_for_status = tab_id.clone();

    // 处理键盘输入
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
            "F1" => vec![0x1B, 0x4F, 0x50],
            "F2" => vec![0x1B, 0x4F, 0x51],
            "F3" => vec![0x1B, 0x4F, 0x52],
            "F4" => vec![0x1B, 0x4F, 0x53],
            "F5" => vec![0x1B, 0x5B, 0x31, 0x35, 0x7E],
            "F6" => vec![0x1B, 0x5B, 0x31, 0x37, 0x7E],
            "F7" => vec![0x1B, 0x5B, 0x31, 0x38, 0x7E],
            "F8" => vec![0x1B, 0x5B, 0x31, 0x39, 0x7E],
            "F9" => vec![0x1B, 0x5B, 0x32, 0x30, 0x7E],
            "F10" => vec![0x1B, 0x5B, 0x32, 0x31, 0x7E],
            "F11" => vec![0x1B, 0x5B, 0x32, 0x33, 0x7E],
            "F12" => vec![0x1B, 0x5B, 0x32, 0x34, 0x7E],
            _ => {
                if key_str.len() == 1 {
                    key_str.as_bytes().to_vec()
                } else {
                    return;
                }
            }
        };

        let session_manager = get_session_manager();
        let _ = session_manager.write_input(&tab_id_for_keyboard, &key_data);
    };

    // 处理滚动
    let on_wheel = move |_event: dioxus::events::WheelEvent| {
        // 滚动功能暂时禁用
    };

    // 终端提示符
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
            // 终端内容区域
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
                onwheel: on_wheel,
                // 终端行
                for (index, line) in state.read().lines.iter().enumerate() {
                    div {
                        key: "{index}",
                        class: "terminal-line",
                        "{line.text}"
                    }
                },
                // 输入提示符
                div {
                    class: "terminal-line",
                    span {
                        color: "#4CAF50",
                        "{prompt} "
                    },
                    span {
                        class: "cursor",
                        " "
                    }
                }
            }
        }
    }
}
