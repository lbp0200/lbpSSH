use dioxus::prelude::*;
use crate::models::connection::SshConnection;

/// 错误详情
#[derive(Debug, Clone, PartialEq)]
pub struct ErrorDetail {
    pub title: String,
    pub message: String,
    pub error_code: Option<String>,
    pub suggestion: String,
    pub severity: ErrorSeverity,
}

#[derive(Debug, Clone, PartialEq)]
pub enum ErrorSeverity {
    Info,
    Warning,
    Error,
    Critical,
}

/// 错误详情对话框组件
#[component]
pub fn ErrorDialog(
    error: ErrorDetail,
    on_close: EventHandler<()>,
) -> Element {
    let severity_class = match error.severity {
        ErrorSeverity::Info => "error-dialog info",
        ErrorSeverity::Warning => "error-dialog warning",
        ErrorSeverity::Error => "error-dialog error",
        ErrorSeverity::Critical => "error-dialog critical",
    };

    let icon = match error.severity {
        ErrorSeverity::Info => "ℹ️",
        ErrorSeverity::Warning => "⚠️",
        ErrorSeverity::Error => "❌",
        ErrorSeverity::Critical => "🛑",
    };

    let severity_text = match error.severity {
        ErrorSeverity::Info => "信息",
        ErrorSeverity::Warning => "警告",
        ErrorSeverity::Error => "错误",
        ErrorSeverity::Critical => "严重错误",
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
            z_index: "2000",
            onclick: move |_| on_close.call(()),
            div {
                class: "{severity_class}",
                border_radius: "8px",
                width: "500px",
                max_width: "90vw",
                max_height: "90vh",
                overflow_y: "auto",
                background_color: "#2D2D2D",
                onclick: move |e| e.stop_propagation(),
                // 头部
                div {
                    class: "error-dialog-header",
                    padding: "16px 20px",
                    border_bottom: "1px solid #3C3C3C",
                    display: "flex",
                    align_items: "center",
                    gap: "12px",
                    div {
                        class: "error-icon",
                        font_size: "24px",
                        "{icon}"
                    },
                    div {
                        flex: "1",
                        h3 {
                            color: "#FFFFFF",
                            font_size: "16px",
                            font_weight: "600",
                            margin: "0",
                            "{error.title}"
                        },
                        span {
                            class: "error-severity",
                            font_size: "12px",
                            color: "#888888",
                            "{severity_text}"
                        }
                    },
                    button {
                        class: "close-btn",
                        background: "transparent",
                        border: "none",
                        color: "#888888",
                        font_size: "20px",
                        cursor: "pointer",
                        onclick: move |_| on_close.call(()),
                        "×"
                    }
                },
                // 内容
                div {
                    class: "error-dialog-content",
                    padding: "20px",
                    // 错误代码
                    if let Some(code) = &error.error_code {
                        div {
                            class: "error-code",
                            margin_bottom: "16px",
                            code {
                                background_color: "#1E1E1E",
                                padding: "4px 8px",
                                border_radius: "4px",
                                font_size: "12px",
                                color: "#007ACC",
                                "错误代码: {code}"
                            }
                        }
                    },
                    // 错误信息
                    div {
                        class: "error-message",
                        margin_bottom: "16px",
                        p {
                            color: "#CCCCCC",
                            font_size: "14px",
                            line_height: "1.6",
                            margin: "0",
                            "{error.message}"
                        }
                    },
                    // 建议
                    div {
                        class: "error-suggestion",
                        background_color: "#1E1E1E",
                        border_radius: "6px",
                        padding: "12px 16px",
                        margin_top: "16px",
                        div {
                            class: "suggestion-label",
                            color: "#4CAF50",
                            font_size: "12px",
                            font_weight: "600",
                            margin_bottom: "8px",
                            "💡 建议解决方案"
                        },
                        p {
                            color: "#AAAAAA",
                            font_size: "13px",
                            line_height: "1.5",
                            margin: "0",
                            "{error.suggestion}"
                        }
                    }
                },
                // 底部按钮
                div {
                    class: "error-dialog-footer",
                    padding: "16px 20px",
                    border_top: "1px solid #3C3C3C",
                    display: "flex",
                    justify_content: "flex-end",
                    gap: "12px",
                    button {
                        class: "btn btn-primary",
                        padding: "8px 20px",
                        border_radius: "4px",
                        border: "none",
                        background_color: "#007ACC",
                        color: "#FFFFFF",
                        font_size: "14px",
                        cursor: "pointer",
                        onclick: move |_| on_close.call(()),
                        "确定"
                    }
                }
            }
        }
    }
}

/// SSH 连接错误帮助工具
pub struct SshErrorHelper;

