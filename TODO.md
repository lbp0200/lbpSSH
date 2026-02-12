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

### 3. 导入导出功能完善 ✅ 已实现

- [x] 集成 `rfd` crate 实现 FilePicker UI
- [x] 添加导入导出界面组件
- [x] 实现文件选择对话框

### 4. 错误处理增强 ✅ 已实现

- [x] 创建 `ErrorDetailDialog` 组件
- [x] 实现详细的错误信息展示
- [x] 添加错误解决方案提示
- [x] 分类错误信息（认证错误/网络错误/配置错误）

### 5. 平台特定功能

#### 5.1 窗口管理 ✅ 已实现
- [x] 使用 dioxus-desktop 内置窗口控制
- [x] 实现窗口最大化功能（WindowControls 组件）
- [x] 窗口大小和最大化状态记忆（ConfigModel WindowConfig）

---

## UI 布局实现

### Flutter 版布局 ✅ 已实现

**实现日期**: 2024-02-12

**布局特点**:
- 顶部标签栏（48px 高度）
- 左侧：设置按钮 ⚙️
- 居中：标签列表
- 右侧：添加按钮 + 下拉菜单
- 全屏终端内容区域
- 无左侧边栏

**实现文件**:
- `src/app.rs` - 主应用组件（Flutter 版布局）
- `src/components/terminal.css` - 更新样式支持新布局

**新增组件**:
- `TopBarComponent` - 顶部导航栏
- `DropdownConnectionItem` - 下拉菜单连接项
- `ConnectionFormModal` - 连接表单弹窗
- `TerminalSettings` - 终端设置
- `ConnectionManagement` - 连接管理
- `ImportExportSettings` - 导入导出
- `SyncSettings` - 同步设置

---

## 代码质量修复

### Cargo Check 警告修复

#### 已完成的修复
- [x] 清理 `src/components/mod.rs` 中未使用的导入
- [x] 清理 `src/ssh/sync_state.rs` 中未使用的导入
- [x] 清理 `src/ssh/mod.rs` 中未使用的导入
- [x] 修复 `src/app.rs` - Rust 所有权和闭包问题
- [x] 移除 `TerminalState` 未使用字段
- [x] 修复 `src/ssh/session.rs` - 处理 disconnect 返回值
- [x] 为 `AuthType` 实现 `Display` trait
- [x] 为 `TabInfo` 实现 `Debug` trait

---

## 单元测试

### UI 组件测试 ✅ 已实现

**实现日期**: 2024-02-12

**测试文件**: `src/tests/components_test.rs`

**测试数量**: 24 个测试

| 测试类别 | 测试数量 |
|---------|---------|
| TabInfo 测试 | 5 |
| SshConnection 测试 | 4 |
| AuthType 测试 | 1 |
| 连接操作测试 | 3 |
| 状态文本测试 | 3 |
| 辅助功能测试 | 8 |

**运行测试**:
```bash
cargo test                    # 运行所有测试
cargo test components_test   # 只运行组件测试
```

**测试统计**:
- 总测试数: 57 个
- 通过: 57 个
- 失败: 0 个

---

## 功能优先级

### P0 - 核心功能
1. ✅ 本地终端支持
2. ✅ GitHub Gist 同步
3. ✅ 错误处理增强
4. ✅ Gitee Gist 同步
5. ✅ 导入导出 UI
6. ✅ Flutter 版布局

### P1 - 增强功能
1. ✅ 窗口管理
2. ✅ 单元测试

---

## 进度跟踪

| 功能 | 状态 | 说明 |
|------|------|------|
| Flutter 版布局 | ✅ 已完成 | 顶部标签栏 + 下拉菜单 |
| GitHub Gist 同步 | ✅ 已完成 | 服务 + UI 已实现 |
| 冲突检测 | ✅ 已完成 | 时间戳/版本号检测 |
| 错误对话框 | ✅ 已完成 | ErrorDialog 组件 |
| 本地终端 | ✅ 已完成 | LocalTerminalService |
| 导入导出 UI | ✅ 已完成 | CSV/SSH Config 导出 |
| Gitee Gist 同步 | ✅ 已完成 | GiteeGistSyncService |
| 窗口管理 | ✅ 已完成 | WindowControls + WindowConfig |
| 单元测试 | ✅ 已完成 | 57 个测试全部通过 |

---

## 更新文件 (v0.2.0 → v0.3.0)

| 文件 | 变更 |
|------|------|
| `src/app.rs` | 重写为 Flutter 版布局 |
| `src/tests/components_test.rs` | 新增 24 个 UI 组件测试 |
| `src/tests/mod.rs` | 新增测试模块 |
| `src/models/connection.rs` | 为 AuthType 实现 Display |
| `src/app.rs` | 为 TabInfo 实现 Debug |

---

## 备注

- Flutter 版作为功能参考实现
- 优先实现高频使用功能
- 保持代码简洁，避免过度设计
- v0.3.0 完成 Flutter 版布局和 UI 测试
