# lbpSSH (Rust + Dioxus)

使用 Rust 和 Dioxus 重写的跨平台 SSH 终端管理器。

## 项目结构

```
dioxus/
├── Cargo.toml
├── src/
│   ├── main.rs              # 程序入口
│   ├── app.rs               # 主应用组件
│   ├── models/
│   │   ├── mod.rs           # 模块导出
│   │   ├── connection.rs    # SSH 连接模型
│   │   └── config.rs        # 应用配置模型
│   ├── components/
│   │   ├── mod.rs          # 组件导出
│   │   ├── terminal.rs      # 终端组件
│   │   ├── terminal.css     # 终端样式
│   │   ├── tabs.rs          # 标签页组件
│   │   ├── connection_list.rs # 连接列表组件
│   │   └── connection_form.rs # 连接表单组件
│   └── ssh/
│       ├── mod.rs          # 模块导出
│       └── session.rs       # SSH 会话管理
```

## 依赖

- Rust 1.70+
- 必要的系统库：
  - **Linux**: `libgtk-3-dev`, `libwebkit2gtk-4.0-dev`
  - **macOS**: Xcode Command Line Tools
  - **Windows**: WebView2 Runtime

## 安装依赖

### Linux (Ubuntu/Debian)
```bash
sudo apt-get install libgtk-3-dev libwebkit2gtk-4.0-dev
```

### macOS
```bash
xcode-select --install
```

## 运行

```bash
cargo run
```

## 构建

```bash
# Debug 构建
cargo build

# Release 构建
cargo build --release

# 构建 AppImage (Linux)
cargo build --release --package appimage

# 构建 DMG (macOS)
cargo build --release --package dmg
```

## 功能

- [x] SSH 连接管理
- [x] 密码认证
- [x] 私钥认证
- [x] 跳板机支持
- [ ] SOCKS5 代理
- [ ] SSH Config 支持
- [x] 多标签页
- [x] 本地配置存储

## 待实现

- 终端渲染（当前使用简单的文本显示OCKS5 ）
- S代理支持
- SSH Config 解析
- 配置导入/导出
- 主题切换

## 许可证

MIT
