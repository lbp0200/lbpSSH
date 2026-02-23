# Kitty 协议文件传输完整实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 实现完整的 Kitty 协议文件传输功能：文件列表浏览、文件下载、目录操作、协议检测

**Architecture:** 使用纯 Kitty 协议 - 通过终端执行 `ls` 命令解析文件列表，使用 `ki send` 接收模式下载文件，通过终端命令操作目录

**Tech Stack:** Flutter, dartssh2, xterm, kterm

---

## Task 1: 实现 RemoteFile 数据模型

**Files:**
- Modify: `lib/presentation/screens/sftp_browser_screen.dart:10-26`

**Step 1: 修改 FileItem 类**

将现有的简单 `FileItem` 类替换为完整实现:

```dart
/// 远程文件项（用于显示文件列表）
class FileItem {
  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final DateTime? modified;
  final String permissions;

  FileItem({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size = 0,
    this.modified,
    this.permissions = '',
  });
}
```

**Step 2: 运行分析验证**

Run: `flutter analyze --no-fatal-infos lib/presentation/screens/sftp_browser_screen.dart`
Expected: PASS (no errors)

**Step 3: Commit**

```bash
git add lib/presentation/screens/sftp_browser_screen.dart
git commit -m "feat: enhance FileItem model with full metadata"
```

---

## Task 2: 实现文件列表解析器

**Files:**
- Create: `lib/domain/services/file_list_parser.dart`

**Step 1: 创建文件列表解析器**

```dart
import 'package:intl/intl.dart';

/// 远程文件解析器
/// 解析 ls -la --time-style=long-iso 输出
class FileListParser {
  /// 解析 ls -la 输出
  /// 示例: drwxr-xr-x  2 user user 4096 2024-01-15 10:30 dirname
  static List<FileItem> parse(String output, String currentPath) {
    final lines = output.split('\n');
    final items = <FileItem>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final item = _parseLine(trimmed, currentPath);
      if (item != null) {
        items.add(item);
      }
    }

    return items;
  }

  static FileItem? _parseLine(String line, String currentPath) {
    // 跳过 total 行
    if (line.startsWith('total ')) return null;

    // 解析权限和类型
    // 格式: drwxr-xr-x  2 user user 4096 2024-01-15 10:30 filename
    // 或: -rw-r--r--  1 user user 1234 2024-01-15 09:20 filename

    final parts = line.split(RegExp(r'\s+'));
    if (parts.length < 9) return null;

    final permissions = parts[0];
    final isDirectory = permissions.startsWith('d');

    // 跳过 . 和 ..
    final name = parts.sublist(8).join(' ');
    if (name == '.' || name == '..') return null;

    // 解析大小
    final size = int.tryParse(parts[4]) ?? 0;

    // 解析日期时间
    DateTime? modified;
    if (parts.length >= 10) {
      final dateStr = '${parts[5]} ${parts[6]} ${parts[7]}';
      try {
        modified = DateTime.parse(dateStr);
      } catch (_) {
        // 忽略解析错误
      }
    }

    // 构建完整路径
    final fullPath = currentPath == '/'
        ? '/$name'
        : '$currentPath/$name';

    return FileItem(
      name: name,
      path: fullPath,
      isDirectory: isDirectory,
      size: size,
      modified: modified,
      permissions: permissions,
    );
  }
}
```

**Step 2: 添加 intl 依赖**

检查 pubspec.yaml 是否已有 intl 依赖，如果没有则添加。

**Step 3: 运行分析验证**

Run: `flutter analyze --no-fatal-infos lib/domain/services/file_list_parser.dart`
Expected: PASS

**Step 4: Commit**

```bash
git add lib/domain/services/file_list_parser.dart
git commit -m "feat: add FileListParser for ls output parsing"
```

---

## Task 3: 实现 KittyFileTransferService 目录导航

**Files:**
- Modify: `lib/domain/services/kitty_file_transfer_service.dart:99-119`

**Step 1: 实现 listCurrentDirectory**

更新 `listCurrentDirectory` 方法，使用 ls 命令:

