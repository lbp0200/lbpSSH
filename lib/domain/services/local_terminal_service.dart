import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:xterm/xterm.dart';
import 'terminal_input_service.dart';

/// 本地终端服务 - 使用 PTY 实现
class LocalTerminalService implements TerminalInputService {
  Pty? _pty;
  Terminal? _terminal;
  final _outputController = StreamController<String>.broadcast();
  final _stateController = StreamController<bool>.broadcast();
  bool _isShuttingDown = false;

  // 性能优化：输出缓冲和批处理
  final _outputBuffer = StringBuffer();
  Timer? _outputTimer;

  /// 输出流
  @override
  Stream<String> get outputStream => _outputController.stream;

  /// 状态流（true = 已连接，false = 已断开）
  @override
  Stream<bool> get stateStream => _stateController.stream;

  /// 是否已连接
  bool get isConnected => _pty != null && !_isShuttingDown;

  /// 设置终端（用于获取终端尺寸）
  void setTerminal(Terminal terminal) {
    _terminal = terminal;
  }

  /// 性能优化：批量输出处理
  void _scheduleOutputFlush() {
    _outputTimer?.cancel();
    _outputTimer = Timer(const Duration(milliseconds: 10), () {
      final output = _outputBuffer.toString();
      _outputBuffer.clear();
      if (output.isNotEmpty) {
        _outputController.add(output);
      }
    });
  }

  /// 启动本地终端
  Future<void> start() async {
    if (_pty != null || _isShuttingDown) {
      return;
    }

    try {
      // 根据平台选择 shell
      String shell;
      List<String> arguments;

      if (Platform.isWindows) {
        shell = 'cmd.exe';
        arguments = [];
      } else {
        // Unix-like 系统（macOS, Linux）
        // 使用系统配置的默认 shell（从环境变量 SHELL 获取）
        // 如果没有设置，回退到 /bin/zsh（macOS 默认）或 /bin/bash
        shell =
            Platform.environment['SHELL'] ??
            (Platform.isMacOS ? '/bin/zsh' : '/bin/bash');
        arguments = ['-l']; // 登录shell
      }

      // 获取终端尺寸（确保有效的最小值）
      // 如果终端还未初始化，使用默认值
      final columns = _terminal?.viewWidth ?? 80;
      final rows = _terminal?.viewHeight ?? 24;
      final finalColumns = (columns > 0 ? columns : 80).clamp(1, 1000);
      final finalRows = (rows > 0 ? rows : 24).clamp(1, 1000);

      final workingDirectory =
          Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          Directory.current.path;

      // 使用 PTY 启动进程
      final pty = Pty.start(
        shell,
        arguments: arguments,
        workingDirectory: workingDirectory,
        environment: Platform.environment,
        columns: finalColumns,
        rows: finalRows,
      );
      _pty = pty;

      // 监听 PTY 输出
      _pty!.output
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen(
            (data) {
              if (!_isShuttingDown) {
                // 性能优化：批量处理输出
                final formattedData = data
                    .replaceAll('\r\n', '\n')
                    .replaceAll('\r', '\n');
                _outputBuffer.write(formattedData);

                // 使用定时器批量发送输出，减少频繁的UI更新
                _scheduleOutputFlush();
              }
            },
            onError: (error) {
              if (!_isShuttingDown) {
                _outputController.add('\r\n[输出流错误: $error]\r\n');
              }
            },
            onDone: () {
              if (!_isShuttingDown) {
                _pty = null;
                _stateController.add(false);
                _outputController.add('\r\n[进程已正常退出]\r\n');
              }
            },
          );

      // 监听进程退出
      _pty!.exitCode
          .then((code) {
            if (!_isShuttingDown) {
              _pty = null;
              _stateController.add(false);
              _outputController.add('\r\n[进程已退出，退出码: $code]\r\n');
            }
          })
          .catchError((error) {
            if (!_isShuttingDown) {
              _pty = null;
              _stateController.add(false);
              _outputController.add('\r\n[进程异常退出: $error]\r\n');
            }
          });

      _stateController.add(true);
      _outputController.add('本地终端已启动 (Shell: $shell)\r\n');
      _outputController.add('终端尺寸: $finalColumns x $finalRows\r\n');
      _outputController.add('当前目录: $workingDirectory\r\n');
    } catch (e) {
      _stateController.add(false);
      _outputController.add('启动本地终端失败: $e\r\n');
      rethrow;
    }
  }

  /// 发送输入到 PTY
  @override
  void sendInput(String input) {
    if (_pty != null && !_isShuttingDown) {
      try {
        // 将字符串转换为 UTF-8 字节并发送到 PTY
        final bytes = const Utf8Encoder().convert(input);
        _pty!.write(bytes);
      } catch (e) {
        _outputController.add('\r\n[发送输入失败: $e]\r\n');
      }
    }
  }

  /// 执行命令（非交互式）
  @override
  Future<String> executeCommand(String command) async {
    if (_pty == null || _isShuttingDown) {
      throw Exception('本地终端未启动');
    }

    final buffer = StringBuffer();
    final subscription = _outputController.stream.listen((data) {
      buffer.write(data);
    });

    try {
      sendInput(command);
      sendInput('\n');

      await Future.delayed(const Duration(seconds: 2));

      await subscription.cancel();
      return buffer.toString();
    } catch (e) {
      await subscription.cancel();
      rethrow;
    }
  }

  /// 调整终端尺寸
  void resize(int rows, int columns) {
    if (_pty != null && !_isShuttingDown) {
      try {
        _pty!.resize(columns, rows);
      } catch (e) {
        // 调整终端尺寸失败，静默处理
      }
    }
  }

  /// 停止终端
  Future<void> stop() async {
    _isShuttingDown = true;

    if (_pty != null) {
      try {
        // 发送 Ctrl+D (EOF) 信号
        sendInput('\x04');
        await Future.delayed(const Duration(milliseconds: 500));

        if (_pty != null) {
          _pty!.kill();
          await _pty!.exitCode;
        }
      } catch (e) {
        // 停止进程时出错，忽略
      } finally {
        _pty = null;
        _stateController.add(false);
        _outputController.add('\r\n[本地终端已停止]\r\n');
      }
    }
  }

  /// 清理资源
  @override
  void dispose() {
    // 清理定时器
    _outputTimer?.cancel();

    // 清理输出缓冲
    _outputBuffer.clear();

    stop();
    _outputController.close();
    _stateController.close();
  }
}
