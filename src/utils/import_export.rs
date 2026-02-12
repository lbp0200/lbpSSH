use csv::{ReaderBuilder, WriterBuilder};
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;

/// 导出格式
#[derive(Debug, Clone, PartialEq)]
pub enum ExportFormat {
    Json,
    Csv,
    SshConfig,
}

/// 导入导出状态
#[derive(Debug, Clone, PartialEq)]
pub enum ImportExportStatus {
    Idle,
    Exporting,
    Importing,
    Success,
    Error(String),
}

/// 导出数据结构
#[derive(Debug, Serialize, Deserialize)]
pub struct ExportData {
    pub app_name: String,
    pub app_version: String,
    pub export_time: String,
    pub version: u32,
    pub total_connections: usize,
    pub connections: Vec<crate::models::connection::SshConnection>,
}

/// 导入导出服务
pub struct ImportExportService {
    connections_path: PathBuf,
}

impl ImportExportService {
    pub fn new(connections_path: PathBuf) -> Self {
        Self { connections_path }
    }

    /// 导出 SSH 连接配置到文件
    pub fn export_to_file(&self, output_path: &PathBuf) -> Result<(), String> {
        // 读取现有连接
        let connections: Vec<crate::models::connection::SshConnection> = if self.connections_path.exists() {
            let content = fs::read_to_string(&self.connections_path)
                .map_err(|e| format!("读取连接文件失败: {}", e))?;
            serde_json::from_str(&content)
                .map_err(|e| format!("解析连接文件失败: {}", e))?
        } else {
            Vec::new()
        };

        if connections.is_empty() {
            return Err("没有 SSH 连接配置可导出".to_string());
        }

        // 准备导出数据
        let export_data = ExportData {
            app_name: "lbpSSH".to_string(),
            app_version: "1.0.0".to_string(),
            export_time: chrono::Utc::now().to_rfc3339(),
            version: 1,
            total_connections: connections.len(),
            connections: connections.clone(),
        };

        // 写入文件
        let json_content = serde_json::to_string_pretty(&export_data)
            .map_err(|e| format!("序列化失败: {}", e))?;
        fs::write(output_path, json_content)
            .map_err(|e| format!("写入文件失败: {}", e))?;

        Ok(())
    }

    /// 从文件导入 SSH 连接配置
    pub fn import_from_file(&self, file_path: &PathBuf) -> Result<Vec<crate::models::connection::SshConnection>, String> {
        if !file_path.exists() {
            return Err("文件不存在".to_string());
        }

        // 读取文件内容
        let content = fs::read_to_string(file_path)
            .map_err(|e| format!("读取文件失败: {}", e))?;

        // 解析 JSON
        let json_data: serde_json::Value = serde_json::from_str(&content)
            .map_err(|e| format!("无效的 JSON 文件格式: {}", e))?;

        // 验证文件结构
        self.validate_export_file(&json_data)?;

        // 解析连接配置
        let connections_json = json_data["connections"].as_array()
            .ok_or("connections 必须是数组")?;

        let mut imported_connections = Vec::new();
        for conn_json in connections_json {
            match serde_json::from_value(conn_json.clone()) {
                Ok(conn) => imported_connections.push(conn),
                Err(_e) => {
                    // 跳过无效的连接配置
                    continue;
                }
            }
        }

        if imported_connections.is_empty() {
            return Err("文件中没有有效的连接配置".to_string());
        }

        Ok(imported_connections)
    }

    /// 验证导出文件格式
    fn validate_export_file(&self, data: &serde_json::Value) -> Result<(), String> {
        // 检查必要字段
        if !data.is_object() {
            return Err("无效的文件格式".to_string());
        }

        let obj = data.as_object().unwrap();

        if !obj.contains_key("connections") {
            return Err("缺少 connections 字段".to_string());
        }

        if !obj["connections"].is_array() {
            return Err("connections 必须是数组".to_string());
        }

        let connections = obj["connections"].as_array().unwrap();
        if connections.is_empty() {
            return Err("文件中没有连接配置".to_string());
        }

        Ok(())
    }

