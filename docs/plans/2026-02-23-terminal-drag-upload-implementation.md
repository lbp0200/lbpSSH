# 终端拖拽上传功能实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在终端界面添加拖拽上传功能，用户可以将本地文件拖拽到终端窗口直接上传到远程服务器

**Architecture:** 使用 desktop_drop 包监听拖拽事件，获取文件路径后调用 KittyFileTransferService 上传

**Tech Stack:** Flutter, desktop_drop, KittyFileTransferService

---

## Task 1: 添加 desktop_drop 依赖

**Files:**
- Modify: `pubspec.yaml`

**Step 1: 添加依赖**

在 pubspec.yaml 的 dependencies 部分添加：
```yaml
  # 桌面拖拽支持
  desktop_drop: ^0.5.0
```

**Step 2: 安装依赖**

Run: `flutter pub get`
Expected: Successfully installed desktop_drop

**Step 3: Commit**

```bash
git add pubspec.yaml
git commit -m "feat: add desktop_drop dependency for drag upload"
```

---

## Task 2: 在 TerminalViewWidget 中添加拖拽支持

**Files:**
- Modify: `lib/presentation/widgets/terminal_view.dart`

**Step 1: 添加 import**

在文件顶部添加：
```dart
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';
```

**Step 2: 添加状态变量**

在 `_TerminalViewWidgetState` 类中添加：
```dart
bool _isDragging = false;
```

**Step 3: 添加 DropTarget**

在 build 方法中，用 DropTarget 包装现有内容：

```dart
return DropTarget(
  onDragEntered: (detail) {
    setState(() => _isDragging = true);
  },
  onDragExited: (detail) {
    setState(() => _isDragging = false);
  },
  onDragDone: (detail) {
    setState(() => _isDragging = false);
    _handleFileDrop(detail.files);
  },
  child: // 现有终端组件
);
```

**Step 4: 实现 _handleFileDrop 方法**

在类中添加：
```dart
Future<void> _handleFileDrop(List<XFile> files) async {
  if (files.isEmpty) return;

  // 获取 TerminalSession
  final terminalProvider = context.read<TerminalProvider>();
  final session = terminalProvider.getSession(widget.sessionId);

  if (session == null) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先连接到服务器')),
      );
    }
    return;
  }

  // 创建文件传输服务
  final transferService = KittyFileTransferService(session: session);

  // 上传每个文件
  for (final file    try in files) {
 {
      await transferService.sendFile(
        localPath: file.path,
        remoteFileName: file.name,
        onProgress: (progress) {
          // 可以在这里显示进度
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${file.name} 上传成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${file.name} 上传失败: $e')),
        );
      }
    }
  }
}
```

**Step 5: 添加拖拽提示覆盖层**

在 DropTarget 的 child 中添加条件渲染的覆盖层：
```dart
Stack(
  children: [
    // 现有终端组件
    if (_isDragging)
      Positioned.fill(
        child: Container(
          color: Colors.black54,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.upload_file, size: 48, color: Colors.blue[700]),
                  const SizedBox(height: 16),
                  Text(
                    '释放以上传文件',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
  ],
)
```

**Step 6: 运行分析验证**

Run: `flutter analyze --no-fatal-infos lib/presentation/widgets/terminal_view.dart`
Expected: PASS

**Step 7: Commit**

```bash
git add lib/presentation/widgets/terminal_view.dart
git commit -m "feat: add drag-and-drop file upload to terminal"
```

---

## Task 3: 完整功能测试

**Step 1: 运行完整分析**

Run: `flutter analyze --no-fatal-infos`
Expected: PASS

**Step 2: 运行测试**

Run: `flutter test`
Expected: All tests pass

**Step 3: Commit**

```bash
git add .
git commit -m "feat: complete terminal drag upload feature"
```

---

## 执行选项

**Plan complete and saved to `docs/plans/2026-02-23-terminal-drag-upload-implementation.md`. Two execution options:**

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

Which approach?
