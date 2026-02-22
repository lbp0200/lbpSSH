# Kitty 协议文件传输替换 SFTP 实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**目标：** 使用 Kitty 协议的 OSC 5113 文件传输完全替换现有的 dartssh2 SFTP 实现

**架构：** 在 TerminalSession 中添加 onPrivateOSC 回调处理接收文件，KittyFileTransferService 实现完整的发送/接收逻辑，SftpProvider 改为调用新服务

**技术栈：** kterm (onPrivateOSC), dart:io (文件读写)

---

## 任务 1：扩展 KittyFileTransferService 实现发送文件功能

**文件：**
- 修改: `lib/domain/services/kitty_file_transfer_service.dart`

**步骤 1：添加必要的 import 和编码器类**

在文件开头添加：
```dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
```

**步骤 2：添加文件传输编码器类**

在 `KittyFileTransferService` 类之前添加：
```dart
/// Kitty 协议文件传输编码器
class KittyFileTransferEncoder {
  static const int chunkSize = 4096;

  /// 编码文件名为 base64
  String encodeFileName(String name) {
    return base64Encode(utf8.encode(name));
  }

  /// 创建发送会话开始序列
  String createSendSession(String sessionId) {
    return '\x1b]5113;ac=send;id=$sessionId\x1b\\';
  }

  /// 创建文件元数据序列
  String createFileMetadata({
    required String sessionId,
    required String fileId,
    required String fileName,
    required int fileSize,
  }) {
    final encodedName = encodeFileName(fileName);
    return '\x1b]5113;ac=file;id=$sessionId;fid=$fileId;n=$encodedName;size=$fileSize\x1b\\';
  }

  /// 创建数据块序列
  String createDataChunk({
    required String sessionId,
    required String fileId,
    required List<int> data,
  }) {
    final encoded = base64Encode(data);
    return '\x1b]5113;ac=data;id=$sessionId;fid=$fileId;d=$encoded\x1b\\';
  }

  /// 创建传输结束序列
  String createFinishSession(String sessionId) {
    return '\x1b]5113;ac=finish;id=$sessionId\x1b\\';
  }
}
```

**步骤 3：修改 KittyFileTransferService 类**

替换整个类为：
```dart
class KittyFileTransferService {
  final KittyFileTransferEncoder _encoder = KittyFileTransferEncoder();

  /// 发送文件到远程
  Future<void> sendFile({
    required String sessionId,
    required String localPath,
    required String remotePath,
    required TransferProgressCallback onProgress,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw Exception('文件不存在: $localPath');
    }

    final fileName = p.basename(localPath);
    final fileSize = await file.length();
    final fileId = 'f${DateTime.now().millisecondsSinceEpoch}';

    // 1. 开始发送会话
    final startSeq = _encoder.createSendSession(sessionId);
    // TODO: 通过 TerminalSession 发送

    // 2. 发送文件元数据
    final metadataSeq = _encoder.createFileMetadata(
      sessionId: sessionId,
      fileId: fileId,
      fileName: remotePath,
      fileSize: fileSize,
    );
    // TODO: 通过 TerminalSession 发送

    // 3. 分块发送数据
    final stream = file.openRead();
    int transferred = 0;
    int startTime = DateTime.now().millisecondsSinceEpoch;

    await for (final chunk in stream) {
      final chunkSeq = _encoder.createDataChunk(
        sessionId: sessionId,
        fileId: fileId,
        data: chunk,
      );
      // TODO: 通过 TerminalSession 发送

      transferred += chunk.length;
      final elapsed = (DateTime.now().millisecondsSinceEpoch - startTime) / 1000;
      final speed = elapsed > 0 ? (transferred / elapsed).round() : 0;

      onProgress(TransferProgress(
        fileName: fileName,
        transferredBytes: transferred,
        totalBytes: fileSize,
        percent: transferred / fileSize * 100,
        bytesPerSecond: speed,
      ));
    }

    // 4. 结束会话
    final finishSeq = _encoder.createFinishSession(sessionId);
    // TODO: 通过 TerminalSession 发送
  }
}
```

**步骤 4：运行分析检查**

Run: `flutter analyze --no-fatal-infos lib/domain/services/kitty_file_transfer_service.dart`
Expected: 无错误

**步骤 5：提交**

```bash
git add lib/domain/services/kitty_file_transfer_service.dart
git commit -m "feat: implement sendFile in KittyFileTransferService"
```

