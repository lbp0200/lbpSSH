# Kitty 协议功能集成实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**目标：** 集成 Kitty 协议的三个功能：桌面通知、剪贴板支持、终端图形显示

**架构：** 在 TerminalSession 中设置 kterm 的回调函数，将通知、剪贴板操作路由到 Flutter 系统功能；创建 GraphicsOverlayWidget 叠加层显示图片

**技术栈：** kterm, flutter_local_notifications, super_clipboard

---

## 任务 1：添加依赖包

**文件：**
- 修改: `pubspec.yaml`

**步骤 1：添加依赖**

在 dependencies 中添加：
```yaml
# 桌面通知
flutter_local_notifications: ^18.0.0

# 剪贴板
super_clipboard: ^0.8.0
```

**步骤 2：运行 flutter pub get**

Run: `flutter pub get`
Expected: 包安装成功

**步骤 3：提交**

```bash
git add pubspec.yaml
git commit -m "feat: add flutter_local_notifications and super_clipboard dependencies"
```

---

## 任务 2：集成桌面通知功能

**文件：**
- 修改: `lib/domain/services/terminal_service.dart`

**步骤 1：在 TerminalSession 中添加通知回调**

在 TerminalSession 构造函数中添加：
```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// 在构造函数中设置回调
terminal.onNotification = (title, body) {
  _showNotification(title, body);
};

void _showNotification(String title, String body) async {
  const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  const InitializationSettings initSettings = InitializationSettings(iOS: iosSettings);

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  const NotificationDetails details = NotificationDetails(
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  await flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    details,
  );
}
```

**步骤 2：运行分析检查**

Run: `flutter analyze --no-fatal-infos lib/domain/services/terminal_service.dart`
Expected: 无错误

**步骤 3：提交**

```bash
git add lib/domain/services/terminal_service.dart
git commit -m "feat: integrate desktop notifications from SSH"
```

---

## 任务 3：集成剪贴板功能

**文件：**
- 修改: `lib/domain/services/terminal_service.dart`

**步骤 1：添加剪贴板回调**

在 TerminalSession 构造函数中添加：
```dart
import 'package:super_clipboard/super_clipboard.dart';

// 剪贴板读取回调
terminal.onClipboardRead = (target) async {
  final clipboard = SystemClipboard.instance;
  if (clipboard == null) return;

  final reader = await clipboard.read();
  if (reader.canProvide(Formats.plainText)) {
    final text = await reader.readValue(Formats.plainText);
    if (text != null) {
      // 返回 base64 编码的数据
      return base64Encode(utf8.encode(text));
    }
  }
  return null;
};

// 剪贴板写入回调
terminal.onClipboardWrite = (data, target) async {
  try {
    final text = utf8.decode(base64Decode(data));
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) return;

    final item = DataWriterItem();
    item.add(Formats.plainText(text));
    await clipboard.write([item]);
  } catch (e) {
    // 忽略错误
  }
};
```

**步骤 2：添加必要的 import**

```dart
import 'dart:convert';
```

**步骤 3：运行分析检查**

Run: `flutter analyze --no-fatal-infos lib/domain/services/terminal_service.dart`
Expected: 无错误

**步骤 4：提交**

```bash
git add lib/domain/services/terminal_service.dart
git commit -m "feat: integrate clipboard with SSH (OSC 52)"
```

---

## 任务 4：集成终端图形功能

**文件：**
- 创建: `lib/presentation/widgets/graphics_overlay.dart`
- 修改: `lib/presentation/widgets/terminal_view.dart`

**步骤 1：创建 GraphicsOverlayWidget**

创建 `lib/presentation/widgets/graphics_overlay.dart`：

```dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:kterm/kterm.dart';

/// 终端图形叠加层组件
/// 显示由 kterm GraphicsManager 管理的图片
class GraphicsOverlayWidget extends StatelessWidget {
  final GraphicsManager graphicsManager;
  final double cellWidth;
  final double cellHeight;
  final int scrollOffset;

  const GraphicsOverlayWidget({
    super.key,
    required this.graphicsManager,
    required this.cellWidth,
    required this.cellHeight,
    required this.scrollOffset,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _createNotifier(),
      builder: (context, _) {
        return Stack(
          children: _buildImageWidgets(),
        );
      },
    );
  }

  List<Widget> _buildImageWidgets() {
    final widgets = <Widget>[];
    final placements = graphicsManager.placements;

    for (final entry in placements.entries) {
      final placement = entry.value;
      final image = graphicsManager.getImage(placement.imageId);
      if (image == null) continue;

      final x = placement.x * cellWidth;
      final y = (placement.y - scrollOffset) * cellHeight;
      final width = placement.width * cellWidth;
      final height = placement.height * cellHeight;

      widgets.add(
        Positioned(
          left: x,
          top: y,
          child: RawImage(
            image: image,
            width: width,
            height: height,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    return widgets;
  }

  ValueNotifier<void> _createNotifier() {
    // 创建一个可通知的 ValueNotifier 来触发重建
    return ValueNotifier(null);
  }
}
```

**步骤 2：修改 terminal_view.dart 集成叠加层**

在 terminal_view.dart 中找到显示终端的部分，添加 GraphicsOverlayWidget：

```dart
// 在 TerminalViewWidgetState 中获取 GraphicsManager
GraphicsManager? get graphicsManager {
  final session = terminalProvider.getSession(widget.sessionId);
  return session?.graphicsManager;
}

// 在 build 方法中叠加图形
Stack(
  children: [
    TerminalView(
      terminal: session.terminal,
      controller: session.controller,
      // ... 其他参数
    ),
    if (graphicsManager != null)
      GraphicsOverlayWidget(
        graphicsManager: graphicsManager!,
        cellWidth: session.controller.fontWidth,
        cellHeight: session.controller.fontHeight,
        scrollOffset: scrollOffset,
      ),
  ],
)
```

**步骤 3：运行分析检查**

Run: `flutter analyze --no-fatal-infos`
Expected: 无错误

**步骤 4：提交**

```bash
git add lib/presentation/widgets/graphics_overlay.dart lib/presentation/widgets/terminal_view.dart
git commit -m "feat: integrate terminal graphics overlay"
```

---

## 任务 5：验证构建

**步骤 1：运行 Flutter 分析**

Run: `flutter analyze --no-fatal-infos`
Expected: 无错误

**步骤 2：构建 macOS**

Run: `flutter build macos --debug --no-tree-shake-icons`
Expected: 构建成功

**步骤 3：提交**

```bash
git add .
git commit -m "feat: complete Kitty protocol integration"
```

---

## 验收标准

1. ✅ 桌面通知：当远程发送 OSC 99 时显示系统通知
2. ✅ 剪贴板：支持 SSH 读写本地剪贴板
3. ✅ 终端图形：可以在终端中显示图片
