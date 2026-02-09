use dioxus::prelude::*;
use crate::models::connection::{SshConnection, AuthType};
use uuid::Uuid;

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

    let form_valid = !name.read().trim().is_empty()
        && !host.read().trim().is_empty()
        && !username.read().trim().is_empty();

    let current_auth_type = auth_type.read().clone();
    let show_password_fields = current_auth_type == AuthType::Password;
    let show_key_fields = current_auth_type == AuthType::Key || current_auth_type == AuthType::KeyWithPassword;
    let show_passphrase_field = current_auth_type == AuthType::KeyWithPassword;

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
                width: "500px",
                max_height: "80vh",
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
                                    _ => AuthType::Password,
                                };
                                auth_type.set(value);
                            },
                            option { value: "Password", "密码认证" }
                            option { value: "Key", "密钥认证" }
                            option { value: "KeyWithPassword", "密钥+密码认证" }
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
                            let conn = SshConnection {
                                id: editing_conn.as_ref().map(|c| c.id.clone()).unwrap_or_else(|| Uuid::new_v4().to_string()),
                                name: name.read().clone(),
                                host: host.read().clone(),
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
                                jump_host: None,
                                socks5_proxy: None,
                                ssh_config_host: None,
                                notes: if !notes.read().is_empty() { Some(notes.read().clone()) } else { None },
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
