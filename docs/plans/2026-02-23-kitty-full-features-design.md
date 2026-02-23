# Kitty 协议文件传输完整实现设计

**日期**: 2026-02-23
**状态**: 已批准
**版本**: 1.0

## 1. 概述

本文档描述使用纯 Kitty 协议实现完整的文件传输功能，包括文件列表浏览、文件下载、目录操作等。

## 2. 整体架构

```
┌─────────────────────────────────────────────────────────┐
│                    SftpBrowserScreen                     │
│  (UI: 文件列表、导航栏、工具栏)                           │
└─────────────────────────┬───────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────┐
│                      SftpProvider                        │
│  (状态管理: 当前路径、文件列表、传输进度)                 │
└─────────────────────────┬───────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────┐
│              KittyFileTransferService                   │
│  - 文件列表浏览 (ls -la 解析)                            │
│  - 文件上传 (已实现)                                     │
│  - 文件下载 (ki send 接收模式)                           │
│  - 目录操作 (cd, mkdir, rm, rmdir)                       │
│  - 协议检测 (checkProtocolSupport)                        │
└─────────────────────────────────────────────────────────┘
```

## 3. 核心功能设计

### 3.1 文件列表浏览

**实现方式**: 通过终端执行 `ls -la --time-style=long-iso` 命令，解析输出

**解析规则**:
```
drwxr-xr-x  2 user user 4096 2024-01-15 10:30 dirname
-rw-r--r--  1 user user 1234 2024-01-15 09:20 filename
```

- 首字符 `d` = 目录
- 提取: 权限、链接数、所有者、文件大小、日期、时间、文件名

**数据结构**:
```dart
class RemoteFile {
  final String name;
  final bool isDirectory;
  final int size;
  final DateTime modified;
  final String permissions;
}
```

### 3.2 文件下载

**Kitty 协议接收模式**:
1. 发送接收会话请求: `OSC 5113;ac=recv;id=xxx`
2. 监听终端输出，解析 OSC 5113 数据序列
3. 接收文件数据块并写入本地文件

**实现**:
```dart
/// 启动文件接收会话
Future<void> startReceiveSession({
  required String remotePath,
  required String localPath,
  required TransferProgressCallback onProgress,
});
```

### 3.3 目录导航

- `changeDirectory(path)`: 发送 `cd <path>` 命令
- `goUp()`: 发送 `cd ..` 命令
- `refresh()`: 重新执行 `ls` 获取最新列表

### 3.4 文件操作

- `createDirectory(name)`: 发送 `mkdir <name>`
- `removeFile(path)`: 发送 `rm <path>`
- `removeDirectory(path)`: 发送 `rmdir <path>`

### 3.5 协议支持检测

发送查询命令，检查远程是否响应：
```dart
Future<ProtocolSupportResult> checkProtocolSupport();
```

## 4. UI 设计

**SftpBrowserScreen**:
- 顶部: 路径导航栏 (可点击进入上级目录)
- 中间: 文件列表 (ListView)
  - 文件夹显示在前
  - 点击目录自动进入
  - 右键菜单: 下载、删除、重命名
- 底部: 工具栏
  - 上传文件按钮
  - 新建文件夹按钮
  - 刷新按钮

## 5. 错误处理

| 场景 | 处理 |
|------|------|
| 远程无 ki 工具 | 提示用户安装，显示安装指南 |
| 权限不足 | 显示错误信息 |
| 文件传输中断 | 支持取消，清理临时文件 |
| 网络断开 | 提示重连 |

## 6. 待实现功能清单

- [x] 文件上传 (已完成)
- [ ] 文件列表浏览
- [ ] 文件下载
- [ ] 目录导航 (cd, cd ..)
- [ ] 创建目录
- [ ] 删除文件
- [ ] 删除目录
- [ ] 协议支持检测
