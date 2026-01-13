import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:xterm/xterm.dart';
import 'terminal_input_service.dart';

/// 本地终端服务
class LocalTerminalService implements TerminalInputService {
  Pty? _pty;
  Terminal? _terminal;
  final _outputController = StreamController<String>.broadcast();
  final _stateController = StreamController<bool>.broadcast();

  /// 输出流
  @override
  Stream<String> get outputStream => _outputController.stream;

  /// 状态流（true = 已连接，false = 已断开）
  @override
  Stream<bool> get stateStream => _stateController.stream;

  /// 是否已连接
  bool get isConnected => _pty != null;

  /// 设置终端（用于获取终端尺寸）
  void setTerminal(Terminal terminal) {
    _terminal = terminal;
  }

  /// 启动本地终端
  Future<void> start() async {
    if (_pty != null) {
      return;
    }

    try {
      // 根据平台选择 shell
      String shell;
      if (Platform.isWindows) {
        shell = 'cmd.exe';
      } else {
        // Unix-like 系统（macOS, Linux）
        // 使用系统配置的默认 shell（从环境变量 SHELL 获取）
        // 如果没有设置，回退到 /bin/zsh（macOS 默认）或 /bin/bash
        shell = Platform.environment['SHELL'] ?? 
                (Platform.isMacOS ? '/bin/zsh' : '/bin/bash');
      }
      
      debugPrint('[LocalTerminalService] 选择的 Shell: $shell');

      // 获取终端尺寸（确保有效的最小值）
      // 如果终端还未初始化，使用默认值
      final columns = _terminal?.viewWidth ?? 80;
      final rows = _terminal?.viewHeight ?? 24;
      final finalColumns = (columns > 0 ? columns : 80).clamp(1, 1000);
      final finalRows = (rows > 0 ? rows : 24).clamp(1, 1000);

      // 调试信息
      debugPrint('[LocalTerminalService] 启动终端:');
      debugPrint('  Shell: $shell');
      debugPrint('  终端尺寸: ${_terminal?.viewWidth} x ${_terminal?.viewHeight}');
      debugPrint('  使用尺寸: $finalColumns x $finalRows');
      debugPrint('  环境变量 SHELL: ${Platform.environment['SHELL']}');

      // 使用 flutter_pty 创建 PTY
      // 注意：不传递 environment 参数，让 flutter_pty 使用默认环境变量处理
      // flutter_pty 会自动设置必要的环境变量（TERM, LANG, HOME, PATH 等）
      // 设置工作目录为用户主目录，确保 shell 有正确的上下文
      _pty = Pty.start(
        shell,
        columns: finalColumns,
        rows: finalRows,
        workingDirectory: Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'],
      );

      debugPrint('[LocalTerminalService] PTY 创建成功');

      // 监听输出（PTY 输出是字节流）
      // 注意：pty.output 返回的是 Stream<Uint8List>，需要转换为字符串
      _pty!.output
          .cast<List<int>>()
          .transform(const Utf8Decoder())
          .listen((data) {
        debugPrint('[LocalTerminalService] 收到输出: ${data.length} 字符');
        _outputController.add(data);
      }, onError: (error) {
        debugPrint('[LocalTerminalService] 输出流错误: $error');
        _outputController.add('\r\n[输出流错误: $error]\r\n');
      }, onDone: () {
        debugPrint('[LocalTerminalService] 输出流关闭');
      }, cancelOnError: false);

      // 监听进程退出
      _pty!.exitCode.then((code) {
        debugPrint('[LocalTerminalService] 进程退出，退出码: $code');
        _pty = null;
        _stateController.add(false);
        _outputController.add('\r\n[进程已退出，退出码: $code]\r\n');
      }).catchError((error) {
        debugPrint('[LocalTerminalService] 退出码获取错误: $error');
      });

      _stateController.add(true);
      _outputController.add('[本地终端已启动]\r\n');
      debugPrint('[LocalTerminalService] 终端启动完成');
    } catch (e, stackTrace) {
      debugPrint('[LocalTerminalService] 启动终端失败: $e');
      debugPrint('[LocalTerminalService] 堆栈跟踪: $stackTrace');
      _stateController.add(false);
      _outputController.add('启动本地终端失败: $e\r\n');
      rethrow;
    }
  }

  /// 发送输入
  @override
  void sendInput(String input) {
    if (_pty != null) {
      try {
        final bytes = const Utf8Encoder().convert(input);
        _pty!.write(bytes);
        debugPrint('[LocalTerminalService] 发送输入: ${input.length} 字符, ${bytes.length} 字节');
      } catch (e) {
        debugPrint('[LocalTerminalService] 发送输入失败: $e');
      }
    } else {
      debugPrint('[LocalTerminalService] 尝试发送输入但 PTY 为 null');
    }
  }

  /// 执行命令（非交互式）
  @override
  Future<String> executeCommand(String command) async {
    if (_pty == null) {
      throw Exception('本地终端未启动');
    }

    // 对于交互式终端，直接发送命令
    sendInput(command);
    // 注意：对于交互式终端，需要等待输出
    // 这里简化处理，实际应该等待命令执行完成
    return '';
  }

  /// 调整终端尺寸
  void resize(int rows, int columns) {
    if (_pty != null) {
      try {
        _pty!.resize(rows, columns);
        debugPrint('[LocalTerminalService] 调整终端尺寸: $rows x $columns');
      } catch (e) {
        debugPrint('[LocalTerminalService] 调整终端尺寸失败: $e');
      }
    }
  }

  /// 停止终端
  Future<void> stop() async {
    if (_pty != null) {
      _pty!.kill();
      await _pty!.exitCode;
      _pty = null;
      _stateController.add(false);
    }
  }

  /// 清理资源
  @override
  void dispose() {
    stop();
    _outputController.close();
    _stateController.close();
  }
}
