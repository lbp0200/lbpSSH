# Kitty 协议文件传输替换 SFTP 设计

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:writing-plans to create implementation plan

**目标：** 使用 Kitty 协议的 OSC 5113 文件传输完全替换现有的 dartssh2 SFTP 实现

**架构：** 在 TerminalSession 中添加 onPrivateOSC 回调处理接收文件，KittyFileTransferService 实现完整的发送/接收逻辑，SftpProvider 改为调用新服务

**技术栈：** kterm (onPrivateOSC), dart:io (文件读写)

---

## 架构设计

### 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                        UI 层                                 │
│  SftpBrowserScreen (不变) ← SftpProvider (改造)             │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                      服务层                                  │
│  KittyFileTransferService (新建 - 完整实现)                  │
│    - sendFile(): 本地 → 远程 (OSC 5113)                     │
│    - receiveFile(): 远程 → 本地 (onPrivateOSC)              │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    TerminalSession                          │
│  - 添加 onPrivateOSC 回调监听 OSC 5113                      │
│  - 接收文件时触发 KittyFileTransferService                  │
└─────────────────────────────────────────────────────────────┘
```

### 组件职责

| 组件 | 职责 |
|------|------|
| `KittyFileTransferService` | 完整的文件传输逻辑：检测协议支持、发送文件、接收文件、进度回调 |
| `TerminalSession` | 添加 `onPrivateOSC` 回调，将 OSC 5113 路由到文件传输服务 |
| `SftpProvider` | 改用 KittyFileTransferService，移除 SftpService 依赖 |
| `SftpBrowserScreen` | UI 不变，只修改底层 service 调用 |

---

## Kitty 协议详解

### OSC 5113 序列格式

**发送文件 (ki 工具命令):**
```bash
# 开始传输
echo -e '\x1b]5113;S|filename|0|1024\x1b\\'

# 数据块 (可多次)
echo -e '\x1b]5113;C|0|dGVzdCBkYXRh\x1b\\'

# 传输结束
echo -e '\x1b]5113;E|0\x1b\\'
```

**接收文件 (ko 工具):**
- 远程发起请求 → 应用程序通过 onPrivateOSC 接收 → 处理并保存

### 传输流程

**发送流程 (本地上传):**
```
1. 用户选择本地文件
2. 读取文件内容（分块）
3. 发送 OSC 5113;S 开始
4. 循环发送 OSC 5113;C 数据块
5. 发送 OSC 5113;E 结束
6. 进度回调通知 UI
```

**接收流程 (下载):**
```
1. 远程发送文件传输请求 (ko tool)
2. Terminal 捕获 OSC 5113 序列
3. onPrivateOSC 回调触发
4. 解析数据块并缓存
5. 传输完成后写入本地文件
6. 通知用户
```

---

## 依赖变化

### 需要移除
- `SftpService` (dartssh2 SFTP 客户端)

### 需要修改
- `terminal_service.dart` - 添加 onPrivateOSC 回调
- `sftp_provider.dart` - 改用 KittyFileTransferService

### 需要实现
- `KittyFileTransferService` - 完整协议实现

---

## UI 交互

### 文件浏览器界面保持不变
- 顶部路径导航
- 文件列表（名称、大小、修改时间）
- 底部工具栏：上传、下载、新建文件夹、删除

### 触发方式
- **上传**：点击工具栏上传按钮 → 选择本地文件 → Kitty 传输
- **下载**：点击文件 → 选择保存位置 → Kitty 传输

### 进度显示
- 继续使用现有的 `TransferProgressDialog`
- 显示：文件名、已传输/总大小、速度、百分比

---

## 错误处理

| 场景 | 处理 |
|------|------|
| 远程未安装 ki/ko 工具 | 提示用户安装 Kitty 工具 |
| 传输中断 | 显示错误，允许重试 |
| 文件过大 | 分块传输，进度实时更新 |
| 磁盘空间不足 | 检测并提示用户 |

---

## 验收标准

1. ✅ 上传文件：通过 OSC 5113 发送文件到远程
2. ✅ 下载文件：通过 onPrivateOSC 接收远程发送的文件
3. ✅ 进度显示：实时显示传输进度
4. ✅ 错误处理：友好的错误提示
5. ✅ 向后兼容：检测远程是否支持，不支持时提示安装工具
