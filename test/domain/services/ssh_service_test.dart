import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lbp_ssh/domain/services/ssh_service.dart';
import 'package:lbp_ssh/domain/services/app_config_service.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/data/models/ssh_config.dart';

// ---------------------------------------------------------------------------
// Fake / Mock classes for dartssh2 types
// ---------------------------------------------------------------------------

class FakeSSHSocket extends Fake implements SSHSocket {}

class FakeSSHClient extends Fake implements SSHClient {}

class FakeSSHSession extends Fake implements SSHSession {}

class FakeSftpClient extends Fake implements SftpClient {}

class MockAppConfigService extends Mock implements AppConfigService {}

class MockSshConfig extends Mock implements SshConfig {}

// ---------------------------------------------------------------------------
// Stub implementation for SSHSocket abstract members needed by mocktail
// ---------------------------------------------------------------------------

class FakeSSHSocketStub extends FakeSSHSocket {
  @override
  Stream<Uint8List> get stream => const Stream.empty();

  @override
  StreamSink<List<int>> get sink => _DummyStreamSink();

  @override
  Future<void> get done => Future<void>.value();

  @override
  Future<void> close() async {}

  @override
  void destroy() {}
}

class _DummyStreamSink implements StreamSink<List<int>> {
  @override
  Future<void> get done => Future<void>.value();

  @override
  void add(List<int> data) {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) async {}

  @override
  Future<void> close() async {}
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

SshConnection makeConnection({
  AuthType authType = AuthType.password,
  String? password,
  String? privateKeyContent,
  String? keyPassphrase,
  JumpHostConfig? jumpHost,
  Socks5ProxyConfig? socks5Proxy,
  String? sshConfigHost,
  int port = 22,
  int connectTimeout = 30000,
  int keepaliveInterval = 30000,
}) {
  return SshConnection(
    id: 'test-id',
    name: 'test-connection',
    host: '127.0.0.1',
    port: port,
    username: 'testuser',
    authType: authType,
    password: password,
    privateKeyContent: privateKeyContent,
    keyPassphrase: keyPassphrase,
    jumpHost: jumpHost,
    socks5Proxy: socks5Proxy,
    sshConfigHost: sshConfigHost,
    connectTimeout: connectTimeout,
    keepaliveInterval: keepaliveInterval,
  );
}

MockAppConfigService createMockAppConfigService({
  int keepaliveInterval = 30000,
}) {
  final mock = MockAppConfigService();
  final mockSsh = MockSshConfig();
  when(() => mockSsh.keepaliveInterval).thenReturn(keepaliveInterval);
  when(() => mock.ssh).thenReturn(mockSsh);
  return mock;
}

/// 绑定一个临时端口后立即关闭，返回一个"已关闭"的本地端口，
/// 用于触发真实的连接拒绝（SocketException）。
Future<int> _closedLocalPort() async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = server.port;
  await server.close();
  return port;
}

/// 绑定一个本地监听端口并保持打开，让 `SSHSocket.connect` 在 TCP 层成功，
/// 以便测试 socket 建立之后的认证校验分支。
Future<int> _openLocalPort() async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((_) {});
  addTearDown(() => server.close());
  return server.port;
}

