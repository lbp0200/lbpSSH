import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../domain/services/terminal_service.dart';
import '../../domain/services/ssh_service.dart';
import '../../domain/services/local_terminal_service.dart';
import '../../domain/services/terminal_input_service.dart';
import '../../domain/services/app_config_service.dart';
import '../../data/models/ssh_connection.dart';
import 'package:uuid/uuid.dart';

/// 终端会话状态管理
class TerminalProvider extends ChangeNotifier {
  final TerminalService _terminalService;
  final AppConfigService _appConfigService;
  final Map<String, TerminalInputService> _services = {};
  String? _activeSessionId;
  final _uuid = const Uuid();

  TerminalProvider(this._terminalService, this._appConfigService);

  List<TerminalSession> get sessions => _terminalService.getAllSessions();
  String? get activeSessionId => _activeSessionId;
  TerminalSession? get activeSession => _activeSessionId != null
      ? _terminalService.getSession(_activeSessionId!)
      : null;

  /// 初始化（创建默认本地终端）
  Future<void> initialize() async {
    // 启动时创建一个本地终端
    try {
      await createLocalTerminal();
    } catch (e) {
      // 如果创建本地终端失败（例如 Process API 问题），则静默失败
    }
  }

  /// 创建本地终端会话
  Future<TerminalSession> createLocalTerminal() async {
    // 生成唯一的会话 id
    final sessionId = _uuid.v4();

    final localService = LocalTerminalService();

    // 获取终端配置（用于设置字体和 shell）
    final terminalConfig = _appConfigService.terminal;

    // 设置 shell 路径
    if (terminalConfig.shellPath.isNotEmpty) {
      localService.setShellPath(terminalConfig.shellPath);
    }

    _services[sessionId] = localService;

    // 先创建会话（这会调用 initialize，设置终端引用）
    final session = _terminalService.createSession(
      id: sessionId,
      name: '本地终端',
      inputService: localService,
      terminalConfig: terminalConfig,
    );

    // 然后启动 PTY（此时终端引用已设置）
    try {
      await localService.start();
    } catch (e) {
      rethrow;
    }

    _activeSessionId = sessionId;
    notifyListeners();

    return session;
  }

  /// 创建新的 SSH 终端会话
  Future<TerminalSession> createSession(SshConnection connection) async {
    final sshService = SshService();
    _services[connection.id] = sshService;

    // 获取终端配置（用于设置字体）
    final terminalConfig = _appConfigService.terminal;

    final session = _terminalService.createSession(
      id: connection.id,
      name: connection.name,
      inputService: sshService,
      terminalConfig: terminalConfig,
    );

    _activeSessionId = connection.id;
    notifyListeners();

    return session;
  }

  /// 切换到指定会话
  void switchToSession(String sessionId) {
    if (_terminalService.getSession(sessionId) != null) {
      _activeSessionId = sessionId;
      notifyListeners();
    }
  }

  /// 关闭会话
  void closeSession(String sessionId) {
    _terminalService.closeSession(sessionId);
    _services[sessionId]?.dispose();
    _services.remove(sessionId);

    if (_activeSessionId == sessionId) {
      final remainingSessions = sessions;
      _activeSessionId = remainingSessions.isNotEmpty
          ? remainingSessions.first.id
          : null;
    }

    notifyListeners();
  }

  /// 获取 SSH 服务
  SshService? getSshService(String connectionId) {
    final service = _services[connectionId];
    return service is SshService ? service : null;
  }

  @override
  void dispose() {
    for (final service in _services.values) {
      service.dispose();
    }
    _terminalService.dispose();
    super.dispose();
  }
}
