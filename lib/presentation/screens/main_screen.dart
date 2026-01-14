import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/ssh_connection.dart';
import '../providers/terminal_provider.dart';
import '../widgets/connection_list.dart';
import '../widgets/terminal_view.dart';

/// 主界面
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  double _splitPosition = 0.25; // 左侧面板宽度比例
  bool _isLeftPanelVisible = true;

  @override
  void initState() {
    super.initState();
    // 初始化本地终端
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final terminalProvider =
          Provider.of<TerminalProvider>(context, listen: false);
      terminalProvider.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // 左侧连接列表面板
          if (_isLeftPanelVisible)
            Container(
              width: MediaQuery.of(context).size.width * _splitPosition,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: Border(
                  right: BorderSide(
                    color: Theme.of(context).dividerColor,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // 面板标题和折叠按钮
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          '连接列表',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          iconSize: 20,
                          onPressed: () {
                            setState(() {
                              _isLeftPanelVisible = false;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  // 连接列表
                  Expanded(
                    child: ConnectionList(
                      onConnectionTap: (connection) {
                        _handleConnectionTap(connection);
                      },
                    ),
                  ),
                ],
              ),
            ),
          // 分割线（可拖动调整大小）
          if (_isLeftPanelVisible)
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    final newPosition = _splitPosition +
                        (details.delta.dx / MediaQuery.of(context).size.width);
                    _splitPosition = newPosition.clamp(0.15, 0.5);
                  });
                },
                child: Container(
                  width: 4,
                  color: Theme.of(context).dividerColor,
                ),
              ),
            ),
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
    final terminalProvider =
        Provider.of<TerminalProvider>(context, listen: false);

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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('连接失败: $e')),
              );
            }
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('创建会话失败: $e')),
          );
        }
      }
    }
  }

}
