use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;

/// GitHub Gist 同步配置
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct GitHubGistConfig {
    pub enabled: bool,
    pub gist_id: String,
    pub personal_access_token: String,
    pub last_sync_time: Option<String>,
    pub auto_sync: bool,
    pub sync_on_startup: bool,
    pub file_name: String,
}

impl Default for GitHubGistConfig {
    fn default() -> Self {
        Self {
            enabled: false,
            gist_id: String::new(),
            personal_access_token: String::new(),
            last_sync_time: None,
            auto_sync: false,
            sync_on_startup: false,
            file_name: "connections.json".to_string(),
        }
    }
}

/// GitHub Gist 文件内容
#[derive(Debug, Serialize, Deserialize)]
pub struct GistFile {
    pub content: String,
}

/// GitHub Gist 响应
#[derive(Debug, Serialize, Deserialize)]
pub struct GistResponse {
    pub id: String,
    pub created_at: String,
    pub updated_at: String,
    pub files: std::collections::HashMap<String, GistFile>,
}

/// Gist 同步结果
#[derive(Debug, Clone)]
pub struct GistSyncResult {
    pub success: bool,
    pub uploaded: usize,
    pub downloaded: usize,
    pub timestamp: String,
    pub message: String,
    pub has_conflict: bool,
    pub remote_timestamp: Option<String>,
}

/// GitHub Gist 同步服务
pub struct GitHubGistSyncService {
    connections_path: PathBuf,
    config_path: PathBuf,
}

impl GitHubGistSyncService {
    /// 创建新服务
    pub fn new(connections_path: PathBuf, config_dir: PathBuf) -> Self {
        let config_path = config_dir.join("github_gist_sync.json");
        Self {
            connections_path,
            config_path,
        }
    }

    /// 加载配置
    pub fn load_config(&self) -> GitHubGistConfig {
        if self.config_path.exists() {
            if let Ok(content) = fs::read_to_string(&self.config_path) {
                if let Ok(config) = serde_json::from_str(&content) {
                    return config;
                }
            }
        }
        GitHubGistConfig::default()
    }

    /// 保存配置
    pub fn save_config(&self, config: &GitHubGistConfig) -> Result<(), String> {
        if let Some(parent) = self.config_path.parent() {
            fs::create_dir_all(parent)
                .map_err(|e| format!("创建配置目录失败: {}", e))?;
        }

        let content = serde_json::to_string_pretty(config)
            .map_err(|e| format!("序列化配置失败: {}", e))?;
        fs::write(&self.config_path, content)
            .map_err(|e| format!("写入配置失败: {}", e))?;

        Ok(())
    }

    /// 读取本地连接
    fn load_local_connections(&self) -> Result<Vec<crate::models::connection::SshConnection>, String> {
        if self.connections_path.exists() {
            let content = fs::read_to_string(&self.connections_path)
                .map_err(|e| format!("读取连接文件失败: {}", e))?;
            serde_json::from_str(&content)
                .map_err(|e| format!("解析连接文件失败: {}", e))
        } else {
            Ok(Vec::new())
        }
    }

    /// 保存本地连接
    fn save_local_connections(&self, connections: &[crate::models::connection::SshConnection]) -> Result<(), String> {
        if let Some(parent) = self.connections_path.parent() {
            fs::create_dir_all(parent)
                .map_err(|e| format!("创建目录失败: {}", e))?;
        }

        let content = serde_json::to_string_pretty(connections)
            .map_err(|e| format!("序列化失败: {}", e))?;
        fs::write(&self.connections_path, content)
            .map_err(|e| format!("写入文件失败: {}", e))?;

        Ok(())
    }

    /// 获取 HTTP 客户端
    fn get_client(&self) -> Result<reqwest::Client, String> {
        reqwest::Client::builder()
            .user_agent("lbpSSH-Rust/1.0")
            .build()
            .map_err(|e| format!("创建 HTTP 客户端失败: {}", e))
    }

    /// 获取远程 Gist 内容
    async fn fetch_remote_gist(&self, config: &GitHubGistConfig) -> Result<Option<GistResponse>, String> {
        if config.gist_id.is_empty() {
            return Err("Gist ID 为空".to_string());
        }

        let client = self.get_client()?;
        let url = format!("https://api.github.com/gists/{}", config.gist_id);

        let mut request = client.get(&url);
        if !config.personal_access_token.is_empty() {
            request = request.header("Authorization", format!("token {}", config.personal_access_token));
        }

        let response = request.send().await
            .map_err(|e| format!("网络请求失败: {}", e))?;

        let status = response.status();
        if status == reqwest::StatusCode::NOT_FOUND {
            return Ok(None);
        }

        if !status.is_success() {
            let error_text = response.text().await
                .unwrap_or_else(|_| "未知错误".to_string());
            return Err(format!("GitHub API 错误: {} - {}", status, error_text));
        }

        let gist: GistResponse = response
            .json()
            .await
            .map_err(|e| format!("解析响应失败: {}", e))?;

        Ok(Some(gist))
    }

