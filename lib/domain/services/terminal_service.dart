import 'dart:async';
import 'package:kterm/kterm.dart';
import 'terminal_input_service.dart';
import 'local_terminal_service.dart';
import '../../data/models/terminal_config.dart';

/// 终端会话
class TerminalSession {
  final String id;
  final String name;
  final TerminalInputService inputService;
  final Terminal terminal;
  final TerminalController controller;
  StreamSubscription<String>? _outputSubscription;
  StreamSubscription<bool>? _stateSubscription;

  // 通知流控制器
  final _notificationController = StreamController<({String title, String body})>.broadcast();
  /// 通知流，用于监听终端发出的桌面通知
  Stream<({String title, String body})> get notificationStream => _notificationController.stream;

  TerminalSession({
    required this.id,
    required this.name,
    required this.inputService,
    TerminalConfig? terminalConfig,
  }) : terminal = Terminal(maxLines: 10000),
       controller = TerminalController() {
    // 禁用 Kitty 键盘模式，使用传统终端序列
    // 这样可以确保与所有 SSH 服务器兼容
    terminal.setKittyMode(false);

    // 监听终端通知（Kitty 协议）
    terminal.onNotification = (title, body) {
      _notificationController.add((title: title, body: body));
    };
  }

  /// 获取 GraphicsManager 实例（由 kterm 自动创建）
  /// 注意: graphicsManager 是由 kterm 内部管理的
  dynamic get graphicsManager => terminal.graphicsManager;

  /// 发送原始字符到终端（用于发送 OSC 序列）
  void writeRaw(String data) {
    terminal.write(data);
  }

  /// 初始化终端会话
  Future<void> initialize() async {
    // 监听输出
    _outputSubscription = inputService.outputStream.listen(
      (output) {
        terminal.write(output);
      },
      onError: (error) {
        // 输出流错误
      },
      onDone: () {
        // 输出流关闭
      },
    );

    // 监听连接状态
    _stateSubscription = inputService.stateStream.listen(
      (isConnected) {
        // 连接状态变化（已移除状态消息显示）
      },
      onError: (error) {
        // 状态流错误
      },
      onDone: () {
        // 状态流关闭
      },
    );

    // 监听终端输入
    terminal.onOutput = (data) {
      // 跳过空数据
      if (data.isEmpty) return;
      // 发送输入到 SSH/本地终端
      try {
        inputService.sendInput(data);
      } catch (e) {
        terminal.write('\r\n[输入发送失败: $e]\r\n');
      }
    };

    // 监听终端尺寸变化（仅对 LocalTerminalService 有效）
    terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      if (inputService is LocalTerminalService) {
        (inputService as LocalTerminalService).resize(width, height);
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
    _notificationController.close();
    inputService.dispose();
    controller.dispose();
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
    TerminalConfig? terminalConfig,
  }) {
    final session = TerminalSession(
      id: id,
      name: name,
      inputService: inputService,
      terminalConfig: terminalConfig,
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
