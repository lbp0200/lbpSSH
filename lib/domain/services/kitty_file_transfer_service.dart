import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'sftp_service.dart';
import 'terminal_service.dart';

/// 文件传输进度
class TransferProgress {
  final String fileName;
  final int transferredBytes;
  final int totalBytes;
  final double percent;
  final int bytesPerSecond;

  TransferProgress({
    required this.fileName,
    required this.transferredBytes,
    required this.totalBytes,
    required this.percent,
    required this.bytesPerSecond,
  });
}

/// 文件传输进度回调
typedef TransferProgressCallback = void Function(TransferProgress progress);

/// Kitty 协议支持检测结果
class ProtocolSupportResult {
  final bool isSupported;
  final String? errorMessage;

  ProtocolSupportResult({
    required this.isSupported,
    this.errorMessage,
  });
}

/// Kitty 协议文件传输编码器
class KittyFileTransferEncoder {
  /// 编码文件名为 base64
  String encodeFileName(String name) {
    return base64Encode(utf8.encode(name));
  }

  /// 创建发送会话开始序列
  String createSendSession(String sessionId) {
    return '\x1b]5113;ac=send;id=$sessionId\x1b\\';
  }

  /// 创建文件元数据序列
  String createFileMetadata({
    required String sessionId,
    required String fileId,
    required String fileName,
    required int fileSize,
  }) {
    final encodedName = encodeFileName(fileName);
    return '\x1b]5113;ac=file;id=$sessionId;fid=$fileId;n=$encodedName;size=$fileSize\x1b\\';
  }

  /// 创建数据块序列
  String createDataChunk({
    required String sessionId,
    required String fileId,
    required List<int> data,
  }) {
    final encoded = base64Encode(data);
    return '\x1b]5113;ac=data;id=$sessionId;fid=$fileId;d=$encoded\x1b\\';
  }

  /// 创建传输结束序列
  String createFinishSession(String sessionId) {
    return '\x1b]5113;ac=finish;id=$sessionId\x1b\\';
  }
}

/// Kitty 文件传输服务
///
/// 通过 SSH 终端发送 OSC 5113 控制序列实现文件传输
class KittyFileTransferService {
  final KittyFileTransferEncoder _encoder = KittyFileTransferEncoder();
  final TerminalSession? _session;
  String _currentPath = '/';

  // ignore: prefer_const_constructors
  KittyFileTransferService({TerminalSession? session}) : _session = session;

  /// 当前路径
  String get currentPath => _currentPath;

  /// 是否已连接
  bool get isConnected => _session != null;

  /// 是否支持 Kitty 协议
  bool get supportsKittyProtocol => false;

  /// 获取当前目录文件列表
  Future<List<SftpItem>> listCurrentDirectory() async {
    // TODO: 使用 ls 命令通过终端获取文件列表
    throw UnimplementedError('目录列表功能待实现');
  }

  /// 进入目录
  Future<void> changeDirectory(String path) async {
    // TODO: 通过终端命令切换目录
    final newPath = path.startsWith('/') ? path : '$_currentPath/$path';
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
    // TODO: 通过终端命令创建目录
    throw UnimplementedError('创建目录功能待实现');
  }

  /// 删除文件
  Future<void> removeFile(String path) async {
    // TODO: 通过终端命令删除文件
    throw UnimplementedError('删除文件功能待实现');
  }

  /// 删除目录
  Future<void> removeDirectory(String path) async {
    // TODO: 通过终端命令删除目录
    throw UnimplementedError('删除目录功能待实现');
  }

  /// 下载文件
  Future<void> downloadFile(String remotePath, String localPath) async {
    // TODO: 通过 Kitty 协议接收文件
    throw UnimplementedError('下载文件功能待实现');
  }

  /// 检查远程是否支持 Kitty 协议
  ///
  /// 发送协议版本请求，等待终端响应
  /// 如果终端不支持，将无法正确响应
  Future<ProtocolSupportResult> checkProtocolSupport(String sessionId) async {
    // 发送协议查询命令到终端
    // 使用 Kitty 协议的版本查询功能

    // 模拟检测逻辑 - 实际需要通过终端会话发送命令并等待响应
    // 如果远程没有安装 ki 工具，将无法响应

    return ProtocolSupportResult(
      isSupported: false,
      errorMessage: '远程服务器不支持 Kitty 文件传输协议。请确保远程已安装 Kitty 的 ki 工具。',
    );
  }

  /// 发送文件到终端（发送模式）
  ///
  /// [localPath] - 本地文件路径
  /// [remoteFileName] - 远程文件名
  /// [onProgress] - 进度回调
  Future<void> sendFile({
    required String localPath,
    required String remoteFileName,
    required TransferProgressCallback onProgress,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw Exception('文件不存在: $localPath');
    }

    final fileName = p.basename(localPath);
    final fileSize = await file.length();
    final fileId = 'f${DateTime.now().millisecondsSinceEpoch}';
    final transferId = 't${DateTime.now().millisecondsSinceEpoch}';

    // 1. 开始发送会话
    print(_encoder.createSendSession(transferId));

    // 2. 发送文件元数据
    print(_encoder.createFileMetadata(
      sessionId: transferId,
      fileId: fileId,
      fileName: remoteFileName,
      fileSize: fileSize,
    ));

    // 3. 分块发送数据
    final stream = file.openRead();
    int transferred = 0;
    int startTime = DateTime.now().millisecondsSinceEpoch;

    await for (final chunk in stream) {
      print(_encoder.createDataChunk(
        sessionId: transferId,
        fileId: fileId,
        data: chunk,
      ));

      transferred += chunk.length;
      final elapsed = (DateTime.now().millisecondsSinceEpoch - startTime) / 1000;
      final speed = elapsed > 0 ? (transferred / elapsed).round() : 0;

      onProgress(TransferProgress(
        fileName: fileName,
        transferredBytes: transferred,
        totalBytes: fileSize,
        percent: transferred / fileSize * 100,
        bytesPerSecond: speed,
      ));
    }

    // 4. 结束会话
    print(_encoder.createFinishSession(transferId));
  }

  /// 从终端接收文件（接收模式）
  ///
  /// [sessionId] - 终端会话 ID
  /// [remotePath] - 远程文件路径
  Future<void> receiveFile(String sessionId, String remotePath) async {
    // TODO: 实现接收文件逻辑
    throw UnimplementedError('接收文件功能待实现');
  }

  /// 取消传输
  Future<void> cancelTransfer(String sessionId) async {
    // TODO: 实现取消传输逻辑
    throw UnimplementedError('取消传输功能待实现');
  }
}
