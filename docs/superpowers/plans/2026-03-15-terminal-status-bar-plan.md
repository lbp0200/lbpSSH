# Terminal Status Bar Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a status bar below each terminal tab showing connection status, latency, duration, and server info. Show disconnect notification with reconnect button.

**Architecture:** Add state tracking to TerminalSession, create TerminalStatusBar widget, integrate into TerminalTabsView Column layout.

**Tech Stack:** Flutter, Provider, kterm.dart

---

## File Structure

| File | Action | Purpose |
|------|--------|---------|
| `lib/domain/services/terminal_service.dart` | Modify | Add connection state tracking to TerminalSession |
| `lib/presentation/widgets/terminal_view.dart` | Modify | Add TerminalStatusBar widget and integrate |
| `lib/l10n/app_zh.arb` | Modify | Add disconnect/ reconnect strings |
| `lib/l10n/app_en.arb` | Modify | Add disconnect/ reconnect strings |

---

## Chunk 1: TerminalSession State Tracking

### Task 1: Add connection state fields to TerminalSession

**Files:**
- Modify: `lib/domain/services/terminal_service.dart:31-70`

- [ ] **Step 1: Add import for SshConnectionState**

```dart
// Add after existing imports in terminal_service.dart
import 'ssh_service.dart';
```

- [ ] **Step 2: Add state fields to TerminalSession class**

Find the TerminalSession class constructor around line 62 and add these fields:

```dart
class TerminalSession {
  // ... existing fields ...

  // 新增：连接状态
  SshConnectionState connectionState = SshConnectionState.disconnected;

  // 新增：连接开始时间（用于计算时长）
  DateTime? connectionStartTime;

  // 新增：是否为本地终端
  final bool isLocal;

  // 新增：服务器信息（SSH时为 user@host，本地为 null）
  final String? serverInfo;

  TerminalSession({
    // ... existing params ...
    this.isLocal = false,
    this.serverInfo,
  }) : // ... existing initialization ...
```

- [ ] **Step 3: Update state subscription to store state**

Find the `_stateSubscription` listener around line 236 and update:

```dart
_stateSubscription = inputService.stateStream.listen(
  (isConnected) {
    connectionState = isConnected
        ? SshConnectionState.connected
        : SshConnectionState.disconnected;
    if (isConnected) {
      connectionStartTime = DateTime.now();
    }
  },
);
```

- [ ] **Step 4: Commit**

```bash
git add lib/domain/services/terminal_service.dart
git commit -m "feat: add connection state tracking to TerminalSession"
```

---

## Chunk 2: Create TerminalStatusBar Widget

### Task 2: Create TerminalStatusBar widget

**Files:**
- Create: `lib/presentation/widgets/terminal_status_bar.dart`

- [ ] **Step 1: Create the widget file**

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/services/terminal_service.dart';
import '../../domain/services/ssh_service.dart';

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
```

- [ ] **Step 2: Commit**

```bash
git add lib/presentation/widgets/terminal_status_bar.dart
git commit -m "feat: add TerminalStatusBar widget"
```

---

## Chunk 3: Integrate Status Bar into UI

### Task 3: Add status bar to TerminalTabsView

**Files:**
- Modify: `lib/presentation/widgets/terminal_view.dart:449-556`

- [ ] **Step 1: Add import for TerminalStatusBar**

Add at the top of terminal_view.dart:

```dart
import 'terminal_status_bar.dart';
```

- [ ] **Step 2: Find the Column layout and add status bar**

Find the `return Column` around line 449 and update to add the status bar after the terminal:

```dart
return Column(
  children: [
    // 标签页栏 (48px)
    Container(
      height: 48,
      // ... existing code ...
    ),
    // 终端内容
    Expanded(
      child: activeSessionId != null
          ? TerminalViewWidget(sessionId: activeSessionId)
          : const SizedBox.shrink(),
    ),
    // 新增：状态栏 (24px)
    if (activeSessionId != null)
      Builder(
        builder: (context) {
          final session = sessions.firstWhere(
            (s) => s.id == activeSessionId,
            orElse: () => sessions.first,
          );
          return TerminalStatusBar(
            session: session,
            onReconnect: () {
              // TODO: 实现重连功能
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reconnecting...')),
              );
            },
          );
        },
      ),
  ],
);
```

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/widgets/terminal_view.dart
git commit -m "feat: integrate TerminalStatusBar into TerminalTabsView"
```

---

## Chunk 4: Disconnect Notification

### Task 4: Add SnackBar notification for disconnect

**Files:**
- Modify: `lib/presentation/widgets/terminal_view.dart`

- [ ] **Step 1: Update onReconnect to show SnackBar and trigger reconnect**

Find the onReconnect callback and update it:

```dart
onReconnect: () {
  // 获取 TerminalProvider 并调用重连
  final terminalProvider = Provider.of<TerminalProvider>(
    context,
    listen: false,
  );
  terminalProvider.reconnectSession(session.id);
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Reconnecting...')),
  );
},
```

- [ ] **Step 2: Add reconnect method to TerminalProvider**

Check if reconnect method exists or add it:

```bash
grep -n "reconnect" lib/presentation/providers/terminal_provider.dart
```

If not exists, add this method to TerminalProvider class:

```dart
Future<void> reconnectSession(String sessionId) async {
  final session = _services[sessionId];
  if (session != null && session.inputService is SshService) {
    // 获取原始连接配置并重新连接
    // 需要存储连接配置或通过 session 获取
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/widgets/terminal_view.dart lib/presentation/providers/terminal_provider.dart
git commit -m "feat: add disconnect SnackBar and reconnect functionality"
```

---

## Chunk 5: Localization (Optional)

### Task 5: Add localization strings

**Files:**
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`

- [ ] **Step 1: Add strings**

In `app_zh.arb`:
```json
{
  "disconnected": "已断开",
  "reconnect": "重连",
  "reconnecting": "正在重连...",
  "connectionLost": "连接已断开"
}
```

In `app_en.arb`:
```json
{
  "disconnected": "Disconnected",
  "reconnect": "Reconnect",
  "reconnecting": "Reconnecting...",
  "connectionLost": "Connection lost"
}
```

- [ ] **Step 2: Update widget to use localization**

Replace hardcoded strings with localization calls.

- [ ] **Step 3: Commit**

```bash
git add lib/l10n/
git commit -m "feat: add disconnect/reconnect localization strings"
```

---

## Verification

Run these commands to verify implementation:

```bash
# Analyze code
flutter analyze --no-fatal-infos

# Run tests
flutter test
```

---

## Plan Complete

Implementation plan saved to `docs/superpowers/plans/2026-03-15-terminal-status-bar-plan.md`. Ready to execute?