    /// 上传到 Gist
    pub async fn upload_to_gist(&self, config: &GitHubGistConfig) -> Result<GistSyncResult, String> {
        if !config.enabled {
            return Err("GitHub Gist 同步未启用".to_string());
        }

        let connections = self.load_local_connections()?;
        let content = serde_json::to_string_pretty(&connections)
            .map_err(|e| format!("序列化连接失败: {}", e))?;

        let client = self.get_client()?;
        let timestamp = chrono::Utc::now().to_rfc3339();
        let file_name = config.file_name.clone();

        let files = serde_json::json!({
            file_name: {
                "content": content
            }
        });

        let mut request = if config.gist_id.is_empty() {
            // 创建新 Gist
            let url = "https://api.github.com/gists";
            client.post(url)
                .json(&serde_json::json!({
                    "description": format!("lbpSSH connections sync - {}", timestamp),
                    "public": false,
                    "files": files
                }))
        } else {
            // 更新现有 Gist
            let url = format!("https://api.github.com/gists/{}", config.gist_id);
            client.patch(&url)
                .json(&serde_json::json!({
                    "description": format!("lbpSSH connections sync - {}", timestamp),
                    "files": files
                }))
        };

        if !config.personal_access_token.is_empty() {
            request = request.header("Authorization", format!("token {}", config.personal_access_token));
        }

        let response = request.send().await
            .map_err(|e| format!("网络请求失败: {}", e))?;

        let status = response.status();
        if !status.is_success() {
            let error_text = response.text().await
                .unwrap_or_else(|_| "未知错误".to_string());
            return Err(format!("GitHub API 错误: {} - {}", status, error_text));
        }

        let gist: GistResponse = response
            .json()
            .await
            .map_err(|e| format!("解析响应失败: {}", e))?;

        // 保存 Gist ID（如果是新建的）
        let mut config = config.clone();
        if config.gist_id.is_empty() {
            config.gist_id = gist.id.clone();
            self.save_config(&config)?;
        }

        // 更新同步时间
        config.last_sync_time = Some(timestamp.clone());
        self.save_config(&config)?;

        Ok(GistSyncResult {
            success: true,
            uploaded: connections.len(),
            downloaded: 0,
            timestamp,
            message: format!("成功上传到 Gist: {}", gist.id),
            has_conflict: false,
            remote_timestamp: Some(gist.updated_at),
        })
    }

    /// 从 Gist 下载
    pub async fn download_from_gist(&self, config: &GitHubGistConfig) -> Result<GistSyncResult, String> {
        if !config.enabled {
            return Err("GitHub Gist 同步未启用".to_string());
        }

        let gist = match self.fetch_remote_gist(config).await? {
            Some(g) => g,
            None => return Err("Gist 不存在".to_string()),
        };

        // 获取文件内容
        let file_content = gist.files.get(&config.file_name)
            .ok_or_else(|| format!("Gist 中找不到文件: {}", config.file_name))?;

        let remote_connections: Vec<crate::models::connection::SshConnection> =
            serde_json::from_str(&file_content.content)
                .map_err(|e| format!("解析远程连接失败: {}", e))?;

        // 保存到本地
        self.save_local_connections(&remote_connections)?;

        let timestamp = chrono::Utc::now().to_rfc3339();

        // 更新同步时间
        let mut config = config.clone();
        config.last_sync_time = Some(timestamp.clone());
        self.save_config(&config)?;

        Ok(GistSyncResult {
            success: true,
            uploaded: 0,
            downloaded: remote_connections.len(),
            timestamp,
            message: format!("成功从 Gist 下载: {} 条连接", remote_connections.len()),
            has_conflict: false,
            remote_timestamp: Some(gist.updated_at),
        })
    }

