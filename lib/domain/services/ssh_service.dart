import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import '../../data/models/ssh_connection.dart';
import '../../utils/encryption.dart';
import 'terminal_input_service.dart';

/// SSH 连接状态
enum SshConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

  /// SSH 连接服务
class SshService implements TerminalInputService {
  SSHClient? _client;
  final _stateController = StreamController<SshConnectionState>.broadcast();
  final _outputController = StreamController<String>.broadcast();
  SSHSession? _session;

  /// 输出流
  @override
  Stream<String> get outputStream => _outputController.stream;

  /// 状态流（转换为 bool: true = connected, false = disconnected）
  @override
  Stream<bool> get stateStream {
    return _stateController.stream.map((state) =>
        state == SshConnectionState.connected);
  }

  /// 获取 SSH 连接状态流（返回详细状态）
  Stream<SshConnectionState> get sshStateStream => _stateController.stream;

  /// 当前连接状态
  SshConnectionState _state = SshConnectionState.disconnected;
  SshConnectionState get state => _state;

  /// 连接到 SSH 服务器
  Future<void> connect(
    SshConnection connection,
    String masterPassword,
  ) async {
    try {
      _updateState(SshConnectionState.connecting);

      final socket = await SSHSocket.connect(connection.host, connection.port);
      
      // 根据认证方式准备认证信息
      String? password;
      switch (connection.authType) {
        case AuthType.password:
          if (connection.encryptedPassword == null) {
            throw Exception('密码未设置');
          }
          // 解密密码
          password = EncryptionUtil.decrypt(
            connection.encryptedPassword!,
            masterPassword,
          );
          break;

        case AuthType.key:
          if (connection.privateKeyPath == null) {
            throw Exception('密钥路径未设置');
          }
          final keyFile = File(connection.privateKeyPath!);
          if (!await keyFile.exists()) {
            throw Exception('密钥文件不存在: ${connection.privateKeyPath}');
          }
          // 临时实现：抛出异常提示需要实现
          throw UnimplementedError(
            '密钥认证未实现，需要根据 dartssh2 API 实现',
          );

        case AuthType.keyWithPassword:
          if (connection.privateKeyPath == null) {
            throw Exception('密钥路径未设置');
          }
          final keyFile = File(connection.privateKeyPath!);
          if (!await keyFile.exists()) {
            throw Exception('密钥文件不存在: ${connection.privateKeyPath}');
          }
          // 临时实现：抛出异常提示需要实现
          throw UnimplementedError(
            '密钥+密码认证未实现，需要根据 dartssh2 API 实现',
          );
      }
      
      // 创建 SSH 客户端
      // dartssh2 2.13.0 使用 onPasswordRequest 回调进行密码认证
      _client = SSHClient(
        socket,
        username: connection.username,
        onPasswordRequest: connection.authType == AuthType.password
            ? () => password!
            : null,
      );

      // TODO: 如果有跳板机，需要先连接到跳板机
      // 这需要先连接到跳板机，然后通过跳板机连接到目标主机
      // 注意：需要在认证之前处理跳板机
      if (connection.jumpHost != null) {
        throw UnimplementedError('跳板机功能未实现');
      }

      // 创建交互式会话
      _session = await _client!.shell();
      // 使用 UTF-8 解码器正确处理多字节字符（如中文）
      _session!.stdout
          .cast<List<int>>()
          .transform(const Utf8Decoder())
          .listen((data) {
        _outputController.add(data);
      }, onError: (error) {
        if (!_isDisposed && !_outputController.isClosed) {
          _outputController.add('\r\n[输出流错误: $error]\r\n');
        }
      }, onDone: () {
        // 输出流关闭
      }, cancelOnError: false);
      
      _session!.stderr
          .cast<List<int>>()
          .transform(const Utf8Decoder())
          .listen((data) {
        _outputController.add(data);
      }, onError: (error) {
        if (!_isDisposed && !_outputController.isClosed) {
          _outputController.add('\r\n[错误流错误: $error]\r\n');
        }
      }, onDone: () {
        // 错误流关闭
      }, cancelOnError: false);

      _updateState(SshConnectionState.connected);
    } catch (e) {
      _updateState(SshConnectionState.error);
      _outputController.add('连接错误: $e\n');
      rethrow;
    }
  }

  /// 执行命令（非交互式）
  @override
  Future<String> executeCommand(String command) async {
    if (_client == null || _state != SshConnectionState.connected) {
      throw Exception('未连接到服务器');
    }

    try {
      final session = await _client!.execute(command);
      final output = <String>[];
      await for (final data in session.stdout
          .cast<List<int>>()
          .transform(const Utf8Decoder())) {
        output.add(data);
        if (!_isDisposed && !_outputController.isClosed) {
          _outputController.add(data);
        }
      }
      return output.join();
    } catch (e) {
      if (!_isDisposed && !_outputController.isClosed) {
        _outputController.add('命令执行错误: $e\n');
      }
      rethrow;
    }
  }

  /// 发送输入到交互式会话
  @override
  void sendInput(String input) {
    if (_session != null && _state == SshConnectionState.connected) {
      // 使用 UTF-8 编码确保多字节字符（如中文）正确传输
      final bytes = const Utf8Encoder().convert(input);
      _session!.stdin.add(bytes);
    }
  }

  bool _isDisposed = false;

  /// 断开连接
  Future<void> disconnect() async {
    if (_isDisposed) return;
    
    try {
      _session?.close();
      _session = null;
      _client?.close();
      _client = null;
      if (!_isDisposed) {
        _updateState(SshConnectionState.disconnected);
      }
    } catch (e) {
      if (!_isDisposed && !_outputController.isClosed) {
        _outputController.add('断开连接错误: $e\n');
      }
    }
  }

  /// 更新状态
  void _updateState(SshConnectionState newState) {
    if (_isDisposed || _stateController.isClosed) return;
    _state = newState;
    _stateController.add(newState);
  }

  /// 清理资源
  @override
  void dispose() {
    _isDisposed = true;
    disconnect();
    if (!_stateController.isClosed) {
      _stateController.close();
    }
    if (!_outputController.isClosed) {
      _outputController.close();
    }
  }
}
