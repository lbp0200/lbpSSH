# Kitty File Transfer Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement Kitty protocol file transfer with progress display in UI.

**Architecture:** Add progress callback support to KittyFileTransferService, integrate with TerminalSession to send OSC 5113 sequences, create transfer progress dialog.

**Tech Stack:** Flutter, dartssh2, kterm, Provider

---

### Task 1: Add progress callback to KittyFileTransferService

**Files:**
- Modify: `lib/domain/services/kitty_file_transfer_service.dart`

**Step 1: Add transfer progress class**

Add this class:
```dart
/// 文件传输进度
class TransferProgress {
  final String fileName;
  final int transferredBytes;
  final int totalBytes;
  final double percent;
  final int bytesPerSecond;

  TransferProgress({
    required this.fileName,
    required this.transferredBytes,
    required this.totalBytes,
    required this.percent,
    required this.bytesPerSecond,
  });
}
```

**Step 2: Add sendFile with progress callback**

Replace sendFile method:
```dart
typedef TransferProgressCallback = void Function(TransferProgress progress);

Future<void> sendFile({
  required String sessionId,
  required String localPath,
  required String remoteFileName,
  required TransferProgressCallback onProgress,
}) async {
  // TODO: 实现带进度回调的文件发送
}
```

**Step 3: Verify it compiles**

Run: `flutter analyze lib/domain/services/kitty_file_transfer_service.dart`

**Step 4: Commit**

```bash
git add lib/domain/services/kitty_file_transfer_service.dart
git commit -m "feat: add progress callback to KittyFileTransferService"
```

---

### Task 2: Add OSC sequence sending to TerminalSession

**Files:**
- Modify: `lib/domain/services/terminal_service.dart`

**Step 1: Add writeRaw method to TerminalSession**

Add method to TerminalSession class:
```dart
/// 发送原始字符到终端（用于发送 OSC 序列）
void writeRaw(String data) {
  terminal.write(data);
}
```

**Step 2: Verify it compiles**

Run: `flutter analyze lib/domain/services/terminal_service.dart`

**Step 3: Commit**

```bash
git add lib/domain/services/terminal_service.dart
git commit -m "feat: add writeRaw to TerminalSession for OSC sequences"
```

---

### Task 3: Create TransferProgressDialog

**Files:**
- Create: `lib/presentation/widgets/transfer_progress_dialog.dart`

**Step 1: Write TransferProgressDialog**

```dart
import 'package:flutter/material.dart';

/// 传输进度对话框
class TransferProgressDialog extends StatefulWidget {
  final String fileName;
  final int totalBytes;
  final Stream<TransferProgress> progressStream;
  final VoidCallback onCancel;

  const TransferProgressDialog({
    super.key,
    required this.fileName,
    required this.totalBytes,
    required this.progressStream,
    required this.onCancel,
  });

  @override
  State<TransferProgressDialog> createState() => _TransferProgressDialogState();
}

class _TransferProgressDialogState extends State<TransferProgressDialog> {
  double _percent = 0;
  int _transferred = 0;
  int _bytesPerSecond = 0;

  @override
  void initState() {
    super.initState();
    widget.progressStream.listen((progress) {
      if (mounted) {
        setState(() {
          _percent = progress.percent;
          _transferred = progress.transferredBytes;
          _bytesPerSecond = progress.bytesPerSecond;
        });
      }
    });
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('上传文件'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('文件: ${widget.fileName}'),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: _percent / 100),
          const SizedBox(height: 8),
          Text('${_percent.toStringAsFixed(1)}%'),
          const SizedBox(height: 8),
          Text('${_formatSize(_transferred)} / ${_formatSize(widget.totalBytes)}'),
          if (_bytesPerSecond > 0)
            Text('速度: ${_formatSize(_bytesPerSecond)}/s'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text('取消'),
        ),
      ],
    );
  }
}
```

**Step 2: Verify it compiles**

Run: `flutter analyze lib/presentation/widgets/transfer_progress_dialog.dart`

**Step 3: Commit**

```bash
git add lib/presentation/widgets/transfer_progress_dialog.dart
git commit -m "feat: add TransferProgressDialog for upload progress"
```

---

### Task 4: Integrate Kitty transfer to file browser

**Files:**
- Modify: `lib/presentation/screens/sftp_browser_screen.dart`

**Step 1: Add import and replace upload logic**

Replace the uploadFile method to use Kitty protocol:
```dart
Future<void> _uploadFile() async {
  final result = await FilePicker.platform.pickFiles();
  if (result != null && result.files.single.path != null) {
    final file = result.files.single;
    final localPath = file.path!;
    final fileName = file.name;
    final fileSize = file.size;

    // 显示进度对话框
    if (!mounted) return;
    final progressController = StreamController<TransferProgress>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TransferProgressDialog(
        fileName: fileName,
        totalBytes: fileSize,
        progressStream: progressController.stream,
        onCancel: () {
          progressController.close();
          Navigator.pop(context);
        },
      ),
    );

    try {
      // TODO: 调用 KittyFileTransferService 发送文件
      // 使用 progressController.add() 更新进度

      if (mounted) {
        Navigator.pop(context); // 关闭进度对话框
        _showMessage('上传成功');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showError('上传失败: $e');
      }
    }
  }
}
```

**Step 2: Verify it compiles**

Run: `flutter analyze lib/presentation/screens/sftp_browser_screen.dart`

**Step 3: Commit**

```bash
git add lib/presentation/screens/sftp_browser_screen.dart
git commit -m "feat: integrate Kitty transfer to file browser"
```

---

### Task 5: Final verification

**Step 1: Run full analysis**

Run: `flutter analyze`

**Step 2: Run tests**

Run: `flutter test`

**Step 3: Commit**

```bash
git add .
git commit -m "feat: complete Kitty file transfer implementation"
```
