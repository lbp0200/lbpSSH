import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'file_list_parser.dart';
import '../../presentation/screens/sftp_browser_screen.dart';
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
  Future<List<FileItem>> listCurrentDirectory() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 发送 ls 命令
    final outputBuffer = StringBuffer();

    // 监听终端输出
    final subscription = _session!.inputService.outputStream.listen((output) {
      outputBuffer.write(output);
    });

    // 执行 ls 命令
    await _session!.executeCommand('ls -la --time-style=long-iso');

    // 等待一段时间让输出完成
    await Future.delayed(const Duration(milliseconds: 500));

    // 取消订阅
    await subscription.cancel();

    // 解析输出
    final output = outputBuffer.toString();
    return FileListParser.parse(output, _currentPath);
  }

  /// 进入目录
  Future<void> changeDirectory(String path) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    final newPath = path.startsWith('/')
        ? path
        : (_currentPath == '/' ? '/$path' : '$_currentPath/$path');

    await _session!.executeCommand('cd "$newPath"');
    _currentPath = newPath;
  }

  /// 返回上级目录
  Future<void> goUp() async {
    if (_currentPath == '/') return;

    await _session!.executeCommand('cd ..');
    final parts = _currentPath.split('/');
    parts.removeLast();
    _currentPath = parts.isEmpty ? '/' : parts.join('/');
  }

  /// 创建目录
  Future<void> createDirectory(String name) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    final path = _currentPath == '/'
        ? '/$name'
        : '$_currentPath/$name';

    await _session!.executeCommand('mkdir "$path"');
  }

  /// 删除文件
  Future<void> removeFile(String path) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    await _session!.executeCommand('rm "$path"');
  }

  /// 删除目录
  Future<void> removeDirectory(String path) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    await _session!.executeCommand('rmdir "$path"');
  }

  /// 下载文件
  ///
  /// [remotePath] - 远程文件路径
  /// [localPath] - 本地保存路径
  /// [onProgress] - 进度回调（可选）
  Future<void> downloadFile(String remotePath, String localPath, {TransferProgressCallback? onProgress}) async {
    if (_session == null) {
      throw Exception('未连接到终端，无法下载文件。请确保已建立 SSH 连接。');
    }

    final transferId = 'dl_${DateTime.now().millisecondsSinceEpoch}';
    final fileName = remotePath.split('/').last;

    // 创建本地文件
    final file = File(localPath);
    final sink = file.openWrite();

    int transferred = 0;
    int totalSize = 0;
    final startTime = DateTime.now().millisecondsSinceEpoch;

    // 创建 Completer 等待传输完成
    final completer = Completer<void>();

    // 监听文件传输事件
    final subscription = _session!.fileTransferStream.listen(
      (event) async {
        switch (event.type) {
          case 'start':
            totalSize = event.fileSize ?? 0;
            break;
          case 'chunk':
            if (event.data != null) {
              sink.add(event.data!);
              transferred += event.data!.length;

              if (onProgress != null) {
                final elapsed = (DateTime.now().millisecondsSinceEpoch - startTime) / 1000;
                final speed = elapsed > 0 ? (transferred / elapsed).round() : 0;

                onProgress(TransferProgress(
                  fileName: fileName,
                  transferredBytes: transferred,
                  totalBytes: totalSize,
                  percent: totalSize > 0 ? transferred / totalSize * 100 : 0,
                  bytesPerSecond: speed,
                ));
              }
            }
            break;
          case 'end':
            await sink.close();
            if (!completer.isCompleted) {
              completer.complete();
            }
            break;
        }
      },
      onError: (error) async {
        await sink.close();
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
    );

    // 发送接收会话请求
    _session!.writeRaw(
      '\x1b]5113;ac=recv;id=$transferId;f=$remotePath\x1b\\'
    );

    // 等待传输完成或超时
    try {
      await completer.future.timeout(const Duration(minutes: 5));
    } catch (e) {
      // 超时
      await sink.close();
      rethrow;
    } finally {
      await subscription.cancel();
    }
  }

  /// 检查远程是否支持 Kitty 协议
  Future<ProtocolSupportResult> checkProtocolSupport() async {
    if (_session == null) {
      return ProtocolSupportResult(
        isSupported: false,
        errorMessage: '未连接到终端',
      );
    }

    // 尝试执行 ki version 命令
    // 如果不支持，将返回 "command not found" 或类似错误
    final outputBuffer = StringBuffer();

    final subscription = _session!.inputService.outputStream.listen((output) {
      outputBuffer.write(output);
    });

    _session!.executeCommand('ki version');

    // 等待响应
    await Future.delayed(const Duration(seconds: 2));
    await subscription.cancel();

    final output = outputBuffer.toString();

    // 检查输出中是否包含版本信息
    if (output.contains('ki version') || output.contains('kitty')) {
      return ProtocolSupportResult(isSupported: true);
    }

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
    if (_session == null) {
      throw Exception('未连接到终端，无法发送文件。请确保已建立 SSH 连接。');
    }

    final file = File(localPath);
    if (!await file.exists()) {
      throw Exception('文件不存在: $localPath');
    }

    final fileName = p.basename(localPath);
    final fileSize = await file.length();
    final fileId = 'f${DateTime.now().millisecondsSinceEpoch}';
    final transferId = 't${DateTime.now().millisecondsSinceEpoch}';

    // 1. 开始发送会话
    _session.writeRaw(_encoder.createSendSession(transferId));

    // 2. 发送文件元数据
    _session.writeRaw(_encoder.createFileMetadata(
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
      _session.writeRaw(_encoder.createDataChunk(
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
    _session.writeRaw(_encoder.createFinishSession(transferId));
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
