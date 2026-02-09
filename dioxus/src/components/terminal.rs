use dioxus::prelude::*;
use std::collections::VecDeque;
use crate::ssh::session_manager::get_session_manager;

/// 终端行
#[derive(Clone, Debug)]
pub struct TerminalLine {
    pub text: String,
}

/// 终端状态
#[derive(Clone)]
pub struct TerminalState {
    pub lines: VecDeque<TerminalLine>,
    pub cursor_row: usize,
    pub cursor_col: usize,
    pub width: usize,
    pub height: usize,
    pub is_connected: bool,
    pub connection_id: Option<String>,
    pub scroll_offset: usize,
}

impl Default for TerminalState {
    fn default() -> Self {
        Self {
            lines: VecDeque::with_capacity(1000),
            cursor_row: 0,
            cursor_col: 0,
            width: 80,
            height: 24,
            is_connected: false,
            connection_id: None,
            scroll_offset: 0,
        }
    }
}

/// ANSI 转义序列解析器
struct AnsiParser {
    buffer: String,
}

impl AnsiParser {
    fn new() -> Self {
        Self {
            buffer: String::new(),
        }
    }

    /// 解析字节数据，返回解析后的行
    fn parse(&mut self, data: &[u8]) -> Vec<TerminalLine> {
        let mut lines = Vec::new();
        let mut current_line = String::new();

        let mut i = 0;
        while i < data.len() {
            let byte = data[i];

            if byte == 0x1B && i + 1 < data.len() && data[i + 1] == 0x5B {
                // ANSI 转义序列开始
                i += 2;
                let mut param_start = i;

                // 收集参数
                while i < data.len() && data[i] >= 0x30 && data[i] <= 0x3F {
                    i += 1;
                }

                let params = if i > param_start {
                    std::str::from_utf8(&data[param_start..i]).unwrap_or("")
                } else {
                    ""
                };

                if i < data.len() {
                    let cmd = data[i] as char;
                    // 处理 ANSI 序列
                    match cmd {
                        'J' => {
                            // 清屏命令
                            if params == "2" || params == "2J" {
                                lines.clear();
                            }
                        }
                        'K' => {
                            // 清除行
                            if params == "0" || params == "" {
                                // 清除从光标到行尾
                            }
                        }
                        'H' | 'f' => {
                            // 光标位置
                        }
                        'A' | 'B' | 'C' | 'D' => {
                            // 光标移动 - 忽略
                        }
                        'm' => {
                            // SGR 样式 - 忽略
                        }
                        's' => {
                            // 保存光标位置
                        }
                        'u' => {
                            // 恢复光标位置
                        }
                        _ => {}
                    }
                }
            } else if byte == 0x0A {
                // 换行 (LF)
                if !current_line.is_empty() || !lines.is_empty() {
                    lines.push(TerminalLine { text: current_line.clone() });
                    current_line.clear();
                }
            } else if byte == 0x0D {
                // 回车 (CR) - 忽略
            } else if byte == 0x08 {
                // 退格
                if !current_line.is_empty() {
                    current_line.pop();
                }
            } else if byte >= 0x20 {
                // 可打印字符
                if let Ok(c) = std::str::from_utf8(&[byte]) {
                    current_line.push_str(c);
                }
            }

            i += 1;
        }

        // 添加最后一行
        if !current_line.is_empty() {
            lines.push(TerminalLine { text: current_line });
        }

        lines
    }
}

/// 终端组件
#[component]
pub fn Terminal() -> Element {
    let state = use_signal(|| TerminalState::default());
    let ansi_parser = use_signal(|| AnsiParser::new());

    // 处理键盘输入
    let on_keydown = move |event: dioxus::events::KeyboardEvent| {
        if !state.read().is_connected {
            return;
        }

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

        if let Some(id) = &state.read().connection_id {
            let session_manager = get_session_manager();
            let _ = session_manager.write_input(id, &key_data);
        }
    };

    // 处理滚动
    let on_wheel = move |_event: dioxus::events::WheelEvent| {
        // 滚动功能暂时禁用，需要正确的 API
    };

    rsx! {
        div {
            class: "terminal-container",
            width: "100%",
            height: "100%",
            display: "flex",
            flex_direction: "column",
            background_color: "#1E1E1E",
            // 终端头部
            div {
                class: "terminal-header",
                padding: "8px 16px",
                background_color: "#252526",
                border_bottom: "1px solid #3C3C3C",
                display: "flex",
                justify_content: "space-between",
                align_items: "center",
                div {
                    font_size: "13px",
                    color: "#FFFFFF",
                    if let Some(id) = &state.read().connection_id {
                        "Connection: {id}"
                    } else {
                        "Not connected"
                    }
                },
                div {
                    font_size: "11px",
                    color: if state.read().is_connected { "#4CAF50" } else { "#F44336" },
                    if state.read().is_connected { "Connected" } else { "Disconnected" }
                }
            },
            // 终端内容区域
            div {
                class: "terminal",
                flex: "1",
                background_color: "#1E1E1E",
                color: "#CCCCCC",
                font_family: "Menlo, Monaco, 'Courier New', monospace",
                font_size: "14px",
                line_height: "1.2",
                white_space: "pre",
                overflow: "auto",
                padding: "8px",
                tabindex: "0",
                onkeydown: on_keydown,
                onwheel: on_wheel,
                if !state.read().is_connected {
                    div {
                        display: "flex",
                        justify_content: "center",
                        align_items: "center",
                        height: "100%",
                        color: "#6A6A6A",
                        font_size: "14px",
                        "Select an SSH connection to start a session"
                    }
                } else {
                    // 终端行
                    for (index, line) in state.read().lines.iter().enumerate() {
                        div {
                            key: "{index}",
                            class: "terminal-line",
                            "{line.text}"
                        }
                    }
                }
            }
        }
    }
}
