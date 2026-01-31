import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';
import '../../domain/services/terminal_service.dart';
import '../providers/terminal_provider.dart';
import '../providers/app_config_provider.dart';

/// 终端视图组件
class TerminalViewWidget extends StatefulWidget {
  final String sessionId;

  const TerminalViewWidget({super.key, required this.sessionId});

  @override
  State<TerminalViewWidget> createState() => _TerminalViewWidgetState();
}

class _TerminalViewWidgetState extends State<TerminalViewWidget> {
  TerminalController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = TerminalController();
  }

  @override
  void dispose() {
    _controller?.dispose();
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
                controller: _controller,
                autofocus: true,
                backgroundOpacity: 1.0,
                textStyle: TerminalStyle(
                  fontSize: config.fontSize,
                  fontFamily: config.fontFamily,
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

  @override
  Widget build(BuildContext context) {
    return Consumer<TerminalProvider>(
      builder: (context, provider, child) {
        final sessions = provider.sessions;
        final activeSessionId = provider.activeSessionId;

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
                      await provider.createLocalTerminal();
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
                          onTap: () => provider.switchToSession(session.id),
                          onClose: () => provider.closeSession(session.id),
                        );
                      },
                    ),
                  ),
                  // 新建终端按钮
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        try {
                          await provider.createLocalTerminal();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('创建终端失败: $e')),
                            );
                          }
                        }
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
                ],
              ),
            ),
            // 终端内容
            Expanded(
              child: activeSessionId != null
                  ? TerminalViewWidget(sessionId: activeSessionId)
                  : Center(
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
                            '没有活动的终端会话',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                ),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () async {
                              try {
                                await provider.createLocalTerminal();
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('创建终端失败: $e')),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('创建本地终端'),
                          ),
                        ],
                      ),
                    ),
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
