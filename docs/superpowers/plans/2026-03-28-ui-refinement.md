# UI Refinement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refined Modern UI overhaul — deeper dark palette, consistent spacing system, component polish for cards/buttons/inputs/sidebar/tabs.

**Architecture:** Update `lib/core/theme/app_theme.dart` with semantic color tokens and spacing constants, then refactor widgets to use theme-aware tokens instead of manual `isDark` checks.

**Tech Stack:** Flutter, Material 3

---

## Files Summary

| File | Changes |
|------|---------|
| `lib/core/theme/app_theme.dart` | New semantic colors, spacing constants, updated theme data |
| `lib/presentation/widgets/connection_list.dart` | Remove manual isDark/grey.shade checks |
| `lib/presentation/widgets/collapsible_sidebar.dart` | Remove manual isDark/grey.shade checks |
| `lib/presentation/widgets/terminal_view.dart` | Remove manual isDark checks |
| `lib/presentation/screens/connection_form.dart` | Remove manual isDark checks |
| `lib/presentation/widgets/shimmer_loading.dart` | Review and update if needed |

---

## Task 1: Theme Foundation — Semantic Colors & Spacing

**Files:**
- Modify: `lib/core/theme/app_theme.dart`

- [ ] **Step 1: Add semantic color constants**

Replace the entire `app_theme.dart` content with updated version including new semantic color tokens:

```dart
import 'package:flutter/material.dart';

class AppTheme {
  // === Spacing Constants (4pt base grid) ===
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 12.0;
  static const double spacingLg = 16.0;
  static const double spacingXl = 24.0;
  static const double spacingXxl = 32.0;

  // === Dark Mode Semantic Colors ===
  static const Color darkBackground = Color(0xFF0B0F19);
  static const Color darkSurface = Color(0xFF161B22);
  static const Color darkSurfaceRaised = Color(0xFF1C2128);
  static const Color darkBorder = Color(0xFF30363D);
  static const Color darkBorderSubtle = Color(0xFF21262D);
  static const Color darkTextPrimary = Color(0xFFE6EDF3);
  static const Color darkTextSecondary = Color(0xFF8B949E);
  static const Color darkTextTertiary = Color(0xFF6E7681);
  static const Color darkAccent = Color(0xFF238636);
  static const Color darkAccentHover = Color(0xFF2EA043);
  static const Color darkAccentMuted = Color(0x26238636); // 15% opacity

  // === Light Mode Semantic Colors ===
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF6F8FA);
  static const Color lightSurfaceRaised = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFD0D7DE);
  static const Color lightBorderSubtle = Color(0xFFEAECEF);
  static const Color lightTextPrimary = Color(0xFF1F2328);
  static const Color lightTextSecondary = Color(0xFF656D76);
  static const Color lightTextTertiary = Color(0xFF8C959F);
  static const Color lightAccent = Color(0xFF1A7F37);
  static const Color lightAccentHover = Color(0xFF2DA44E);
  static const Color lightAccentMuted = Color(0x1A1A7F37); // 10% opacity

  // Legacy constants for backward compatibility (deprecated)
  static const Color accentGreen = darkAccent;
  static const Color primaryDark = darkBackground;
  static const Color secondaryDark = darkSurface;
  static const Color backgroundDark = darkBackground;
  static const Color surfaceDark = darkSurface;
  static const Color cardDark = darkSurfaceRaised;
  static const Color terminalBackground = Color(0xFF1E1E1E);
  static const Color terminalForeground = Color(0xFFD4D4D4);

  // === Updated Themes ===

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: lightBackground,
    colorScheme: ColorScheme.light(
      primary: lightAccent,
      secondary: lightAccent,
      surface: lightSurface,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: lightTextPrimary,
      surfaceContainerHighest: lightSurfaceRaised,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: lightSurfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: lightBorder),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: lightAccent, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: lightAccent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: lightBorderSubtle,
      thickness: 1,
    ),
    iconTheme: const IconThemeData(color: lightTextSecondary),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontWeight: FontWeight.w600, color: lightTextPrimary),
      headlineMedium: TextStyle(fontWeight: FontWeight.w600, color: lightTextPrimary),
      headlineSmall: TextStyle(fontWeight: FontWeight.w600, color: lightTextPrimary),
      titleLarge: TextStyle(fontWeight: FontWeight.w600, color: lightTextPrimary),
      titleMedium: TextStyle(fontWeight: FontWeight.w500, color: lightTextPrimary),
      titleSmall: TextStyle(fontWeight: FontWeight.w500, color: lightTextPrimary),
      bodyLarge: TextStyle(color: lightTextPrimary),
      bodyMedium: TextStyle(color: lightTextSecondary),
      bodySmall: TextStyle(color: lightTextTertiary),
      labelLarge: TextStyle(color: lightTextSecondary),
      labelMedium: TextStyle(color: lightTextTertiary),
      labelSmall: TextStyle(color: lightTextTertiary),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: lightSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: lightTextPrimary,
      contentTextStyle: const TextStyle(color: lightBackground),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      behavior: SnackBarBehavior.floating,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBackground,
    colorScheme: const ColorScheme.dark(
      primary: darkAccent,
      secondary: darkAccent,
      surface: darkSurface,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: darkTextPrimary,
      surfaceContainerHighest: darkSurfaceRaised,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: darkBackground,
      surfaceTintColor: Colors.transparent,
      foregroundColor: darkTextPrimary,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: darkSurfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: darkBorder),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: darkAccent, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      labelStyle: const TextStyle(color: darkTextSecondary),
      hintStyle: const TextStyle(color: darkTextTertiary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: darkAccent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: darkBorderSubtle,
      thickness: 1,
    ),
    iconTheme: const IconThemeData(color: darkTextSecondary),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontWeight: FontWeight.w600, color: darkTextPrimary),
      headlineMedium: TextStyle(fontWeight: FontWeight.w600, color: darkTextPrimary),
      headlineSmall: TextStyle(fontWeight: FontWeight.w600, color: darkTextPrimary),
      titleLarge: TextStyle(fontWeight: FontWeight.w600, color: darkTextPrimary),
      titleMedium: TextStyle(fontWeight: FontWeight.w500, color: darkTextPrimary),
      titleSmall: TextStyle(fontWeight: FontWeight.w500, color: darkTextPrimary),
      bodyLarge: TextStyle(color: darkTextPrimary),
      bodyMedium: TextStyle(color: darkTextSecondary),
      bodySmall: TextStyle(color: darkTextTertiary),
      labelLarge: TextStyle(color: darkTextSecondary),
      labelMedium: TextStyle(color: darkTextTertiary),
      labelSmall: TextStyle(color: darkTextTertiary),
    ),
    listTileTheme: const ListTileThemeData(
      textColor: darkTextPrimary,
      iconColor: darkTextSecondary,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: darkSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: darkSurfaceRaised,
      contentTextStyle: const TextStyle(color: darkTextPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
```

