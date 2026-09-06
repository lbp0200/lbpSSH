import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/ssh_connection.dart';
import '../../domain/services/app_config_service.dart';
import '../../domain/services/local_terminal_service.dart';
import '../../domain/services/ssh_service.dart';
import '../../domain/services/terminal_input_service.dart';
import '../../domain/services/terminal_service.dart';
import 'service_providers.dart';

/// 终端会话状态
class TerminalState {
  final List<TerminalSession> sessions;
  final String? activeSessionId;

  const TerminalState({this.sessions = const [], this.activeSessionId});

  TerminalSession? get activeSession => activeSessionId != null
      ? sessions.where((s) => s.id == activeSessionId).firstOrNull
      : null;

  TerminalState copyWith({
    List<TerminalSession>? sessions,
    String? activeSessionId,
    bool clearActive = false,
  }) {
    return TerminalState(
      sessions: sessions ?? this.sessions,
      activeSessionId: clearActive
          ? null
          : (activeSessionId ?? this.activeSessionId),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TerminalState &&
          activeSessionId == other.activeSessionId &&
          listEquals(sessions, other.sessions);

  @override
  int get hashCode => Object.hash(activeSessionId, Object.hashAll(sessions));
}

/// 映射 [TerminalService.getAllSessions] 到 immutable 列表
List<TerminalSession> _snapshotSessions(TerminalService service) {
  // TerminalService.getSession 返回内部引用，直接透传
  return service.getAllSessions();
}

/// 终端会话通知器
class TerminalNotifier extends Notifier<TerminalState> {
  final _uuid = const Uuid();
  final Map<String, TerminalInputService> _services = {};
  final Map<String, SshConnection> _connectionCache = {};

  @override
  TerminalState build() {
    return const TerminalState();
  }

  TerminalService get _terminalService => ref.read(terminalServiceProvider);
  AppConfigService get _appConfigService => ref.read(appConfigServiceProvider);
  LocalTerminalService Function() get _localTerminalServiceFactory =>
      ref.read(localTerminalServiceFactoryProvider);
  SshService Function() get _sshServiceFactory =>
      ref.read(sshServiceFactoryProvider);

  /// 初始化（创建默认本地终端）
  Future<void> initialize() async {
    try {
      await createLocalTerminal();
    } catch (e) {
      // 静默失败
    }
  }

  /// 创建本地终端会话
  Future<TerminalSession> createLocalTerminal() async {
    final sessionId = _uuid.v4();
    final localService = _localTerminalServiceFactory();
    final terminalConfig = _appConfigService.terminal;

    if (terminalConfig.shellPath.isNotEmpty) {
      localService.setShellPath(terminalConfig.shellPath);
    }

    _services[sessionId] = localService;

    final initialDir =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.current.path;

    final initialFolderName = initialDir.split('/').last;
    final initialName = 'local $initialFolderName';

    final session = _terminalService.createSession(
      id: sessionId,
      name: initialName,
      inputService: localService,
      terminalConfig: terminalConfig,
      isLocal: true,
    );

    session.setWorkingDirectoryAndUpdateName(initialDir);
    localService.initWorkingDirectory(initialDir);

    try {
      await localService.start();
    } catch (e) {
      // 启动失败（如 shellPath 无效导致 spawn 抛错）：清理已注册的服务与终端会话，
      // 避免残留孤儿 TerminalSession 与泄漏的 LocalTerminalService。
      closeSession(sessionId);
      rethrow;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cols = session.terminal.viewWidth;
      final rows = session.terminal.viewHeight;
      if (cols > 0 && rows > 0) {
        localService.resize(rows, cols);
      }
    });

    localService.onDirectoryChange = (String newDir) {
      session.setWorkingDirectoryAndUpdateName(newDir);
      state = state.copyWith(sessions: _snapshotSessions(_terminalService));
    };

    localService.onActualDirectoryChange = (String actualDir) {
      session.setWorkingDirectoryAndUpdateName(actualDir);
      state = state.copyWith(sessions: _snapshotSessions(_terminalService));
    };

    state = TerminalState(
      sessions: _snapshotSessions(_terminalService),
      activeSessionId: sessionId,
    );

    return session;
  }

  /// 创建新的 SSH 终端会话
  Future<TerminalSession> createSession(SshConnection connection) async {
    final sessionId = _uuid.v4();
    final terminalConfig = _appConfigService.terminal;

    final sshService = _sshServiceFactory();
    _services[sessionId] = sshService;
    _connectionCache[sessionId] = connection;

    final name =
        '${connection.name} (${connection.username}@${connection.host})';

    final session = _terminalService.createSession(
      id: sessionId,
      name: name,
      inputService: sshService,
      terminalConfig: terminalConfig,
      serverInfo: '${connection.username}@${connection.host}',
    );

    state = TerminalState(
      sessions: _snapshotSessions(_terminalService),
      activeSessionId: sessionId,
    );

    try {
      await sshService.connect(connection);

      final s = _terminalService.getSession(sessionId);
      if (s != null) {
        try {
          final pwdResult = await sshService.executeCommand(
            'pwd',
            silent: true,
          );
          s.setWorkingDirectory(pwdResult.trim());
        } catch (e) {
          // 使用默认目录
        }
      }
    } catch (e) {
      closeSession(sessionId);
      rethrow;
    }

    // 重新读取会话列表
    state = state.copyWith(sessions: _snapshotSessions(_terminalService));

    return session;
  }

  /// 切换到指定会话
  void switchToSession(String sessionId) {
    if (_terminalService.getSession(sessionId) != null) {
      state = state.copyWith(activeSessionId: sessionId);
    }
  }

  /// 关闭会话
  void closeSession(String sessionId) {
    _terminalService.closeSession(sessionId);
    _services[sessionId]?.dispose();
    _services.remove(sessionId);
    _connectionCache.remove(sessionId);

    String? nextActive;
    if (state.activeSessionId == sessionId) {
      final sessions = _snapshotSessions(_terminalService);
      nextActive = sessions.isNotEmpty ? sessions.first.id : null;
    } else {
      nextActive = state.activeSessionId;
    }

    state = TerminalState(
      sessions: _snapshotSessions(_terminalService),
      activeSessionId: nextActive,
    );
  }

  /// 获取 SSH 服务
  SshService? getSshService(String connectionId) {
    final service = _services[connectionId];
    return service is SshService ? service : null;
  }

  /// 获取终端会话
  TerminalSession? getSession(String sessionId) {
    return _terminalService.getSession(sessionId);
  }

  /// 重连指定会话（关闭旧会话，创建新会话）
  Future<void> reconnectSession(String sessionId) async {
    final oldSession = _terminalService.getSession(sessionId);
    if (oldSession != null) {
      _services[sessionId]?.dispose();
      _services.remove(sessionId);
    }

    final existingSession = state.sessions
        .where((TerminalSession s) => s.id == sessionId)
        .firstOrNull;

    if (existingSession == null) return;

    // 优先使用缓存的真实连接（包含端口、私钥、跳板机等完整信息）
    final cached = _connectionCache[sessionId];
    if (cached != null) {
      final sshService = _sshServiceFactory();
      _services[sessionId] = sshService;
      // 旧服务已销毁，将存活的会话重新绑定到新服务（切换输出/状态流订阅），
      // 须在 connect 之前，以捕获"已连接"状态事件与连接进度输出
      existingSession.rebind(sshService);
      try {
        await sshService.connect(cached);
      } catch (e) {
        _teardownService(sessionId);
        throw Exception('重连失败: $e');
      }
      state = TerminalState(
        sessions: _snapshotSessions(_terminalService),
        activeSessionId: sessionId,
      );
      return;
    }

    // 兼容旧路径：仅当无缓存时回退到 serverInfo 解析（测试或历史会话）
    final serverInfo = existingSession.serverInfo ?? '';
    final parts = serverInfo.split('@');
    if (parts.length < 2) return;

    final username = parts[0];
    final host = parts[1];

    final sshService = _sshServiceFactory();
    _services[sessionId] = sshService;
    // 旧服务已销毁，将存活的会话重新绑定到新服务（切换输出/状态流订阅），
    // 须在 connect 之前，以捕获"已连接"状态事件与连接进度输出
    existingSession.rebind(sshService);

    try {
      await sshService.connect(
        SshConnection(
          id: '',
          name: existingSession.name,
          host: host,
          username: username,
          authType: AuthType.password,
          password: '',
        ),
      );
    } catch (e) {
      _teardownService(sessionId);
      throw Exception('重连失败: $e');
    }

    state = TerminalState(
      sessions: _snapshotSessions(_terminalService),
      activeSessionId: sessionId,
    );
  }

  /// 重连失败时销毁本次新建的 SSH 服务，但保留会话对象本身。
  /// 注意：不能调用 closeSession —— 那会移除 TerminalService 中的会话、
  /// 导致 tab 消失且无法再次"重连"重试；此处只释放连接资源（服务），
  /// 让存活的会话继续显示，等待用户重试。
  void _teardownService(String sessionId) {
    _services[sessionId]?.dispose();
    _services.remove(sessionId);
  }

  void disposeServices() {
    for (final service in _services.values) {
      service.dispose();
    }
    _connectionCache.clear();
  }
}

final terminalProvider = NotifierProvider<TerminalNotifier, TerminalState>(
  TerminalNotifier.new,
);
