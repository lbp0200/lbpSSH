import 'package:flutter/foundation.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/domain/services/kitty_file_transfer_service.dart';
import 'package:lbp_ssh/presentation/providers/terminal_provider.dart';

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
}

/// SFTP 提供者
class SftpProvider extends ChangeNotifier {
  final TerminalProvider _terminalProvider;
  final Map<String, SftpTab> _tabs = {};

  SftpProvider(this._terminalProvider);

  List<SftpTab> get tabs => _tabs.values.toList();

  /// 打开 SFTP 标签页
  Future<SftpTab> openTab(SshConnection connection, {String? password}) async {
    final tabId = '${connection.id}_${DateTime.now().millisecondsSinceEpoch}';

    // 获取终端会话
    final session = _terminalProvider.getSession(connection.id);
    if (session == null) {
      throw Exception('终端会话不存在');
    }

    // 创建 KittyFileTransferService
    final transferService = KittyFileTransferService(session: session);

    final tab = SftpTab(
      id: tabId,
      connection: connection,
      service: transferService,
      currentPath: '/',
    );

    _tabs[tabId] = tab;
    notifyListeners();
    return tab;
  }

  /// 关闭标签页
  Future<void> closeTab(String tabId) async {
    final tab = _tabs[tabId];
    if (tab != null) {
      // 不关闭共享的 SFTP 连接
      _tabs.remove(tabId);
      notifyListeners();
    }
  }

  /// 获取标签页
  SftpTab? getTab(String tabId) => _tabs[tabId];
}
