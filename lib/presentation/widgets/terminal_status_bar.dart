import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/services/terminal_service.dart';
import '../../domain/services/ssh_service.dart';

/// 终端状态栏组件
/// 显示连接状态、延迟、连接时长和服务器信息
class TerminalStatusBar extends StatefulWidget {
  final TerminalSession session;
  final VoidCallback? onReconnect;

  const TerminalStatusBar({
    super.key,
    required this.session,
    this.onReconnect,
  });

  @override
  State<TerminalStatusBar> createState() => _TerminalStatusBarState();
}

class _TerminalStatusBarState extends State<TerminalStatusBar> {
  Timer? _durationTimer;
  Duration _connectionDuration = Duration.zero;
  String _latency = '--';

  @override
  void initState() {
    super.initState();
    _startDurationTimer();
    // 初始化时同步当前状态
    _syncInitialState();
  }

  void _syncInitialState() {
    if (widget.session.connectionStartTime != null) {
      _connectionDuration = DateTime.now()
          .difference(widget.session.connectionStartTime!);
    }
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    super.dispose();
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (widget.session.connectionStartTime != null && mounted) {
        setState(() {
          _connectionDuration = DateTime.now()
              .difference(widget.session.connectionStartTime!);
        });
      }
    });
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.session.connectionState ==
        SshConnectionState.connected;
    final isConnecting = widget.session.connectionState ==
        SshConnectionState.connecting;
    final isDisconnected = widget.session.connectionState ==
        SshConnectionState.disconnected ||
        widget.session.connectionState == SshConnectionState.error;

    // 颜色方案
    final backgroundColor = isDisconnected
        ? Colors.red.shade900
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final textColor = isDisconnected
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    final indicatorColor = isConnecting
        ? Colors.amber
        : isConnected
            ? Colors.green
            : isDisconnected
                ? Colors.red
                : Colors.blue; // 本地终端

    final statusText = widget.session.isLocal
        ? 'Local'
        : isConnecting
            ? 'Connecting...'
            : isConnected
                ? 'Connected'
                : 'Disconnected';

    return Container(
      height: 24,
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          // 状态指示器
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: indicatorColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
            ),
          ),
          // 延迟（仅 SSH 连接显示）
          if (!widget.session.isLocal && isConnected) ...[
            const SizedBox(width: 8),
            Text(
              '• $_latency',
              style: TextStyle(
                color: textColor.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
          // 连接时长
          if (isConnected || isDisconnected) ...[
            const SizedBox(width: 8),
            Text(
              '• ${_formatDuration(_connectionDuration)}',
              style: TextStyle(
                color: textColor.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
          // 服务器信息
          if (widget.session.serverInfo != null) ...[
            const SizedBox(width: 8),
            Text(
              '• ${widget.session.serverInfo}',
              style: TextStyle(
                color: textColor.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
          const Spacer(),
          // 重连按钮（仅 SSH 断开时显示）
          if (isDisconnected && !widget.session.isLocal && widget.onReconnect != null)
            TextButton.icon(
              onPressed: widget.onReconnect,
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('Reconnect', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
              ),
            ),
        ],
      ),
    );
  }
}
