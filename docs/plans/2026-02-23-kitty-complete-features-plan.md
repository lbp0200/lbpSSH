# Kitty 协议完整实现计划

**日期**: 2026-02-23
**状态**: 规划中
**版本**: 1.0

---

## 1. File Transfer (OSC 5113) - 文件传输

### 1.1 现有功能 ✅
- [x] 文件上传 (send)
- [x] 文件下载 (receive)
- [x] 目录导航 (cd, cd ..)
- [x] 目录操作 (mkdir, rm, rmdir)
- [x] 拖拽上传
- [x] 协议支持检测

### 1.2 待实现功能
- [ ] 目录批量传输 (递归传输整个目录)
- [ ] 压缩传输 (compression=zlib)
- [ ] Rsync 增量同步 (transmission_type=rsync)
- [ ] 符号链接处理 (file_type=symlink)
- [ ] 硬链接处理 (file_type=link)
- [ ] 元数据保留 (permissions, mtime)
- [ ] 传输取消 (action=cancel)
- [ ] 静默模式 (quiet=1/2)
- [ ] 预共享密码授权 (bypass=sha256:xxx)
- [ ] 传输进度确认 (解析 status 响应)

---

## 2. Clipboard (OSC 52 / OSC 5522) - 剪贴板

### 2.1 现有功能 ✅
- [x] 读取剪贴板 (kterm 内置)
- [x] 写入剪贴板 (kterm 内置)

### 2.2 待实现功能
- [ ] 多格式 MIME 类型支持
- [ ] 剪贴板别名 (walias)
- [ ] 读取状态响应处理
- [ ] 大数据分块传输

---

## 3. Desktop Notifications (OSC 99) - 桌面通知

### 3.1 待实现功能
- [ ] 显示桌面通知
- [ ] 通知关闭 (action=close)
- [ ] 通知点击回调
- [ ] 通知进度更新
- [ ] 通知持久化
- [ ] 查询通知状态

---

## 4. Graphics Protocol - 图片显示

### 4.1 现有功能 ✅
- [x] 加载图片 (kterm 内置)
- [x] 图像传输

### 4.2 待实现功能
- [ ] 图像位置控制 (placement)
- [ ] 图像动画支持
- [ ] 动画帧传输
- [ ] 图像删除 (action=delete)
- [ ] 图像位置查询
- [ ] 转储图像到文件

---

## 5. Shell Integration (OSC 133) - Shell 集成

### 5.1 待实现功能
- [ ] 提示符检测 (OSC 133;A/B/C/D)
- [ ] 命令行获取 (cmdline)
- [ ] 退出状态通知
- [ ] 工作目录变化检测

---

## 6. 其他协议

### 6.1 待实现功能
- [ ] Color Stack (OSC 4, 21) - 颜色栈管理
- [ ] Text Sizing Protocol - 文本大小调整
- [ ] Pointer Shapes (OSC 22) - 鼠标指针形状
- [ ] Hyperlinks (OSC 8) - 超链接
- [ ] Marks - 终端标记

---

## 实现优先级

### 高优先级
1. 目录批量传输
2. 压缩传输
3. 元数据保留
4. 传输取消
5. 桌面通知

### 中优先级
6. Rsync 增量同步
7. 符号链接/硬链接
8. 图像位置控制
9. Shell 集成

### 低优先级
10. 静默模式
11. 预共享密码
12. 其他协议

---

## 技术架构

```
lib/domain/services/
├── kitty_file_transfer_service.dart    # 文件传输 (OSC 5113)
├── kitty_clipboard_service.dart         # 剪贴板 (OSC 52/5522)
├── kitty_notification_service.dart       # 桌面通知 (OSC 99)
├── kitty_graphics_service.dart          # 图像显示
└── kitty_shell_integration.dart       # Shell 集成 (OSC 133)
```

---

## 参考资料

- **Kitty 协议文档**: `/Users/lbp/Projects/KittyProtocol/docs/kitty/docs`
- **Kitty 协议 Dart 实现**: `/Users/lbp/Projects/KittyProtocol`
- **kterm 终端控件源码**: `/Users/lbp/Projects/kterm.dart`
