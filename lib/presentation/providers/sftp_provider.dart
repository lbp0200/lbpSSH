import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/ssh_connection.dart';
import '../../domain/services/kitty_file_transfer_service.dart';
import 'terminal_provider.dart';

/// SFTP 标签页数据
class SftpTab {
  final String id;
  final SshConnection connection;
  final KittyFileTransferService service;
  String currentPath;

  SftpTab({
    required this.id,
    required this.connection,
    required this.service,
    required this.currentPath,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SftpTab && id == other.id && currentPath == other.currentPath;

  @override
  int get hashCode => Object.hash(id, currentPath);
}

/// SFTP 标签页状态
class SftpState {
  final List<SftpTab> tabs;

  const SftpState({this.tabs = const []});

  SftpState copyWith({List<SftpTab>? tabs}) =>
      SftpState(tabs: tabs ?? this.tabs);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SftpState && listEquals(tabs, other.tabs);

  @override
  int get hashCode => Object.hashAll(tabs);
}

/// SFTP 通知器
class SftpNotifier extends Notifier<SftpState> {
  @override
  SftpState build() => const SftpState();

  /// 打开 SFTP 标签页
  Future<SftpTab> openTab(SshConnection connection, {String? password}) async {
    final tabId = '${connection.id}_${DateTime.now().millisecondsSinceEpoch}';

    final terminalNotifier = ref.read(terminalProvider.notifier);
    final session = terminalNotifier.getSession(connection.id);
    if (session == null) {
      throw Exception('终端会话不存在');
    }

    final initialPath = session.workingDirectory.isNotEmpty
        ? session.workingDirectory
        : '/';

    final transferService = KittyFileTransferService(
      session: session,
      initialPath: initialPath,
    );

    final tab = SftpTab(
      id: tabId,
      connection: connection,
      service: transferService,
      currentPath: initialPath,
    );

    state = state.copyWith(tabs: [...state.tabs, tab]);
    return tab;
  }

  /// 关闭标签页
  Future<void> closeTab(String tabId) async {
    // 收集该标签页的传输服务并在移除前释放：进行中的下载可能持有打开的文件句柄，
    // 若仅从 state 移除而不 dispose，这些资源会泄漏（与 TerminalProvider 关闭会话时
    // 释放服务的做法保持一致）。
    final servicesToDispose = <KittyFileTransferService>[];
    for (final tab in state.tabs) {
      if (tab.id == tabId) {
        servicesToDispose.add(tab.service);
      }
    }
    for (final service in servicesToDispose) {
      await service.dispose();
    }

    state = state.copyWith(
      tabs: state.tabs.where((t) => t.id != tabId).toList(),
    );
  }

  /// 获取标签页
  SftpTab? getTab(String tabId) {
    return state.tabs.where((t) => t.id == tabId).firstOrNull;
  }
}

final sftpProvider = NotifierProvider<SftpNotifier, SftpState>(
  SftpNotifier.new,
);
