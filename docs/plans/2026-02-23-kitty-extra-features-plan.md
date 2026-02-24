# 额外 Kitty 协议功能实现计划

**日期**: 2026-02-23
**版本**: 1.1
**状态**: 已完成

---

## 已实现功能 ✅

### 1. File Transfer (OSC 5113) - 文件传输
- [x] 文件上传 (send)
- [x] 文件下载 (receive)
- [x] 目录导航 (cd, cd ..)
- [x] 目录操作 (mkdir, rm, rmdir)
- [x] 拖拽上传
- [x] 协议支持检测
- [x] 目录批量传输 (递归传输整个目录)
- [x] 压缩传输 (compression=zlib)
- [x] 符号链接处理 (file_type=symlink)
- [x] 元数据保留 (permissions, mtime)
- [x] 传输取消 (action=cancel)
- [x] 静默模式 (quiet=1/2)
- [x] 预共享密码授权 (bypass=sha256:xxx)

### 2. Desktop Notifications (OSC 99) - 桌面通知
- [x] 显示桌面通知
- [x] 通知关闭 (action=close)
- [x] 通知点击回调
- [x] 通知进度更新
- [x] 查询通知状态

### 3. Graphics Protocol (OSC 71) - 图片显示
- [x] 加载图片 (从数据或路径)
- [x] 图像删除 (单个和全部)
- [x] 图像位置查询
- [x] 转储图像到文件
- [x] 移动图像位置
- [x] 列出图像

### 4. Shell Integration (OSC 133) - Shell 集成
- [x] 提示符检测 (OSC 133;A/B/C/D)
- [x] 命令行获取 (cmdline)
- [x] 退出状态通知
- [x] 工作目录变化检测

### 5. 其他协议 - 超链接、指针、颜色栈、文本大小、标记
- [x] Color Stack (OSC 4, 21)
- [x] Text Sizing Protocol
- [x] Pointer Shapes (OSC 22)
- [x] Hyperlinks (OSC 8)
- [x] Marks - 终端标记
- [x] 窗口标题服务 (OSC 0, 1, 2)
- [x] 提示符颜色服务 (OSC 10, 11, 12, 13, 14, 17, 132, 708)

### 6. 额外实现的功能 ✅ (v1.1)

#### 6.1 Keyboard Protocol - 键盘协议
- [x] 发送文本到终端
- [x] 发送按键 (功能键、光标键、Home/End、Page Up/Down、Insert、Delete、Tab、Enter、Escape、Backspace)
- [x] 修饰键状态设置
- [x] 键盘事件回调处理

#### 6.2 Remote Control - 远程控制
- [x] 获取终端标题
- [x] 获取终端尺寸
- [x] 获取光标位置
- [x] 获取前台进程
- [x] 读取屏幕/缓冲区内容
- [x] 发送文本和按键
- [x] 发送中断信号 (Ctrl+C, Ctrl+D, Ctrl+Z)
- [x] 清除屏幕和行

#### 6.3 Terminal Modes - 终端模式
- [x] 设置/重置终端模式 (SM/RM)
- [x] Bracketed Paste 模式
- [x] Kitty Graphics 模式
- [x] 鼠标追踪模式
- [x] 光标键应用模式
- [x] 自动换行
- [x] 132 列模式
- [x] 同步输出模式
- [x] Sixel 图形模式
- [x] 终端重置

#### 6.4 Session Management - 会话管理
- [x] 获取当前工作目录
- [x] 获取/设置窗口标题
- [x] 获取前台进程
- [x] 获取终端尺寸
- [x] 发送命令和文本
- [x] 发送中断信号
- [x] 光标控制
- [x] 屏幕操作

---

## 实现的服务文件

```
lib/domain/services/
├── kitty_file_transfer_service.dart         # 文件传输 (OSC 5113)
├── kitty_notification_service.dart          # 桌面通知 (OSC 99)
├── kitty_graphics_service.dart              # 图像显示 (OSC 71)
├── kitty_shell_integration_service.dart    # Shell 集成 (OSC 133)
├── kitty_extended_protocol_service.dart    # 其他协议
├── kitty_keyboard_service.dart             # 键盘协议 (新增)
├── kitty_remote_control_service.dart       # 远程控制 (新增)
├── kitty_terminal_modes_service.dart       # 终端模式 (新增)
└── kitty_session_service.dart              # 会话管理 (新增)
```

---

## 参考资料

- **Kitty 协议文档**: `/Users/lbp/Projects/KittyProtocol/docs/kitty/docs`
- **Kitty 协议 Dart 实现**: `/Users/lbp/Projects/KittyProtocol`
- **kterm 终端控件源码**: `/Users/lbp/Projects/kterm.dart`