    /// 合并导入的连接配置
    pub fn merge_imported_connections(
        &self,
        imported_connections: Vec<crate::models::connection::SshConnection>,
        mut existing_connections: Vec<crate::models::connection::SshConnection>,
        overwrite: bool,
        add_prefix: bool,
    ) -> Result<Vec<crate::models::connection::SshConnection>, String> {
        let existing_ids: std::collections::HashSet<String> =
            existing_connections.iter().map(|c| c.id.clone()).collect();

        let mut added_ids = std::collections::HashSet::new();

        for imported in imported_connections {
            let (final_id, final_name) = if existing_ids.contains(&imported.id) {
                if overwrite {
                    // 覆盖现有连接，生成新 ID
                    let new_id = format!("{}_imported_{}", imported.id, chrono::Utc::now().timestamp());
                    let new_name = if add_prefix {
                        format!("导入_{}", imported.name)
                    } else {
                        imported.name.clone()
                    };
                    // 移除现有连接
                    existing_connections.retain(|c| c.id != imported.id);
                    (new_id, new_name)
                } else {
                    // 跳过重复的连接
                    continue;
                }
            } else {
                // 新连接，应用前缀（如果需要）
                let final_name = if add_prefix {
                    format!("导入_{}", imported.name)
                } else {
                    imported.name.clone()
                };
                (imported.id.clone(), final_name)
            };

            let new_connection = crate::models::connection::SshConnection {
                id: final_id.clone(),
                name: final_name,
                ..imported
            };

            existing_connections.push(new_connection);
            added_ids.insert(final_id);
        }

        Ok(existing_connections)
    }

    /// 获取导出统计信息
    pub fn get_export_stats(&self) -> Result<ExportStats, String> {
        let connections: Vec<crate::models::connection::SshConnection> = if self.connections_path.exists() {
            let content = fs::read_to_string(&self.connections_path)
                .map_err(|e| format!("读取连接文件失败: {}", e))?;
            serde_json::from_str(&content)
                .map_err(|e| format!("解析连接文件失败: {}", e))?
        } else {
            Vec::new()
        };

        let mut password_count = 0;
        let mut key_count = 0;
        let mut key_with_password_count = 0;
        let mut jump_host_count = 0;

        for conn in &connections {
            match conn.auth_type {
                crate::models::connection::AuthType::Password => password_count += 1,
                crate::models::connection::AuthType::Key => key_count += 1,
                crate::models::connection::AuthType::KeyWithPassword => key_with_password_count += 1,
                crate::models::connection::AuthType::SshConfig => {}
            }

            if conn.jump_host.is_some() {
                jump_host_count += 1;
            }
        }

        let last_updated = connections.iter()
            .map(|c| c.updated_at)
            .max()
            .map(|t| t.to_rfc3339());

        Ok(ExportStats {
            total_connections: connections.len(),
            password_auth: password_count,
            key_auth: key_count,
            key_with_password_auth: key_with_password_count,
            jump_host_connections: jump_host_count,
            last_updated,
        })
    }

    /// 生成导出摘要
    pub fn generate_export_summary(&self) -> Result<String, String> {
        let stats = self.get_export_stats()?;

        let mut summary = Vec::new();
        summary.push("SSH连接配置导出摘要".to_string());
        summary.push("=".repeat(30));
        summary.push(format!("总连接数: {}", stats.total_connections));
        summary.push(format!("密码认证: {}", stats.password_auth));
        summary.push(format!("密钥认证: {}", stats.key_auth));
        summary.push(format!("密钥+密码: {}", stats.key_with_password_auth));
        summary.push(format!("跳板机连接: {}", stats.jump_host_connections));

        if let Some(last_updated) = stats.last_updated {
            summary.push(format!("最后更新: {}", last_updated));
        }

        summary.push(format!("导出时间: {}", chrono::Utc::now().to_rfc3339()));
        summary.push("".to_string());
        summary.push("注意: 此配置文件包含敏感信息(密码、私钥等)".to_string());
        summary.push("请妥善保管，不要在不安全的网络环境中传输".to_string());

        Ok(summary.join("\n"))
    }

