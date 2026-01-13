# SSH Manager

跨平台 SSH 终端管理器，支持 Windows、Linux、macOS。

## 功能特性

- ✅ SSH 连接管理：添加、编辑、删除 SSH 连接配置
- ✅ 多种认证方式：密码、密钥、密钥+密码
- ✅ 跳板机支持：通过跳板机连接到目标服务器
- ✅ 终端模拟器：完整的交互式终端体验
- ✅ 多标签页：同时管理多个 SSH 连接
- ✅ 配置同步：支持同步到 GitHub 或 Gitee
- ✅ 数据加密：敏感信息加密存储和传输
- ✅ 分割视图：可调整的连接列表和终端区域

## 技术栈

- **Flutter** - 跨平台 UI 框架
- **dartssh2** - SSH 客户端
- **xterm** - 终端模拟器
- **Hive** - 本地数据存储
- **Provider** - 状态管理
- **Dio** - HTTP 客户端（用于同步）

## 安装和运行

### 前置要求

- Flutter SDK (3.10.7 或更高版本)
- Dart SDK
- 桌面平台支持（Windows、Linux、macOS）

### 安装依赖

```bash
flutter pub get
```

### 代码生成

如果需要生成 JSON 序列化代码：

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 运行应用

```bash
# Windows
flutter run -d windows

# Linux
flutter run -d linux

# macOS
flutter run -d macos
```

## 使用说明

### 添加 SSH 连接

1. 点击应用栏的"添加连接"按钮
2. 填写连接信息：
   - 连接名称
   - 主机地址和端口
   - 用户名
   - 选择认证方式（密码/密钥/密钥+密码）
   - 输入相应的认证信息
3. 可选：配置跳板机
4. 点击"保存"

### 连接 SSH 服务器

1. 在左侧连接列表中点击要连接的服务器
2. 输入主密码（用于解密连接信息）
3. 连接成功后，终端会在右侧标签页中打开

### 配置同步

1. 点击应用栏的"同步设置"按钮
2. 选择同步平台（GitHub 或 Gitee）
3. 完成 OAuth 认证
4. 配置仓库信息：
   - 仓库所有者
   - 仓库名称
   - 分支
   - 文件路径
5. 设置主密码（用于加密敏感信息）
6. 点击"保存配置"
7. 使用"上传配置"或"下载配置"按钮进行同步

## 项目结构

```
lib/
├── main.dart                    # 应用入口
├── core/                        # 核心配置
│   ├── theme/                   # 主题
│   └── constants/               # 常量
├── data/                        # 数据层
│   ├── models/                  # 数据模型
│   └── repositories/            # 数据仓库
├── domain/                      # 业务逻辑层
│   └── services/                # 业务服务
├── presentation/                # 展示层
│   ├── screens/                 # 页面
│   ├── widgets/                 # 组件
│   └── providers/               # 状态管理
└── utils/                       # 工具类
```

## 安全注意事项

- 所有敏感信息（密码、密钥）都使用主密码加密存储
- 同步到云端前，敏感信息会被加密
- OAuth token 存储在系统密钥链中（需要实现）
- 建议使用强主密码

## 开发计划

- [ ] 实现完整的 SSH 交互式终端
- [ ] 支持终端主题自定义
- [ ] 实现连接分组和搜索
- [ ] 支持快捷键
- [ ] 实现自动同步功能
- [ ] 完善冲突处理机制
- [ ] 添加连接历史记录

## 许可证

MIT License
