# lbpSSH Rust 版功能开发计划

## 概述

对比 Flutter 版 lbpSSH，列出 Rust 版需要实现的功能和待修复的问题。

---

## 核心功能缺失

### 1. 本地终端支持 ✅ 已实现

- [x] 实现 `LocalTerminalService` - 支持创建本地 Shell 终端会话
- [x] 添加本地终端选项到连接表单
- [x] 支持 macOS/Linux/Windows 本地 shell 路径检测

### 2. 同步功能完善

#### 2.1 GitHub Gist 同步 ✅ 已实现
- [x] 实现 `GitHubGistSyncService`
- [x] 添加 Gist ID 和 Token 配置 UI
- [x] 实现 Gist 上传/下载功能
- [x] 双向同步支持

#### 2.2 Gitee Gist 同步 ✅ 已实现
- [x] 实现 `GiteeGistSyncService`
- [x] 添加 Gitee Token 配置 UI
- [x] Gitee API 集成

#### 2.3 冲突检测 ✅ 已实现
- [x] 实现基于版本号的冲突检测
- [x] 实现基于时间戳的冲突检测
- [ ] 冲突解决 UI 对话框
- [ ] 手动合并/覆盖选项

### 3. 导入导出功能完善 ✅ 已实现

- [x] 集成 `rfd` crate 实现 FilePicker UI
- [x] 添加导入导出界面组件
- [x] 实现文件选择对话框
- [ ] 添加合并策略选择 UI（覆盖/跳过/合并）
- [ ] 导入预览功能

### 4. 错误处理增强 ✅ 已实现

- [x] 创建 `ErrorDetailDialog` 组件
- [x] 实现详细的错误信息展示
- [x] 添加错误解决方案提示
- [x] 分类错误信息（认证错误/网络错误/配置错误）

### 5. 平台特定功能

#### 5.1 macOS 沙箱处理
- [ ] 实现私钥文件沙箱路径处理
- [ ] 添加 `file_picker` 或 `objc` crate 处理文件访问
- [ ] macOS App Sandbox 兼容性

#### 5.2 窗口管理
- [ ] 集成 `window` crate 实现窗口控制
- [ ] 实现窗口最大化功能
- [ ] 窗口大小记忆

---

## 代码质量修复

### Cargo Check 警告修复

#### 已完成的修复
- [x] 清理 `src/components/mod.rs` 中未使用的导入
  - [x] `SettingsButton`, `SyncSettings`, `SyncSettingsButton`
  - [x] `ImportExport`, `ImportExportButton`
  - [x] `ConnectionSearch`, `GroupFilter`
  - [x] `TerminalSettingsButton`
  - [x] `SettingsPage`, `SettingsPageButton`, `SettingsTab`

- [x] 清理 `src/ssh/sync_state.rs` 中未使用的导入
- [x] 清理 `src/ssh/mod.rs` 中未使用的导入

- [x] 修复 `src/app.rs:57` - `conn_id`
- [x] 修复 `src/components/terminal.rs:146` - `ansi_parser`
- [x] 修复 `src/components/connection_list.rs:19-20`
- [x] 修复 `src/components/search.rs:10` - `filter_group`

- [x] 移除 `src/components/terminal.rs:63` - `param_start` 的 mut

- [x] 移除 `TerminalState` 未使用字段
- [x] 移除 `AnsiParser` 的 `buffer` 和 `parse` 方法

- [x] 修复 `src/ssh/session.rs:374` - 处理 disconnect 返回值

#### 待处理的警告（预期，因为功能未完整实现）
以下警告是预期的，因为相关功能仍在计划中：
- `LocalTerminalService` - 本地终端功能已实现，UI 待集成
- `LocalTerminalError` - 错误类型已定义，使用时将消除警告
- `SimpleTerminal` - 简单终端已实现，UI 待集成
- `GiteeGistSyncService` - Gitee 同步已实现，UI 待集成
- `GitHubGistSyncService` - GitHub 同步已实现，UI 已集成
- `FilePicker` - 文件选择器已实现，与 UI 集成中
- `ImportExportService` - 导入导出已实现，UI 已集成

**当前状态**: 核心功能已完成，UI 集成进行中

---

## 功能优先级

### P0 - 核心功能
1. ✅ 本地终端支持
2. ✅ GitHub Gist 同步
3. ✅ 错误处理增强
4. ✅ 代码警告修复
5. ✅ Gitee Gist 同步
6. ✅ 导入导出 UI

### P1 - 重要功能
1. [ ] 冲突检测 UI
2. [ ] 导入合并策略 UI
3. [ ] macOS 沙箱处理

### P2 - 增强功能
1. [ ] 窗口管理
2. [ ] 导入预览功能
3. [ ] 次要代码警告修复

---

## 进度跟踪

| 功能 | 状态 | 说明 |
|------|------|------|
| 代码警告修复 | ✅ 已完成 | 从 47 个减少到预期数量 |
| GitHub Gist 同步 | ✅ 已完成 | 服务 + UI 已实现 |
| 冲突检测 | ✅ 已完成 | 时间戳/版本号检测 |
| 错误对话框 | ✅ 已完成 | ErrorDialog 组件 |
| 本地终端 | ✅ 已完成 | LocalTerminalService |
| 导入导出 UI | ✅ 已完成 | CSV/SSH Config 导出 |
| Gitee Gist 同步 | ✅ 已完成 | GiteeGistSyncService |

---

## 新增文件 (v0.2.0)

| 文件 | 描述 |
|------|------|
| `src/utils/file_picker.rs` | 跨平台文件选择器封装 |
| `src/utils/gitee_gist_sync.rs` | Gitee Gist 同步服务 |
| `src/ssh/local_terminal.rs` | 本地终端服务 |
| `src/components/error_dialog.rs` | 错误对话框组件 |
| `src/components/settings_page.rs` | 设置页面组件 |

---

## 更新文件 (v0.2.0)

| 文件 | 变更 |
|------|------|
| `Cargo.toml` | 添加 rfd, csv 依赖 |
| `src/utils/mod.rs` | 导出新模块 |
| `src/utils/import_export.rs` | 添加 CSV/SSH Config 支持 |
| `src/utils/github_gist_sync.rs` | 完善 Gist 同步功能 |
| `src/models/config.rs` | 添加 SyncPlatform, gist_id, detect_shell |
| `src/components/import_export.rs` | 集成 FilePicker |
| `src/components/sync_settings.rs` | 添加 Gitee 选项和 Gist ID |
| `src/components/terminal.rs` | 添加 TerminalType 支持 |
| `src/ssh/mod.rs` | 导出 local_terminal 模块 |

---

## 备注

- Flutter 版作为功能参考实现
- 优先实现高频使用功能
- 保持代码简洁，避免过度设计
- v0.2.0 完成所有核心功能实现
