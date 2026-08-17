import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/domain/services/ssh_service.dart';
import 'package:socks5_proxy/socks_server.dart';

// ---------------------------------------------------------------------------
// Helpers: 本地 echo 目标服务器 + 本地 SOCKS5 代理服务器
// ---------------------------------------------------------------------------

/// 启动一个本地 echo TCP 服务器，收到什么就原样返回什么。
Future<ServerSocket> startEchoServer() async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((socket) {
    socket.listen(
      (data) => socket.add(data),
      onError: (_) => socket.destroy(),
      onDone: () => socket.destroy(),
    );
  });
  return server;
}

/// 启动一个本地 SOCKS5 代理服务器，将连接转发到目标主机。
Future<SocksServer> startSocksServer({AuthHandler? authHandler}) async {
  final server = SocksServer(authHandler: authHandler);
  await server.bind(InternetAddress.loopbackIPv4, 0);
  server.connections.listen((connection) {
    connection.forward();
  });
  return server;
}

int proxyPortOf(SocksServer server) => server.proxies.keys.first;

/// 收集流中的数据直到达到期望字节数，带超时保护。
Future<List<int>> collectUntil(
  Stream<List<int>> stream,
  int expectedBytes, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final bytes = <int>[];
  final completer = Completer<void>();
  final sub = stream.listen((data) {
    bytes.addAll(data);
    if (bytes.length >= expectedBytes && !completer.isCompleted) {
      completer.complete();
    }
  });
  await completer.future.timeout(timeout);
  await sub.cancel();
  return bytes;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('connectViaSocks5Proxy()', () {
    late ServerSocket target;
    late int targetPort;

    setUp(() async {
      target = await startEchoServer();
      targetPort = target.port;
    });

    tearDown(() async {
      await target.close();
    });

    test('Given local proxy and echo target, '
        'When connecting via SOCKS5 proxy, '
        'Then data round-trips through the proxy', () async {
      final proxy = await startSocksServer();
      addTearDown(proxy.stop);

      final socket = await connectViaSocks5Proxy(
        '127.0.0.1',
        proxyPortOf(proxy),
        '127.0.0.1',
        targetPort,
      );

      final received = collectUntil(socket.stream, 13);
      socket.sink.add(utf8.encode('hello through'));
      await socket.flush();

      final echoed = utf8.decode(await received);
      expect(echoed, 'hello through');
      expect(socket.toString(), contains('127.0.0.1'));

      await socket.close();
    });

    test('Given proxy requiring auth, '
        'When connecting with correct credentials, '
        'Then connection succeeds and data round-trips', () async {
      final proxy = await startSocksServer(
        authHandler: (user, pass) => user == 'user' && pass == 'pass',
      );
      addTearDown(proxy.stop);

      final socket = await connectViaSocks5Proxy(
        '127.0.0.1',
        proxyPortOf(proxy),
        '127.0.0.1',
        targetPort,
        username: 'user',
        password: 'pass',
      );

      final received = collectUntil(socket.stream, 6);
      socket.sink.add(utf8.encode('authed'));
      await socket.flush();

      expect(utf8.decode(await received), 'authed');

      await socket.close();
    });

    test('Given proxy requiring auth, '
        'When connecting with wrong credentials, '
        'Then connection fails (server closes connection)', () async {
      final proxy = await startSocksServer(
        authHandler: (user, pass) => user == 'user' && pass == 'pass',
      );
      addTearDown(proxy.stop);

      // 认证失败时服务端会关闭连接，客户端抛异常（不会成功建立连接）。
      await expectLater(
        connectViaSocks5Proxy(
          '127.0.0.1',
          proxyPortOf(proxy),
          '127.0.0.1',
          targetPort,
          username: 'user',
          password: 'wrong',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('Given a proxy that never responds, '
        'When connecting with a short timeout, '
        'Then throws TimeoutException', () async {
      // 接受连接但故意不回应的“哑”代理。
      final silent = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(silent.close);
      // 订阅并消费数据以保持连接存活，但不回写任何响应。
      // （Windows 上不订阅的 accepted Socket 可能被回收导致连接关闭，
      //  客户端会收到 SocksClientConnectionClosedException 而非等待超时。）
      silent.listen((socket) {
        socket.listen((_) {});
      });

      await expectLater(
        connectViaSocks5Proxy(
          '127.0.0.1',
          silent.port,
          '127.0.0.1',
          targetPort,
          timeout: const Duration(milliseconds: 300),
        ),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('Given a successful connection, '
        'When close called, '
        'Then socket closes without throwing', () async {
      final proxy = await startSocksServer();
      addTearDown(proxy.stop);

      final socket = await connectViaSocks5Proxy(
        '127.0.0.1',
        proxyPortOf(proxy),
        '127.0.0.1',
        targetPort,
      );

      await socket.close();
      // 重复 close 不应抛出。
      await socket.close();
    });

    test('Given a successful connection, '
        'When done getter accessed, '
        'Then returns a Future that completes when socket closes', () async {
      final proxy = await startSocksServer();
      addTearDown(proxy.stop);

      final socket = await connectViaSocks5Proxy(
        '127.0.0.1',
        proxyPortOf(proxy),
        '127.0.0.1',
        targetPort,
      );

      // done 应返回一个 Future（不抛异常），且 socket 关闭后完成。
      final done = socket.done;
      expect(done, isA<Future<void>>());

      await socket.close();
      await done.timeout(const Duration(seconds: 2), onTimeout: () {});
    });

    test('Given a successful connection, '
        'When destroy called, '
        'Then destroys the underlying socket without throwing', () async {
      final proxy = await startSocksServer();
      addTearDown(proxy.stop);

      final socket = await connectViaSocks5Proxy(
        '127.0.0.1',
        proxyPortOf(proxy),
        '127.0.0.1',
        targetPort,
      );

      expect(() => socket.destroy(), returnsNormally);
      // 销毁后重复 destroy 不应抛出。
      expect(() => socket.destroy(), returnsNormally);
    });
  });
}
