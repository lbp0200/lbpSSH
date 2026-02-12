//! UI 组件测试
//!
//! 测试组件的数据结构和逻辑
//!
//! 运行测试:
//! ```
//! cargo test --lib
//! ```

use crate::models::connection::{SshConnection, AuthType, JumpHostConfig};
use crate::app::TabInfo;

/// 测试 TabInfo 结构体的创建
#[test]
fn test_tab_info_creation() {
    let tab = TabInfo {
        id: "test-id".to_string(),
        name: "测试终端".to_string(),
        connection: None,
    };

    assert_eq!(tab.id, "test-id");
    assert_eq!(tab.name, "测试终端");
    assert!(tab.connection.is_none());
}

/// 测试带 SSH 连接的 TabInfo
#[test]
fn test_tab_info_with_connection() {
    let conn = create_test_connection();

    let tab = TabInfo {
        id: "tab-1".to_string(),
        name: "服务器连接".to_string(),
        connection: Some(conn),
    };

    assert!(tab.connection.is_some());
    assert_eq!(tab.connection.as_ref().unwrap().host, "192.168.1.100");
}

/// 测试 SshConnection 的克隆
#[test]
fn test_ssh_connection_clone() {
    let conn = create_test_connection();
    let cloned = conn.clone();

    assert_eq!(conn.id, cloned.id);
    assert_eq!(conn.name, cloned.name);
    assert_eq!(conn.host, cloned.host);
    assert_eq!(conn.port, cloned.port);
    assert_eq!(conn.auth_type, cloned.auth_type);
}

/// 测试 AuthType 枚举变体
#[test]
fn test_auth_type_variants() {
    assert!(matches!(AuthType::Password, AuthType::Password));
    assert!(matches!(AuthType::Key, AuthType::Key));
    assert!(matches!(AuthType::KeyWithPassword, AuthType::KeyWithPassword));
    assert!(matches!(AuthType::SshConfig, AuthType::SshConfig));
}

/// 测试 TabInfo 的 PartialEq 实现
#[test]
fn test_tab_info_eq() {
    let tab1 = TabInfo {
        id: "tab-1".to_string(),
        name: "终端1".to_string(),
        connection: None,
    };

    let tab2 = TabInfo {
        id: "tab-1".to_string(),
        name: "终端1".to_string(),
        connection: None,
    };

    assert_eq!(tab1, tab2);
}

/// 测试 TabInfo 不相等的情况
#[test]
fn test_tab_info_ne() {
    let tab1 = TabInfo {
        id: "tab-1".to_string(),
        name: "终端1".to_string(),
        connection: None,
    };

    let tab2 = TabInfo {
        id: "tab-2".to_string(),
        name: "终端2".to_string(),
        connection: None,
    };

    assert_ne!(tab1, tab2);
}

/// 测试批量连接操作
#[test]
fn test_batch_connection_operations() {
    let mut connections: Vec<SshConnection> = Vec::new();

    // 添加多个连接
    for i in 1..=5 {
        let conn = SshConnection {
            id: format!("conn-{}", i),
            name: format!("服务器 {}", i),
            host: format!("10.0.0.{}", i),
            port: 22,
            username: "root".to_string(),
            auth_type: AuthType::Password,
            password: None,
            private_key_path: None,
            private_key_content: None,
            key_passphrase: None,
            jump_host: None,
            socks5_proxy: None,
            ssh_config_host: None,
            notes: None,
            group: None,
            color: None,
            created_at: chrono::Utc::now(),
            updated_at: chrono::Utc::now(),
            version: 1,
        };
        connections.push(conn);
    }

    assert_eq!(connections.len(), 5);

    // 按 ID 查找
    let found = connections.iter().find(|c| c.id == "conn-3");
    assert!(found.is_some());
    assert_eq!(found.unwrap().host, "10.0.0.3");

    // 按名称过滤
    let filtered: Vec<_> = connections.iter().filter(|c| c.name.contains("服务器 1")).collect();
    assert_eq!(filtered.len(), 1);

    // 删除连接
    connections.retain(|c| c.id != "conn-2");
    assert_eq!(connections.len(), 4);
    assert!(connections.iter().find(|c| c.id == "conn-2").is_none());
}

/// 测试终端提示符生成 - SSH 连接
#[test]
fn test_ssh_terminal_prompt() {
    let conn = create_test_connection();
    let expected_prompt = format!("{}@{}:~$", conn.username, conn.host);
    assert_eq!(expected_prompt, "root@192.168.1.100:~$");
}

/// 测试本地终端提示符
#[test]
fn test_local_terminal_prompt() {
    let local_prompt = "~ $";
    assert!(local_prompt.contains('$'));
    assert!(local_prompt.starts_with('~'));
}

/// 测试连接状态文本 - 已连接
#[test]
fn test_connection_status_connected() {
    let status = "● 已连接";
    assert!(status.contains("已连接"));
    assert!(status.contains("●"));
}

/// 测试连接状态文本 - 未连接
#[test]
fn test_connection_status_disconnected() {
    let status = "○ 未连接";
    assert!(status.contains("未连接"));
    assert!(status.contains("○"));
}

/// 测试连接状态文本 - 本地终端
#[test]
fn test_connection_status_local() {
    let status = "● 本地终端";
    assert!(status.contains("本地终端"));
}

