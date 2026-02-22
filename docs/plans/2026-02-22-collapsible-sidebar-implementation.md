# 可折叠侧边栏实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目标：** 将左侧 280px 固定宽度的连接列表改为可折叠侧边栏，展开 280px，折叠 60px（图标模式），并添加搜索功能。

**架构：** 使用 StatefulWidget 内部状态管理展开/折叠，使用 AnimatedContainer 实现宽度动画过渡。

**技术栈：** Flutter, Provider

---

## 任务 1：添加搜索功能到 ConnectionProvider

**文件：**
- 修改: `lib/presentation/providers/connection_provider.dart`

**步骤 1：添加搜索状态和过滤方法**

修改 `lib/presentation/providers/connection_provider.dart`，添加：

```dart
String _searchQuery = '';

String get searchQuery => _searchQuery;

List<SshConnection> get filteredConnections {
  if (_searchQuery.isEmpty) return _connections;
  final query = _searchQuery.toLowerCase();
  return _connections.where((c) =>
    c.name.toLowerCase().contains(query) ||
    c.host.toLowerCase().contains(query) ||
    c.username.toLowerCase().contains(query)
  ).toList();
}

void setSearchQuery(String query) {
  _searchQuery = query;
  notifyListeners();
}

void clearSearch() {
  _searchQuery = '';
  notifyListeners();
}
```

**步骤 2：运行分析检查**

Run: `flutter analyze --no-fatal-infos lib/presentation/providers/connection_provider.dart`
Expected: 无错误

**步骤 3：提交**

```bash
git add lib/presentation/providers/connection_provider.dart
git commit -m "feat: add search functionality to ConnectionProvider"
```

---

## 任务 2：创建 CollapsibleSidebar 组件

**文件：**
- 创建: `lib/presentation/widgets/collapsible_sidebar.dart`

**步骤 1：编写 CollapsibleSidebar 组件**

创建 `lib/presentation/widgets/collapsible_sidebar.dart`：

```dart
import 'package:flutter/material.dart';
import '../screens/app_settings_screen.dart';
import 'connection_list.dart';

class CollapsibleSidebar extends StatefulWidget {
  final Function(SshConnection)? onConnectionTap;
  final Function(SshConnection)? onSftpTap;

  const CollapsibleSidebar({
    super.key,
    this.onConnectionTap,
    this.onSftpTap,
  });

  @override
  State<CollapsibleSidebar> createState() => _CollapsibleSidebarState();
}

class _CollapsibleSidebarState extends State<CollapsibleSidebar> {
  bool _isExpanded = true;
  final _searchController = TextEditingController();
  bool _showSearch = false;

  static const double _expandedWidth = 280.0;
  static const double _collapsedWidth = 60.0;

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _showSearch = false;
      }
    });
  }

  void _toggleSearch() {
    setState(() {
      if (_isExpanded) {
        _showSearch = !_showSearch;
        if (!_showSearch) {
          _searchController.clear();
        }
      } else {
        _isExpanded = true;
        _showSearch = true;
      }
    });
  }

  void _openSettings() {
    setState(() {
      _isExpanded = true;
      _showSearch = false;
    });
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AppSettingsScreen()),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: _isExpanded ? _expandedWidth : _collapsedWidth,
      child: Column(
        children: [
          // Top buttons row
          Padding(
            padding: const EdgeInsets.all(8),
            child: _isExpanded
                ? Column(
                    children: [
                      if (_showSearch)
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: '搜索连接...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: _toggleSearch,
                            ),
                            border: const OutlineInputBorder(),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          onChanged: (value) {
                            context.read<ConnectionProvider>().setSearchQuery(value);
                          },
                        )
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.search),
                              onPressed: _toggleSearch,
                              tooltip: '搜索',
                            ),
                            IconButton(
                              icon: const Icon(Icons.settings),
                              onPressed: _openSettings,
                              tooltip: '设置',
                            ),
                          ],
                        ),
                    ],
                  )
                : Column(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: _toggleExpanded,
                        tooltip: '展开',
                      ),
                    ],
                  ),
          ),
          // Connection list
          Expanded(
            child: ConnectionList(
              isCompact: !_isExpanded,
              onConnectionTap: widget.onConnectionTap,
              onSftpTap: widget.onSftpTap,
            ),
          ),
          // Bottom toggle button
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.all(8),
              child: IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _toggleExpanded,
                tooltip: '折叠',
              ),
            ),
          if (!_isExpanded)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _toggleSearch,
                    tooltip: '搜索',
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: _openSettings,
                    tooltip: '设置',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
```

**步骤 2：添加缺失的 import**

需要在文件顶部添加：
```dart
import 'package:provider/provider.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/presentation/providers/connection_provider.dart';
```

**步骤 3：运行分析检查**