```dart
/// 获取当前目录文件列表
Future<List<FileItem>> listCurrentDirectory() async {
  if (_session == null) {
    throw Exception('未连接到终端');
  }

  // 发送 ls 命令
  final completer = Completer<String>();
  final outputBuffer = StringBuffer();

  // 监听终端输出，等待命令完成
  final subscription = _session!.inputService.outputStream.listen((output) {
    outputBuffer.write(output);
  });

  // 执行 ls 命令
  await _session!.executeCommand('ls -la --time-style=long-iso');

  // 等待一段时间让输出完成
  await Future.delayed(const Duration(milliseconds: 500));

  // 取消订阅
  await subscription.cancel();

  // 解析输出
  final output = outputBuffer.toString();
  return FileListParser.parse(output, _currentPath);
}
```

**Step 2: 实现 changeDirectory**

```dart
/// 进入目录
Future<void> changeDirectory(String path) async {
  if (_session == null) {
    throw Exception('未连接到终端');
  }

  final newPath = path.startsWith('/')
      ? path
      : (_currentPath == '/' ? '/$path' : '$_currentPath/$path');

  await _session!.executeCommand('cd "$newPath"');
  _currentPath = newPath;

  // 同时更新 PWD
  await _session!.executeCommand('export PWD="$newPath"');
}
```

**Step 3: 实现 goUp**

```dart
/// 返回上级目录
Future<void> goUp() async {
  if (_currentPath == '/') return;

  await _session!.executeCommand('cd ..');
  final parts = _currentPath.split('/');
  parts.removeLast();
  _currentPath = parts.isEmpty ? '/' : parts.join('/');
}
```

**Step 4: 运行分析验证**

Run: `flutter analyze --no-fatal-infos lib/domain/services/kitty_file_transfer_service.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/domain/services/kitty_file_transfer_service.dart
git commit -m "feat: implement directory navigation in KittyFileTransferService"
```

---

## Task 4: 实现目录操作 (mkdir, rm, rmdir)

**Files:**
- Modify: `lib/domain/services/kitty_file_transfer_service.dart:121-137`

**Step 1: 实现 createDirectory**

```dart
/// 创建目录
Future<void> createDirectory(String name) async {
  if (_session == null) {
    throw Exception('未连接到终端');
  }

  final path = _currentPath == '/'
      ? '/$name'
      : '$_currentPath/$name';

  await _session!.executeCommand('mkdir "$path"');
}
```

**Step 2: 实现 removeFile**

```dart
/// 删除文件
Future<void> removeFile(String path) async {
  if (_session == null) {
    throw Exception('未连接到终端');
  }

  await _session!.executeCommand('rm "$path"');
}
```

**Step 3: 实现 removeDirectory**

```dart
/// 删除目录
Future<void> removeDirectory(String path) async {
  if (_session == null) {
    throw Exception('未连接到终端');
  }

  await _session!.executeCommand('rmdir "$path"');
}
```

**Step 4: 运行分析验证**

Run: `flutter analyze --no-fatal-infos lib/domain/services/kitty_file_transfer_service.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/domain/services/kitty_file_transfer_service.dart
git commit -m "feat: implement directory operations (mkdir, rm, rmdir)"
```

---

## Task 5: 实现文件下载功能

**Files:**
- Modify: `lib/domain/services/kitty_file_transfer_service.dart:139-143`

**Step 1: 实现 downloadFile**

```dart
/// 下载文件
/// 使用 Kitty 协议的接收模式
Future<void> downloadFile({
  required String remotePath,
  required String localPath,
  required TransferProgressCallback onProgress,
}) async {
  if (_session == null) {
    throw Exception('未连接到终端');
  }

  final transferId = 'dl_${DateTime.now().millisecondsSinceEpoch}';
  final fileName = remotePath.split('/').last;

  // 创建本地文件
  final file = File(localPath);
  final sink = file.openWrite();

  int transferred = 0;
  int totalSize = 0;
  final startTime = DateTime.now().millisecondsSinceEpoch;

  // 监听文件传输事件
  final subscription = _session!.fileTransferStream.listen((event) async {
    switch (event.type) {
      case 'start':
        totalSize = event.fileSize ?? 0;
        break;
      case 'chunk':
        if (event.data != null) {
          sink.add(event.data!);
          transferred += event.data!.length;

          final elapsed = (DateTime.now().millisecondsSinceEpoch - startTime) / 1000;
          final speed = elapsed > 0 ? (transferred / elapsed).round() : 0;

          onProgress(TransferProgress(
            fileName: fileName,
            transferredBytes: transferred,
            totalBytes: totalSize,
            percent: totalSize > 0 ? transferred / totalSize * 100 : 0,
            bytesPerSecond: speed,
          ));
        }
        break;
      case 'end':
        await sink.close();
        break;
    }
  });

  // 发送接收会话请求
  _session!.writeRaw(
    '\x1b]5113;ac=recv;id=$transferId;f=$remotePath\x1b\\'
  );

  // 等待传输完成 (超时 5 分钟)
  try {
    await Future.delayed(const Duration(minutes: 5));
  } finally {
    await subscription.cancel();
  }
}
```

