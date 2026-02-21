# Error Dialog Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a reusable error dialog component that displays error details with stack trace, supports one-click copy, and guides users to report issues on GitHub.

**Architecture:** Create a standalone `error_dialog.dart` widget with `ErrorDialog` class and `showErrorDialog` helper function. Reference existing `ErrorDetailDialog` in `terminal_view.dart` for implementation patterns.

**Tech Stack:** Flutter, Material Design, Clipboard, url_launcher

---

### Task 1: Create error_dialog.dart

**Files:**
- Create: `lib/presentation/widgets/error_dialog.dart`

**Step 1: Write the error_dialog.dart file**

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// 显示错误详情对话框
///
/// [title] 简要错误标题
/// [error] 错误对象
/// [stackTrace] 堆栈跟踪（可选）
/// [extraContext] 额外上下文信息（如连接名、主机等）
Future<void> showErrorDialog(
  BuildContext context, {
  required String title,
  required Object error,
  StackTrace? stackTrace,
  Map<String, String>? extraContext,
}) {
  return showDialog(
    context: context,
    builder: (context) => ErrorDialog(
      title: title,
      error: error,
      stackTrace: stackTrace,
      extraContext: extraContext,
    ),
  );
}

/// 错误详情对话框
class ErrorDialog extends StatefulWidget {
  final String title;
  final Object error;
  final StackTrace? stackTrace;
  final Map<String, String>? extraContext;

  const ErrorDialog({
    super.key,
    required this.title,
    required this.error,
    this.stackTrace,
    this.extraContext,
  });

  @override
  State<ErrorDialog> createState() => _ErrorDialogState();
}

class _ErrorDialogState extends State<ErrorDialog> {
  bool _copied = false;
  bool _errorExpanded = true;
  bool _stackExpanded = true;

  String get _errorString => widget.error.toString();
  String get _stackString => widget.stackTrace?.toString() ?? '';

  String _buildReport() {
    final buffer = StringBuffer();
    buffer.writeln('## 错误报告');
    buffer.writeln();
    buffer.writeln('**错误类型**: ${widget.error.runtimeType}');
    buffer.writeln('**错误信息**: ${widget.error}');
    buffer.writeln();

    if (_stackString.isNotEmpty) {
      buffer.writeln('**Stack Trace**:');
      buffer.writeln('```');
      buffer.writeln(_stackString);
      buffer.writeln('```');
      buffer.writeln();
    }

    if (widget.extraContext != null && widget.extraContext!.isNotEmpty) {
      buffer.writeln('**额外上下文**:');
      for (final entry in widget.extraContext!.entries) {
        buffer.writeln('- ${entry.key}: ${entry.value}');
      }
      buffer.writeln();
    }

    buffer.writeln('**环境信息**:');
    buffer.writeln('- 操作系统: ${Platform.operatingSystem}');
    buffer.writeln('- 应用版本: 1.0.2');
    buffer.writeln('- 时间: ${DateTime.now().toIso8601String()}');

    return buffer.toString();
  }

