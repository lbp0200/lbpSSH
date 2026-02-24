# SFTP 界面改进设计

## 概述

改进 SFTP 功能的用户体验，解决三个问题：
1. 点击 SFTP 时自动创建终端会话
2. SFTP 初始目录使用用户主目录而非根目录
3. MacOS 远程服务器命令兼容性问题

## 问题 1：自动打开终端

### 当前问题
点击 SFTP 按钮时，SFTPProvider.openTab() 要求已有终端会话，否则抛出异常 "终端会话不存在"。

### 解决方案
修改 main_screen.dart 的 onSftpTap 回调：

```dart
onSftpTap: (connection) async {
  final terminalProvider = context.read<TerminalProvider>();
  // 先创建终端会话
  await terminalProvider.createSession(connection);
  // 然后打开 SFTP 页面
  if (context.mounted) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SftpBrowserScreen(connection: connection),
      ),
    );
  }
}
```

## 问题 2：SFTP 初始目录

### 当前问题
SFTP 打开时固定使用根目录 `/`，用户体验不佳。

### 解决方案
从终端会话获取用户主目录。SSH 连接后可通过以下方式获取：
1. 使用 `echo $HOME` 或 `echo ~` 命令获取主目录
2. 在 TerminalSession 中存储工作目录信息

修改 SftpProvider.openTab()：
- 终端创建后自动执行 `pwd` 或 `echo $HOME` 获取目录
- 将获取的目录作为初始 currentPath

## 问题 3：MacOS 命令兼容性

### 当前问题
SSH 到 MacOS 服务器时，终端可能发送 Linux 特有的命令参数，导致错误。

### 解决方案
添加 OS 类型检测机制：

1. 在 SSH 连接时执行 `uname -s` 检测操作系统类型
2. 在 TerminalSession 中存储 osType 属性
3. 创建命令适配器，根据 OS 类型调整命令参数

示例适配：
- Linux: `ls -la --time-style=long-iso`
- MacOS: `ls -la -T` 或 `ls -la`

## 数据流

```
用户点击 SFTP
    ↓
TerminalProvider.createSession() 创建终端
    ↓
SSH 连接成功，执行 uname -s 检测 OS
    ↓
TerminalSession 存储 osType
    ↓
SftpProvider.openTab() 读取当前目录
    ↓
SftpBrowserScreen 显示文件列表
```

## 文件修改清单

| 文件 | 修改内容 |
|------|----------|
| main_screen.dart | onSftpTap 添加自动创建终端逻辑 |
| terminal_service.dart | 添加 osType 属性和获取方法 |
| terminal_provider.dart | 添加 OS 类型获取逻辑 |
| sftp_provider.dart | openTab 获取初始目录逻辑 |
| sftp_browser_screen.dart | 移除固定根目录逻辑 |

## 测试要点

1. 点击 SFTP 按钮自动创建终端并打开页面
2. SFTP 初始目录为用户主目录
3. SSH 到 MacOS 服务器无命令错误
4. SSH 到 Linux 服务器正常工作
