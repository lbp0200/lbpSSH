import 'dart:convert';

import 'kitty_file_transfer_models.dart';

export 'kitty_file_transfer_models.dart';

/// Kitty 协议文件传输编码器
/// 从 kitty_file_transfer_service.dart 抽离，降低长文件复杂度
class KittyFileTransferEncoder {
  const KittyFileTransferEncoder();

  /// 编码文件名为 base64
  String encodeFileName(String name) {
    return base64Encode(utf8.encode(name));
  }

  /// 创建发送会话开始序列
  String createSendSession(
    String sessionId, {
    CompressionType compression = CompressionType.none,
    String? bypass,
    int quiet = 0,
  }) {
    String cmd = '\x1b]5113;ac=send;id=$sessionId';
    if (compression == CompressionType.zlib) {
      cmd += ';zip=zlib';
    }
    if (bypass != null) {
      cmd += ';pw=$bypass';
    }
    if (quiet > 0) {
      cmd += ';q=$quiet';
    }
    cmd += '\x1b\\';
    return cmd;
  }

  /// 创建接收会话开始序列
  String createReceiveSession(
    String sessionId, {
    CompressionType compression = CompressionType.none,
    String? bypass,
    int quiet = 0,
  }) {
    String cmd = '\x1b]5113;ac=recv;id=$sessionId';
    if (compression == CompressionType.zlib) {
      cmd += ';zip=zlib';
    }
    if (bypass != null) {
      cmd += ';pw=$bypass';
    }
    if (quiet > 0) {
      cmd += ';q=$quiet';
    }
    cmd += '\x1b\\';
    return cmd;
  }

  /// 创建文件元数据序列
  String createFileMetadata({
    required String sessionId,
    required String fileId,
    required String fileName,
    required int fileSize,
    FileType fileType = FileType.regular,
    TransmissionType transmissionType = TransmissionType.simple,
    int? permissions,
    int? mtime,
    String? linkTarget,
  }) {
    final encodedName = encodeFileName(fileName);
    String cmd =
        '\x1b]5113;ac=file;id=$sessionId;fid=$fileId;n=$encodedName;size=$fileSize';

    switch (fileType) {
      case FileType.directory:
        cmd += ';ft=directory';
        break;
      case FileType.symlink:
        cmd += ';ft=symlink';
        break;
      case FileType.link:
        cmd += ';ft=link';
        break;
      default:
        break;
    }

    if (transmissionType == TransmissionType.rsync) {
      cmd += ';tt=rsync';
    }

    if (permissions != null) {
      cmd += ';prm=$permissions';
    }

    if (mtime != null) {
      cmd += ';mod=$mtime';
    }

    if (linkTarget != null) {
      cmd += ';n=${encodeFileName(linkTarget)}';
    }

    cmd += '\x1b\\';
    return cmd;
  }

  /// 创建目录元数据序列
  String createDirectoryMetadata({
    required String sessionId,
    required String fileId,
    required String dirName,
    int? permissions,
    int? mtime,
  }) {
    final encodedName = encodeFileName(dirName);
    String cmd =
        '\x1b]5113;ac=file;id=$sessionId;fid=$fileId;n=$encodedName;ft=directory';

    if (permissions != null) {
      cmd += ';prm=$permissions';
    }
    if (mtime != null) {
      cmd += ';mod=$mtime';
    }

    cmd += '\x1b\\';
    return cmd;
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

  /// 创建数据结束序列
  String createEndData(String sessionId, String fileId, {List<int>? data}) {
    if (data != null) {
      final encoded = base64Encode(data);
      return '\x1b]5113;ac=end_data;id=$sessionId;fid=$fileId;d=$encoded\x1b\\';
    }
    return '\x1b]5113;ac=end_data;id=$sessionId;fid=$fileId\x1b\\';
  }

  /// 创建传输结束序列
  String createFinishSession(String sessionId) {
    return '\x1b]5113;ac=finish;id=$sessionId\x1b\\';
  }

  /// 创建取消传输序列
  String createCancelSession(String sessionId) {
    return '\x1b]5113;ac=cancel;id=$sessionId\x1b\\';
  }

  /// 解析状态响应
  TransferStatus? parseStatusResponse(String response) {
    try {
      final regex = RegExp(r'ac=status;id=([^;]+);st=([^:;]+)(?::(.*))?');
      final match = regex.firstMatch(response);
      if (match != null) {
        final sessionId = match.group(1)!;
        final status = match.group(2)!;
        final message = match.group(3);
        final isOk = status == 'OK';

        int? size;
        final sizeRegex = RegExp(r'sz=(\d+)');
        final sizeMatch = sizeRegex.firstMatch(response);
        if (sizeMatch != null) {
          size = int.tryParse(sizeMatch.group(1)!);
        }

        return TransferStatus(
          sessionId: sessionId,
          isOk: isOk,
          errorMessage: message,
          size: size,
        );
      }
    } catch (_) {
      // 忽略解析错误
    }
    return null;
  }
}
