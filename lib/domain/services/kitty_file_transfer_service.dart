import 'dart:async';

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
  /// [sessionId] - 终端会话 ID
  /// [filePath] - 要发送的文件路径
  Future<void> sendFile(String sessionId, String filePath) async {
    // TODO: 实现发送文件逻辑
    // 1. 构建 OSC 5113 控制序列
    // 2. 通过终端会话发送
    // 3. 处理响应
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
