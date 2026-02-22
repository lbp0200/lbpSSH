# Kitty 协议功能集成设计

## 背景

lbpSSH 使用 kterm 作为终端模拟器，kterm 已经支持部分 Kitty 协议功能，需要将以下功能集成到 Flutter 应用中：

1. 桌面通知 (Desktop Notifications)
2. 剪贴板支持 (Clipboard)
3. 终端图形 (Terminal Graphics)

## 架构设计

### 1. 桌面通知 (Desktop Notifications)

**目标：** 当 SSH 服务器发送桌面通知时，在本地显示通知

**实现方案：**
- 在 `TerminalSession` 初始化时设置 `terminal.onNotification` 回调
- 回调接收 `title` 和 `body` 参数
- 使用 Flutter 的 `flutter_local_notifications` 包显示系统通知

**文件变更：**
- `pubspec.yaml`: 添加 `flutter_local_notifications` 依赖
- `lib/domain/services/terminal_service.dart`: 设置 onNotification 回调

### 2. 剪贴板支持 (Clipboard)

**目标：** 支持 SSH 服务器读写本地剪贴板 (OSC 52)

**实现方案：**
- 设置 `terminal.onClipboardRead`: 当 SSH 请求读取剪贴板时，从 Flutter 读取
- 设置 `terminal.onClipboardWrite`: 当 SSH 写入剪贴板时，写入 Flutter 剪贴板
- 使用 `super_clipboard` 包进行跨平台剪贴板操作

**文件变更：**
- `pubspec.yaml`: 添加 `super_clipboard` 依赖
- `lib/domain/services/terminal_service.dart`: 设置剪贴板回调

### 3. 终端图形 (Terminal Graphics)

**目标：** 在终端中显示图片 (Kitty Graphics Protocol)

**实现方案：**
- kterm 的 `GraphicsManager` 负责接收和存储图片
- 需要创建一个 Flutter widget 叠加在终端上显示图片
- 实现 `GraphicsOverlayWidget` 监听 GraphicsManager 的状态变化
- 图片需要与文字一起滚动

**文件变更：**
- `lib/presentation/widgets/graphics_overlay.dart`: 新建图片叠加层组件
- `lib/presentation/widgets/terminal_view.dart`: 集成图片叠加层

## 技术细节

### Desktop Notifications

```dart
terminal.onNotification = (title, body) {
  // 调用 Flutter 本地通知插件显示通知
};
```

### Clipboard

```dart
terminal.onClipboardRead = (target) async {
  // 从 Flutter 剪贴板读取并返回 base64 编码的数据
};

terminal.onClipboardWrite = (data, target) {
  // 将数据写入 Flutter 剪贴板
};
```

### Terminal Graphics

- `GraphicsManager` 提供: `storeImage()`, `getImage()`, `placements`
- 需要监听 placements 变化并更新 Flutter UI
- 图片需要跟随文字滚动（placement 包含位置信息）

## 验收标准

1. 桌面通知：当远程发送 OSC 99 序列时，本地显示系统通知
2. 剪贴板：支持 `Ctrl+Shift+V` 在 SSH 中粘贴本地内容，支持复制到本地剪贴板
3. 终端图形：可以在终端中显示图片（如 `eza --icons` 或 `lsd` 的图片预览）
