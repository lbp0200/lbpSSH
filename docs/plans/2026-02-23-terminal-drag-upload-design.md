# 终端拖拽上传功能设计

**日期**: 2026-02-23
**状态**: 已批准
**版本**: 1.0

## 1. 概述

在终端界面添加拖拽上传功能，用户可以将本地文件拖拽到终端窗口直接上传到远程服务器。

## 2. 技术方案

### 使用 desktop_drop 包

```dart
import 'package:desktop_drop/desktop_drop.dart';

DropTarget(
  onDragEntered: (detail) => _showDropHint(),
  onDragExited: (detail) => _hideDropHint(),
  onDragDone: (detail) => _handleFileDrop(detail.files),
  child: // 现有终端组件
)
```

### 实现步骤

1. 添加 `desktop_drop` 依赖
2. 在 `TerminalViewWidget` 中包装 `DropTarget`
3. 实现 `_handleFileDrop` 处理文件上传

## 3. 关键实现

### 获取 TerminalSession

```dart
final terminalProvider = context.read<TerminalProvider>();
final session = terminalProvider.getSession(widget.sessionId);
final transferService = KittyFileTransferService(session: session);
```

### 上传逻辑

```dart
Future<void> _handleFileDrop(List<XFile> files) async {
  for (final file in files) {
    await transferService.sendFile(
      localPath: file.path,
      remoteFileName: file.name,
      onProgress: (progress) {
        // 更新进度
      },
    );
  }
}
```

## 4. 用户体验

- 拖拽文件进入终端区域 → 显示半透明覆盖层提示"释放以上传"
- 释放文件 → 显示上传进度对话框
- 支持多文件拖拽

## 5. 待实现功能

- [x] 拖拽上传功能