    /// 双向同步
    pub async fn sync_bidirectional(&self, config: &GitHubGistConfig) -> Result<GistSyncResult, String> {
        if !config.enabled {
            return Err("GitHub Gist 同步未启用".to_string());
        }

        // 获取本地数据
        let local_connections = self.load_local_connections()?;
        let local_content = serde_json::to_string_pretty(&local_connections)
            .map_err(|e| format!("序列化本地连接失败: {}", e))?;

        // 获取远程数据
        let gist = match self.fetch_remote_gist(config).await? {
            Some(g) => g,
            None => {
                // 没有远程数据，直接上传
                return self.upload_to_gist(config).await;
            }
        };

        let remote_file = gist.files.get(&config.file_name)
            .ok_or_else(|| format!("Gist 中找不到文件: {}", config.file_name))?;

        let remote_connections: Vec<crate::models::connection::SshConnection> =
            serde_json::from_str(&remote_file.content)
                .map_err(|e| format!("解析远程连接失败: {}", e))?;
        let remote_content = &remote_file.content;

        // 冲突检测：比较内容
        let has_conflict = local_content.trim() != remote_content.trim();

        if has_conflict {
            // 检测哪些连接有冲突
            let local_ids: std::collections::HashSet<String> =
                local_connections.iter().map(|c| c.id.clone()).collect();
            let remote_ids: std::collections::HashSet<String> =
                remote_connections.iter().map(|c| c.id.clone()).collect();

            let added_remote: Vec<_> = remote_ids.difference(&local_ids).collect();
            let added_local: Vec<_> = local_ids.difference(&remote_ids).collect();
            let common: Vec<_> = local_ids.intersection(&remote_ids).collect();

            // 简单的合并策略：保留两者，更新共同的，添加新增的
            let mut merged = Vec::new();

            // 添加远程独有的
            for id in added_remote.iter() {
                if let Some(conn) = remote_connections.iter().find(|c| &c.id == *id) {
                    merged.push(conn.clone());
                }
            }

            // 添加本地独有的
            for id in added_local.iter() {
                if let Some(conn) = local_connections.iter().find(|c| &c.id == *id) {
                    merged.push(conn.clone());
                }
            }

            // 保留更新的版本（基于 updated_at）
            for id in common.iter() {
                let local_conn = local_connections.iter().find(|c| &c.id == *id);
                let remote_conn = remote_connections.iter().find(|c| &c.id == *id);

                match (local_conn, remote_conn) {
                    (Some(l), Some(r)) => {
                        // 比较更新时间，选择更新的
                        if l.updated_at > r.updated_at {
                            merged.push(l.clone());
                        } else {
                            merged.push(r.clone());
                        }
                    }
                    (Some(l), None) => merged.push(l.clone()),
                    (None, Some(r)) => merged.push(r.clone()),
                    (None, None) => {}
                }
            }

            // 保存合并后的结果
            self.save_local_connections(&merged)?;

            let timestamp = chrono::Utc::now().to_rfc3339();

            // 更新同步时间
            let mut config = config.clone();
            config.last_sync_time = Some(timestamp.clone());
            self.save_config(&config)?;

            Ok(GistSyncResult {
                success: true,
                uploaded: local_connections.len(),
                downloaded: remote_connections.len(),
                timestamp,
                message: format!("双向同步完成，发现冲突并已合并"),
                has_conflict: true,
                remote_timestamp: Some(gist.updated_at),
            })
        } else {
            // 没有冲突，更新远程
            self.upload_to_gist(config).await
        }
    }

    /// 获取最后同步时间
    pub fn get_last_sync_time(&self) -> Option<String> {
        self.load_config().last_sync_time
    }

    /// 检查是否已配置
    pub fn is_configured(&self) -> bool {
        let config = self.load_config();
        !config.gist_id.is_empty() && !config.personal_access_token.is_empty()
    }

    /// 获取 Gist URL
    pub fn get_gist_url(&self) -> String {
        let config = self.load_config();
        if config.gist_id.is_empty() {
            String::new()
        } else {
            format!("https://gist.github.com/{}", config.gist_id)
        }
    }
}

/// 冲突详情
#[derive(Debug, Clone)]
pub struct ConflictDetail {
    pub local_id: String,
    pub local_updated: String,
    pub remote_updated: String,
    pub conflict_type: ConflictType,
}

#[derive(Debug, Clone)]
pub enum ConflictType {
    BothModified,
    LocalDeletedRemoteModified,
    RemoteDeletedLocalModified,
}

impl GitHubGistSyncService {
    /// 检测冲突详情
    pub async fn detect_conflicts(&self, config: &GitHubGistConfig) -> Result<Vec<ConflictDetail>, String> {
        let local_connections = self.load_local_connections()?;
        let gist = match self.fetch_remote_gist(config).await? {
            Some(g) => g,
            None => return Ok(Vec::new()),
        };

        let remote_file = gist.files.get(&config.file_name)
            .ok_or_else(|| format!("Gist 中找不到文件: {}", config.file_name))?;

        let remote_connections: Vec<crate::models::connection::SshConnection> =
            serde_json::from_str(&remote_file.content)
                .map_err(|e| format!("解析远程连接失败: {}", e))?;

        let mut conflicts = Vec::new();

        let local_ids: std::collections::HashSet<String> =
            local_connections.iter().map(|c| c.id.clone()).collect();
        let remote_ids: std::collections::HashSet<String> =
            remote_connections.iter().map(|c| c.id.clone()).collect();

        // 检查共同存在的连接
        for id in local_ids.intersection(&remote_ids) {
            let local_conn = local_connections.iter().find(|c| &c.id == id).unwrap();
            let remote_conn = remote_connections.iter().find(|c| &c.id == id).unwrap();

            if local_conn.updated_at != remote_conn.updated_at {
                conflicts.push(ConflictDetail {
                    local_id: id.clone(),
                    local_updated: local_conn.updated_at.to_rfc3339(),
                    remote_updated: remote_conn.updated_at.to_rfc3339(),
                    conflict_type: ConflictType::BothModified,
                });
            }
        }

        Ok(conflicts)
    }
}
