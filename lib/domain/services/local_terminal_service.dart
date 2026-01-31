import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:xterm/xterm.dart';
import 'terminal_input_service.dart';

/// 本地终端服务 - 简化版实现
class LocalTerminalService implements TerminalInputService {
  Process? _process;
  Terminal? _terminal;
  final _outputController = StreamController<String>.broadcast();
  final _stateController = StreamController<bool>.broadcast();
  bool _isShuttingDown = false;

  /// 输出流
  @override
  Stream<String> get outputStream => _outputController.stream;

  /// 状态流（true = 已连接，false = 已断开）
  @override
  Stream<bool> get stateStream => _stateController.stream;

  /// 是否已连接
  bool get isConnected => _process != null && !_isShuttingDown;

  /// 设置终端（用于获取终端尺寸）
  void setTerminal(Terminal terminal) {
    _terminal = terminal;
  }

  /// 启动本地终端
  Future<void> start() async {
    if (_process != null || _isShuttingDown) {
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

      // 使用 Dart 的 Process API 启动进程
      final workingDirectory =
          Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          Directory.current.path;

      _process = await Process.start(
        shell,
        arguments,
        workingDirectory: workingDirectory,
        environment: Map.from(Platform.environment),
        includeParentEnvironment: true,
      );

      // 设置终端尺寸（通过环境变量或直接向进程发送信号）
      try {
        // 发送窗口大小调整命令到进程
        // 这通常通过向进程的stdout发送特定的控制序列来实现
        final resizeCommand = Platform.isWindows
            ? ''
            : '\x1b[8;$finalRows;${finalColumns}t';

        if (resizeCommand.isNotEmpty) {
          _process!.stdin.write(resizeCommand);
          await _process!.stdin.flush();
        }
      } catch (e) {
        // 终端尺寸设置失败，继续运行
      }

      // 监听进程输出
      _process!.stdout
          .transform(const Utf8Decoder())
          .listen(
            (data) {
              if (!_isShuttingDown) {
                _outputController.add(data);
              }
            },
            onError: (error) {
              if (!_isShuttingDown) {
                _outputController.add('\r\n[输出流错误: $error]\r\n');
              }
            },
            onDone: () {
              if (!_isShuttingDown) {
                _process = null;
                _stateController.add(false);
                _outputController.add('\r\n[进程已正常退出]\r\n');
              }
            },
          );

      // 监听stderr
      _process!.stderr.transform(const Utf8Decoder()).listen((data) {
        if (!_isShuttingDown) {
          _outputController.add('\r\n[错误输出: $data]');
        }
      });

      // 监听进程退出
      _process!.exitCode
          .then((code) {
            if (!_isShuttingDown) {
              _process = null;
              _stateController.add(false);
              _outputController.add('\r\n[进程已退出，退出码: $code]\r\n');
            }
          })
          .catchError((error) {
            if (!_isShuttingDown) {
              _process = null;
              _stateController.add(false);
              _outputController.add('\r\n[进程异常退出: $error]\r\n');
            }
          });

      _stateController.add(true);
      _outputController.add('本地终端已启动 (Shell: $shell)\r\n');
    } catch (e) {
      _stateController.add(false);
      _outputController.add('启动本地终端失败: $e\r\n');
      rethrow;
    }
  }

  /// 发送输入
  @override
  void sendInput(String input) {
    if (_process != null && !_isShuttingDown) {
      try {
        _process!.stdin.write(input);
        _process!.stdin.flush();
      } catch (e) {
        _outputController.add('\r\n[发送输入失败: $e]\r\n');
      }
    }
  }

  /// 执行命令（非交互式）
  @override
  Future<String> executeCommand(String command) async {
    if (_process == null || _isShuttingDown) {
      throw Exception('本地终端未启动');
    }

    // 发送命令并等待结果
    final buffer = StringBuffer();
    final subscription = _outputController.stream.listen((data) {
      buffer.write(data);
    });

    try {
      sendInput(command);
      sendInput('\n');

      // 等待命令执行完成（简化实现）
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
    if (_process != null && !_isShuttingDown) {
      try {
        // 发送终端尺寸调整命令
        final resizeCommand = Platform.isWindows
            ? ''
            : '\x1b[8;$rows;${columns}t';

        if (resizeCommand.isNotEmpty) {
          sendInput(resizeCommand);
        }
      } catch (e) {
        // 调整终端尺寸失败
      }
    }
  }

  /// 停止终端
  Future<void> stop() async {
    _isShuttingDown = true;

    if (_process != null) {
      try {
        // 优雅地发送退出命令
        sendInput('exit\n');
        await Future.delayed(const Duration(milliseconds: 500));

        // 如果进程仍在运行，强制终止
        if (_process != null) {
          _process!.kill();
          await _process!.exitCode;
        }
      } catch (e) {
        // 停止进程时出错，忽略
      } finally {
        _process = null;
        _stateController.add(false);
        _outputController.add('\r\n[本地终端已停止]\r\n');
      }
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
