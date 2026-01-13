import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';
import '../../domain/services/terminal_service.dart';
import '../providers/terminal_provider.dart';

/// 终端视图组件
class TerminalViewWidget extends StatefulWidget {
  final String sessionId;

  const TerminalViewWidget({
    super.key,
    required this.sessionId,
  });

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
    return Consumer<TerminalProvider>(
      builder: (context, provider, child) {
        final session = provider.activeSession;

        if (session == null) {
          return const Center(
            child: Text('请选择一个连接'),
          );
        }

        // 使用 xterm 4.0.0 的 TerminalView widget
        return TerminalView(
          session.terminal,
          controller: _controller,
          autofocus: true,
          backgroundOpacity: 1.0,
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
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  '点击左侧连接以打开终端',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.5),
                      ),
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
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor,
                  ),
                ),
              ),
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
            // 终端内容
            Expanded(
              child: activeSessionId != null
                  ? TerminalViewWidget(sessionId: activeSessionId)
                  : const Center(child: Text('请选择一个连接')),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.surface
              : Theme.of(context).colorScheme.surface.withOpacity(0.5),
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
            Text(
              session.name,
              style: TextStyle(
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onClose,
              child: Icon(
                Icons.close,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
