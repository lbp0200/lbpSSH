library;

/// Kitty 文件传输模型（枚举与数据类）
/// 从 kitty_file_transfer_service.dart 抽离，降低长文件复杂度

/// 压缩类型
enum CompressionType { none, zlib }

/// 文件类型
enum FileType { regular, directory, symlink, link }

/// 传输类型
enum TransmissionType { simple, rsync }

/// 文件元数据
class FileMetadata {
  final String name;
  final FileType fileType;
  final int? size;
  final int? permissions;
  final int? mtime; // 纳秒级时间戳
  final String? linkTarget;

  FileMetadata({
    required this.name,
    this.fileType = FileType.regular,
    this.size,
    this.permissions,
    this.mtime,
    this.linkTarget,
  });
}

/// 传输状态
class TransferStatus {
  final String sessionId;
  final String? fileId;
  final bool isOk;
  final String? errorMessage;
  final int? size;

  TransferStatus({
    required this.sessionId,
    this.fileId,
    required this.isOk,
    this.errorMessage,
    this.size,
  });
}

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

  ProtocolSupportResult({required this.isSupported, this.errorMessage});
}
