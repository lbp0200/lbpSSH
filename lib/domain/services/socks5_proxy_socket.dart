import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:socks5_proxy/socks_client.dart';

/// 将 SOCKS5 连接适配为 SSHSocket
///
/// socks5_proxy 在握手阶段已通过 `asBroadcastStream()` 监听了 socket，
/// 因此这里直接复用其广播流，不能再对原始 socket 调用 [Socket.listen]，
/// 否则会抛出 "Stream has already been listened to" 错误。
class Socks5ProxySocket implements SSHSocket {
  final Socket _socket;
  final Stream<Uint8List> _stream;

  Socks5ProxySocket(Socket socket, Stream<Uint8List> stream)
    : _socket = socket,
      _stream = stream;

  @override
  Stream<Uint8List> get stream => _stream;

  @override
  StreamSink<List<int>> get sink => _socket;

  @override
  Future<void> get done => _socket.done;

  @override
  Future<void> close() => _socket.close();

  @override
  Future<void> flush() => _socket.flush();

  @override
  void destroy() {
    _socket.destroy();
  }

  @override
  String toString() {
    final address = '${_socket.remoteAddress.host}:${_socket.remotePort}';
    return 'Socks5ProxySocket($address)';
  }
}

/// 连接到 SOCKS5 代理并返回 SSHSocket
///
/// 使用 socks5_proxy 包实现，支持远程 DNS 解析。
Future<SSHSocket> connectViaSocks5Proxy(
  String proxyHost,
  int proxyPort,
  String targetHost,
  int targetPort, {
  String? username,
  String? password,
  Duration? timeout,
}) async {
  final proxy = ProxySettings(
    InternetAddress(proxyHost, type: InternetAddressType.IPv4),
    proxyPort,
    username: username,
    password: password,
  );

  // ignore: close_sinks - socksSocket.socket 所有权转移给 Socks5ProxySocket，由调用方 close
  final socksSocket = await SocksTCPClient.connect(
    [proxy],
    InternetAddress(targetHost, type: InternetAddressType.unix),
    targetPort,
  ).timeout(timeout ?? const Duration(seconds: 30));

  return Socks5ProxySocket(socksSocket.socket, socksSocket.stream);
}
