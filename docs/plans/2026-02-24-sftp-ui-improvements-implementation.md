# SFTP UI 改进实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 改进 SFTP 功能用户体验：点击 SFTP 自动创建终端、使用用户主目录作为初始目录、MacOS 命令兼容性

**Architecture:** 在 TerminalSession 中添加 osType 和 workingDirectory 属性，SSH 连接时检测并存储

**Tech Stack:** Flutter, dartssh2, provider

---

## Task 1: 修改 main_screen.dart - 点击 SFTP 自动创建终端

**Files:**
- Modify: `lib/presentation/screens/main_screen.dart:43-50`

**Step 1: 修改 onSftpTap 回调**

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
},
```

**Step 2: 验证构建**

Run: `flutter analyze lib/presentation/screens/main_screen.dart`
Expected: 无错误

---

## Task 2: 修改 TerminalSession - 添加 OS 类型和工作目录

**Files:**
- Modify: `lib/domain/services/terminal_service.dart:30-50`

**Step 1: 在 TerminalSession 类中添加属性**

在 TerminalSession 类中，添加以下属性（在 `_fileTransferController` 之后）：

```dart
// OS 类型: 'Linux', 'Darwin' (macOS), 'Windows' 等
String osType = 'Linux';

// 当前工作目录
String workingDirectory = '/';
```

**Step 2: 添加设置工作目录的方法**

```dart
/// 设置当前工作目录
void setWorkingDirectory(String path) {
  workingDirectory = path;
}

/// 设置 OS 类型
void setOsType(String type) {
  osType = type;
}
```

**Step 3: 验证构建**

Run: `flutter analyze lib/domain/services/terminal_service.dart`
Expected: 无错误

---

## Task 3: 修改 SshService - 连接时检测 OS 类型和获取工作目录

**Files:**
- Modify: `lib/domain/services/ssh_service.dart:430` (在 `_updateState(SshConnectionState.connected)` 之后添加)

**Step 1: 在连接成功后检测 OS 类型和获取工作目录**

在 `connect` 方法中，`_updateState(SshConnectionState.connected)` 之后添加：

```dart
// 连接成功后，获取 OS 类型和工作目录
await _detectOsTypeAndWorkingDirectory();
```

**Step 2: 添加检测方法**

在 SshService 类末尾（dispose 方法之前）添加：

```dart
/// 检测远程 OS 类型和获取工作目录
Future<void> _detectOsTypeAndWorkingDirectory() async {
  try {
    // 检测 OS 类型
    final osResult = await executeCommand('uname -s');
    final detectedOs = osResult.trim();
    
    // 存储 OS 类型（需要通过某种方式通知 TerminalSession）
    // 由于 TerminalSession 由 TerminalService 管理，这里暂不直接设置
    // 改为在需要时通过 SshService 获取
  } catch (e) {
    // 检测失败，使用默认 Linux
  }
}

/// 获取 OS 类型
String get osType {
  return _osType;
}

String _osType = 'Linux';
```

**Step 3: 修改 executeCommand 以存储 OS 类型**

修改 `executeCommand` 方法，在执行 `uname -s` 时存储结果：

```dart
if (command.trim() == 'uname -s') {
  _osType = output.trim();
}
```

或者更简洁的方式：在 connect 成功后执行一次命令检测。

**Step 4: 验证构建**

Run: `flutter analyze lib/domain/services/ssh_service.dart`
Expected: 无错误

---

## Task 4: 修改 TerminalProvider - 传递 OS 信息到 TerminalSession

**Files:**
- Modify: `lib/presentation/providers/terminal_provider.dart:76-103`

**Step 1: 修改 createSession 方法**

在 SSH 连接成功后，获取 OS 类型并设置到 TerminalSession：

```dart
// 自动连接 SSH
try {
  await sshService.connect(connection);
  
  // 获取 OS 类型并设置到 TerminalSession
  final session = _terminalService.getSession(connection.id);
  if (session != null) {
    session.setOsType(sshService.osType);
    // 获取工作目录
    try {
      final pwdResult = await sshService.executeCommand('pwd');
      session.setWorkingDirectory(pwdResult.trim());
    } catch (e) {
      // 使用默认目录
    }
  }
} catch (e) {
  // ...
}
```

**Step 2: 验证构建**

Run: `flutter analyze lib/presentation/providers/terminal_provider.dart`
Expected: 无错误

---

## Task 5: 修改 SftpProvider - 使用终端工作目录作为初始目录

**Files:**
- Modify: `lib/presentation/providers/sftp_provider.dart:31-53`

**Step 1: 修改 openTab 方法**

获取终端会话的当前目录作为 SFTP 初始目录：

```dart
Future<SftpTab> openTab(SshConnection connection, {String? password}) async {
  final tabId = '${connection.id}_${DateTime.now().millisecondsSinceEpoch}';

  // 获取终端会话
  final session = _terminalProvider.getSession(connection.id);
  if (session == null) {
    throw Exception('终端会话不存在');
  }

  // 创建 KittyFileTransferService
  final transferService = KittyFileTransferService(session: session);

  // 使用终端当前工作目录作为初始目录
  final initialPath = session.workingDirectory.isNotEmpty 
      ? session.workingDirectory 
      : '/';

  final tab = SftpTab(
    id: tabId,
    connection: connection,
    service: transferService,
    currentPath: initialPath,
  );

  _tabs[tabId] = tab;
  notifyListeners();
  return tab;
}
```

**Step 2: 验证构建**

Run: `flutter analyze lib/presentation/providers/sftp_provider.dart`
Expected: 无错误

---

## Task 6: 测试完整流程

**Step 1: 运行应用并测试**

```bash
flutter run -d macos
```

**Step 2: 测试场景**
1. 选择一个 SSH 连接，点击 SFTP 按钮
2. 验证自动创建终端并打开 SFTP 页面
3. 验证初始目录为用户主目录（不是 /）
4. SSH 到 MacOS 服务器，验证终端命令正常工作

**Step 3: 运行分析**

Run: `flutter analyze`
Expected: 无错误

---

## 提交变更

```bash
git add lib/presentation/screens/main_screen.dart \
  lib/domain/services/terminal_service.dart \
  lib/domain/services/ssh_service.dart \
  lib/presentation/providers/terminal_provider.dart \
  lib/presentation/providers/sftp_provider.dart

git commit -m "feat: improve SFTP - auto-create terminal, use home directory, MacOS compatibility"
```
