# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

lbpSSH is a cross-platform SSH terminal manager built with Rust and Dioxus 0.7 (desktop). It manages SSH connections with support for multiple auth types, jump hosts, SOCKS5 proxies, and multi-tab terminals.

## Build Commands

```bash
cargo run              # Run in debug mode
cargo build            # Debug build
cargo build --release  # Optimized release build
cargo check            # Type-check without building
```

## Architecture

### Global State Pattern
- `main.rs` initializes global `ConfigModel` using atomic pointers (`std::sync::atomic::AtomicPtr`) and provides it via Dioxus context
- `ssh/session_manager.rs` provides global SSH session management using `OnceLock<Mutex<HashMap<Uuid, SshSession>>>`

### Key Modules
- **`models/`**: Data models (`SshConnection`, `AuthType`, `ConfigModel`, `TerminalConfig`)
- **`components/`**: Dioxus UI components (`terminal.rs`, `tabs.rs`, `connection_list.rs`, `connection_form.rs`)
- **`ssh/`**: SSH session management (`SshSession`, `SessionManager`, sync state)
- **`utils/`**: Import/export and sync utilities

### Configuration
- Uses `confy` for platform-specific config storage
- Connections serialized to JSON

### Async Runtime
- SSH operations use `tokio` async runtime with `ssh2` crate

## Code Style

Comments, documentation, and identifiers are in **Chinese**. Maintain this convention.

## Testing

No tests currently exist. Use standard `#[test]` attribute when adding tests:
```bash
cargo test              # Run all tests
cargo test test_name    # Run specific test
```

## Platform-Specific Dependencies

| Platform | Dependencies |
|----------|--------------|
| macOS | Xcode Command Line Tools |
| Linux | `libgtk-3-dev`, `libwebkit2gtk-4.0-dev` |
| Windows | WebView2 Runtime |