Run: `flutter analyze --no-fatal-infos lib/presentation/widgets/collapsible_sidebar.dart`
Expected: 无错误

**步骤 4：提交**

```bash
git add lib/presentation/widgets/collapsible_sidebar.dart
git commit -m "feat: create CollapsibleSidebar component"
```

---

## 任务 3：修改 ConnectionList 支持紧凑模式

**文件：**
- 修改: `lib/presentation/widgets/connection_list.dart`

**步骤 1：添加 isCompact 参数**

修改 `ConnectionList` 类，添加 `isCompact` 参数：

```dart
class ConnectionList extends StatelessWidget {
  final Function(SshConnection)? onConnectionTap;
  final Function(SshConnection)? onSftpTap;
  final bool isCompact;

  const ConnectionList({
    super.key,
    this.onConnectionTap,
    this.onSftpTap,
    this.isCompact = false,
  });
```

**步骤 2：使用 filteredConnections**

在 build 方法中，将：
```dart
final connections = provider.connections;
```
改为：
```dart
final connections = provider.filteredConnections;
```

**步骤 3：修改列表项渲染逻辑**

在 ListView.builder 的 itemBuilder 中，根据 isCompact 返回不同布局：

```dart
itemBuilder: (context, index) {
  final connection = connections[index];
  if (isCompact) {
    return _CompactConnectionItem(
      connection: connection,
      onTap: () {
        onConnectionTap?.call(connection);
        _onConnectionTap(context, connection);
      },
      onSftpTap: () => onSftpTap?.call(connection),
    );
  }
  return _ConnectionListItem(
    // ... existing code
  );
},
```

**步骤 4：添加 _CompactConnectionItem 组件**

在文件末尾添加：

```dart
/// 紧凑模式连接项（图标模式）
class _CompactConnectionItem extends StatelessWidget {
  final SshConnection connection;
  final VoidCallback onTap;
  final VoidCallback? onSftpTap;

  const _CompactConnectionItem({
    required this.connection,
    required this.onTap,
    this.onSftpTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Icon(
                  Icons.computer,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 4),
                Text(
                  connection.name,
                  style: const TextStyle(fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
        if (onSftpTap != null)
          InkWell(
            onTap: onSftpTap,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Icon(
                Icons.folder_copy,
                size: 16,
              ),
            ),
          ),
      ],
    );
  }
}
```

**步骤 5：运行分析检查**

Run: `flutter analyze --no-fatal-infos lib/presentation/widgets/connection_list.dart`
Expected: 无错误

**步骤 6：提交**

```bash
git add lib/presentation/widgets/connection_list.dart
git commit -m "feat: add compact mode to ConnectionList"
```

---

## 任务 4：修改 MainScreen 使用 CollapsibleSidebar

**文件：**
- 修改: `lib/presentation/screens/main_screen.dart`

**步骤 1：替换 SizedBox 为 CollapsibleSidebar**

修改 `lib/presentation/screens/main_screen.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/terminal_provider.dart';
import '../screens/sftp_browser_screen.dart';
import '../widgets/collapsible_sidebar.dart';
import '../widgets/terminal_view.dart';

/// 主界面
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final terminalProvider = Provider.of<TerminalProvider>(
        context,
        listen: false,
      );
      terminalProvider.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Collapsible sidebar
          CollapsibleSidebar(
            onSftpTap: (connection) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SftpBrowserScreen(connection: connection),
                ),
              );
            },
          ),
          const VerticalDivider(width: 1),
          // Terminal view
          const Expanded(
            child: TerminalTabsView(),
          ),
        ],
      ),
    );
  }
}
```

**步骤 2：运行分析检查**

Run: `flutter analyze --no-fatal-infos lib/presentation/screens/main_screen.dart`
Expected: 无错误

**步骤 3：提交**

```bash
git add lib/presentation/screens/main_screen.dart
git commit -m "feat: use CollapsibleSidebar in MainScreen"
```

---

## 任务 5：验证构建

**步骤 1：运行 Flutter 分析**

Run: `flutter analyze --no-fatal-infos`
Expected: 无错误

**步骤 2：构建 macOS**

Run: `flutter build macos --debug --no-tree-shake-icons`
Expected: 构建成功

**步骤 3：提交**

```bash
git add .
git commit -m "feat: implement collapsible sidebar with search"
```

---

## 验收标准

1. ✅ 侧边栏可以展开/折叠
2. ✅ 展开状态宽度 280px，显示完整连接列表 + 搜索框 + 设置按钮
3. ✅ 折叠状态宽度 60px，只显示连接图标 + 搜索图标 + 设置图标
4. ✅ 搜索可以过滤连接名称和 hostname/username
5. ✅ 设置按钮在展开和折叠状态下都可访问
6. ✅ 展开/折叠动画平滑（200ms）
