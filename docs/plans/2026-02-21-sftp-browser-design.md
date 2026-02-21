# SFTP 文件浏览器设计

## 背景

用户需要通过 lbpSSH 使用 SFTP 功能管理远程服务器上的文件，希望通过独立文件浏览器界面操作。

## 目标

- 在连接列表中添加 SFTP 入口按钮
- 复用已有终端连接建立 SFTP 会话
- 支持多标签页同时打开多个 SFTP 浏览器

## 架构

### 组件

| 组件 | 位置 | 说明 |
|------|------|------|
| `SftpService` | `lib/domain/services/sftp_service.dart` | SFTP 操作封装 |
| `SftpProvider` | `lib/presentation/providers/sftp_provider.dart` | 状态管理 |
| `SftpBrowserScreen` | `lib/presentation/screens/sftp_browser_screen.dart` | 文件浏览器界面 |
| `SftpBrowserTab` | `lib/presentation/widgets/sftp_browser_tab.dart` | 浏览器标签页组件 |

### 数据流

```
用户点击 SFTP 按钮
    → 检查终端是否已连接该服务器
    → 复用 SSHClient 创建 SFTP 会话
    → 显示 SftpBrowserScreen
```

## 界面设计

### SftpBrowserScreen

```
┌─────────────────────────────────────────────────┐
│ ← /home/user/Documents                    [↑]  │  ← 路径栏 + 刷新
├─────────────────────────────────────────────────┤
│  📁 parent/                                    │
│  📁 subfolder/                          [...]   │
│  📄 file1.txt                          [...]   │
│  🖼️ image.png                           [...]   │
├─────────────────────────────────────────────────┤
│  [↑ 上传   ↓ 下载   📁 新建   ⟳ 刷新           │  ← 工具栏
└─────────────────────────────────────────────────┘
```

### 功能清单

| 功能 | 说明 |
|------|------|
| 浏览目录 | 双击进入目录，点击".."返回上级 |
| 上传文件 | 从本地上传文件到当前目录 |
| 下载文件 | 将远程文件下载到本地 |
| 新建文件夹 | 在当前目录创建文件夹 |
| 删除 | 删除文件或目录 |
| 重命名 | 长按/右键重命名 |
| 复制路径 | 复制当前文件完整路径 |

## 技术方案

### dartssh2 SFTP 支持

通过 `client.sftp()` 获取 SFTP 客户端实例：

```dart
final sftp = client.sftp();
final items = await sftp.listdir('/path');
await sftp.upload(localPath, remotePath);
await sftp.download(remotePath, localPath);
await sftp.mkdir('/path/dir');
await sftp.rmdir('/path/dir');
await sftp.remove('/path/file');
await sftp.rename('/old', '/new');
```

### 连接复用

- 已有终端连接时，复用 `SSHService._client`
- 未连接时，创建新连接

## 实现步骤

1. 创建 `SftpService`
2. 创建 `SftpProvider`
3. 创建 `SftpBrowserScreen` 和 `SftpBrowserTab`
4. 修改连接列表添加 SFTP 按钮

## 验收标准

- [ ] SFTP 按钮出现在连接列表
- [ ] 可以浏览远程目录
- [ ] 可以上传文件
- [ ] 可以下载文件
- [ ] 可以创建文件夹
- [ ] 可以删除文件/目录
- [ ] 可以重命名
- [ ] 支持多标签页
