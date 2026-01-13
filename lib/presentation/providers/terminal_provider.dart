import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../domain/services/terminal_service.dart';
import '../../domain/services/ssh_service.dart';
import '../../domain/services/local_terminal_service.dart';
import '../../domain/services/terminal_input_service.dart';
import '../../data/models/ssh_connection.dart';

/// 终端会话状态管理
class TerminalProvider extends ChangeNotifier {
  final TerminalService _terminalService;
  final Map<String, TerminalInputService> _services = {};
  String? _activeSessionId;
  static const String _localTerminalId = 'local_terminal';

  TerminalProvider(this._terminalService);

  List<TerminalSession> get sessions => _terminalService.getAllSessions();
  String? get activeSessionId => _activeSessionId;
  TerminalSession? get activeSession =>
      _activeSessionId != null
          ? _terminalService.getSession(_activeSessionId!)
          : null;

  /// 初始化（创建默认本地终端）
  Future<void> initialize() async {
    // 如果还没有本地终端，则创建
    if (!_services.containsKey(_localTerminalId)) {
      try {
        await createLocalTerminal();
      } catch (e) {
        // 如果创建本地终端失败（例如 flutter_pty 未正确构建），
        // 则静默失败，不阻止应用启动
        debugPrint('创建本地终端失败: $e');
        // 可以选择不创建本地终端，或者显示错误提示
      }
    }
  }

  /// 创建本地终端会话
  Future<TerminalSession> createLocalTerminal() async {
    debugPrint('[TerminalProvider] 创建本地终端会话');
    
    final localService = LocalTerminalService();
    _services[_localTerminalId] = localService;

    // 先创建会话（这会调用 initialize，设置终端引用）
    debugPrint('[TerminalProvider] 创建 TerminalSession');
    final session = _terminalService.createSession(
      id: _localTerminalId,
      name: '本地终端',
      inputService: localService,
    );

    // 然后启动 PTY（此时终端引用已设置）
    debugPrint('[TerminalProvider] 启动 PTY');
    try {
      await localService.start();
      debugPrint('[TerminalProvider] PTY 启动成功');
    } catch (e, stackTrace) {
      debugPrint('[TerminalProvider] PTY 启动失败: $e');
      debugPrint('[TerminalProvider] 堆栈跟踪: $stackTrace');
      rethrow;
    }

    _activeSessionId = _localTerminalId;
    notifyListeners();
    debugPrint('[TerminalProvider] 本地终端会话创建完成');

    return session;
  }

  /// 创建新的 SSH 终端会话
  Future<TerminalSession> createSession(SshConnection connection) async {
    final sshService = SshService();
    _services[connection.id] = sshService;

    final session = _terminalService.createSession(
      id: connection.id,
      name: connection.name,
      inputService: sshService,
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
    // 不允许关闭本地终端
    if (sessionId == _localTerminalId) {
      return;
    }

    _terminalService.closeSession(sessionId);
    _services[sessionId]?.dispose();
    _services.remove(sessionId);

    if (_activeSessionId == sessionId) {
      final remainingSessions = sessions;
      _activeSessionId =
          remainingSessions.isNotEmpty ? remainingSessions.first.id : null;
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
