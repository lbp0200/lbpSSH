import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/ssh_connection.dart';
import '../providers/terminal_provider.dart';
import '../widgets/compact_connection_list.dart';
import '../widgets/connection_list.dart';
import '../widgets/terminal_view.dart';
import '../screens/connection_form.dart';
import 'app_settings_screen.dart';

/// 主界面
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const double _compactPanelWidth = 80; // 紧凑型面板固定宽度
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
                children: [
                  // 面板操作按钮
                  Container(
                    height: 75,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                    ),
                    child: Column(
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
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const AppSettingsScreen(),
                              ),
                            );
                          },
                        ),
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
            onConnectionTap: (connection) {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      ConnectionFormScreen(connection: connection),
                ),
              );
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
