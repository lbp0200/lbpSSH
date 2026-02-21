import 'dart:async';

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

/// Kitty 文件传输服务
///
/// 通过 SSH 终端发送 OSC 5113 控制序列实现文件传输
class KittyFileTransferService {
  /// 是否支持 Kitty 协议
  bool get supportsKittyProtocol => false;

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
    // TODO: 实现带进度回调的文件发送
    // 1. 读取本地文件
    // 2. 分块发送 OSC 5113 序列
    // 3. 通过 onProgress 报告进度
    throw UnimplementedError('发送文件功能待实现');
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