    /// 导出到 CSV 格式
    pub fn export_to_csv(&self, output_path: &PathBuf) -> Result<(), String> {
        let connections = self.load_connections()?;

        if connections.is_empty() {
            return Err("没有 SSH 连接配置可导出".to_string());
        }

        let mut wtr = WriterBuilder::new()
            .has_headers(true)
            .from_path(output_path)
            .map_err(|e| format!("创建 CSV 文件失败: {}", e))?;

        // 写入 CSV 头
        wtr.write_record(&[
            "name",
            "host",
            "port",
            "username",
            "auth_type",
            "password",
            "private_key_path",
            "jump_host",
            "socks5_proxy",
            "notes",
            "group",
        ])
        .map_err(|e| format!("写入 CSV 头失败: {}", e))?;

        // 写入数据行
        for conn in &connections {
            let password = conn.password.clone().unwrap_or_default();
            let private_key_path = conn.private_key_path.clone().unwrap_or_default();
            let jump_host = conn.jump_host.clone().map(|j| format!("{}@{}:{}", j.username, j.host, j.port)).unwrap_or_default();
            let socks5_proxy = conn.socks5_proxy.clone().map(|p| format!("{}:{}", p.host, p.port)).unwrap_or_default();
            let notes = conn.notes.clone().unwrap_or_default();
            let group = conn.group.clone().unwrap_or_default();

            let auth_type = match &conn.auth_type {
                crate::models::connection::AuthType::Password => "Password",
                crate::models::connection::AuthType::Key => "Key",
                crate::models::connection::AuthType::KeyWithPassword => "KeyWithPassword",
                crate::models::connection::AuthType::SshConfig => "SshConfig",
            };

            wtr.write_record(&[
                &conn.name,
                &conn.host,
                &conn.port.to_string(),
                &conn.username,
                auth_type,
                &password,
                &private_key_path,
                &jump_host,
                &socks5_proxy,
                &notes,
                &group,
            ])
            .map_err(|e| format!("写入 CSV 行失败: {}", e))?;
        }

        wtr.flush().map_err(|e| format!("刷新 CSV 文件失败: {}", e))?;

        Ok(())
    }

    /// 从 CSV 导入
    pub fn import_from_csv(&self, file_path: &PathBuf) -> Result<Vec<crate::models::connection::SshConnection>, String> {
        if !file_path.exists() {
            return Err("文件不存在".to_string());
        }

        let mut rdr = ReaderBuilder::new()
            .has_headers(true)
            .from_path(file_path)
            .map_err(|e| format!("读取 CSV 文件失败: {}", e))?;

        let mut connections = Vec::new();

        for result in rdr.records() {
            let record = result.map_err(|e| format!("解析 CSV 行失败: {}", e))?;

            // 跳过空行
            if record.len() < 3 {
                continue;
            }

            let name = record.get(0).unwrap_or("").to_string();
            let host = record.get(1).unwrap_or("").to_string();
            let port: u16 = record.get(2).unwrap_or("22").parse().unwrap_or(22);
            let username = record.get(3).unwrap_or("").to_string();

            if name.is_empty() || host.is_empty() {
                continue;
            }

            let auth_type_str = record.get(4).unwrap_or("Password");
            let auth_type = match auth_type_str {
                "Key" => crate::models::connection::AuthType::Key,
                "KeyWithPassword" => crate::models::connection::AuthType::KeyWithPassword,
                "SshConfig" => crate::models::connection::AuthType::SshConfig,
                _ => crate::models::connection::AuthType::Password,
            };

            let password = record.get(5).filter(|s| !s.is_empty()).map(|s| s.to_string());
            let private_key_path = record.get(6).filter(|s| !s.is_empty()).map(|s| s.to_string());

            // 解析跳板机
            let jump_host = record.get(7).filter(|s| !s.is_empty()).map(|s| {
                let parts: Vec<&str> = s.split('@').collect();
                if parts.len() == 2 {
                    let host_parts: Vec<&str> = parts[0].split(':').collect();
                    crate::models::connection::JumpHostConfig {
                        host: host_parts.get(0).unwrap_or(&"").to_string(),
                        port: host_parts.get(1).unwrap_or(&"22").parse().unwrap_or(22),
                        username: parts.get(1).unwrap_or(&"").to_string(),
                        auth_type: crate::models::connection::AuthType::Password,
                        password: None,
                        private_key_path: None,
                    }
                } else {
                    crate::models::connection::JumpHostConfig {
                        host: s.to_string(),
                        port: 22,
                        username: String::new(),
                        auth_type: crate::models::connection::AuthType::Password,
                        password: None,
                        private_key_path: None,
                    }
                }
            });

            // 解析 SOCKS5 代理
            let socks5_proxy = record.get(8).filter(|s| !s.is_empty()).map(|s| {
                let parts: Vec<&str> = s.split(':').collect();
                crate::models::connection::Socks5ProxyConfig {
                    host: parts.get(0).unwrap_or(&"").to_string(),
                    port: parts.get(1).unwrap_or(&"1080").parse().unwrap_or(1080),
                    username: None,
                    password: None,
                }
            });

            let notes = record.get(9).filter(|s| !s.is_empty()).map(|s| s.to_string());
            let group = record.get(10).filter(|s| !s.is_empty()).map(|s| s.to_string());

            let now = chrono::Utc::now();

            connections.push(crate::models::connection::SshConnection {
                id: format!("csv_import_{}", uuid::Uuid::new_v4()),
                name,
                host,
                port,
                username,
                auth_type,
                password,
                private_key_path,
                private_key_content: None,
                key_passphrase: None,
                jump_host,
                socks5_proxy,
                ssh_config_host: None,
                notes,
                group,
                color: None,
                created_at: now,
                updated_at: now,
                version: 1,
            });
        }

        if connections.is_empty() {
            return Err("CSV 文件中没有有效的连接配置".to_string());
        }

        Ok(connections)
    }

