use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;

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
                (imported.id.clone(), imported.name.clone())
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
