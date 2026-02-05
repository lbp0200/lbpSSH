import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';
import '../../data/models/ssh_connection.dart';
import '../../domain/services/terminal_service.dart';
import '../providers/terminal_provider.dart';
import '../providers/app_config_provider.dart';
import '../providers/connection_provider.dart';
import '../screens/app_settings_screen.dart';

/// 终端视图组件
class TerminalViewWidget extends StatefulWidget {
  final String sessionId;

  const TerminalViewWidget({super.key, required this.sessionId});

  @override
  State<TerminalViewWidget> createState() => _TerminalViewWidgetState();
}

class _TerminalViewWidgetState extends State<TerminalViewWidget> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'terminal-input');

  @override
  void initState() {
    super.initState();
    // 确保组件挂载后请求焦点
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FocusScope.of(context).requestFocus(_focusNode);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<TerminalProvider, AppConfigProvider>(
      builder: (context, terminalProvider, configProvider, child) {
        final session = terminalProvider.activeSession;

        if (session == null) {
          return const Center(child: Text('请选择一个连接'));
        }

        // 获取终端配置
        final config = configProvider.terminalConfig;

        // 解析颜色（从 #RRGGBB 格式转换为 Color）
        Color parseColor(String colorHex) {
          try {
            return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
          } catch (e) {
            return Colors.white;
          }
        }

        // 使用 xterm 4.0.0 的 TerminalView widget
        // 通过 TerminalTheme 应用颜色配置
        // 通过 TerminalStyle 应用字体大小

        return LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: TerminalView(
                session.terminal,
                key: ValueKey(
                  'terminal_${config.fontSize}_${config.fontFamily}',
                ),
                controller: session.controller,
                autofocus: true,
                textStyle: TerminalStyle(
                  fontSize: config.fontSize,
                  fontFamily: config.fontFamily.isEmpty ? 'Menlo' : config.fontFamily,
                  height: config.lineHeight,
                ),
                theme: TerminalTheme(
                  foreground: parseColor(config.foregroundColor),
                  background: parseColor(config.backgroundColor),
                  cursor: parseColor(config.cursorColor),
                  selection: parseColor(
                    config.foregroundColor,
                  ).withValues(alpha: 0.3),
                  black: parseColor('#000000'),
                  red: parseColor('#CD3131'),
                  green: parseColor('#0DBC79'),
                  yellow: parseColor('#E5E510'),
                  blue: parseColor('#2472C8'),
                  magenta: parseColor('#BC3FBC'),
                  cyan: parseColor('#11A8CD'),
                  white: parseColor('#E5E5E5'),
                  brightBlack: parseColor('#666666'),
                  brightRed: parseColor('#F14C4C'),
                  brightGreen: parseColor('#23D18B'),
                  brightYellow: parseColor('#F5F543'),
                  brightBlue: parseColor('#3B8EEA'),
                  brightMagenta: parseColor('#D670D6'),
                  brightCyan: parseColor('#29B8DB'),
                  brightWhite: parseColor('#E5E5E5'),
                  searchHitBackground: parseColor(
                    '#FFFF00',
                  ).withValues(alpha: 0.3),
                  searchHitBackgroundCurrent: parseColor(
                    '#FFFF00',
                  ).withValues(alpha: 0.5),
                  searchHitForeground: parseColor('#000000'),
                ),
              ),
            );
          },
        );
      },
    );
  }
}


/// 终端标签页视图
class TerminalTabsView extends StatelessWidget {
  const TerminalTabsView({super.key});

  Future<void> _createLocalTerminal(BuildContext context) async {
    final terminalProvider = Provider.of<TerminalProvider>(
      context,
      listen: false,
    );
    try {
      await terminalProvider.createLocalTerminal();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建终端失败: $e')),
        );
      }
    }
  }

  Future<void> _handleConnectionTap(
    BuildContext context,
    SshConnection connection,
  ) async {
    final terminalProvider = Provider.of<TerminalProvider>(
      context,
      listen: false,
    );

    final existingSession =
        terminalProvider.sessions.where((s) => s.id == connection.id).firstOrNull;

    if (existingSession != null) {
      terminalProvider.switchToSession(connection.id);
    } else {
      try {
        await terminalProvider.createSession(connection);
        final sshService = terminalProvider.getSshService(connection.id);

        if (sshService != null) {
          try {
            await sshService.connect(connection);
          } catch (e) {
            terminalProvider.closeSession(connection.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('连接失败: $e')),
              );
            }
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('创建会话失败: $e')),
          );
        }
      }
    }
  }

  List<PopupMenuItem<String>> _buildConnectionItems(
    BuildContext context,
    List<SshConnection> connections,
  ) {
    return connections.map((connection) {
      return PopupMenuItem(
        value: connection.id,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.vpn_key,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                connection.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<TerminalProvider, ConnectionProvider>(
      builder: (context, terminalProvider, connProvider, child) {
        final sessions = terminalProvider.sessions;
        final activeSessionId = terminalProvider.activeSessionId;
        final connections = connProvider.connections;

        if (sessions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.terminal,
                  size: 64,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  '点击左侧连接以打开终端',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () async {
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
                  icon: const Icon(Icons.add),
                  label: const Text('创建本地终端'),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // 标签页栏
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  bottom: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Row(
                children: [
                  // 设置按钮
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AppSettingsScreen(),
                          ),
                        );
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
                  // 标签列表
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: sessions.length,
                      itemBuilder: (context, index) {
                        final session = sessions[index];
                        final isActive = session.id == activeSessionId;

                        return _TerminalTab(
                          session: session,
                          isActive: isActive,
                          onTap: () => terminalProvider.switchToSession(session.id),
                          onClose: () => terminalProvider.closeSession(session.id),
                        );
                      },
                    ),
                  ),
                  // 下拉菜单按钮
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
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
                    itemBuilder: (context) {
                      final items = <PopupMenuEntry<String>>[
                        PopupMenuItem(
                          value: 'local_terminal',
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.computer,
                                size: 20,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              const Text('本地终端'),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                      ];
                      if (connections.isEmpty) {
                        items.add(PopupMenuItem(
                          value: 'no_connections',
                          enabled: false,
                          child: Text(
                            '暂无保存的连接',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ));
                      } else {
                        items.addAll(_buildConnectionItems(context, connections));
                      }
                      return items;
                    },
                    onSelected: (value) async {
                      if (value == 'no_connections') {
                        return;
                      }
                      if (value == 'local_terminal') {
                        await _createLocalTerminal(context);
                        return;
                      }
                      final connection = connections.firstWhere((c) => c.id == value);
                      await _handleConnectionTap(context, connection);
                    },
                  ),
                ],
              ),
            ),
            // 终端内容
            Expanded(
              child: activeSessionId != null
                  ? TerminalViewWidget(sessionId: activeSessionId)
                  : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }
}

/// 终端标签页
class _TerminalTab extends StatelessWidget {
  final TerminalSession session;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _TerminalTab({
    required this.session,
    required this.isActive,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).colorScheme.surface
                : Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
            border: Border(
              bottom: BorderSide(
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Text(
                  session.name,
                  style: TextStyle(
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    // 阻止事件冒泡，避免触发父级的 onTap
                    onClose();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.transparent,
                    ),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