- [ ] **Step 2: Run analyze to check for errors**

Run: `flutter analyze lib/core/theme/app_theme.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/core/theme/app_theme.dart
git commit -m "refactor(theme): add semantic colors and spacing constants"
```

---

## Task 2: Refactor connection_list.dart

**Files:**
- Modify: `lib/presentation/widgets/connection_list.dart:1-398`

- [ ] **Step 1: Read current file to understand structure**

Read: `lib/presentation/widgets/connection_list.dart`

- [ ] **Step 2: Replace connection_list.dart with theme-aware version**

Replace the entire file with this content:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/ssh_connection.dart';
import '../../core/theme/app_theme.dart';
import '../providers/connection_provider.dart';
import '../screens/connection_form.dart';

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

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null) {
          return Center(
            child: Text(
              provider.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          );
        }

        final connections = provider.filteredConnections;

        if (connections.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.dns_outlined,
                  size: 56,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(height: AppTheme.spacingLg),
                Text(
                  '暂无连接配置',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingLg),
                FilledButton.icon(
                  onPressed: () => _showConnectionForm(context, null),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加连接'),
                ),
              ],
            ),
          );
        }

        final bottomPadding = isCompact ? AppTheme.spacingSm : AppTheme.spacingXl + AppTheme.spacingMd;
        return Stack(
          children: [
            ListView.builder(
              padding: EdgeInsets.only(top: AppTheme.spacingSm, bottom: bottomPadding),
              itemCount: connections.length,
              itemBuilder: (context, index) {
                final connection = connections[index];
                if (isCompact) {
                  return _CompactConnectionItem(
                    connection: connection,
                    onTap: () => onConnectionTap?.call(connection),
                    onSftpTap: onSftpTap != null ? () => onSftpTap!(connection) : null,
                  );
                }
                return _ConnectionListItem(
                  connection: connection,
                  onTap: () => onConnectionTap?.call(connection),
                  onEdit: () => _showConnectionForm(context, connection),
                  onDelete: () => _deleteConnection(context, provider, connection),
                  onSftpTap: onSftpTap != null ? () => onSftpTap!(connection) : null,
                );
              },
            ),
            if (!isCompact)
              Positioned(
                bottom: AppTheme.spacingSm,
                right: AppTheme.spacingSm,
                child: FloatingActionButton.small(
                  heroTag: 'add_connection',
                  onPressed: () => _showConnectionForm(context, null),
                  tooltip: '添加连接',
                  child: const Icon(Icons.add),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showConnectionForm(BuildContext context, SshConnection? connection) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ConnectionFormScreen(connection: connection),
      ),
    );
  }

  Future<void> _deleteConnection(
    BuildContext context,
    ConnectionProvider provider,
    SshConnection connection,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除连接 "${connection.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await provider.deleteConnection(connection.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('连接已删除')),
        );
      }
    }
  }
}