    /// 导出到 SSH Config 格式
    pub fn export_to_ssh_config(&self, output_path: &PathBuf) -> Result<(), String> {
        let connections = self.load_connections()?;

        if connections.is_empty() {
            return Err("没有 SSH 连接配置可导出".to_string());
        }

        let mut content = String::new();
        content.push_str("# SSH Config Export from lbpSSH\n");
        content.push_str(&format!("# Generated at: {}\n", chrono::Utc::now().to_rfc3339()));
        content.push('\n');

        for conn in &connections {
            content.push_str(&format!("Host {}\n", conn.name.replace(' ', "_")));
            content.push_str(&format!("    HostName {}\n", conn.host));
            content.push_str(&format!("    Port {}\n", conn.port));
            content.push_str(&format!("    User {}\n", conn.username));

            match &conn.auth_type {
                crate::models::connection::AuthType::Key => {
                    if let Some(key_path) = &conn.private_key_path {
                        content.push_str(&format!("    IdentityFile {}\n", key_path));
                    }
                    if let Some(passphrase) = &conn.key_passphrase {
                        content.push_str("    IdentitiesOnly yes\n");
                    }
                }
                crate::models::connection::AuthType::KeyWithPassword => {
                    if let Some(key_path) = &conn.private_key_path {
                        content.push_str(&format!("    IdentityFile {}\n", key_path));
                    }
                    content.push_str("    IdentitiesOnly yes\n");
                }
                _ => {}
            }

            if let Some(jump_host) = &conn.jump_host {
                content.push_str(&format!("    ProxyJump {}@{}\n", jump_host.username, jump_host.host));
            }

            if let Some(proxy) = &conn.socks5_proxy {
                content.push_str(&format!("    ProxyCommand nc -X 5 -x {}:%p %h\n", proxy.host));
            }

            content.push('\n');
        }

        fs::write(output_path, content)
            .map_err(|e| format!("写入 SSH Config 文件失败: {}", e))?;

        Ok(())
    }

    /// 加载所有连接
    fn load_connections(&self) -> Result<Vec<crate::models::connection::SshConnection>, String> {
        if self.connections_path.exists() {
            let content = fs::read_to_string(&self.connections_path)
                .map_err(|e| format!("读取连接文件失败: {}", e))?;
            serde_json::from_str(&content)
                .map_err(|e| format!("解析连接文件失败: {}", e))
        } else {
            Ok(Vec::new())
        }
    }
}

/// 导出统计信息
pub struct ExportStats {
    pub total_connections: usize,
    pub password_auth: usize,
    pub key_auth: usize,
    pub key_with_password_auth: usize,
    pub jump_host_connections: usize,
    pub last_updated: Option<String>,
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::connection::SshConnection;
    use crate::models::connection::AuthType;

    /// 测试 ExportData 的序列化
    #[test]
    fn test_export_data_serialization() {
        let connections = vec![
            SshConnection {
                id: "test-1".to_string(),
                name: "服务器1".to_string(),
                host: "192.168.1.1".to_string(),
                port: 22,
                username: "admin".to_string(),
                auth_type: AuthType::Password,
                password: Some("pass1".to_string()),
                private_key_path: None,
                private_key_content: None,
                key_passphrase: None,
                jump_host: None,
                socks5_proxy: None,
                ssh_config_host: None,
                notes: None,
                group: None,
                color: None,
                created_at: chrono::DateTime::from_timestamp(1700000000, 0).unwrap(),
                updated_at: chrono::DateTime::from_timestamp(1700000000, 0).unwrap(),
                version: 1,
            },
        ];

        let export_data = ExportData {
            app_name: "lbpSSH".to_string(),
            app_version: "1.0.0".to_string(),
            export_time: "2024-01-01T00:00:00Z".to_string(),
            version: 1,
            total_connections: connections.len(),
            connections: connections.clone(),
        };

        let serialized = serde_json::to_string_pretty(&export_data).expect("序列化失败");
        let deserialized: ExportData = serde_json::from_str(&serialized).expect("反序列化失败");

        assert_eq!(export_data.app_name, deserialized.app_name);
        assert_eq!(export_data.total_connections, deserialized.total_connections);
    }

