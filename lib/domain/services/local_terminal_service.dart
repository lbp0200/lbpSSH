import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_pty/flutter_pty.dart';
import 'terminal_input_service.dart';

/// 本地终端服务 - 使用 PTY 实现
class LocalTerminalService implements TerminalInputService {
  Pty? _pty;
  final _outputController = StreamController<String>.broadcast();
  final _stateController = StreamController<bool>.broadcast();
  bool _isShuttingDown = false;
  String _shellPath = '';

  /// 输出流
  @override
  Stream<String> get outputStream => _outputController.stream;

  /// 状态流（true = 已连接，false = 已断开）
  @override
  Stream<bool> get stateStream => _stateController.stream;

  /// 是否已连接
  bool get isConnected => _pty != null && !_isShuttingDown;

  /// 设置 shell 路径
  void setShellPath(String path) {
    _shellPath = path.trim();
  }

  /// 获取默认 shell 路径
  static String getDefaultShellPath() {
    if (Platform.isWindows) {
      return 'cmd.exe';
    }
    // Unix-like 系统
    return Platform.environment['SHELL'] ??
        (Platform.isMacOS ? '/bin/zsh' : '/bin/bash');
  }

  /// 启动本地终端
  Future<void> start() async {
    if (_pty != null || _isShuttingDown) {
      return;
    }

    try {
      // 根据配置选择 shell
      String shell;
      List<String> arguments;

      if (Platform.isWindows) {
        shell = _shellPath.isNotEmpty ? _shellPath : 'cmd.exe';
        arguments = [];
      } else {
        // Unix-like 系统（macOS, Linux）
        if (_shellPath.isNotEmpty) {
          shell = _shellPath;
        } else {
          // 使用系统配置的默认 shell（从环境变量 SHELL 获取）
          shell =
              Platform.environment['SHELL'] ??
              (Platform.isMacOS ? '/bin/zsh' : '/bin/bash');
        }
        arguments = ['-l']; // 登录shell
      }

      // 使用默认终端尺寸
      const finalColumns = 80;
      const finalRows = 24;

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
                // 直接输出，不做缓冲处理
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
      // 不输出启动信息，保持简洁
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
  Future<String> executeCommand(String command, {bool silent = false}) async {
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
    stop();
    _outputController.close();
    _stateController.close();
  }
}