impl SshErrorHelper {
    /// 根据错误类型创建错误详情
    pub fn create_error_detail(error_type: &str, connection: Option<&SshConnection>, detail: Option<String>) -> ErrorDetail {
        match error_type {
            "auth_failed" => ErrorDetail {
                title: "认证失败".to_string(),
                message: format!(
                    "无法连接到 {}@{}:{}，认证失败。{}",
                    connection.map(|c| c.username.as_str()).unwrap_or("未知用户"),
                    connection.map(|c| c.host.as_str()).unwrap_or("未知主机"),
                    connection.map(|c| c.port).unwrap_or(22),
                    detail.unwrap_or_else(|| "用户名或密码/密钥错误".to_string())
                ),
                error_code: Some("SSH_AUTH_FAILED".to_string()),
                suggestion: "请检查：\n1. 用户名是否正确\n2. 密码是否正确\n3. 如果使用密钥，请确保私钥文件路径正确且密钥未加密或密码正确\n4. 服务器是否允许密码登录或密钥登录".to_string(),
                severity: ErrorSeverity::Error,
            },
            "connection_timeout" => ErrorDetail {
                title: "连接超时".to_string(),
                message: format!(
                    "连接到 {}:{} 超时",
                    connection.map(|c| c.host.as_str()).unwrap_or("未知主机"),
                    connection.map(|c| c.port).unwrap_or(22)
                ),
                error_code: Some("SSH_CONNECTION_TIMEOUT".to_string()),
                suggestion: "请检查：\n1. 主机地址是否正确\n2. 主机是否在线\n3. SSH 服务是否正在运行（默认端口 22）\n4. 防火墙是否阻止了连接\n5. 网络是否正常".to_string(),
                severity: ErrorSeverity::Warning,
            },
            "host_unreachable" => ErrorDetail {
                title: "主机不可达".to_string(),
                message: format!(
                    "无法连接到 {}:{}，主机不可达",
                    connection.map(|c| c.host.as_str()).unwrap_or("未知主机"),
                    connection.map(|c| c.port).unwrap_or(22)
                ),
                error_code: Some("SSH_HOST_UNREACHABLE".to_string()),
                suggestion: "请检查：\n1. 主机地址是否正确\n2. 主机是否开机\n3. 网络连接是否正常\n4. DNS 是否能解析该主机名".to_string(),
                severity: ErrorSeverity::Critical,
            },
            "connection_refused" => ErrorDetail {
                title: "连接被拒绝".to_string(),
                message: format!(
                    "连接到 {}:{} 被拒绝",
                    connection.map(|c| c.host.as_str()).unwrap_or("未知主机"),
                    connection.map(|c| c.port).unwrap_or(22)
                ),
                error_code: Some("SSH_CONNECTION_REFUSED".to_string()),
                suggestion: "请检查：\n1. SSH 服务是否正在运行\n2. SSH 端口是否正确\n3. SSH 服务配置是否允许连接\n4. 防火墙是否允许该端口".to_string(),
                severity: ErrorSeverity::Error,
            },
            "jump_host_failed" => ErrorDetail {
                title: "跳板机连接失败".to_string(),
                message: format!(
                    "无法通过跳板机 {}:{} 连接",
                    connection.and_then(|c| c.jump_host.as_ref().map(|jh| jh.host.as_str())).unwrap_or("未知"),
                    connection.and_then(|c| c.jump_host.as_ref().map(|jh| jh.port)).unwrap_or(22)
                ),
                error_code: Some("SSH_JUMP_HOST_FAILED".to_string()),
                suggestion: "请检查：\n1. 跳板机连接配置是否正确\n2. 跳板机是否在线\n3. 跳板机认证信息是否正确".to_string(),
                severity: ErrorSeverity::Error,
            },
            "proxy_failed" => ErrorDetail {
                title: "代理连接失败".to_string(),
                message: format!(
                    "无法通过 SOCKS5 代理 {} 连接",
                    connection.and_then(|c| c.socks5_proxy.as_ref().map(|p| p.host.as_str())).unwrap_or("未知代理")
                ),
                error_code: Some("SSH_PROXY_FAILED".to_string()),
                suggestion: "请检查：\n1. 代理服务器地址和端口是否正确\n2. 代理服务器是否在线\n3. 代理是否需要认证\n4. 防火墙是否允许连接到代理".to_string(),
                severity: ErrorSeverity::Error,
            },
            "key_parse_error" => ErrorDetail {
                title: "密钥解析错误".to_string(),
                message: detail.unwrap_or("无法解析私钥文件".to_string()),
                error_code: Some("SSH_KEY_PARSE_ERROR".to_string()),
                suggestion: "请检查：\n1. 私钥文件路径是否正确\n2. 私钥文件格式是否正确（OpenSSH 格式）\n3. 密钥是否损坏\n4. 如果密钥已加密，密钥密码是否正确".to_string(),
                severity: ErrorSeverity::Error,
            },
            "ssh_config_error" => ErrorDetail {
                title: "SSH Config 错误".to_string(),
                message: detail.unwrap_or("无法解析 SSH Config".to_string()),
                error_code: Some("SSH_CONFIG_ERROR".to_string()),
                suggestion: "请检查：\n1. SSH Config 文件路径是否正确\n2. 文件格式是否符合 SSH Config 标准\n3. 目标主机配置是否正确".to_string(),
                severity: ErrorSeverity::Error,
            },
            "unknown_error" | _ => ErrorDetail {
                title: "未知错误".to_string(),
                message: detail.unwrap_or("发生未知错误".to_string()),
                error_code: Some("SSH_UNKNOWN_ERROR".to_string()),
                suggestion: "请尝试：\n1. 检查网络连接\n2. 确认服务器状态\n3. 验证认证信息\n4. 如果问题持续，请联系支持".to_string(),
                severity: ErrorSeverity::Error,
            },
        }
    }
}
