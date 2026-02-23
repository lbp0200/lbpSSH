# lbpSSH

跨平台 SSH 终端管理器 | Cross-platform SSH Terminal Manager

<div align="center">

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-green.svg)](#)
[![Flutter](https://img.shields.io/badge/Flutter-3.10.7+-blue.svg)](#)

</div>

---

## 功能特性 | Features

- **SSH 连接管理** - 添加、编辑、删除 SSH 连接配置
  - SSH connection management - Add, edit, delete SSH connections
- **多种认证方式** - 密码、密钥、密钥+密码
  - Multiple authentication methods - Password, Private Key, Private Key + Password
- **跳板机支持** - 通过跳板机连接到目标服务器
  - Jump host/Bastion support - Connect through jump hosts
- **终端模拟器** - 基于 xterm 的完整交互式终端体验
  - Terminal emulator - Full interactive terminal based on xterm
- **多标签页** - 同时管理多个 SSH 连接
  - Multi-tab support - Manage multiple SSH connections simultaneously
- **配置同步** - 支持同步到 Gitee Gist 或 GitHub Gist
  - Configuration sync - Sync to Gitee Gist or GitHub Gist
- **加密存储** - 敏感信息本地加密存储
  - Encrypted storage - Sensitive data encrypted locally

---

## 为什么选择 lbpSSH | Why lbpSSH

| Feature | lbpSSH | Termius | MobaXterm | PuTTY | Tabby |
|---------|--------|---------|-----------|-------|-------|
| **跨平台** Cross-platform | ✅ Win/Lin/Mac | ✅ Win/Lin/Mac | ❌ Windows | ❌ Windows | ✅ Win/Lin/Mac |
| **开源免费** Open Source & Free | ✅ MIT | ❌ 收费 | ❌ 收费 | ✅ 免费 | ✅ 免费 |
| **配置同步** Config Sync | ✅ Gist | ✅ Termius Cloud | ❌ | ❌ | ❌ |
| **跳板机** Jump Host | ✅ | ✅ | ✅ | ❌ | ✅ |
| **多标签页** Multi-tab | ✅ | ✅ | ✅ | ❌ | ✅ |
| **加密存储** Encrypted Storage | ✅ | ✅ | ✅ | ❌ | ❌ |
| **自托管同步** Self-hosted Sync | ✅ Gitee | ❌ | ❌ | ❌ | ❌ |

### 核心优势 | Key Advantages

1. **完全开源** - MIT 许可证，代码完全透明
   - Fully open source - MIT license, completely transparent code

2. **自托管同步** - 支持 Gitee Gist，无需第三方云服务
   - Self-hosted sync - Gitee Gist support, no third-party cloud

3. **隐私优先** - 所有数据本地加密存储
   - Privacy first - All data encrypted locally

4. **Flutter 开发** - 现代化 UI，一套代码多平台
   - Flutter based - Modern UI, single codebase multi-platform

### 对比说明 | Comparison Notes

- **Termius**: 功能全面但收费，自有云服务
- **MobaXterm**: Windows 首选，但仅限 Windows
- **PuTTY**: 经典工具，但功能简单，无标签页
- **Tabby**: 现代化终端，但配置同步需要付费插件

lbpSSH 结合了以上工具的优点，提供免费、跨平台、配置同步的完整解决方案。

---

## 下载安装 | Download & Install

### macOS

#### Homebrew (推荐 | Recommended)

```bash
# 添加 Homebrew Tap
brew tap lbp0200/lbpssh-tap

# 安装 lbpSSH
brew install --cask lbpssh
```

#### 手动下载 | Manual Download

从 [GitHub Releases](https://github.com/lbp0200/lbpssh/releases/latest) 下载 `lbpSSH-macos-universal.zip`，解压后拖动 `lbpSSH.app` 到 Applications 文件夹。

---

### Windows

从 [GitHub Releases](https://github.com/lbp0200/lbpssh/releases/latest) 下载 `lbpSSH-windows-x64.zip`，解压后运行 `lbpSSH.exe`。

---

### Linux

从 [GitHub Releases](https://github.com/lbp0200/lbpssh/releases/latest) 下载 `lbpSSH-linux-x64.zip`，解压后运行：

```bash
cd bundle
chmod +x lbpSSH
./lbpSSH
```

---

## 快速开始 | Quick Start

### 前置要求 | Requirements

- Flutter SDK (3.10.7+)
- Dart SDK
- Desktop platform support (Windows, Linux, macOS)

### 安装依赖 | Install Dependencies

```bash
flutter pub get
```

### 运行应用 | Run Application

```bash
# Windows
flutter run -d windows

# Linux
flutter run -d linux

# macOS
flutter run -d macos
```

### 构建发布版本 | Build for Release

```bash
# Windows
flutter build windows --release

# Linux
flutter build linux --release

# macOS
flutter build macos --release
```

---

## 配置同步 | Configuration Sync

将 SSH 配置同步到云端 Gist，方便多设备共享配置 | Sync SSH config to cloud Gist for multi-device sharing

### Gitee Gist 同步 | Gitee Gist Sync

1. 访问 [Gitee 个人访问令牌](https://gitee.com/profile/personal_access_tokens) 创建 Token | Create token at Gitee personal access tokens
2. 在应用的"同步设置"中选择 **Gitee Gist** | Select **Gitee Gist** in sync settings
3. 填入 Token，选择是否填写 Gist ID | Enter token, optionally fill Gist ID
4. 点击"保存配置"，然后使用"上传配置"同步到 Gist | Save config, then use "Upload" to sync

### GitHub Gist 同步 | GitHub Gist Sync

1. 访问 [GitHub Settings](https://github.com/settings/tokens/new?scopes=gist) 创建 Personal Access Token（需勾选 `gist` 权限）| Create Personal Access Token at GitHub Settings (need `gist` scope)
2. 在应用的"同步设置"中选择 **GitHub Gist** | Select **GitHub Gist** in sync settings
3. 填入 Token，选择是否填写 Gist ID | Enter token, optionally fill Gist ID
4. 点击"保存配置"，然后使用"上传配置"同步到 Gist | Save config, then use "Upload" to sync

---

## 使用说明 | Usage

### 添加 SSH 连接 | Add SSH Connection

1. 点击应用栏的"添加连接"按钮 | Click "Add Connection" button
2. 填写连接信息：| Fill connection info:
   - 连接名称 | Connection name
   - 主机地址和端口 | Host address and port
   - 用户名 | Username
   - 选择认证方式（密码/密钥/密钥+密码）| Auth method (Password/Private Key/Private Key+Password)
   - 输入相应的认证信息 | Enter auth info
3. 可选：配置跳板机 | Optional: Configure jump host
4. 点击"保存" | Click "Save"

### 连接管理 | Connection Management

- 点击连接列表中的连接快速打开终端 | Click connection to open terminal
- 支持多标签页同时连接多个服务器 | Multi-tab for multiple servers
- 标签页支持拖拽排序 | Drag to reorder tabs

### 文件传输 | File Transfer

lbpSSH 使用 Kitty 协议的 OSC 5113 实现文件传输 | lbpSSH uses Kitty protocol OSC 5113 for file transfer

> **注意 | Note**: 远程服务器需要安装 Kitty 的 `ki` 工具才能接收文件 | Remote server needs Kitty's `ki` tool installed to receive files

- **已实现 | Implemented**: 文件上传、文件列表浏览、文件下载 (File Upload, File list browsing, File download)

---

## 注意事项 | Notes

### Kitty 协议文件传输 | Kitty Protocol File Transfer

lbpSSH 使用 Kitty 协议的 OSC 5113 实现文件传输，替代传统的 SFTP。

lbpSSH uses Kitty protocol OSC 5113 for file transfer, replacing traditional SFTP.

**前置要求 | Requirements**:
- 远程服务器需要安装 [Kitty](https://sw.kovidgoyal.net/kitty/) 终端工具
- Remote server needs [Kitty](https://sw.kovidgoyal.net/kitty/) terminal tool installed

**安装 ki 工具 | Install ki tool**:
```bash
# 方法一：从源码编译
git clone https://github.com/kovidgoyal/kitty
cd kitty
python3 setup.py ki

# 方法二：使用 pip
pip3 install kitty-cli
```

**已实现功能 | Implemented**:
- ✅ 文件上传 (File Upload)
- ✅ 文件列表浏览 (File list browsing)
- ✅ 文件下载 (File download)
- ✅ 目录导航 (cd, cd ..)
- ✅ 目录操作 (mkdir, rm, rmdir)

---

## 项目结构 | Project Structure

```
lib/
├── main.dart                    # 应用入口 | App entry point
├── core/                        # 核心配置 | Core config
│   ├── theme/                   # 主题配置 | Theme
│   └── constants/               # 常量定义 | Constants
├── data/                         # 数据层 | Data layer
│   ├── models/                  # 数据模型 | Data models
│   └── repositories/             # 数据仓库 | Repositories
├── domain/                       # 业务逻辑层 | Business logic
│   └── services/                # 业务服务 | Services
├── presentation/                  # 展示层 | Presentation layer
│   ├── screens/                 # 页面 | Screens
│   ├── widgets/                 # 组件 | Widgets
│   └── providers/               # 状态管理 | State management
└── utils/                        # 工具类 | Utilities
```

---

## 技术栈 | Tech Stack

| 技术 | Technology | 用途 | Purpose |
|------|------------|------|---------|
| Flutter | Cross-platform UI | UI 框架 | UI framework |
| dartssh2 | SSH Client | SSH 客户端 | SSH client |
| xterm | Terminal Emulator | 终端模拟器 | Terminal emulator |
| flutter_pty | PTY Support | 伪终端支持 | PTY support |
| provider | State Management | 状态管理 | State management |
| dio | HTTP Client | HTTP 客户端 | HTTP client |
| encrypt | Encryption | 加密 | Encryption |
| shared_preferences | Local Storage | 本地存储 | Local storage |

---

## 开发 | Development

### 代码规范 | Code Conventions

- 文件命名使用 `snake_case` | Files: `snake_case`
- 类使用 `PascalCase` | Classes: `PascalCase`
- 变量方法使用 `camelCase` | Variables/Methods: `camelCase`
- 私有成员使用下划线前缀 | Private members: underscore prefix

### 代码生成 | Code Generation

修改模型类后需要重新生成代码 | Regenerate after model changes:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 代码分析 | Code Analysis

```bash
flutter analyze
```

---

## 贡献 | Contributing

欢迎提交 Issue 和 Pull Request！| Issues and PRs welcome!

---

## 许可证 | License

MIT License