  Future<void> _copyReport() async {
    await Clipboard.setData(ClipboardData(text: _buildReport()));
    if (mounted) {
      setState(() => _copied = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('错误报告已复制到剪贴板')),
      );
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _copied = false);
      });
    }
  }

  Future<void> _copyAndOpenIssues() async {
    await Clipboard.setData(ClipboardData(text: _buildReport()));

    final uri = Uri.parse('https://github.com/lbp0200/lbpssh/issues');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    if (mounted) {
      setState(() => _copied = true);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _copied = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorTextStyle = theme.textTheme.bodyMedium?.copyWith(
      fontFamily: 'monospace',
    );

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error),
          const SizedBox(width: 12),
          Expanded(child: Text(widget.title)),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.6,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 错误信息
              _buildSection(
                title: '错误信息',
                expanded: _errorExpanded,
                onToggle: () => setState(() => _errorExpanded = !_errorExpanded),
                child: SelectableText(_errorString, style: errorTextStyle),
              ),

              // Stack Trace
              if (_stackString.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildSection(
                  title: 'Stack Trace',
                  expanded: _stackExpanded,
                  onToggle: () => setState(() => _stackExpanded = !_stackExpanded),
                  child: SelectableText(_stackString, style: errorTextStyle),
                ),
              ],

              // 额外上下文
              if (widget.extraContext != null && widget.extraContext!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: widget.extraContext!.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text(
                                '${entry.key}:',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              child: SelectableText(
                                entry.value,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _copyReport,
          child: const Text('复制报告'),
        ),
        FilledButton.icon(
          onPressed: _copyAndOpenIssues,
          icon: Icon(_copied ? Icons.check : Icons.open_in_new),
          label: Text(_copied ? '已复制' : '反馈问题'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required bool expanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (expanded) child,
      ],
    );
  }
}
```

**Step 2: Verify the file compiles**

Run: `flutter analyze lib/presentation/widgets/error_dialog.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/presentation/widgets/error_dialog.dart
git commit -m "feat: add ErrorDialog component

- Add ErrorDialog widget with collapsible sections
- Add showErrorDialog helper function
- Support copy report and open GitHub Issues
- Include stack trace and extra context"
```

---

### Task 2: Migrate connection errors

**Files:**
- Modify: `lib/presentation/widgets/terminal_view.dart:304`

**Step 1: Update the import**

Add import at top of file:
```dart
import 'error_dialog.dart';
```

**Step 2: Replace the SnackBar with ErrorDialog**

Find line 304 in terminal_view.dart:
```dart
).showSnackBar(SnackBar(content: Text('创建终端失败: $e')));
```

Replace with:
```dart
showErrorDialog(
  context,
  title: '创建终端失败',
  error: e,
  stackTrace: stackTrace,
);
```

**Step 3: Verify it compiles**

Run: `flutter analyze lib/presentation/widgets/terminal_view.dart`
Expected: No errors

**Step 4: Commit**

```bash
git add lib/presentation/widgets/terminal_view.dart
git commit -m "refactor: use ErrorDialog for terminal creation errors"
```

---

### Task 3: Migrate sync settings errors

**Files:**
- Modify: `lib/presentation/screens/sync_settings.dart:123,403,427`

**Step 1: Add import**

Add import at top of sync_settings.dart:
```dart
import '../widgets/error_dialog.dart';
```

**Step 2: Migrate connection test error (line 123)**

Find:
```dart
).showSnackBar(SnackBar(content: Text('连接测试失败: $e')));
```

Replace with:
```dart
showErrorDialog(
  context,
  title: '连接测试失败',
  error: e,
  stackTrace: stackTrace,
);
```

**Step 3: Migrate upload error (line 403)**

Find:
```dart
).showSnackBar(SnackBar(content: Text('上传失败: $e')));
```

Replace with:
```dart
showErrorDialog(
  context,
  title: '上传失败',
  error: e,
  stackTrace: stackTrace,
);
```

**Step 4: Migrate download error (line 427)**

Find:
```dart
).showSnackBar(SnackBar(content: Text('下载失败: $e')));
```

Replace with:
```dart
showErrorDialog(
  context,
  title: '下载失败',
  error: e,
  stackTrace: stackTrace,
);
```

**Step 5: Verify it compiles**

Run: `flutter analyze lib/presentation/screens/sync_settings.dart`
Expected: No errors

**Step 6: Commit**

```bash
git add lib/presentation/screens/sync_settings.dart
git commit -m "refactor: use ErrorDialog for sync errors"
```

---

### Task 4: Migrate connection form errors

**Files:**
- Modify: `lib/presentation/screens/connection_form.dart:136,169,341`

**Step 1: Add import**

Add import at top of connection_form.dart:
```dart
import '../widgets/error_dialog.dart';
```

**Step 2: Migrate read file error (line 136)**

Find:
```dart
).showSnackBar(SnackBar(content: Text('读取文件失败: $e')));
```

Replace with:
```dart
showErrorDialog(
  context,
  title: '读取文件失败',
  error: e,
  stackTrace: stackTrace,
);
```

**Step 3: Migrate select file error (line 169)**

Find:
```dart
).showSnackBar(SnackBar(content: Text('选择文件失败: $e')));
```

Replace with:
```dart
showErrorDialog(
  context,
  title: '选择文件失败',
  error: e,
  stackTrace: stackTrace,
);
```

**Step 4: Migrate save error (line 341)**

Find:
```dart
).showSnackBar(SnackBar(content: Text('保存失败: $e')));
```

Replace with:
```dart
showErrorDialog(
  context,
  title: '保存失败',
  error: e,
  stackTrace: stackTrace,
);
```

**Step 5: Verify it compiles**

Run: `flutter analyze lib/presentation/screens/connection_form.dart`
Expected: No errors

**Step 6: Commit**

```bash
git add lib/presentation/screens/connection_form.dart
git commit -m "refactor: use ErrorDialog for connection form errors"
```

---

### Task 5: Final verification

**Step 1: Run full analysis**

Run: `flutter analyze`
Expected: No errors

**Step 2: Run tests**

Run: `flutter test`
Expected: All tests pass

**Step 3: Commit**

```bash
git add .
git commit -m "feat: complete error dialog implementation

- Migrated 7 error locations to use ErrorDialog
- Users can now copy error reports and report issues"
```