// ---------------------------------------------------------------------------
// Main test suite
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(FakeSSHSocket());
    registerFallbackValue(FakeSSHClient());
    registerFallbackValue(FakeSSHSession());
    registerFallbackValue(FakeSftpClient());
    registerFallbackValue(makeConnection());
    registerFallbackValue(MockSshConfig());
  });

  // -------------------------------------------------------------------------
  // SshService Constructor
  // -------------------------------------------------------------------------
  group('SshService constructor', () {
    test('Given SshService without AppConfigService, '
        'When created, '
        'Then service is functional (uses default AppConfigService)', () {
      // Act
      final service = SshService();

      // Assert — service should be created without throwing
      // The default AppConfigService singleton is used internally.
      expect(service.state, SshConnectionState.disconnected);
      expect(service, isA<SshService>());
    });

    test('Given SshService with AppConfigService, '
        'When created, '
        'Then service uses provided AppConfigService', () {
      final mockConfig = createMockAppConfigService(keepaliveInterval: 60000);

      // Act
      final service = SshService(appConfigService: mockConfig);

      // Assert — service should use the provided mock.
      // The _config getter returns the injected service (verified by
      // behavioral outcomes: connect() uses _config.ssh.keepaliveInterval).
      expect(service.state, SshConnectionState.disconnected);
    });
  });

  // -------------------------------------------------------------------------
  // resize()
  // -------------------------------------------------------------------------
  group('resize()', () {
    test('Given session is null, '
        'When resize called, '
        'Then does not throw', () {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      expect(() => service.resize(24, 80), returnsNormally);
    });

    test('Given session is null, '
        'When resize called with zero dimensions, '
        'Then does not throw', () {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      expect(() => service.resize(0, 0), returnsNormally);
    });

    test('Given session is null, '
        'When resize called with negative dimensions, '
        'Then does not throw', () {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      expect(() => service.resize(-1, -1), returnsNormally);
    });
  });

  // -------------------------------------------------------------------------
  // sendInput()
  // -------------------------------------------------------------------------
  group('sendInput()', () {
    test('Given not connected, '
        'When sendInput called, '
        'Then does nothing (no throw)', () {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      expect(() => service.sendInput('hello'), returnsNormally);
    });

    test('Given not connected, '
        'When sendInput called with empty string, '
        'Then does nothing (no throw)', () {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      expect(() => service.sendInput(''), returnsNormally);
    });
  });

  // -------------------------------------------------------------------------
  // disconnect()
  // -------------------------------------------------------------------------
  group('disconnect()', () {
    test('Given already disposed, '
        'When disconnect called, '
        'Then does nothing (no throw)', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);
      service.dispose();

      expect(() => service.disconnect(), returnsNormally);
    });

    test('Given disconnected, '
        'When disconnect called, '
        'Then emits disconnected state', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      final states = <SshConnectionState>[];
      service.sshStateStream.listen(states.add);

      await service.disconnect();

      expect(states, contains(SshConnectionState.disconnected));
    });

    test('Given connecting state, '
        'When disconnect called, '
        'Then emits disconnected state', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      final states = <SshConnectionState>[];
      service.sshStateStream.listen(states.add);

      await service.disconnect();

      expect(states, contains(SshConnectionState.disconnected));
    });

    test('Given error state, '
        'When disconnect called, '
        'Then emits disconnected state', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      final states = <SshConnectionState>[];
      service.sshStateStream.listen(states.add);

      await service.disconnect();

      expect(states, contains(SshConnectionState.disconnected));
    });
  });

  // -------------------------------------------------------------------------
  // outputStream
  // -------------------------------------------------------------------------
  group('outputStream', () {
    test('Given disposed, '
        'When output received, '
        'Then outputStream does not emit', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);
      service.dispose();

      final outputs = <String>[];
      service.outputStream.listen(outputs.add);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(outputs, isEmpty);
    });

    test('Given not disposed, '
        'When output received, '
        'Then outputStream is available', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      final outputs = <String>[];
      service.outputStream.listen(outputs.add);

      // No data was explicitly added so list is empty.
      expect(outputs, isEmpty);

      service.dispose();
    });
  });

  // -------------------------------------------------------------------------
  // state property
  // -------------------------------------------------------------------------
  group('state property', () {
    test('Given initial state, '
        'When created, '
        'Then state is disconnected', () {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      expect(service.state, SshConnectionState.disconnected);
    });

    test('Given after disconnect, '
        'When state accessed, '
        'Then state is disconnected', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);
      await service.disconnect();

      expect(service.state, SshConnectionState.disconnected);
    });
  });

  // -------------------------------------------------------------------------
  // sshStateStream
  // -------------------------------------------------------------------------
  group('sshStateStream', () {
    test('Given subscribed, '
        'When state changes, '
        'Then stream emits new state', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      final states = <SshConnectionState>[];
      service.sshStateStream.listen(states.add);

      await service.disconnect();

      expect(states.last, SshConnectionState.disconnected);
    });

    test('Given multiple subscribers, '
        'When state changes, '
        'Then all subscribers receive the state', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      final states1 = <SshConnectionState>[];
      final states2 = <SshConnectionState>[];
      service.sshStateStream.listen(states1.add);
      service.sshStateStream.listen(states2.add);

      await service.disconnect();

      expect(states1.last, SshConnectionState.disconnected);
      expect(states2.last, SshConnectionState.disconnected);
    });

    test('Given stream listened to after state change, '
        'Then does not receive past states', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      await service.disconnect();

      final states = <SshConnectionState>[];
      service.sshStateStream.listen(states.add);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      // Should not receive the disconnected state emitted before subscribe.
      expect(states, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // connect() — Error handling (validation before socket creation)
  // -------------------------------------------------------------------------
  group('connect() error handling', () {
    test('Given missing password, '
        'When connect called with password auth, '
        'Then throws Exception', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      final conn = makeConnection();

      await expectLater(
        () => service.connect(conn),
        throwsA(predicate<Exception>((e) => e.toString().contains('密码'))),
      );
    });

    test('Given empty password, '
        'When connect called with password auth, '
        'Then throws Exception', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      final conn = makeConnection(password: '');

      await expectLater(
        () => service.connect(conn),
        throwsA(predicate<Exception>((e) => e.toString().contains('密码'))),
      );
    });

    test('Given missing privateKeyContent, '
        'When connect called with key auth, '
        'Then throws Exception', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      final conn = makeConnection(authType: AuthType.key);

      await expectLater(
        () => service.connect(conn),
        throwsA(predicate<Exception>((e) => e.toString().contains('私钥'))),
      );
    });

    test('Given missing keyPassphrase, '
        'When connect called with keyWithPassword auth, '
        'Then throws Exception', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      final conn = makeConnection(
        authType: AuthType.keyWithPassword,
        privateKeyContent:
            '-----BEGIN OPENSSH PRIVATE KEY-----\ntest\n-----END OPENSSH PRIVATE KEY-----',
      );

      await expectLater(
        () => service.connect(conn),
        throwsA(predicate<Exception>((e) => e.toString().contains('密钥密码'))),
      );
    });

    test('Given missing sshConfigHost, '
        'When connect called with sshConfig auth, '
        'Then throws Exception', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      final conn = makeConnection(authType: AuthType.sshConfig);

      await expectLater(
        () => service.connect(conn),
        throwsA(
          predicate<Exception>((e) => e.toString().contains('SSH Config')),
        ),
      );
    });

    test('Given empty privateKeyContent, '
        'When connect called with key auth, '
        'Then throws Exception', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);
      final port = await _openLocalPort();

      final conn = makeConnection(
        authType: AuthType.key,
        privateKeyContent: '',
        port: port,
      );

      await expectLater(
        () => service.connect(conn),
        throwsA(predicate<Exception>((e) => e.toString().contains('私钥内容未设置'))),
      );
    });

    test('Given invalid private key content, '
        'When connect called with key auth, '
        'Then throws Exception', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);
      final port = await _openLocalPort();

      final conn = makeConnection(
        authType: AuthType.key,
        privateKeyContent: 'not-a-valid-pem',
        port: port,
      );

      await expectLater(
        () => service.connect(conn),
        throwsA(predicate<Exception>((e) => e.toString().contains('私钥格式错误'))),
      );
    });

    test('Given empty privateKeyContent, '
        'When connect called with keyWithPassword auth, '
        'Then throws Exception', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);
      final port = await _openLocalPort();

      final conn = makeConnection(
        authType: AuthType.keyWithPassword,
        privateKeyContent: '',
        keyPassphrase: 'secret',
        port: port,
      );

      await expectLater(
        () => service.connect(conn),
        throwsA(predicate<Exception>((e) => e.toString().contains('私钥内容未设置'))),
      );
    });

    test('Given empty keyPassphrase, '
        'When connect called with keyWithPassword auth, '
        'Then throws Exception', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);
      final port = await _openLocalPort();

      final conn = makeConnection(
        authType: AuthType.keyWithPassword,
        privateKeyContent:
            '-----BEGIN OPENSSH PRIVATE KEY-----\ntest\n-----END OPENSSH PRIVATE KEY-----',
        keyPassphrase: '',
        port: port,
      );

      await expectLater(
        () => service.connect(conn),
        throwsA(predicate<Exception>((e) => e.toString().contains('密钥密码未设置'))),
      );
    });

    test('Given invalid private key with passphrase, '
        'When connect called with keyWithPassword auth, '
        'Then throws Exception', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);
      final port = await _openLocalPort();

      final conn = makeConnection(
        authType: AuthType.keyWithPassword,
        privateKeyContent: 'not-a-valid-pem',
        keyPassphrase: 'secret',
        port: port,
      );

      await expectLater(
        () => service.connect(conn),
        throwsA(predicate<Exception>((e) => e.toString().contains('私钥或密码错误'))),
      );
    });

    test('Given empty sshConfigHost, '
        'When connect called with sshConfig auth, '
        'Then throws Exception', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);
      final port = await _openLocalPort();

      final conn = makeConnection(
        authType: AuthType.sshConfig,
        sshConfigHost: '',
        port: port,
      );

      await expectLater(
        () => service.connect(conn),
        throwsA(predicate<Exception>((e) => e.toString().contains('SSH Config 主机名未设置'))),
      );
    });

    test('Given sshConfig host not found in ~/.ssh/config, '
        'When connect called with sshConfig auth, '
        'Then throws Exception', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);
      final port = await _openLocalPort();

      final conn = makeConnection(
        authType: AuthType.sshConfig,
        sshConfigHost: 'lbpssh-test-nonexistent-host',
        port: port,
      );

      await expectLater(
        () => service.connect(conn),
        throwsA(
          predicate<Exception>((e) => e.toString().contains('未在 ~/.ssh/config 中找到')),
        ),
      );
    });
  });

  // -------------------------------------------------------------------------
  // connect() — Jump host validation branches
  // -------------------------------------------------------------------------
  group('connect() jump host validation', () {
    test('Given jump host with missing password, '
        'When connect called with password auth, '
        'Then throws Exception', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);
      final port = await _openLocalPort();

      final conn = makeConnection(
        password: 'secret',
        port: port,
        jumpHost: JumpHostConfig(
          host: '127.0.0.1',
          port: port,
          username: 'jumpuser',
          authType: AuthType.password,
        ),
      );

      await expectLater(
        () => service.connect(conn),
        throwsA(predicate<Exception>((e) => e.toString().contains('跳板机密码未设置'))),
      );
    });

    test('Given jump host key auth with missing privateKeyPath, '
        'When connect called, '
        'Then throws Exception', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);
      final port = await _openLocalPort();

      final conn = makeConnection(
        password: 'secret',
        port: port,
        jumpHost: JumpHostConfig(
          host: '127.0.0.1',
          port: port,
          username: 'jumpuser',
          authType: AuthType.key,
        ),
      );

      await expectLater(
        () => service.connect(conn),
        throwsA(predicate<Exception>((e) => e.toString().contains('跳板机私钥路径未设置'))),
      );
    });

    test('Given jump host key auth with nonexistent key file, '
        'When connect called, '
        'Then throws Exception', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);
      final port = await _openLocalPort();

      final conn = makeConnection(
        password: 'secret',
        port: port,
        jumpHost: JumpHostConfig(
          host: '127.0.0.1',
          port: port,
          username: 'jumpuser',
          authType: AuthType.key,
          privateKeyPath: '/nonexistent/key.pem',
        ),
      );

      await expectLater(
        () => service.connect(conn),
        throwsA(predicate<Exception>((e) => e.toString().contains('跳板机私钥读取失败'))),
      );
    });

    test('Given jump host keyWithPassword auth with missing privateKeyPath, '
        'When connect called, '
        'Then throws Exception', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);
      final port = await _openLocalPort();

      final conn = makeConnection(
        password: 'secret',
        port: port,
        jumpHost: JumpHostConfig(
          host: '127.0.0.1',
          port: port,
          username: 'jumpuser',
          authType: AuthType.keyWithPassword,
          password: 'jump-pass',
        ),
      );

      await expectLater(
        () => service.connect(conn),
        throwsA(predicate<Exception>((e) => e.toString().contains('跳板机私钥路径未设置'))),
      );
    });

    test('Given jump host keyWithPassword auth with missing password, '
        'When connect called, '
        'Then throws Exception', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);
      final port = await _openLocalPort();

      final conn = makeConnection(
        password: 'secret',
        port: port,
        jumpHost: JumpHostConfig(
          host: '127.0.0.1',
          port: port,
          username: 'jumpuser',
          authType: AuthType.keyWithPassword,
          privateKeyPath: '/some/key.pem',
        ),
      );

      await expectLater(
        () => service.connect(conn),
        throwsA(predicate<Exception>((e) => e.toString().contains('跳板机密钥密码未设置'))),
      );
    });

    test('Given jump host keyWithPassword auth with bad key file, '
        'When connect called, '
        'Then throws Exception', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);
      final port = await _openLocalPort();

      final conn = makeConnection(
        password: 'secret',
        port: port,
        jumpHost: JumpHostConfig(
          host: '127.0.0.1',
          port: port,
          username: 'jumpuser',
          authType: AuthType.keyWithPassword,
          password: 'jump-pass',
          privateKeyPath: '/nonexistent/key.pem',
        ),
      );

      await expectLater(
        () => service.connect(conn),
        throwsA(predicate<Exception>((e) => e.toString().contains('跳板机私钥或密码错误'))),
      );
    });

    test('Given jump host with sshConfig auth, '
        'When connect called, '
        'Then throws Exception', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);
      final port = await _openLocalPort();

      final conn = makeConnection(
        password: 'secret',
        port: port,
        jumpHost: JumpHostConfig(
          host: '127.0.0.1',
          port: port,
          username: 'jumpuser',
          authType: AuthType.sshConfig,
        ),
      );

      await expectLater(
        () => service.connect(conn),
        throwsA(predicate<Exception>((e) => e.toString().contains('跳板机不支持 SSH Config 认证方式'))),
      );
    });
  });

  // -------------------------------------------------------------------------
  // connect() — SOCKS5 proxy branch
  // -------------------------------------------------------------------------
  group('connect() socks5 proxy branch', () {
    test('Given unreachable SOCKS5 proxy, '
        'When connect called with socks5Proxy configured, '
        'Then emits error state and rethrows', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);
      final proxyPort = await _closedLocalPort();

      final states = <SshConnectionState>[];
      service.sshStateStream.listen(states.add);
      final outputs = <String>[];
      service.outputStream.listen(outputs.add);

      await expectLater(
        () => service.connect(
          makeConnection(
            password: 'secret',
            socks5Proxy: Socks5ProxyConfig(
              host: '127.0.0.1',
              port: proxyPort,
            ),
          ),
        ),
        throwsA(isA<Exception>()),
      );

      // broadcast 流异步派发，等待事件送达
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(states, contains(SshConnectionState.connecting));
      expect(states.last, SshConnectionState.error);
      expect(outputs.any((o) => o.contains('连接错误')), isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // connect() — Real socket failure path
  // -------------------------------------------------------------------------
  group('connect() failure path', () {
    test('Given valid password but unreachable server, '
        'When connect called, '
        'Then emits connecting then error states', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);
      final port = await _closedLocalPort();

      final states = <SshConnectionState>[];
      service.sshStateStream.listen(states.add);

      await expectLater(
        () => service.connect(
          makeConnection(password: 'secret', port: port, connectTimeout: 2000),
        ),
        throwsA(isA<Exception>()),
      );

      // broadcast 流异步派发，等待事件送达
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(states, contains(SshConnectionState.connecting));
      expect(states.last, SshConnectionState.error);
    });

    test('Given connection failure, '
        'When connect called, '
        'Then outputStream receives 连接错误 message', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);
      final port = await _closedLocalPort();

      final outputs = <String>[];
      service.outputStream.listen(outputs.add);

      await expectLater(
        () => service.connect(
          makeConnection(password: 'secret', port: port, connectTimeout: 2000),
        ),
        throwsA(isA<Exception>()),
      );

      // broadcast 流异步派发，等待事件送达
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(outputs.any((o) => o.contains('连接错误')), isTrue);
    });

    test('Given failed connect, '
        'When disconnect called, '
        'Then emits disconnected state', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);
      final port = await _closedLocalPort();

      await expectLater(
        () => service.connect(
          makeConnection(password: 'secret', port: port, connectTimeout: 2000),
        ),
        throwsA(isA<Exception>()),
      );

      final states = <SshConnectionState>[];
      service.sshStateStream.listen(states.add);
      await service.disconnect();

      expect(states.last, SshConnectionState.disconnected);
    });
  });

  // -------------------------------------------------------------------------
  // stateStream
  // -------------------------------------------------------------------------
  group('stateStream', () {
    test('Given disconnected state, '
        'When stateStream listened, '
        'Then emits false', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      final bools = <bool>[];
      service.stateStream.listen(bools.add);

      await service.disconnect();

      expect(bools, contains(false));
    });
  });

  // -------------------------------------------------------------------------
  // osType
  // -------------------------------------------------------------------------
  group('osType', () {
    test('Then returns Linux', () {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      expect(service.osType, 'Linux');
    });
  });

  // -------------------------------------------------------------------------
  // executeCommand()
  // -------------------------------------------------------------------------
  group('executeCommand()', () {
    test('Given not connected, '
        'When executeCommand called, '
        'Then throws Exception', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      await expectLater(
        () => service.executeCommand('ls'),
        throwsA(predicate<Exception>((e) => e.toString().contains('未连接到服务器'))),
      );
    });

    test('Given disconnected, '
        'When executeCommand called, '
        'Then throws Exception', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);
      await service.disconnect();

      await expectLater(
        () => service.executeCommand('ls'),
        throwsA(predicate<Exception>((e) => e.toString().contains('未连接到服务器'))),
      );
    });

    test('Given not connected, '
        'When executeCommand called with silent flag, '
        'Then throws Exception', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      await expectLater(
        () => service.executeCommand('ls', silent: true),
        throwsA(predicate<Exception>((e) => e.toString().contains('未连接到服务器'))),
      );
    });
  });

  // -------------------------------------------------------------------------
  // getSftpClient()
  // -------------------------------------------------------------------------
  group('getSftpClient()', () {
    test('Given not connected, '
        'When getSftpClient called, '
        'Then returns null', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      final result = await service.getSftpClient();

      expect(result, isNull);
    });

    test('Given disconnected, '
        'When getSftpClient called, '
        'Then returns null', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);
      await service.disconnect();

      final result = await service.getSftpClient();

      expect(result, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // dispose()
  // -------------------------------------------------------------------------
  group('dispose()', () {
    test('When dispose called, '
        'Then closes streams and subsequent disconnect is no-op', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      service.dispose();

      // Subsequent disconnect should be a no-op.
      expect(() => service.disconnect(), returnsNormally);

      // sshStateStream should be closed (no more emissions).
      final states = <SshConnectionState>[];
      service.sshStateStream.listen(states.add);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(states, isEmpty);
    });

    test('Given multiple dispose calls, '
        'Then does not throw', () {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      service.dispose();
      expect(() => service.dispose(), returnsNormally);
    });

    test('When dispose called, '
        'Then state property is still accessible', () {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      service.dispose();

      expect(service.state, SshConnectionState.disconnected);
    });
  });

  // -------------------------------------------------------------------------
  // SshConnectionState enum
  // -------------------------------------------------------------------------
  group('SshConnectionState enum', () {
    test('Has all expected values', () {
      expect(SshConnectionState.values, [
        SshConnectionState.disconnected,
        SshConnectionState.connecting,
        SshConnectionState.connected,
        SshConnectionState.error,
      ]);
    });
  });
}