**Step 2: 运行分析验证**

Run: `flutter analyze --no-fatal-infos lib/domain/services/kitty_file_transfer_service.dart`
Expected: PASS

**Step 3: Commit**

```bash
git add lib/domain/services/kitty_file_transfer_service.dart
git commit -m "feat: implement file download with Kitty protocol"
```

---

## Task 6: 实现协议支持检测

**Files:**
- Modify: `lib/domain/services/kitty_file_transfer_service.dart:145-160`

**Step 1: 实现 checkProtocolSupport**

```dart
/// 检查远程是否支持 Kitty 协议
Future<ProtocolSupportResult> checkProtocolSupport() async {
  if (_session == null) {
    return ProtocolSupportResult(
      isSupported: false,
      errorMessage: '未连接到终端',
    );
  }

  // 尝试执行 ki version 命令
  // 如果不支持，将返回 "command not found" 或类似错误
  final completer = Completer<String>();
  final outputBuffer = StringBuffer();

  final subscription = _session!.inputService.outputStream.listen((output) {
    outputBuffer.write(output);
  });

  _session!.executeCommand('ki version');

  // 等待响应
  await Future.delayed(const Duration(seconds: 2));
  await subscription.cancel();

  final output = outputBuffer.toString();

  // 检查输出中是否包含版本信息
  if (output.contains('ki version') || output.contains('kitty')) {
    return ProtocolSupportResult(isSupported: true);
  }

  return ProtocolSupportResult(
    isSupported: false,
    errorMessage: '远程服务器不支持 Kitty 文件传输协议。请确保远程已安装 Kitty 的 ki 工具。',
  );
}
```

**Step 2: 运行分析验证**

Run: `flutter analyze --no-fatal-infos lib/domain/services/kitty_file_transfer_service.dart`
Expected: PASS

**Step 3: Commit**

```bash
git add lib/domain/services/kitty_file_transfer_service.dart
git commit -m "feat: implement protocol support detection"
```

---

## Task 7: 更新 UI 调用

**Files:**
- Modify: `lib/presentation/screens/sftp_browser_screen.dart:79-225`

**Step 1: 更新 _refresh 方法**

确保正确调用新的 `listCurrentDirectory` 方法并处理 `FileItem` 类型:

```dart
Future<void> _refresh() async {
  if (_transferService == null) return;

  setState(() {
    _loading = true;
  });

  try {
    // 调用服务获取文件列表
    final items = await _transferService!.listCurrentDirectory();
    setState(() {
      _items = items;
      _currentPath = _transferService!.currentPath;
    });
  } catch (e) {
    setState(() {
      _error = e.toString();
    });
  } finally {
    setState(() {
      _loading = false;
    });
  }
}
```

**Step 2: 更新类型转换**

由于 `listCurrentDirectory` 现在返回 `List<FileItem>` 而不是 `List<dynamic>`，移除类型转换。

**Step 3: 运行分析验证**

Run: `flutter analyze --no-fatal-infos lib/presentation/screens/sftp_browser_screen.dart`
Expected: PASS

**Step 4: Commit**

```bash
git add lib/presentation/screens/sftp_browser_screen.dart
git commit -m "feat: update UI to use new file listing methods"
```

---

## Task 8: 完整功能测试

**Step 1: 运行完整分析**

Run: `flutter analyze --no-fatal-infos`
Expected: PASS (no errors)

**Step 2: 运行测试**

Run: `flutter test`
Expected: All tests pass

**Step 3: Commit**

```bash
git add .
git commit -m "feat: complete Kitty protocol file transfer implementation"
```

---

## 执行选项

**Plan complete and saved to `docs/plans/2026-02-23-kitty-full-features-implementation.md`. Two execution options:**

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

Which approach?