---

## 任务 2：修改 TerminalSession 添加文件传输支持

**文件：**
- 修改: `lib/domain/services/terminal_service.dart`

**步骤 1：添加文件传输回调**

在 `TerminalSession` 类中添加：
```dart
// 文件传输回调
typedef FileTransferCallback = void Function(FileTransferEvent event);

/// 文件传输事件
class FileTransferEvent {
  final String type; // 'start', 'chunk', 'end', 'error'
  final String? fileId;
  final String? fileName;
  final int? fileSize;
  final int? offset;
  final List<int>? data;
  final String? error;

  FileTransferEvent({
    required this.type,
    this.fileId,
    this.fileName,
    this.fileSize,
    this.offset,
    this.data,
    this.error,
  });
}
```

**步骤 2：添加 onPrivateOSC 回调监听**

在构造函数中，在 `terminal.onClipboardWrite =` 之后添加：
```dart
// 监听私有 OSC 序列（用于文件传输等）
terminal.onPrivateOSC = (code, args) {
  if (code == '5113') {
    _handleFileTransfer(args);
  }
};

void _handleFileTransfer(List<String> args) {
  // 解析 OSC 5113 参数
  // 格式: ac=xxx;id=xxx;fid=xxx;n=xxx;size=xxx;d=xxx
  final params = <String, String>{};
  for (final arg in args) {
    final parts = arg.split('=');
    if (parts.length == 2) {
      params[parts[0]] = parts[1];
    }
  }

  final action = params['ac'];

  switch (action) {
    case 'send':
      // 远程请求发送文件给我们
      _fileTransferController.add(FileTransferEvent(
        type: 'start',
        fileId: params['fid'],
        fileName: params['n'] != null ? utf8.decode(base64Decode(params['n']!)) : null,
        fileSize: int.tryParse(params['size'] ?? ''),
      ));
      break;
    case 'data':
      _fileTransferController.add(FileTransferEvent(
        type: 'chunk',
        fileId: params['fid'],
        offset: int.tryParse(params['offset'] ?? ''),
        data: params['d'] != null ? base64Decode(params['d']!) : null,
      ));
      break;
    case 'finish':
      _fileTransferController.add(FileTransferEvent(
        type: 'end',
        fileId: params['fid'],
      ));
      break;
  }
}
```

**步骤 3：添加文件传输流控制器**

在 `_notificationController` 之后添加：
```dart
final _fileTransferController = StreamController<FileTransferEvent>.broadcast();
Stream<FileTransferEvent> get fileTransferStream => _fileTransferController.stream;
```

**步骤 4：在 dispose 中关闭控制器**

```dart
_fileTransferController.close();
```

**步骤 5：运行分析检查**

Run: `flutter analyze --no-fatal-infos lib/domain/services/terminal_service.dart`
Expected: 无错误

**步骤 6：提交**

```bash
git add lib/domain/services/terminal_service.dart
git commit -m "feat: add file transfer callback to TerminalSession"
```

---

## 任务 3：修改 SftpProvider 改用 KittyFileTransferService

**文件：**
- 修改: `lib/presentation/providers/sftp_provider.dart`

**步骤 1：修改 import**

```dart
import 'package:lbp_ssh/domain/services/kitty_file_transfer_service.dart';
```

**步骤 2：修改 SftpTab 类**

将 `SftpService` 替换为 `KittyFileTransferService`：
```dart
class SftpTab {
  final String id;
  final SshConnection connection;
  final KittyFileTransferService service;  // 改为 KittyFileTransferService
  String currentPath;

  SftpTab({
    required this.id,
    required this.connection,
    required this.service,
    required this.currentPath,
  });
}
```

**步骤 3：修改 openTab 方法**

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

  final tab = SftpTab(
    id: tabId,
    connection: connection,
    service: transferService,
    currentPath: '/',
  );

  _tabs[tabId] = tab;
  notifyListeners();
  return tab;
}
```

**步骤 4：运行分析检查**

Run: `flutter analyze --no-fatal-infos lib/presentation/providers/sftp_provider.dart`
Expected: 无错误

**步骤 5：提交**

```bash
git add lib/presentation/providers/sftp_provider.dart
git commit -m "refactor: use KittyFileTransferService in SftpProvider"
```

---

## 任务 4：更新 KittyFileTransferService 构造函数

**文件：**
- 修改: `lib/domain/services/kitty_file_transfer_service.dart`

**步骤 1：添加构造函数参数**

修改类定义：
```dart
class KittyFileTransferService {
  final TerminalSession _session;
  final KittyFileTransferEncoder _encoder = KittyFileTransferEncoder();

