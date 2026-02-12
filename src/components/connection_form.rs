use dioxus::prelude::*;
use crate::models::connection::{SshConnection, AuthType};
use uuid::Uuid;
use std::fs;
use std::path::Path;

/// 解析 ~/.ssh/config 文件中的主机列表
pub fn parse_ssh_config_hosts() -> Vec<String> {
    let mut hosts = Vec::new();

    // 获取主目录下的 .ssh/config 文件
    if let Ok(home) = std::env::var("HOME") {
        let config_path = Path::new(&home).join(".ssh").join("config");

        if let Ok(content) = fs::read_to_string(&config_path) {
            for line in content.lines() {
                let trimmed = line.trim();
                if trimmed.is_empty() || trimmed.starts_with('#') {
                    continue;
                }

                // 解析 Host 指令
                if let Some(host_name) = trimmed.strip_prefix("Host ") {
                    if !host_name.trim().is_empty() {
                        // 只添加简单的 host 别名（排除通配符）
                        if !host_name.contains('*') && !host_name.contains('?') {
                            hosts.push(host_name.trim().to_string());
                        }
                    }
                }
            }
        }
    }

    hosts
}

/// 连接表单组件
#[component]
pub fn ConnectionForm(
    connection: Option<SshConnection>,
    on_save: EventHandler<SshConnection>,
    on_cancel: EventHandler<()>,
) -> Element {
    let editing = connection.is_some();

    let mut name = use_signal(|| connection.as_ref().map(|c| c.name.clone()).unwrap_or_default());
    let mut host = use_signal(|| connection.as_ref().map(|c| c.host.clone()).unwrap_or_default());
    let mut port = use_signal(|| connection.as_ref().map(|c| c.port.to_string()).unwrap_or_else(|| "22".to_string()));
    let mut username = use_signal(|| connection.as_ref().map(|c| c.username.clone()).unwrap_or_default());
    let mut auth_type = use_signal(|| connection.as_ref().map(|c| c.auth_type.clone()).unwrap_or(AuthType::Password));
    let mut password = use_signal(|| String::new());
    let mut private_key_path = use_signal(|| String::new());
    let private_key_content = use_signal(|| String::new());
    let mut key_passphrase = use_signal(|| String::new());
    let mut notes = use_signal(|| connection.as_ref().and_then(|c| c.notes.clone()).unwrap_or_default());

    // 跳板机状态
    let mut use_jump_host = use_signal(|| connection.as_ref().and_then(|c| c.jump_host.clone()).is_some());
    let mut jump_host = use_signal(|| {
        connection.as_ref()
            .and_then(|c| c.jump_host.clone())
            .unwrap_or_default()
    });
    let mut jump_host_password = use_signal(|| String::new());
    let mut jump_host_key_path = use_signal(|| String::new());

    // SOCKS5代理状态
    let mut use_socks5_proxy = use_signal(|| connection.as_ref().and_then(|c| c.socks5_proxy.clone()).is_some());
    let mut socks5_proxy = use_signal(|| {
        connection.as_ref()
            .and_then(|c| c.socks5_proxy.clone())
            .unwrap_or_default()
    });
    let mut socks5_password = use_signal(|| String::new());

    // SSH Config 主机列表
    let ssh_config_hosts: Vec<String> = parse_ssh_config_hosts();
    let mut selected_ssh_config_host = use_signal(|| connection.as_ref().and_then(|c| c.ssh_config_host.clone()).unwrap_or_default());
    let mut use_ssh_config = use_signal(|| connection.as_ref().and_then(|c| c.ssh_config_host.clone()).is_some());

    let form_valid = !name.read().trim().is_empty()
        && ((!*use_ssh_config.read() && !host.read().trim().is_empty())
            || (*use_ssh_config.read() && !selected_ssh_config_host.read().is_empty()))
        && !username.read().trim().is_empty();

    let current_auth_type = auth_type.read().clone();
    let current_jump_host_auth_type = jump_host.read().auth_type.clone();
    let show_password_fields = current_auth_type == AuthType::Password;
    let show_key_fields = current_auth_type == AuthType::Key || current_auth_type == AuthType::KeyWithPassword;
    let show_passphrase_field = current_auth_type == AuthType::KeyWithPassword;

    let show_jump_host_password = current_jump_host_auth_type == AuthType::Password;
    let show_jump_host_key = current_jump_host_auth_type == AuthType::Key || current_jump_host_auth_type == AuthType::KeyWithPassword;

    let editing_conn = connection.clone();

    rsx! {
        div {
            class: "connection-form-modal",
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
            onclick: move |_| {},
            div {
                class: "connection-form",
                background_color: "#252526",
                border_radius: "8px",
                width: "600px",
                max_height: "85vh",
                overflow_y: "auto",
                box_shadow: "0 4px 20px rgba(0, 0, 0, 0.4)",
                div {
                    class: "form-header",
                    padding: "16px 20px",
                    border_bottom: "1px solid #3C3C3C",
                    display: "flex",
                    justify_content: "space-between",
                    align_items: "center",
                    h2 {
                        margin: "0",
                        font_size: "16px",
                        color: "#FFFFFF",
                        if editing { "编辑连接" } else { "添加连接" }
                    },
                    button {
                        class: "close-btn",
                        border: "none",
                        background: "transparent",
                        font_size: "20px",
                        color: "#858585",
                        cursor: "pointer",
                        onclick: move |_| on_cancel.call(()),
                        "×"
                    }
                },
                form {
                    class: "form-body",
                    padding: "20px",
                    // 基本信息
                    div {
                        class: "form-section-title",
                        font_size: "14px",
                        color: "#FFFFFF",
                        font_weight: "600",
                        margin_bottom: "12px",
                        "基本设置"
                    },
                    div {
                        class: "form-group",
                        label {
                            display: "block",
                            margin_bottom: "6px",
                            font_size: "13px",
                            color: "#CCCCCC",
                            "连接名称"
                        },
                        input {
                            class: "form-input",
                            r#type: "text",
                            value: "{name.read()}",
                            oninput: move |e| name.set(e.value().clone()),
                            placeholder: "例如：生产服务器",
                        }
                    },
                    // SSH Config 选择
                    div {
                        class: "form-group",
                        label {
                            display: "flex",
                            align_items: "center",
                            gap: "8px",
                            margin_bottom: "6px",
                            font_size: "13px",
                            color: "#CCCCCC",
                            cursor: "pointer",
                            input {
                                r#type: "checkbox",
                                checked: *use_ssh_config.read(),
                                oninput: move |e| {
                                    use_ssh_config.set(e.value().parse().unwrap_or(false));
                                    if *use_ssh_config.read() {
                                        host.set(String::new());
                                    }
                                }
                            },
                            "使用 SSH Config 主机"
                        },
                        if *use_ssh_config.read() {
                            select {
                                class: "form-select",
                                value: "{selected_ssh_config_host.read()}",
                                oninput: move |e| {
                                    selected_ssh_config_host.set(e.value().clone());
                                },
                                option { value: "", "请选择主机..." },
                                for ssh_host in &ssh_config_hosts {
                                    option { value: "{ssh_host}", "{ssh_host}" }
                                }
                            }
                        }
                    },
                    // 主机和端口
                    if !*use_ssh_config.read() {
                        div {
                            class: "form-row",
                            div {
                                class: "form-group",
                                flex: "3",
                                label {
                                    display: "block",
                                    margin_bottom: "6px",
                                    font_size: "13px",
                                    color: "#CCCCCC",
                                    "主机地址"
                                },
                                input {
                                    class: "form-input",
                                    r#type: "text",
                                    value: "{host.read()}",
                                    oninput: move |e| host.set(e.value().clone()),
                                    placeholder: "例如：192.168.1.100",
                                }
                            },
                            div {
                                class: "form-group",
                                flex: "1",
                                label {
                                    display: "block",
                                    margin_bottom: "6px",
                                    font_size: "13px",
                                    color: "#CCCCCC",
                                    "端口"
                                },
                                input {
                                    class: "form-input",
                                    r#type: "text",
                                    value: "{port.read()}",
                                    oninput: move |e| port.set(e.value().clone()),
                                }
                            }
                        },
                    },
                    div {
                        class: "form-group",
                        label {
                            display: "block",
                            margin_bottom: "6px",
                            font_size: "13px",
                            color: "#CCCCCC",
                            "用户名"
                        },
                        input {
                            class: "form-input",
                            r#type: "text",
                            value: "{username.read()}",
                            oninput: move |e| username.set(e.value().clone()),
                            placeholder: "例如：root",
                        }
                    },
                    div {
                        class: "form-group",
                        label {
                            display: "block",
                            margin_bottom: "6px",
                            font_size: "13px",
                            color: "#CCCCCC",
                            "认证方式"
                        },
                        select {
                            class: "form-select",
                            value: "{current_auth_type:?}",
                            oninput: move |e| {
                                let value = match e.value().as_str() {
                                    "Password" => AuthType::Password,
                                    "Key" => AuthType::Key,
                                    "KeyWithPassword" => AuthType::KeyWithPassword,
                                    "SshConfig" => AuthType::SshConfig,
                                    _ => AuthType::Password,
                                };
                                auth_type.set(value);
                            },
                            option { value: "Password", "密码认证" }
                            option { value: "Key", "密钥认证" }
                            option { value: "KeyWithPassword", "密钥+密码认证" }
                            option { value: "SshConfig", "SSH Config" }
                        }
                    },
                    if show_password_fields {
                        div {
                            class: "form-group",
                            label {
                                display: "block",
                                margin_bottom: "6px",
                                font_size: "13px",
                                color: "#CCCCCC",
                                "密码"
                            },
                            input {
                                class: "form-input",
                                r#type: "password",
                                value: "{password.read()}",
                                oninput: move |e| password.set(e.value().clone()),
                            }
                        }
                    },
                    if show_key_fields {
                        div {
                            class: "form-group",
                            label {
                                display: "block",
                                margin_bottom: "6px",
                                font_size: "13px",
                                color: "#CCCCCC",
                                "私钥文件"
                            },
                            input {
                                class: "form-input",
                                r#type: "text",
                                value: "{private_key_path.read()}",
                                oninput: move |e| private_key_path.set(e.value().clone()),
                                placeholder: "~/.ssh/id_rsa",
                            }
                        }
                    },
                    if show_passphrase_field {
                        div {
                            class: "form-group",
                            label {
                                display: "block",
                                margin_bottom: "6px",
                                font_size: "13px",
                                color: "#CCCCCC",
                                "密钥密码"
                            },
                            input {
                                class: "form-input",
                                r#type: "password",
                                value: "{key_passphrase.read()}",
                                oninput: move |e| key_passphrase.set(e.value().clone()),
                            }
                        }
                    },
                    // 跳板机配置
                    div {
                        class: "form-divider",
                        margin: "16px 0",
                        border_bottom: "1px solid #3C3C3C"
                    },
                    div {
                        class: "form-section-title",
                        font_size: "14px",
                        color: "#FFFFFF",
                        font_weight: "600",
                        margin_bottom: "12px",
                        "跳板机配置"
                    },
                    div {
                        class: "form-group",
                        label {
                            display: "flex",
                            align_items: "center",
                            gap: "8px",
                            margin_bottom: "6px",
                            font_size: "13px",
                            color: "#CCCCCC",
                            cursor: "pointer",
                            input {
                                r#type: "checkbox",
                                checked: *use_jump_host.read(),
                                oninput: move |e| {
                                    use_jump_host.set(e.value().parse().unwrap_or(false));
                                }
                            },
                            "使用跳板机"
                        },
                    },
                    if *use_jump_host.read() {
                        div {
                            class: "form-indent",
                            div {
                                class: "form-row",
                                div {
                                    class: "form-group",
                                    flex: "3",
                                    label {
                                        display: "block",
                                        margin_bottom: "6px",
                                        font_size: "13px",
                                        color: "#AAAAAA",
                                        "跳板机地址"
                                    },
                                    input {
                                        class: "form-input",
                                        r#type: "text",
                                        value: "{jump_host.read().host}",
                                        oninput: move |e| {
                                            let mut jh = jump_host.read().clone();
                                            jh.host = e.value().clone();
                                            jump_host.set(jh);
                                        },
                                        placeholder: "跳板机IP或域名",
                                    }
                                },
                                div {
                                    class: "form-group",
                                    flex: "1",
                                    label {
                                        display: "block",
                                        margin_bottom: "6px",
                                        font_size: "13px",
                                        color: "#AAAAAA",
                                        "端口"
                                    },
                                    input {
                                        class: "form-input",
                                        r#type: "text",
                                        value: "{jump_host.read().port.to_string()}",
                                        oninput: move |e| {
                                            let mut jh = jump_host.read().clone();
                                            jh.port = e.value().parse().unwrap_or(22);
                                            jump_host.set(jh);
                                        },
                                    }
                                }
                            },
                            div {
                                class: "form-group",
                                label {
                                    display: "block",
                                    margin_bottom: "6px",
                                    font_size: "13px",
                                    color: "#AAAAAA",
                                    "跳板机用户名"
                                },
                                input {
                                    class: "form-input",
                                    r#type: "text",
                                    value: "{jump_host.read().username}",
                                    oninput: move |e| {
                                        let mut jh = jump_host.read().clone();
                                        jh.username = e.value().clone();
                                        jump_host.set(jh);
                                    },
                                    placeholder: "跳板机用户名",
                                }
                            },
                            div {
                                class: "form-group",
                                label {
                                    display: "block",
                                    margin_bottom: "6px",
                                    font_size: "13px",
                                    color: "#AAAAAA",
                                    "跳板机认证方式"
                                },
                                select {
                                    class: "form-select",
                                    value: "{current_jump_host_auth_type:?}",
                                    oninput: move |e| {
                                        let value = match e.value().as_str() {
                                            "Password" => AuthType::Password,
                                            "Key" => AuthType::Key,
                                            "KeyWithPassword" => AuthType::KeyWithPassword,
                                            _ => AuthType::Password,
                                        };
                                        let mut jh = jump_host.read().clone();
                                        jh.auth_type = value;
                                        jump_host.set(jh);
                                    },
                                    option { value: "Password", "密码认证" }
                                    option { value: "Key", "密钥认证" }
                                    option { value: "KeyWithPassword", "密钥+密码认证" }
                                }
                            },
                            if show_jump_host_password {
                                div {
                                    class: "form-group",
                                    label {
                                        display: "block",
                                        margin_bottom: "6px",
                                        font_size: "13px",
                                        color: "#AAAAAA",
                                        "跳板机密码"
                                    },
                                    input {
                                        class: "form-input",
                                        r#type: "password",
                                        value: "{jump_host_password.read()}",
                                        oninput: move |e| jump_host_password.set(e.value().clone()),
                                    }
                                }
                            },
                            if show_jump_host_key {
                                div {
                                    class: "form-group",
                                    label {
                                        display: "block",
                                        margin_bottom: "6px",
                                        font_size: "13px",
                                        color: "#AAAAAA",
                                        "跳板机私钥文件"
                                    },
                                    input {
                                        class: "form-input",
                                        r#type: "text",
                                        value: "{jump_host_key_path.read()}",
                                        oninput: move |e| jump_host_key_path.set(e.value().clone()),
                                        placeholder: "~/.ssh/id_rsa",
                                    }
                                }
                            }
                        }
                    },
                    // SOCKS5 代理配置
                    div {
                        class: "form-divider",
                        margin: "16px 0",
                        border_bottom: "1px solid #3C3C3C"
                    },
                    div {
                        class: "form-section-title",
                        font_size: "14px",
                        color: "#FFFFFF",
                        font_weight: "600",
                        margin_bottom: "12px",
                        "SOCKS5 代理配置"
                    },
                    div {
                        class: "form-group",
                        label {
                            display: "flex",
                            align_items: "center",
                            gap: "8px",
                            margin_bottom: "6px",
                            font_size: "13px",
                            color: "#CCCCCC",
                            cursor: "pointer",
                            input {
                                r#type: "checkbox",
                                checked: *use_socks5_proxy.read(),
                                oninput: move |e| {
                                    use_socks5_proxy.set(e.value().parse().unwrap_or(false));
                                }
                            },
                            "使用 SOCKS5 代理"
                        },
                    },
                    if *use_socks5_proxy.read() {
                        div {
                            class: "form-indent",
                            div {
                                class: "form-row",
                                div {
                                    class: "form-group",
                                    flex: "3",
                                    label {
                                        display: "block",
                                        margin_bottom: "6px",
                                        font_size: "13px",
                                        color: "#AAAAAA",
                                        "代理地址"
                                    },
                                    input {
                                        class: "form-input",
                                        r#type: "text",
                                        value: "{socks5_proxy.read().host}",
                                        oninput: move |e| {
                                            let mut sp = socks5_proxy.read().clone();
                                            sp.host = e.value().clone();
                                            socks5_proxy.set(sp);
                                        },
                                        placeholder: "代理服务器地址",
                                    }
                                },
                                div {
                                    class: "form-group",
                                    flex: "1",
                                    label {
                                        display: "block",
                                        margin_bottom: "6px",
                                        font_size: "13px",
                                        color: "#AAAAAA",
                                        "端口"
                                    },
                                    input {
                                        class: "form-input",
                                        r#type: "text",
                                        value: "{socks5_proxy.read().port.to_string()}",
                                        oninput: move |e| {
                                            let mut sp = socks5_proxy.read().clone();
                                            sp.port = e.value().parse().unwrap_or(1080);
                                            socks5_proxy.set(sp);
                                        },
                                    }
                                }
                            },
                            div {
                                class: "form-group",
                                label {
                                    display: "block",
                                    margin_bottom: "6px",
                                    font_size: "13px",
                                    color: "#AAAAAA",
                                    "代理用户名（可选）"
                                },
                                input {
                                    class: "form-input",
                                    r#type: "text",
                                    value: "{socks5_proxy.read().username.clone().unwrap_or_default()}",
                                    oninput: move |e| {
                                        let mut sp = socks5_proxy.read().clone();
                                        sp.username = if e.value().is_empty() { None } else { Some(e.value().clone()) };
                                        socks5_proxy.set(sp);
                                    },
                                    placeholder: "代理用户名",
                                }
                            },
                            div {
                                class: "form-group",
                                label {
                                    display: "block",
                                    margin_bottom: "6px",
                                    font_size: "13px",
                                    color: "#AAAAAA",
                                    "代理密码（可选）"
                                },
                                input {
                                    class: "form-input",
                                    r#type: "password",
                                    value: "{socks5_password.read()}",
                                    oninput: move |e| socks5_password.set(e.value().clone()),
                                }
                            }
                        }
                    },
                    // 备注
                    div {
                        class: "form-divider",
                        margin: "16px 0",
                        border_bottom: "1px solid #3C3C3C"
                    },
                    div {
                        class: "form-group",
                        label {
                            display: "block",
                            margin_bottom: "6px",
                            font_size: "13px",
                            color: "#CCCCCC",
                            "备注"
                        },
                        textarea {
                            class: "form-textarea",
                            value: "{notes.read()}",
                            oninput: move |e| notes.set(e.value().clone()),
                            rows: "3",
                        }
                    }
                },
                div {
                    class: "form-footer",
                    padding: "16px 20px",
                    border_top: "1px solid #3C3C3C",
                    display: "flex",
                    justify_content: "flex-end",
                    gap: "12px",
                    button {
                        class: "btn btn-secondary",
                        padding: "8px 16px",
                        border: "1px solid #3C3C3C",
                        background: "transparent",
                        color: "#CCCCCC",
                        border_radius: "4px",
                        cursor: "pointer",
                        font_size: "13px",
                        onclick: move |_| on_cancel.call(()),
                        "取消"
                    },
                    button {
                        class: "btn btn-primary",
                        padding: "8px 20px",
                        border: "none",
                        background: "#007ACC",
                        color: "#FFFFFF",
                        border_radius: "4px",
                        cursor: if form_valid { "pointer" } else { "not-allowed" },
                        font_size: "13px",
                        opacity: if form_valid { "1" } else { "0.5" },
                        disabled: !form_valid,
                        onclick: move |_| {
                            let effective_host = if *use_ssh_config.read() {
                                selected_ssh_config_host.read().clone()
                            } else {
                                host.read().clone()
                            };

                            let conn = SshConnection {
                                id: editing_conn.as_ref().map(|c| c.id.clone()).unwrap_or_else(|| Uuid::new_v4().to_string()),
                                name: name.read().clone(),
                                host: effective_host,
                                port: port.read().parse().unwrap_or(22),
                                username: username.read().clone(),
                                auth_type: auth_type.read().clone(),
                                password: if *auth_type.read() == AuthType::Password && !password.read().is_empty() {
                                    Some(password.read().clone())
                                } else {
                                    None
                                },
                                private_key_path: if !private_key_path.read().is_empty() { Some(private_key_path.read().clone()) } else { None },
                                private_key_content: if !private_key_content.read().is_empty() { Some(private_key_content.read().clone()) } else { None },
                                key_passphrase: if !key_passphrase.read().is_empty() { Some(key_passphrase.read().clone()) } else { None },
                                jump_host: if *use_jump_host.read() {
                                    let mut jh = jump_host.read().clone();
                                    if jh.auth_type == AuthType::Password && !jump_host_password.read().is_empty() {
                                        jh.password = Some(jump_host_password.read().clone());
                                    }
                                    if !jump_host_key_path.read().is_empty() {
                                        jh.private_key_path = Some(jump_host_key_path.read().clone());
                                    }
                                    Some(jh)
                                } else { None },
                                socks5_proxy: if *use_socks5_proxy.read() {
                                    let mut sp = socks5_proxy.read().clone();
                                    if !socks5_password.read().is_empty() {
                                        sp.password = Some(socks5_password.read().clone());
                                    }
                                    Some(sp)
                                } else { None },
                                ssh_config_host: if *use_ssh_config.read() && !selected_ssh_config_host.read().is_empty() {
                                    Some(selected_ssh_config_host.read().clone())
                                } else { None },
                                notes: if !notes.read().is_empty() { Some(notes.read().clone()) } else { None },
                                group: editing_conn.as_ref().and_then(|c| c.group.clone()),
                                color: editing_conn.as_ref().and_then(|c| c.color.clone()),
                                created_at: editing_conn.as_ref().map(|c| c.created_at).unwrap_or_else(chrono::Utc::now),
                                updated_at: chrono::Utc::now(),
                                version: editing_conn.as_ref().map(|c| c.version).unwrap_or(1) + 1,
                            };
                            on_save.call(conn);
                        },
                        "保存"
                    }
                }
            }
        }
    }
}
