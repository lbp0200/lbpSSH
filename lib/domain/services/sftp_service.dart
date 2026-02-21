import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import 'package:lbp_ssh/data/models/ssh_connection.dart';

/// SFTP 文件项
class SftpItem {
  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final DateTime? modified;

  SftpItem({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size = 0,
    this.modified,
  });
}

/// SFTP 服务
class SftpService {
  SftpClient? _sftp;
  String _currentPath = '/';

  String get currentPath => _currentPath;
  bool get isConnected => _sftp != null;

  /// 连接 SFTP
  Future<void> connect(SshConnection connection, {String? password}) async {
    final socket = await SSHSocket.connect(
      connection.host,
      connection.port,
    );

    // 根据认证方式准备认证信息
    List<SSHKeyPair>? identities;
    String? keyPassword;

    switch (connection.authType) {
      case AuthType.password:
        // 密码在 onPasswordRequest 中处理
        break;

      case AuthType.key:
        if (connection.privateKeyContent != null &&
            connection.privateKeyContent!.isNotEmpty) {
          identities = SSHKeyPair.fromPem(connection.privateKeyContent!);
        }
        break;

      case AuthType.keyWithPassword:
        if (connection.privateKeyContent != null &&
            connection.privateKeyContent!.isNotEmpty) {
          keyPassword = connection.keyPassphrase ?? password;
          identities = SSHKeyPair.fromPem(
            connection.privateKeyContent!,
            keyPassword,
          );
        }
        break;

      case AuthType.sshConfig:
        // SSH Config 认证 - 使用本地配置的私钥
        if (connection.privateKeyContent != null &&
            connection.privateKeyContent!.isNotEmpty) {
          identities = SSHKeyPair.fromPem(connection.privateKeyContent!);
        }
        break;
    }

    _sftp = await SSHClient(
      socket,
      username: connection.username,
      onPasswordRequest: connection.authType == AuthType.password
          ? () => password ?? connection.password
          : null,
      identities: identities,
    ).sftp();

    // 获取初始目录
    _currentPath = await _sftp!.absolute('.');
  }

  /// 复用已有 SSH 连接
  void attachClient(SftpClient client, String path) {
    _sftp = client;
    _currentPath = path;
  }

  /// 列出目录
  Future<List<SftpItem>> listDirectory(String path) async {
    if (_sftp == null) throw Exception('未连接到 SFTP');

    final items = await _sftp!.listdir(path);
    return items.where((item) => item.filename != '.' && item.filename != '..').map((item) {
      return SftpItem(
        name: item.filename,
        path: '$path/${item.filename}'.replaceAll('//', '/'),
        isDirectory: item.attr.isDirectory,
        size: item.attr.size ?? 0,
        modified: item.attr.modifyTime != null
            ? DateTime.fromMillisecondsSinceEpoch(item.attr.modifyTime! * 1000)
            : null,
      );
    }).toList();
  }

  /// 获取当前目录文件列表
  Future<List<SftpItem>> listCurrentDirectory() async {
    return listDirectory(_currentPath);
  }

  /// 进入目录
  Future<void> changeDirectory(String path) async {
    if (_sftp == null) throw Exception('未连接到 SFTP');

    final newPath = path.startsWith('/') ? path : '$_currentPath/$path';
    // 验证目录存在
    await _sftp!.listdir(newPath);
    _currentPath = newPath;
  }

  /// 返回上级目录
  Future<void> goUp() async {
    if (_currentPath == '/') return;
    final parts = _currentPath.split('/');
    parts.removeLast();
    _currentPath = parts.isEmpty ? '/' : parts.join('/');
  }

  /// 创建目录
  Future<void> createDirectory(String name) async {
    if (_sftp == null) throw Exception('未连接到 SFTP');
    final path = _currentPath == '/' ? '/$name' : '$_currentPath/$name';
    await _sftp!.mkdir(path);
  }

  /// 删除文件
  Future<void> removeFile(String path) async {
    if (_sftp == null) throw Exception('未连接到 SFTP');
    await _sftp!.remove(path);
  }

  /// 删除目录
  Future<void> removeDirectory(String path) async {
    if (_sftp == null) throw Exception('未连接到 SFTP');
    await _sftp!.rmdir(path);
  }

  /// 重命名
  Future<void> rename(String oldPath, String newName) async {
    if (_sftp == null) throw Exception('未连接到 SFTP');
    final parts = oldPath.split('/');
    parts.removeLast();
    final dir = parts.join('/');
    final newPath = dir.isEmpty ? '/$newName' : '$dir/$newName';
    await _sftp!.rename(oldPath, newPath);
  }

  /// 上传文件 (从本地路径)
  Future<void> uploadFile(String localPath, String remoteFileName) async {
    if (_sftp == null) throw Exception('未连接到 SFTP');
    final remotePath = _currentPath == '/' ? '/$remoteFileName' : '$_currentPath/$remoteFileName';

    final localFile = File(localPath);
    if (!await localFile.exists()) {
      throw Exception('本地文件不存在: $localPath');
    }

    final file = await _sftp!.open(
      remotePath,
      mode: SftpFileOpenMode.create | SftpFileOpenMode.write | SftpFileOpenMode.truncate,
    );

    final stream = localFile.openRead();
    await for (final chunk in stream) {
      await file.write(Stream.value(Uint8List.fromList(chunk)));
    }
    await file.close();
  }

  /// 下载文件 (到本地路径)
  Future<void> downloadFile(String remotePath, String localPath) async {
    if (_sftp == null) throw Exception('未连接到 SFTP');

    final file = await _sftp!.open(remotePath);
    final chunks = <int>[];
    await for (final chunk in file.read()) {
      chunks.addAll(chunk);
    }
    await file.close();

    final localFile = File(localPath);
    await localFile.writeAsBytes(Uint8List.fromList(chunks));
  }

  /// 断开连接
  void disconnect() {
    _sftp?.close();
    _sftp = null;
    _currentPath = '/';
  }
}