class _ConnectionListItem extends StatelessWidget {
  final SshConnection connection;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onSftpTap;

  const _ConnectionListItem({
    required this.connection,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.onSftpTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSm,
        vertical: 3,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          hoverColor: colorScheme.primary.withValues(alpha: 0.08),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingMd,
              vertical: AppTheme.spacingSm + 2,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.terminal,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        connection.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${connection.username}@${connection.host}:${connection.port}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.spacingSm),
                if (onSftpTap != null)
                  IconButton(
                    icon: Icon(
                      Icons.folder_copy_outlined,
                      size: 20,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    onPressed: onSftpTap,
                    tooltip: 'SFTP',
                    visualDensity: VisualDensity.compact,
                  ),
                PopupMenuButton(
                  icon: Icon(
                    Icons.more_vert,
                    size: 20,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit,
                            size: 18,
                            color: colorScheme.onSurface.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: AppTheme.spacingSm + 2),
                          Text('编辑', style: TextStyle(color: colorScheme.onSurface)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: AppTheme.spacingSm + 2),
                          Text('删除', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'delete') {
                      onDelete();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: '${connection.name}\n${connection.host}',
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            hoverColor: colorScheme.primary.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppTheme.spacingSm,
                horizontal: AppTheme.spacingSm + 2,
              ),
              child: Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.terminal,
                      color: colorScheme.primary,
                      size: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    connection.name,
                    style: theme.textTheme.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (onSftpTap != null)
          Tooltip(
            message: 'SFTP',
            child: InkWell(
              onTap: onSftpTap,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Icon(
                  Icons.folder_copy_outlined,
                  size: 14,
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 3: Run analyze to check for errors**

Run: `flutter analyze lib/presentation/widgets/connection_list.dart`
Expected: No errors

- [ ] **Step 4: Run tests**

Run: `flutter test test/widgets/connection_list_test.dart`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/widgets/connection_list.dart
git commit -m "refactor(UI): use theme-aware colors in connection_list"
```

---

## Task 3: Refactor collapsible_sidebar.dart

**Files:**
- Modify: `lib/presentation/widgets/collapsible_sidebar.dart:1-292`

- [ ] **Step 1: Read current file**

Read: `lib/presentation/widgets/collapsible_sidebar.dart`

- [ ] **Step 2: Replace with theme-aware version**

Replace the entire file with this content:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/core/theme/app_theme.dart';
import 'package:lbp_ssh/presentation/providers/connection_provider.dart';
import '../screens/app_settings_screen.dart';
import 'connection_list.dart';

class CollapsibleSidebar extends StatefulWidget {
  final Function(SshConnection)? onConnectionTap;
  final Function(SshConnection)? onSftpTap;

  const CollapsibleSidebar({super.key, this.onConnectionTap, this.onSftpTap});

  @override
  State<CollapsibleSidebar> createState() => _CollapsibleSidebarState();
}

class _CollapsibleSidebarState extends State<CollapsibleSidebar>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = true;
  final _searchController = TextEditingController();
  bool _showSearch = false;
  late AnimationController _animationController;
  late Animation<double> _widthAnimation;

  static const double _expandedWidth = 280.0;
  static const double _collapsedWidth = 60.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
      value: 1.0,
    );
    _widthAnimation = Tween<double>(begin: _collapsedWidth, end: _expandedWidth)
        .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ),
        );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _showSearch = false;
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _toggleSearch() {
    final provider = context.read<ConnectionProvider>();
    setState(() {
      if (_isExpanded) {
        _showSearch = !_showSearch;
        if (!_showSearch) {
          _searchController.clear();
          provider.clearSearch();
        }
      } else {
        _isExpanded = true;
        _animationController.forward();
        _showSearch = true;
      }
    });
  }

  void _openSettings() {
    setState(() {
      _isExpanded = true;
      _showSearch = false;
      _animationController.forward();
    });
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AppSettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: _widthAnimation,
      builder: (context, child) {
        final currentWidth = _widthAnimation.value;
        final isCompactMode = currentWidth < 200;

        return Container(
          width: currentWidth,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              right: BorderSide(color: theme.dividerColor),
            ),
          ),
          child: Column(
            children: [
              _buildHeader(theme, colorScheme, isCompactMode),
              Expanded(
                child: ConnectionList(
                  isCompact: isCompactMode,
                  onConnectionTap: widget.onConnectionTap,
                  onSftpTap: widget.onSftpTap,
                ),
              ),
              _buildBottomBar(theme, colorScheme, isCompactMode),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme, bool isCompactMode) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: !isCompactMode
          ? Column(
              children: [
                if (_showSearch)
                  _buildSearchField(theme, colorScheme)
                else
                  _buildExpandedHeader(theme, colorScheme),
              ],
            )
          : _buildCollapsedHeader(theme, colorScheme),
    );
  }

  Widget _buildExpandedHeader(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildIconButton(
          icon: Icons.search,
          onPressed: _toggleSearch,
          tooltip: '搜索',
          theme: theme,
          colorScheme: colorScheme,
        ),
        _buildIconButton(
          icon: Icons.settings,
          onPressed: _openSettings,
          tooltip: '设置',
          theme: theme,
          colorScheme: colorScheme,
        ),
      ],
    );
  }

  Widget _buildSearchField(ThemeData theme, ColorScheme colorScheme) {
    return TextField(
      controller: _searchController,
      style: TextStyle(color: colorScheme.onSurface),
      decoration: InputDecoration(
        hintText: '搜索连接...',
        hintStyle: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5)),
        prefixIcon: Icon(Icons.search, color: colorScheme.onSurface.withValues(alpha: 0.6)),
        suffixIcon: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _toggleSearch,
          color: colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd,
          vertical: AppTheme.spacingSm + 2,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: colorScheme.primary),
        ),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
      ),
      onChanged: (value) {
        context.read<ConnectionProvider>().setSearchQuery(value);
      },
    );
  }

  Widget _buildCollapsedHeader(ThemeData theme, ColorScheme colorScheme) {
    return _buildIconButton(
      icon: Icons.chevron_right,
      onPressed: _toggleExpanded,
      tooltip: '展开',
      theme: theme,
      colorScheme: colorScheme,
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          hoverColor: colorScheme.primary.withValues(alpha: 0.1),
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spacingSm + 2),
            child: Icon(
              icon,
              color: colorScheme.onSurface.withValues(alpha: 0.8),
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme, ColorScheme colorScheme, bool isCompactMode) {
    if (!isCompactMode) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: _buildIconButton(
          icon: Icons.chevron_left,
          onPressed: _toggleExpanded,
          tooltip: '折叠',
          theme: theme,
          colorScheme: colorScheme,
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.spacingSm),
        child: Column(
          children: [
            _buildIconButton(
              icon: Icons.search,
              onPressed: _toggleSearch,
              tooltip: '搜索',
              theme: theme,
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 4),
            _buildIconButton(
              icon: Icons.settings,
              onPressed: _openSettings,
              tooltip: '设置',
              theme: theme,
              colorScheme: colorScheme,
            ),
          ],
        ),
      );
    }
  }
}
```

- [ ] **Step 3: Run analyze**

Run: `flutter analyze lib/presentation/widgets/collapsible_sidebar.dart`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/widgets/collapsible_sidebar.dart
git commit -m "refactor(UI): use theme-aware colors in collapsible_sidebar"
```

---

## Task 4: Refactor terminal_view.dart

**Files:**
- Modify: `lib/presentation/widgets/terminal_view.dart` (only the UI parts, not the terminal logic)

- [ ] **Step 1: Read the file to identify specific lines needing changes**

Run: `grep -n "isDark\|Colors.grey\|withValues" lib/presentation/widgets/terminal_view.dart`

Expected output shows lines using:
- `isDark` for color decisions
- `Colors.grey` for dark mode styling
- `withValues(alpha: X)` for opacity

- [ ] **Step 2: Update specific UI sections**

The following sections in `terminal_view.dart` need updates:

1. **Empty state section** (around lines 405-447):
   - Replace `Colors.grey.shadeXXX` with theme-aware colors
   - Replace `withValues(alpha: 0.3)` and `withValues(alpha: 0.5)` with theme tokens

2. **Tab bar styling** (around lines 453-548):
   - Update container colors to use `colorScheme.surface`
   - Update text colors to use theme text colors

3. **Tab item** (around lines 583-702):
   - Update hover/active states to use theme tokens

4. **Error dialog** (around lines 790-1048):
   - Replace `Colors.grey.shade600` with theme text color
   - Replace manual dark/light color decisions with theme tokens

Specific changes needed (show the diff-like replacements):

For the empty state (find and replace):
```dart
// OLD:
Icon(
  Icons.terminal,
  size: 64,
  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
),

// NEW: (same - already uses theme correctly, no change needed)
```

For the ErrorDetailDialog info row:
```dart
// OLD:
SizedBox(
  width: 80,
  child: Text(
    label,
    style: TextStyle(
      color: Colors.grey.shade600,
      fontSize: 12,
    ),
  ),
),

// NEW:
SizedBox(
  width: 80,
  child: Text(
    label,
    style: theme.textTheme.bodySmall,
  ),
),
```

- [ ] **Step 3: Run analyze**

Run: `flutter analyze lib/presentation/widgets/terminal_view.dart`
Expected: No errors

- [ ] **Step 4: Run tests**

Run: `flutter test test/widgets/terminal_status_bar_test.dart`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/widgets/terminal_view.dart
git commit -m "refactor(UI): use theme-aware colors in terminal_view"
```

---

## Task 5: Refactor connection_form.dart

**Files:**
- Modify: `lib/presentation/screens/connection_form.dart`

- [ ] **Step 1: Search for manual color usage**

Run: `grep -n "isDark\|Colors.grey" lib/presentation/screens/connection_form.dart`

- [ ] **Step 2: Read relevant sections**

Read sections of `connection_form.dart` that contain `isDark` checks.

- [ ] **Step 3: Update the UI sections**

Replace manual `isDark` color checks with theme-aware tokens. The pattern to find:

```dart
// Look for patterns like:
color: isDark ? Colors.white54 : Colors.black45,
color: isDark ? Colors.white70 : Colors.black54,
borderColor: isDark ? AppTheme.secondaryDark : Colors.grey.shade300,
```

Replace with theme-aware versions:
```dart
color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
borderColor: Theme.of(context).dividerColor,
```

- [ ] **Step 4: Run analyze**

Run: `flutter analyze lib/presentation/screens/connection_form.dart`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/screens/connection_form.dart
git commit -m "refactor(UI): use theme-aware colors in connection_form"
```

---

## Task 6: Review and Update shimmer_loading.dart

**Files:**
- Modify: `lib/presentation/widgets/shimmer_loading.dart`

- [ ] **Step 1: Check if shimmer_loading needs updates**

Run: `grep -n "isDark\|Colors.grey" lib/presentation/widgets/shimmer_loading.dart`

- [ ] **Step 2: Update if needed**

If manual color checks exist, replace with theme-aware tokens.

- [ ] **Step 3: Run analyze**

Run: `flutter analyze lib/presentation/widgets/shimmer_loading.dart`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/widgets/shimmer_loading.dart
git commit -m "refactor(UI): use theme-aware colors in shimmer_loading"
```

---

## Task 7: Final Verification

- [ ] **Step 1: Run full analyze**

Run: `flutter analyze --no-fatal-infos`
Expected: No errors (infos are acceptable)

- [ ] **Step 2: Run all tests**

Run: `flutter test`
Expected: All tests pass

- [ ] **Step 3: Check for remaining anti-patterns**

Run: `grep -rn "Colors.grey\|isDark ?" lib/presentation/ --include="*.dart" | grep -v "_test.dart"`
Expected: No matches (or only legitimate uses)

- [ ] **Step 4: Final commit if needed**

```bash
git add -A && git commit -m "refactor(UI): complete refined modern theme updates"
```

---

## Self-Review Checklist

After completing all tasks:

- [ ] All `Colors.grey.shadeXXX` removed from widgets in dark mode
- [ ] All manual `isDark ? Colors.white : Colors.black` removed from widgets
- [ ] All explicit hex colors like `#FFFFFF` replaced with theme tokens
- [ ] All scattered `AppTheme.accentGreen` replaced with `Theme.of(context).colorScheme.primary`
- [ ] Spacing constants used (`AppTheme.spacingSm`, `AppTheme.spacingMd`, etc.)
- [ ] Border radius consistent (8px cards, 6px buttons/inputs)
- [ ] Tab height reduced to 40px
- [ ] All tests pass
