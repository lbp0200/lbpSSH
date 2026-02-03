import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/ssh_connection.dart';
import '../providers/connection_provider.dart';
import '../providers/terminal_provider.dart';
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
      body: Column(
        children: [
          // 顶部栏：标签页左对齐，按钮右对齐
          _buildTopBar(context),
          const Expanded(child: TerminalTabsView()),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          // 左侧空白占位（标签页区域）
          const Expanded(child: SizedBox.shrink()),
          // 右侧按钮：加号和设置
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 加号按钮 - 弹出连接列表
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    _showConnectionListPopup(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Icon(
                      Icons.add,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              // 设置按钮
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    _showSettingsMenu(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Icon(
                      Icons.settings,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ],
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

  void _showConnectionListPopup(BuildContext context) {
    final terminalProvider = Provider.of<TerminalProvider>(
      context,
      listen: false,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('选择连接'),
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
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 本地连接（最上方）
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: ListTile(
                  leading: Icon(
                    Icons.computer,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text('本地终端'),
                  subtitle: const Text('打开本地终端'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    try {
                      await terminalProvider.createLocalTerminal();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('创建终端失败: $e')));
                      }
                    }
                  },
                ),
              ),
              const Divider(),
              // 已保存的连接列表
              Expanded(
                child: Consumer<ConnectionProvider>(
                  builder: (context, provider, child) {
                    if (provider.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final connections = provider.connections;

                    if (connections.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.cloud_off,
                              size: 48,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '暂无连接配置',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: connections.length,
                      itemBuilder: (context, index) {
                        final connection = connections[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: ListTile(
                            leading: Icon(
                              Icons.vpn_key,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            title: Text(connection.name),
                            subtitle: Text(
                              '${connection.username}@${connection.host}:${connection.port}',
                            ),
                            onTap: () async {
                              Navigator.of(context).pop();
                              await _handleConnectionTap(connection);
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
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
}
