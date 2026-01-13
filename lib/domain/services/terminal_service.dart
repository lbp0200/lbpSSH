import 'dart:async';
import 'package:xterm/xterm.dart';
import 'terminal_input_service.dart';
import 'local_terminal_service.dart';

/// 终端会话
class TerminalSession {
  final String id;
  final String name;
  final TerminalInputService inputService;
  final Terminal terminal;
  StreamSubscription<String>? _outputSubscription;
  StreamSubscription<bool>? _stateSubscription;

  TerminalSession({
    required this.id,
    required this.name,
    required this.inputService,
  }) : terminal = Terminal(
          maxLines: 10000,
        );

  /// 初始化终端会话
  Future<void> initialize() async {
    // 如果输入服务是 LocalTerminalService，设置终端引用
    if (inputService is LocalTerminalService) {
      (inputService as LocalTerminalService).setTerminal(terminal);
    }

    // 监听输出
    _outputSubscription = inputService.outputStream.listen((output) {
      terminal.write(output);
    }, onError: (error) {
      // 输出流错误
    }, onDone: () {
      // 输出流关闭
    });

    // 监听连接状态
    _stateSubscription = inputService.stateStream.listen((isConnected) {
      if (isConnected) {
        terminal.write('\r\n[已连接]\r\n');
      } else {
        terminal.write('\r\n[已断开]\r\n');
      }
    }, onError: (error) {
      // 状态流错误
    }, onDone: () {
      // 状态流关闭
    });

    // 监听终端输入
    terminal.onOutput = (data) {
      // 当用户输入时，发送到输入服务
      inputService.sendInput(data);
    };

    // 监听终端尺寸变化（仅对 LocalTerminalService 有效）
    terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      if (inputService is LocalTerminalService) {
        (inputService as LocalTerminalService).resize(height, width);
      }
    };
  }

  /// 执行命令
  Future<void> executeCommand(String command) async {
    terminal.write('$command\r\n');
    try {
      await inputService.executeCommand(command);
    } catch (e) {
      terminal.write('错误: $e\r\n');
    }
  }

  /// 清理资源
  void dispose() {
    _outputSubscription?.cancel();
    _stateSubscription?.cancel();
    inputService.dispose();
  }
}

/// 终端服务管理器
class TerminalService {
  final Map<String, TerminalSession> _sessions = {};

  /// 创建新的终端会话
  TerminalSession createSession({
    required String id,
    required String name,
    required TerminalInputService inputService,
  }) {
    final session = TerminalSession(
      id: id,
      name: name,
      inputService: inputService,
    );
    _sessions[id] = session;
    session.initialize();
    return session;
  }

  /// 获取会话
  TerminalSession? getSession(String id) {
    return _sessions[id];
  }

  /// 关闭会话
  void closeSession(String id) {
    final session = _sessions[id];
    session?.dispose();
    _sessions.remove(id);
  }

  /// 获取所有会话
  List<TerminalSession> getAllSessions() {
    return _sessions.values.toList();
  }

  /// 清理所有会话
  void dispose() {
    for (final session in _sessions.values) {
      session.dispose();
    }
    _sessions.clear();
  }
}
