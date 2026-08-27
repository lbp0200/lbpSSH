import 'dart:io';

/// 在本机寻找一个可用端口（绑定 0 让系统分配）
Future<int> findAvailablePort() async {
  ServerSocket? server;
  try {
    server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    return server.port;
  } finally {
    await server?.close();
  }
}

/// 轮询探测跳板机隧道是否就绪
///
/// 轮询最多 2s（10 次 × 200ms），与旧固定等待对齐但可提前返回
Future<void> waitForTunnelReady(int port) async {
  const maxAttempts = 10;
  const interval = Duration(milliseconds: 200);
  for (var i = 0; i < maxAttempts; i++) {
    try {
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: const Duration(milliseconds: 200),
      );
      await socket.close();
      return;
    } catch (_) {
      await Future<void>.delayed(interval);
    }
  }
  // 超时仍未就绪则继续，后续连接会抛错
}
