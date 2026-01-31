# AGENTS.md - Development Guidelines for lbpSSH

This document provides guidelines and commands for agentic coding agents working in the lbpSSH Flutter project.

## 🏗️ Build, Lint, and Test Commands

### Essential Commands
```bash
# Install dependencies
flutter pub get

# Code generation (required after modifying model classes)
dart run build_runner build --delete-conflicting-outputs

# Clean build artifacts
flutter clean

# Analyze code
flutter analyze --no-fatal-infos

# Run all tests
flutter test

# Run single test file
flutter test test/models/ssh_connection_test.dart

# Run specific test with pattern
flutter test --name="SshConnection"

# Build for different platforms
flutter build macos --debug --no-tree-shake-icons
flutter build linux --debug
flutter build windows --debug

# Run application
flutter run -d macos
flutter run -d linux  
flutter run -d windows
```

### Development Workflow
1. Make code changes
2. Run `flutter analyze` to check for issues
3. Run relevant tests with `flutter test test/path/to/specific_test.dart`
4. Run code generation if needed: `dart run build_runner build --delete-conflicting-outputs`
5. Build and test: `flutter build macos --debug --no-tree-shake-icons`

## 📝 Code Style Guidelines

### Project Structure
```
lib/
├── core/                    # Core configuration, constants, theme
├── data/                    # Data models, repositories
├── domain/                  # Business logic, services
├── presentation/            # UI screens, widgets, providers
└── utils/                   # Utility classes
test/                       # Test files
```

### Import Organization
- **Dart/Flutter imports first**, sorted alphabetically
- **Third-party package imports** second, sorted alphabetically
- **Project imports** last, with relative paths
- Use explicit imports, avoid `import 'package:/*/**`

```dart
// Good import order
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

import '../../data/models/ssh_connection.dart';
import '../providers/connection_provider.dart';
```

### Naming Conventions
- **Files**: `snake_case.dart`
- **Classes**: `PascalCase`
- **Variables/Methods**: `camelCase`
- **Constants**: `SCREAMING_SNAKE_CASE`
- **Private members**: Leading underscore (`_privateMethod`)

### Type Guidelines
- **Always specify return types** for methods
- **Use `final`** by default, `var` only when necessary
- **Prefer concrete types** over `dynamic`
- **Use `required`** for required named parameters

```dart
// Good
class SshConnection {
  final String id;
  final String name;
  final int port;
  
  const SshConnection({
    required this.id,
    required this.name,
    this.port = 22,
  });
  
  void connect() {
    // Implementation
  }
}
```

### Widget Construction
- **Use const constructors** when possible
- **Break long widgets** into smaller components
- **Extract widgets** to separate files when >100 lines
- **Use named parameters** for better readability

```dart
// Good
class ConnectionList extends StatelessWidget {
  const ConnectionList({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SSH Connections'),
      ),
      body: const ConnectionListView(),
    );
  }
}
```

### Error Handling
- **Use try-catch** for async operations
- **Provide user-friendly error messages**
- **Log errors appropriately** (avoid sensitive data)
- **Handle null states** in UI

```dart
// Good
Future<void> _saveConnection() async {
  try {
    await provider.saveConnection(connection);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection saved')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }
}
```

### Code Generation
- **Run build_runner** after modifying model classes
- **Use `part`** and `part of** for generated files
- **Add `json_annotation`** for JSON serialization
- **Always run with `--delete-conflicting-outputs`**

### Flutter-Specific Guidelines
- **Use `Key` parameters** for widgets
- **Implement `Disposable`** for services
- **Use `ChangeNotifier`** for state management
- **Always check `mounted`** in async callbacks
- **Use proper `BuildContext` usage** (no across async gaps)

### Testing Guidelines
- **Unit tests**: test/models/, test/utils/, test/repositories/
- **Widget tests**: test/widgets/
- **Naming**: `*_test.dart`
- **Group tests** by functionality
- **Mock external dependencies**

```dart
// Good test structure
void main() {
  group('SshConnection', () {
    late SshConnection connection;
    
    setUp(() {
      connection = SshConnection(
        id: 'test-id',
        name: 'Test Connection',
        host: 'localhost',
        username: 'test',
        authType: AuthType.password,
      );
    });
    
    test('should create connection with default port', () {
      expect(connection.port, equals(22));
    });
  });
}
```

## 🔧 Development Configuration

### Analysis Options
- Uses Flutter's standard `flutter.yaml` lints
- Fatal infos excluded to focus on critical issues
- Custom rules can be added in `analysis_options.yaml`

### Build Configuration
- **Flutter 3.10.7+** required
- **Dart 3.10.7+** required
- **Desktop platforms**: Windows, Linux, macOS
- **No mobile platforms** supported

### Dependencies
- **Core**: Flutter SDK, dart language
- **UI**: Material/Cupertino icons
- **SSH**: dartssh2
- **Terminal**: xterm, Process API
- **State**: Provider pattern
- **Networking**: Dio
- **Storage**: JSON files, SharedPreferences
- **Development**: build_runner, json_serializable

## 🚨 Critical Development Rules

1. **Never commit secrets** (passwords, tokens, keys) in code
2. **Always run `flutter analyze`** before committing
3. **Test on multiple platforms** before pushing
4. **Update documentation** for new features
5. **Use semantic versioning** for releases
6. **Follow Material Design** guidelines for UI
7. **Implement proper error boundaries** for critical operations
8. **Use consistent code formatting** (automatic via dart format)

## 📋 Quick Reference

| Task | Command |
|------|---------|
| Install deps | `flutter pub get` |
| Analyze code | `flutter analyze` |
| Format code | `dart format .` |
| Run tests | `flutter test` |
| Build project | `flutter build macos --debug` |
| Generate code | `dart run build_runner build --delete-conflicting-outputs` |

When working in this repository, always prioritize code quality, user experience, and platform compatibility.