# 错误详情对话框设计

## 背景

用户反馈：使用中发现错误，错误信息在下方提示，很快就消失，而且无法复制，导致问题无法排查。

## 目标

- 错误信息不会消失，用户可以查看完整内容
- 支持一键复制错误信息（含 stack trace）
- 引导用户到 GitHub Issues 反馈问题

## 方案

创建通用错误对话框组件 `ErrorDialog`，在捕获异常的地方调用显示。

### 核心组件

**文件位置：** `lib/presentation/widgets/error_dialog.dart`

#### 1. ErrorDialog Widget

| 属性 | 类型 | 说明 |
|------|------|------|
| title | String | 简要错误标题 |
| error | Object | 错误对象（会调用 toString） |
| stackTrace | StackTrace? | 堆栈跟踪（可选） |
| extraContext | Map<String, String>? | 额外上下文信息（如连接名、主机等） |

#### 2. showErrorDialog 工具函数

```dart
Future<void> showErrorDialog(
  BuildContext context, {
  required String title,
  required Object error,
  StackTrace? stackTrace,
  Map<String, String>? extraContext,
})
```

#### 3. 复制报告内容格式

```markdown
## 错误报告

**错误类型**: RuntimeException
**错误信息**: 具体错误描述

**Stack Trace**:
```
(stack trace 内容)
```

**额外上下文**:
- 连接名称: xxx
- 主机: xxx

**环境信息**:
- 操作系统: macOS
- 应用版本: 1.0.2
- 时间: 2024-02-21 10:30:00
```

#### 4. 对话框 UI 设计

- 标题栏：错误图标 + 红色标题
- 内容区：
  - 简要错误信息（可折叠）
  - Stack Trace（可折叠，可滚动）
  - 额外上下文信息（如有）
- 操作按钮：
  - "复制报告" - 复制完整报告到剪贴板
  - "反馈问题" - 复制报告 + 打开 GitHub Issues
  - "关闭" - 关闭对话框

### 实现位置

- 新建文件：`lib/presentation/widgets/error_dialog.dart`
- 无需修改现有文件结构

### 迁移策略

逐个将现有的 `SnackBar` 错误显示改为 `showErrorDialog` 调用：

1. 优先迁移明显需要排查的（如连接失败、加载失败）
2. 保留简单的成功提示不变

## 已知现有实现参考

`lib/presentation/widgets/terminal_view.dart` 第536-610行已有 `ErrorDetailDialog` 实现，可作为参考。

## 验收标准

- [ ] 创建 `error_dialog.dart` 包含 ErrorDialog 和 showErrorDialog
- [ ] 对话框显示错误信息和 stack trace
- [ ] 支持复制完整报告到剪贴板
- [ ] 支持打开 GitHub Issues 页面
- [ ] 至少迁移 3 处现有错误提示
