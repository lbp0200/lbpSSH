import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/ssh_connection.dart';
import '../providers/terminal_provider.dart';
import '../widgets/connection_list.dart';
import '../widgets/terminal_view.dart';
import '../screens/connection_form.dart';
import 'app_settings_screen.dart';
import 'import_export_settings.dart';
import 'sync_settings.dart';

/// 主界面
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const double _compactPanelWidth = 60; // 紧凑型面板固定宽度
  bool _isLeftPanelVisible = true;

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
          // 左侧紧凑型连接Logo面板
          if (_isLeftPanelVisible)
            Container(
              width: _compactPanelWidth,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: Border(
                  right: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 面板操作按钮 - 上对齐，占满高度
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.settings),
                          iconSize: 18,
                          tooltip: '设置',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 30,
                            minHeight: 30,
                          ),
                          onPressed: () {
                            _showSettingsMenu(context);
                          },
                        ),
                        const SizedBox(height: 8),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          iconSize: 18,
                          tooltip: '编辑连接',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 30,
                            minHeight: 30,
                          ),
                          onPressed: () {
                            _showConnectionListForEditing();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          // 分割线
          if (_isLeftPanelVisible)
            Container(width: 1, color: Theme.of(context).dividerColor),
          // 右侧终端区域
          Expanded(
            child: _isLeftPanelVisible
                ? const TerminalTabsView()
                : Column(
                    children: [
                      // 显示左侧面板按钮
                      Container(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: () {
                                setState(() {
                                  _isLeftPanelVisible = true;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const Expanded(child: TerminalTabsView()),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _showSettingsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '设置',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('应用设置'),
              subtitle: const Text('终端配置、自动同步等'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AppSettingsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_upload),
              title: const Text('导入导出'),
              subtitle: const Text('本地配置文件管理'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ImportExportSettingsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud_sync),
              title: const Text('云端同步'),
              subtitle: const Text('GitHub Gist/GitHub/Gitee同步'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SyncSettingsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleConnectionTap(SshConnection connection) async {
    final terminalProvider = Provider.of<TerminalProvider>(
      context,
      listen: false,
    );

    // 检查是否已存在会话
    final existingSession = terminalProvider.sessions
        .where((s) => s.id == connection.id)
        .firstOrNull;

    if (existingSession != null) {
      // 切换到已存在的会话
      terminalProvider.switchToSession(connection.id);
    } else {
      // 创建新会话
      try {
        await terminalProvider.createSession(connection);
        final sshService = terminalProvider.getSshService(connection.id);

        if (sshService != null) {
          try {
            await sshService.connect(connection);
          } catch (e) {
            // 连接失败，关闭会话
            terminalProvider.closeSession(connection.id);
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('连接失败: $e')));
            }
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('创建会话失败: $e')));
        }
      }
    }
  }

  void _showConnectionListForEditing() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('管理连接'),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        const ConnectionFormScreen(connection: null),
                  ),
                );
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('新建连接'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          height: 300,
          child: ConnectionList(
            onConnectionTap: (connection) async {
              Navigator.of(context).pop();
              await _handleConnectionTap(connection);
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
