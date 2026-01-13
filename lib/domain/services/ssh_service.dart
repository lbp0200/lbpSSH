import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
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
      _client = SSHClient(socket, username: connection.username);

      // 根据认证方式连接
      // TODO: 根据 dartssh2 2.13.0 的实际 API 实现认证
      // 需要查看 dartssh2 的文档来确定正确的认证方法
      // 可能的方法名：
      // - authenticatePassword()
      // - authenticatePublicKey()
      // - authenticate() 配合不同的参数
      // 根据认证方式连接
      // TODO: 根据 dartssh2 2.13.0 的实际 API 实现认证
      // 需要查看 dartssh2 的文档来确定正确的认证方法
      switch (connection.authType) {
        case AuthType.password:
          if (connection.encryptedPassword == null) {
            throw Exception('密码未设置');
          }
          // 临时实现：抛出异常提示需要实现
          // 解密后的密码需要传递给 SSHClient 的认证方法
          EncryptionUtil.decrypt(
            connection.encryptedPassword!,
            masterPassword,
          );
          throw UnimplementedError(
            '密码认证未实现，需要根据 dartssh2 API 实现',
          );

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

      // TODO: 如果有跳板机，需要先连接到跳板机
      // 这需要先连接到跳板机，然后通过跳板机连接到目标主机
      // 注意：需要在认证之前处理跳板机
      if (connection.jumpHost != null) {
        throw UnimplementedError('跳板机功能未实现');
      }

      // 创建交互式会话
      _session = await _client!.shell();
      _session!.stdout.listen((data) {
        _outputController.add(String.fromCharCodes(data));
      });
      _session!.stderr.listen((data) {
        _outputController.add(String.fromCharCodes(data));
      });

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
      await for (final data in session.stdout) {
        final text = String.fromCharCodes(data);
        output.add(text);
        _outputController.add(text);
      }
      return output.join();
    } catch (e) {
      _outputController.add('命令执行错误: $e\n');
      rethrow;
    }
  }

  /// 发送输入到交互式会话
  @override
  void sendInput(String input) {
    if (_session != null && _state == SshConnectionState.connected) {
      _session!.stdin.add(Uint8List.fromList(input.codeUnits));
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    try {
      _session?.close();
      _session = null;
      _client?.close();
      _client = null;
      _updateState(SshConnectionState.disconnected);
    } catch (e) {
      _outputController.add('断开连接错误: $e\n');
    }
  }

  /// 更新状态
  void _updateState(SshConnectionState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  /// 清理资源
  @override
  void dispose() {
    disconnect();
    _stateController.close();
    _outputController.close();
  }
}
