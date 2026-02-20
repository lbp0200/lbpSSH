# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

lbpSSH is a cross-platform SSH terminal manager built with Flutter for Windows, Linux, and macOS. It manages SSH connections with multiple authentication methods, supports jump/bastion hosts, and syncs configurations to GitHub Gist/Repository or Gitee.

## Release Process

```bash
# 1. Update version in pubspec.yaml
# 2. Commit changes: git add pubspec.yaml && git commit -m "release: bump version to X.Y.Z"
# 3. Create tag: git tag vX.Y.Z
# 4. Push: git push && git push origin vX.Y.Z
```

## Build Commands

```bash
# Install dependencies
flutter pub get

# Code generation (required after modifying model classes)
dart run build_runner build --delete-conflicting-outputs

# Analyze code
flutter analyze --no-fatal-infos

# Run all tests
flutter test

# Run single test file
flutter test test/models/ssh_connection_test.dart

# Build for specific platform (debug)
flutter build macos --debug --no-tree-shake-icons
flutter build linux --debug
flutter build windows --debug
```

## Architecture

The project follows clean architecture with clear separation:

```
lib/
├── main.dart           # App entry point, DI setup via MultiProvider
├── core/               # Constants, theme configuration
├── data/               # Models (JSON-serializable), repositories
├── domain/             # Services, use cases
├── presentation/       # Screens, widgets, ChangeNotifier providers
└── utils/              # Utilities (encryption, etc.)
```

**Key dependencies:**
- `dartssh2` - SSH client
- `xterm` - Terminal emulator
- `provider` - State management
- `go_router` - Routing
- `dio` - HTTP client for sync
- `encrypt` - Encryption

## Code Conventions

### Import Order
1. Dart/Flutter imports (alphabetical)
2. Third-party package imports (alphabetical)
3. Project imports with relative paths (alphabetical)

### Naming
- Files: `snake_case.dart`
- Classes: `PascalCase`
- Variables/Methods: `camelCase`
- Constants: `SCREAMING_SNAKE_CASE`
- Private members: Leading underscore

### Model Pattern
Models use `@JsonSerializable()` with `part '*.g.dart'` and include:
- `copyWith()` method
- `fromJson()` and `toJson()` factories

### State Management
Providers use `ChangeNotifier` via `MultiProvider` in `main.dart`. Follow the pattern:
- Check `mounted`/`context.mounted` in async callbacks
- Use `if (context.mounted)` before context operations after await

### Widget Guidelines
- Use `const` constructors when possible
- Extract widgets >100 lines to separate files
- Always specify `Key` parameter

## Development Notes

- Flutter 3.10.7+ required
- No mobile platform support (desktop only)
- Sensitive data encrypted with user-provided master password
- Configuration stored in local JSON file (`~/.config/lbpSSH/ssh_connections.json` on Linux)