    /// 测试 ExportStats 结构
    #[test]
    fn test_export_stats() {
        let stats = ExportStats {
            total_connections: 10,
            password_auth: 5,
            key_auth: 3,
            key_with_password_auth: 1,
            jump_host_connections: 2,
            last_updated: Some("2024-01-01T00:00:00Z".to_string()),
        };

        assert_eq!(stats.total_connections, 10);
        assert_eq!(stats.password_auth, 5);
        assert_eq!(stats.key_auth, 3);
        assert_eq!(stats.jump_host_connections, 2);
        assert!(stats.last_updated.is_some());
    }

    /// 测试 ImportExportService 创建
    #[test]
    fn test_import_export_service_new() {
        let path = PathBuf::from("/test/connections.json");
        let service = ImportExportService::new(path.clone());
        assert_eq!(service.connections_path, path);
    }

    /// 测试验证空 JSON
    #[test]
    fn test_validate_empty_json() {
        let service = ImportExportService::new(PathBuf::from("/test/connections.json"));

        let empty_obj = serde_json::json!({});
        assert!(service.validate_export_file(&empty_obj).is_err());

        let no_connections = serde_json::json!({"other": "data"});
        assert!(service.validate_export_file(&no_connections).is_err());
    }

    /// 测试验证有效的 JSON
    #[test]
    fn test_validate_valid_json() {
        let service = ImportExportService::new(PathBuf::from("/test/connections.json"));

        let valid_json = serde_json::json!({
            "connections": [
                {
                    "id": "test-1",
                    "name": "测试服务器",
                    "host": "192.168.1.1",
                    "port": 22,
                    "username": "admin",
                    "auth_type": "Password",
                    "password": null,
                    "private_key_path": null,
                    "private_key_content": null,
                    "key_passphrase": null,
                    "jump_host": null,
                    "socks5_proxy": null,
                    "ssh_config_host": null,
                    "notes": null,
                    "group": null,
                    "color": null,
                    "created_at": "2024-01-01T00:00:00Z",
                    "updated_at": "2024-01-01T00:00:00Z",
                    "version": 1
                }
            ]
        });

        assert!(service.validate_export_file(&valid_json).is_ok());
    }

    /// 测试合并导入的连接（不覆盖）
    #[test]
    fn test_merge_connections_no_overwrite() {
        let service = ImportExportService::new(PathBuf::from("/test/connections.json"));

        let existing = vec![
            SshConnection {
                id: "existing-1".to_string(),
                name: "现有服务器".to_string(),
                host: "192.168.1.1".to_string(),
                port: 22,
                username: "admin".to_string(),
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
            },
        ];

        let imported = vec![
            SshConnection {
                id: "existing-1".to_string(),
                name: "导入服务器".to_string(),
                host: "192.168.1.2".to_string(),
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
            },
        ];

        let merged = service.merge_imported_connections(imported, existing, false, false).unwrap();
        assert_eq!(merged.len(), 1);
        assert_eq!(merged[0].name, "现有服务器");
    }

    /// 测试合并时添加前缀（覆盖模式）
    #[test]
    fn test_merge_connections_with_prefix() {
        let service = ImportExportService::new(PathBuf::from("/test/connections.json"));

        let existing = vec![];
        let imported = vec![
            SshConnection {
                id: "imported-1".to_string(),
                name: "服务器".to_string(),
                host: "192.168.1.1".to_string(),
                port: 22,
                username: "admin".to_string(),
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
            },
        ];

        // 前缀只在覆盖模式（overwrite=true）时添加
        let merged = service.merge_imported_connections(imported, existing, true, true).unwrap();
        assert_eq!(merged.len(), 1);
        assert_eq!(merged[0].name, "导入_服务器");
    }
}