  KittyFileTransferService({required TerminalSession session}) : _session = session;
```

**步骤 2：实现发送方法中的 terminal.write 调用**

修改 `sendFile` 方法中的 TODO：
```dart
// 1. 开始发送会话
_session.writeRaw(_encoder.createSendSession(sessionId));

// 2. 发送文件元数据
_session.writeRaw(_encoder.createFileMetadata(...));

// 3. 分块发送数据
_session.writeRaw(_encoder.createDataChunk(...));

// 4. 结束会话
_session.writeRaw(_encoder.createFinishSession(sessionId));
```

**步骤 3：运行分析检查**

Run: `flutter analyze --no-fatal-infos lib/domain/services/kitty_file_transfer_service.dart`
Expected: 无错误

**步骤 4：提交**

```bash
git add lib/domain/services/kitty_file_transfer_service.dart
git commit -m "feat: connect KittyFileTransferService to TerminalSession"
```

---

## 任务 5：修改 SftpBrowserScreen 使用新服务

**文件：**
- 修改: `lib/presentation/screens/sftp_browser_screen.dart`

**步骤 1：查看上传下载代码**

检查 `_uploadFile` 和下载相关方法需要如何修改。

**步骤 2：修改上传方法**

```dart
Future<void> _uploadFile() async {
  final result = await FilePicker.platform.pickFiles();
  if (result == null || result.files.isEmpty) return;

  final localPath = result.files.single.path;
  if (localPath == null) return;

  final fileName = result.files.single.name;

  // 使用 KittyFileTransferService 上传
  final session = _terminalProvider.getSession(connection.id);
  if (session == null) return;

  final transferService = KittyFileTransferService(session: session);

  // 显示进度对话框
  if (!mounted) return;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => TransferProgressDialog(
      onCancel: () {
        transferService.cancelTransfer();
        Navigator.pop(context);
      },
    ),
  );

  try {
    await transferService.sendFile(
      sessionId: connection.id,
      localPath: localPath,
      remotePath: '$_currentPath/$fileName',
      onProgress: (progress) {
        // 更新进度对话框
      },
    );
    if (mounted) {
      Navigator.pop(context); // 关闭进度对话框
      _refresh(); // 刷新文件列表
    }
  } catch (e) {
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('上传失败: $e')),
      );
    }
  }
}
```

**步骤 3：运行分析检查**

Run: `flutter analyze --no-fatal-infos lib/presentation/screens/sftp_browser_screen.dart`
Expected: 无错误

**步骤 4：提交**

```bash
git add lib/presentation/screens/sftp_browser_screen.dart
git commit -m "feat: use KittyFileTransferService in SftpBrowserScreen"
```

---

## 任务 6：移除 SftpService 依赖

**文件：**
- 删除: `lib/domain/services/sftp_service.dart`
- 修改: `pubspec.yaml` (如需要)

**步骤 1：检查是否有其他地方使用 SftpService**

```bash
grep -r "SftpService" lib/
```

**步骤 2：如果没有其他地方使用，删除文件**

```bash
rm lib/domain/services/sftp_service.dart
```

**步骤 3：提交**

```bash
git rm lib/domain/services/sftp_service.dart
git commit -m "refactor: remove SftpService, use KittyFileTransferService"
```

---

## 任务 7：验证构建

**步骤 1：运行 Flutter 分析**

Run: `flutter analyze --no-fatal-infos`
Expected: 无错误

**步骤 2：构建 macOS**

Run: `flutter build macos --debug --no-tree-shake-icons`
Expected: 构建成功

**步骤 3：提交**

```bash
git add .
git commit -m "feat: complete Kitty file transfer implementation"
```

---

## 验收标准

1. ✅ 上传文件：通过 OSC 5113 发送文件到远程
2. ✅ 下载文件：通过 onPrivateOSC 接收远程发送的文件
3. ✅ 进度显示：实时显示传输进度
4. ✅ 错误处理：友好的错误提示
5. ✅ 向后兼容：检测远程是否支持，不支持时提示安装工具