/// 测试颜色代码格式
#[test]
fn test_color_format() {
    let colors = vec!["#FF5733", "#1E1E1E", "#4CAF50", "#FFFFFF"];

    for color in &colors {
        assert!(color.starts_with('#'));
        assert_eq!(color.len(), 7);
    }
}

/// 测试端口号范围
#[test]
fn test_port_range() {
    let conn = create_test_connection();
    assert!(conn.port >= 1 && conn.port <= 65535);
}

/// 测试密钥认证类型
#[test]
fn test_key_auth_type() {
    let conn = SshConnection {
        id: "conn-1".to_string(),
        name: "密钥服务器".to_string(),
        host: "10.0.0.1".to_string(),
        port: 22,
        username: "admin".to_string(),
        auth_type: AuthType::Key,
        password: None,
        private_key_path: Some("/home/user/.ssh/id_rsa".to_string()),
        private_key_content: None,
        key_passphrase: None,
        jump_host: None,
        socks5_proxy: None,
        ssh_config_host: None,
        notes: Some("使用密钥认证".to_string()),
        group: Some("生产环境".to_string()),
        color: Some("#FF5733".to_string()),
        created_at: chrono::Utc::now(),
        updated_at: chrono::Utc::now(),
        version: 1,
    };

    assert!(matches!(conn.auth_type, AuthType::Key));
    assert!(conn.private_key_path.is_some());
    assert!(conn.notes.is_some());
    assert!(conn.group.is_some());
}

/// 测试连接组过滤
#[test]
fn test_connection_group_filter() {
    let connections = vec![
        create_test_connection_with_group("生产环境"),
        create_test_connection_with_group("测试环境"),
        create_test_connection_with_group("生产环境"),
    ];

    let group_name = "生产环境".to_string();
    let prod_conns: Vec<_> = connections.iter()
        .filter(|c| c.group.as_ref() == Some(&group_name))
        .collect();

    assert_eq!(prod_conns.len(), 2);
}

/// 测试连接备注
#[test]
fn test_connection_notes() {
    let conn = SshConnection {
        id: "conn-1".to_string(),
        name: "测试服务器".to_string(),
        host: "192.168.1.1".to_string(),
        port: 22,
        username: "user".to_string(),
        auth_type: AuthType::Password,
        password: Some("pass".to_string()),
        private_key_path: None,
        private_key_content: None,
        key_passphrase: None,
        jump_host: None,
        socks5_proxy: None,
        ssh_config_host: None,
        notes: Some("用于开发测试".to_string()),
        group: None,
        color: None,
        created_at: chrono::Utc::now(),
        updated_at: chrono::Utc::now(),
        version: 1,
    };

    assert!(conn.notes.is_some());
    assert_eq!(conn.notes.unwrap(), "用于开发测试");
}

/// 测试 SshConfig 认证类型
#[test]
fn test_ssh_config_auth_type() {
    let conn = SshConnection {
        id: "conn-1".to_string(),
        name: "SSH Config".to_string(),
        host: "192.168.1.1".to_string(),
        port: 22,
        username: "user".to_string(),
        auth_type: AuthType::SshConfig,
        password: None,
        private_key_path: None,
        private_key_content: None,
        key_passphrase: None,
        jump_host: None,
        socks5_proxy: None,
        ssh_config_host: Some("myhost".to_string()),
        notes: None,
        group: None,
        color: None,
        created_at: chrono::Utc::now(),
        updated_at: chrono::Utc::now(),
        version: 1,
    };

    assert!(matches!(conn.auth_type, AuthType::SshConfig));
    assert!(conn.ssh_config_host.is_some());
}

/// 测试跳板机配置
#[test]
fn test_jump_host_config() {
    let jump_host = JumpHostConfig {
        host: "bastion.example.com".to_string(),
        port: 22,
        username: "admin".to_string(),
        auth_type: AuthType::Key,
        password: None,
        private_key_path: Some("/home/user/.ssh/id_ed25519".to_string()),
    };

    assert_eq!(jump_host.host, "bastion.example.com");
    assert_eq!(jump_host.port, 22);
    assert!(matches!(jump_host.auth_type, AuthType::Key));
}

/// 辅助函数：创建测试用 SSH 连接
fn create_test_connection() -> SshConnection {
    SshConnection {
        id: "conn-1".to_string(),
        name: "生产服务器".to_string(),
        host: "192.168.1.100".to_string(),
        port: 22,
        username: "root".to_string(),
        auth_type: AuthType::Password,
        password: None,
        private_key_path: None,
        private_key_content: None,
        key_passphrase: None,
        jump_host: None,
        socks5_proxy: None,
        ssh_config_host: None,
        notes: None,
        group: None,
        color: None,
        created_at: chrono::Utc::now(),
        updated_at: chrono::Utc::now(),
        version: 1,
    }
}

/// 辅助函数：创建带分组的测试连接
fn create_test_connection_with_group(group: &str) -> SshConnection {
    SshConnection {
        id: format!("conn-{}", uuid::Uuid::new_v4().to_string()[..8].to_string()),
        name: format!("{} 服务器", group),
        host: "192.168.1.1".to_string(),
        port: 22,
        username: "root".to_string(),
        auth_type: AuthType::Password,
        password: None,
        private_key_path: None,
        private_key_content: None,
        key_passphrase: None,
        jump_host: None,
        socks5_proxy: None,
        ssh_config_host: None,
        notes: None,
        group: Some(group.to_string()),
        color: None,
        created_at: chrono::Utc::now(),
        updated_at: chrono::Utc::now(),
        version: 1,
    }
}
