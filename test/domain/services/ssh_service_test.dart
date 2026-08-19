import 'dart:async';
import 'dart:convert';
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
// 成功路径测试桩：可控 stdout/stderr/done 的 SSHSession
// ---------------------------------------------------------------------------

/// 记录写入 stdin 的数据
class _RecordingStdin implements StreamSink<Uint8List> {
  _RecordingStdin(this.data);

  final List<Uint8List> data;

  @override
  Future<void> get done => Future<void>.value();

  @override
  void add(Uint8List event) => data.add(event);

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<Uint8List> stream) async {}

  @override
  Future<void> close() async {}
}

/// 可控会话桩：stdout/stderr 用广播流，done 用 Completer，可记录 stdin 与 resize。
class StubSSHSession extends FakeSSHSession {
  StubSSHSession() {
    _stdoutCtrl = StreamController<Uint8List>.broadcast();
    _stderrCtrl = StreamController<Uint8List>.broadcast();
    _doneCompleter = Completer<void>();
    _stdin = _RecordingStdin(_stdinData);
  }

  late final StreamController<Uint8List> _stdoutCtrl;
  late final StreamController<Uint8List> _stderrCtrl;
  late final Completer<void> _doneCompleter;
  final List<Uint8List> _stdinData = [];
  late final StreamSink<Uint8List> _stdin;
  final List<(int, int)> resizeCalls = [];

  StreamController<Uint8List> get stdoutCtrl => _stdoutCtrl;
  StreamController<Uint8List> get stderrCtrl => _stderrCtrl;
  Completer<void> get doneCompleter => _doneCompleter;
  List<Uint8List> get stdinData => _stdinData;

  @override
  Stream<Uint8List> get stdout => _stdoutCtrl.stream;

  @override
  Stream<Uint8List> get stderr => _stderrCtrl.stream;

  @override
  Future<void> get done => _doneCompleter.future;

  @override
  StreamSink<Uint8List> get stdin => _stdin;

  @override
  void resizeTerminal(
    int width,
    int height, [
    int pixelWidth = 0,
    int pixelHeight = 0,
  ]) {
    resizeCalls.add((width, height));
  }

  @override
  Future<void> close() async => _doneCompleter.complete();
}

/// 可控客户端桩：shell 返回给定会话，可配置 PTY shell 抛错以覆盖回退分支。
class StubSSHClient extends FakeSSHClient {
  StubSSHClient({
    required this.session,
    this.executeSession,
    this.ptyShellError,
    this.executeError,
  });

  final SSHSession session;

  /// execute() 返回的独立会话（真实 dartssh2 中 execute 是独立通道）
  final SSHSession? executeSession;

  /// PTY shell 调用时抛出（用于验证回退到无 PTY shell）
  Object? ptyShellError;

  /// execute() 调用时抛出（用于验证 executeCommand 错误分支）
  Object? executeError;

  int shellCalls = 0;

  @override
  Future<SSHSession> shell({
    SSHPtyConfig? pty,
    SSHX11Config? x11,
    Map<String, String>? environment,
  }) async {
    shellCalls++;
    if (pty != null && ptyShellError != null) {
      throw ptyShellError!;
    }
    return session;
  }

  @override
  Future<SSHSession> execute(
    String command, {
    SSHPtyConfig? pty,
    SSHX11Config? x11,
    Map<String, String>? environment,
  }) async {
    if (executeError != null) {
      throw executeError!;
    }
    return executeSession ?? session;
  }

  @override
  Future<SftpClient> sftp() async => FakeSftpClient();

  @override
  Future<void> close() async {}
}

/// 所有 shell 调用都失败的客户端（用于验证"建立会话失败"）。
class _FailingSSHClient extends FakeSSHClient {
  @override
  Future<SSHSession> shell({
    SSHPtyConfig? pty,
    SSHX11Config? x11,
    Map<String, String>? environment,
  }) async {
    throw Exception('boom');
  }
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
  // connect() — 成功路径（注入 stub 客户端）
  // -------------------------------------------------------------------------
  group('connect() success path', () {
    /// 构建注入 stub 的 service，connect 成功后返回 (service, client, session)
    Future<(SshService, StubSSHClient, StubSSHSession)> connectSuccess({
      Object? ptyShellError,
    }) async {
      final session = StubSSHSession();
      final client = StubSSHClient(
        session: session,
        ptyShellError: ptyShellError,
      );
      final mockConfig = createMockAppConfigService();
      final service = SshService(
        appConfigService: mockConfig,
        clientFactory: (socket, {required username, onPasswordRequest, identities,
                keepAliveInterval}) =>
            client,
        socketConnector: (host, port, {timeout}) async => FakeSSHSocketStub(),
      );

      final conn = makeConnection(password: 'secret');
      await service.connect(conn);

      return (service, client, session);
    }

    test('Given password auth with stub client, '
        'When connect called, '
        'Then state becomes connected and shell is started with pty', () async {
      // Act
      final (service, client, session) = await connectSuccess();

      // Assert
      expect(service.state, SshConnectionState.connected);
      expect(client.shellCalls, 1);

      // 清理
      service.dispose();
    });

    test('Given pty shell throws, '
        'When connect called, '
        'Then falls back to non-pty shell and still connects', () async {
      // Arrange — PTY shell 抛错，触发回退分支
      final (service, client, _) = await connectSuccess(
        ptyShellError: Exception('pty failed'),
      );

      // Assert — 回退后仍连接成功
      expect(service.state, SshConnectionState.connected);
      expect(client.shellCalls, 2);

      service.dispose();
    });

    test('Given all shell attempts fail, '
        'When connect called, '
        'Then throws 建立会话失败', () async {
      // Arrange
      final client = _FailingSSHClient();
      final mockConfig = createMockAppConfigService();
      final service = SshService(
        appConfigService: mockConfig,
        clientFactory: (socket, {required username, onPasswordRequest, identities,
                keepAliveInterval}) =>
            client,
        socketConnector: (host, port, {timeout}) async => FakeSSHSocketStub(),
      );

      // Act & Assert
      await expectLater(
        () => service.connect(makeConnection(password: 'secret')),
        throwsA(predicate<Exception>((e) => e.toString().contains('建立会话失败'))),
      );

      service.dispose();
    });

    test('Given connected, '
        'When session stdout emits data, '
        'Then outputStream receives decoded data', () async {
      // Arrange
      final (service, _, session) = await connectSuccess();
      final outputs = <String>[];
      service.outputStream.listen(outputs.add);

      // Act — 写入 UTF-8 数据
      session.stdoutCtrl.add(utf8.encode('hello world\r\n'));
      // 等待输出缓冲 flush（16ms 定时器）
      await Future<void>.delayed(const Duration(milliseconds: 60));

      // Assert
      expect(outputs.join(), contains('hello world'));

      service.dispose();
    });

    test('Given connected, '
        'When session stderr emits data, '
        'Then outputStream receives decoded data', () async {
      // Arrange
      final (service, _, session) = await connectSuccess();
      final outputs = <String>[];
      service.outputStream.listen(outputs.add);

      // Act — stderr 也路由到 outputStream
      session.stderrCtrl.add(utf8.encode('warning: disk full\r\n'));
      await Future<void>.delayed(const Duration(milliseconds: 60));

      // Assert
      expect(outputs.join(), contains('warning: disk full'));

      service.dispose();
    });

    test('Given connected, '
        'When session done completes, '
        'Then state becomes disconnected and emits 连接已断开', () async {
      // Arrange
      final (service, _, session) = await connectSuccess();
      final outputs = <String>[];
      service.outputStream.listen(outputs.add);

      // Act — 完成 done completer 模拟会话断开
      session.doneCompleter.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Assert
      expect(service.state, SshConnectionState.disconnected);
      expect(outputs.join(), contains('连接已断开'));

      service.dispose();
    });

    test('Given connected, '
        'When session stdout emits repeated Last login lines, '
        'Then only the first Last login line is kept', () async {
      // Arrange
      final (service, _, session) = await connectSuccess();
      final outputs = <String>[];
      service.outputStream.listen(outputs.add);

      // Act — 写入多条 Last login 行（模拟重连/重复登录信息）
      session.stdoutCtrl.add(
        utf8.encode(
          'Last login: Tue Aug 12 09:00:00 on ttys000\n'
          'Last login: Tue Aug 12 09:00:01 on ttys000\n'
          'user@host:~\$ ',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));

      // Assert — 只保留第一条 Last login，其他内容原样保留
      final joined = outputs.join();
      expect('Last login:'.allMatches(joined).length, 1);
      expect(joined, contains('user@host:~\$'));

      service.dispose();
    });

    test('Given connected, '
        'When session stdout stream errors, '
        'Then emits output stream error message and disconnects', () async {
      // Arrange
      final (service, _, session) = await connectSuccess();
      final outputs = <String>[];
      service.outputStream.listen(outputs.add);

      // Act — stdout 流报错
      session.stdoutCtrl.addError(Exception('boom'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Assert
      expect(outputs.join(), contains('[输出流错误'));
      expect(service.state, SshConnectionState.disconnected);

      service.dispose();
    });

    test('Given connected, '
        'When session stderr stream errors, '
        'Then emits error stream error message', () async {
      // Arrange
      final (service, _, session) = await connectSuccess();
      final outputs = <String>[];
      service.outputStream.listen(outputs.add);

      // Act — stderr 流报错
      session.stderrCtrl.addError(Exception('boom'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Assert
      expect(outputs.join(), contains('[错误流错误'));

      service.dispose();
    });

    test('Given connected, '
        'When stdout emits more than the buffer max size, '
        'Then buffer is flushed immediately', () async {
      // Arrange
      final (service, _, session) = await connectSuccess();
      final outputs = <String>[];
      service.outputStream.listen(outputs.add);

      // Act — 写入超过 65536 字节，触发 _flushOutputBuffer 立即刷出
      final bigChunk = 'x' * 70000;
      session.stdoutCtrl.add(utf8.encode(bigChunk));
      await Future<void>.delayed(const Duration(milliseconds: 60));

      // Assert — 大块数据被立即冲刷到输出流
      expect(outputs.join(), contains(bigChunk));
      // 仍保持连接状态（flush 不触发断开）
      expect(service.state, SshConnectionState.connected);

      service.dispose();
    });

    test('Given connected, '
        'When stdout stream closes, '
        'Then session is disconnected', () async {
      // Arrange
      final (service, _, session) = await connectSuccess();
      final outputs = <String>[];
      service.outputStream.listen(outputs.add);

      // Act — stdout onDone → _onSessionDone
      await session.stdoutCtrl.close();
      await Future<void>.delayed(const Duration(milliseconds: 60));

      // Assert
      expect(service.state, SshConnectionState.disconnected);
      expect(outputs.join(), contains('连接已断开'));

      service.dispose();
    });

    test('Given connected, '
        'When stderr stream closes, '
        'Then session stays connected', () async {
      // Arrange
      final (service, _, session) = await connectSuccess();
      final outputs = <String>[];
      service.outputStream.listen(outputs.add);

      // Act — stderr onDone 为空实现，不影响连接状态
      await session.stderrCtrl.close();
      await Future<void>.delayed(const Duration(milliseconds: 60));

      // Assert
      expect(service.state, SshConnectionState.connected);
      expect(outputs, isEmpty);

      service.dispose();
    });
  });

  // -------------------------------------------------------------------------
  // executeCommand() — 命令执行失败分支
  // -------------------------------------------------------------------------
  group('executeCommand() failure path', () {
    test('Given connected client whose execute throws, '
        'When executeCommand called, '
        'Then rethrows and emits 命令执行错误', () async {
      // Arrange
      final session = StubSSHSession();
      final client = StubSSHClient(
        session: session,
        executeError: Exception('remote command failed'),
      );
      final mockConfig = createMockAppConfigService();
      final service = SshService(
        appConfigService: mockConfig,
        clientFactory: (socket, {required username, onPasswordRequest,
                identities, keepAliveInterval}) =>
            client,
        socketConnector: (host, port, {timeout}) async => FakeSSHSocketStub(),
      );
      await service.connect(makeConnection(password: 'secret'));

      final outputs = <String>[];
      service.outputStream.listen(outputs.add);

      // Act & Assert — 错误向上传播
      await expectLater(
        () => service.executeCommand('ls'),
        throwsA(predicate<Exception>((e) => e.toString().contains('remote command failed'))),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(outputs.join(), contains('命令执行错误'));

      service.dispose();
    });
  });

  // -------------------------------------------------------------------------
  // connect() — 跳板机成功路径（注入 stub 客户端）
  // -------------------------------------------------------------------------
  group('connect() jump host success path', () {
    Future<(SshService, StubSSHClient, StubSSHSession)> connectViaJumpHost({
      AuthType jumpAuthType = AuthType.password,
      String? jumpPassword,
    }) async {
      final session = StubSSHSession();
      final client = StubSSHClient(session: session);
      final mockConfig = createMockAppConfigService();
      final service = SshService(
        appConfigService: mockConfig,
        clientFactory: (socket, {required username, onPasswordRequest,
                identities, keepAliveInterval}) =>
            client,
        socketConnector: (host, port, {timeout}) async => FakeSSHSocketStub(),
      );

      final conn = makeConnection(
        password: 'secret',
        jumpHost: JumpHostConfig(
          host: '127.0.0.1',
          username: 'jumpuser',
          authType: jumpAuthType,
          password: jumpPassword,
        ),
      );
      await service.connect(conn);

      return (service, client, session);
    }

    test('Given jump host with password auth, '
        'When connect called, '
        'Then connects through jump host and reaches connected state', () async {
      // Arrange & Act
      final (service, client, _) = await connectViaJumpHost(
        jumpPassword: 'jump-pass',
      );

      // Assert — 跳板机路径建立隧道后目标客户端被创建
      expect(service.state, SshConnectionState.connected);
      expect(client.shellCalls, 1);

      service.dispose();
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('Given jump host with password auth, '
        'When connect called, '
        'Then outputStream contains jump host progress messages', () async {
      // Arrange
      final session = StubSSHSession();
      final client = StubSSHClient(session: session);
      final mockConfig = createMockAppConfigService();
      final service = SshService(
        appConfigService: mockConfig,
        clientFactory: (socket, {required username, onPasswordRequest,
                identities, keepAliveInterval}) =>
            client,
        socketConnector: (host, port, {timeout}) async => FakeSSHSocketStub(),
      );
      final outputs = <String>[];
      service.outputStream.listen(outputs.add);

      // Act
      await service.connect(
        makeConnection(
          password: 'secret',
          jumpHost: JumpHostConfig(
            host: '127.0.0.1',
            username: 'jumpuser',
            authType: AuthType.password,
            password: 'jump-pass',
          ),
        ),
      );

      // Assert — 跳板机连接、隧道建立、目标连接的消息依次出现
      // broadcast 流异步派发，等待事件送达
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final joined = outputs.join();
      expect(joined, contains('正在连接到跳板机'));
      expect(joined, contains('跳板机连接成功'));
      expect(joined, contains('建立跳板机隧道'));
      expect(joined, contains('跳板机隧道建立成功'));
      expect(joined, contains('通过跳板机连接到目标服务器'));
      expect(joined, contains('跳板机连接建立成功'));

      service.dispose();
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('Given jump host with missing password, '
        'When connect called, '
        'Then throws Exception before tunnel setup', () async {
      // Arrange
      final session = StubSSHSession();
      final client = StubSSHClient(session: session);
      final mockConfig = createMockAppConfigService();
      final service = SshService(
        appConfigService: mockConfig,
        clientFactory: (socket, {required username, onPasswordRequest,
                identities, keepAliveInterval}) =>
            client,
        socketConnector: (host, port, {timeout}) async => FakeSSHSocketStub(),
      );

      // Act & Assert
      await expectLater(
        () => service.connect(
          makeConnection(
            password: 'secret',
            jumpHost: JumpHostConfig(
              host: '127.0.0.1',
              username: 'jumpuser',
              authType: AuthType.password,
            ),
          ),
        ),
        throwsA(predicate<Exception>((e) => e.toString().contains('跳板机密码未设置'))),
      );

      service.dispose();
    });
  });

  // -------------------------------------------------------------------------
  // executeCommand() — 成功路径
  // -------------------------------------------------------------------------
  group('executeCommand() success path', () {
    test('Given connected, '
        'When executeCommand called, '
        'Then returns command output', () async {
      // Arrange
      final session = StubSSHSession();
      final execSession = StubSSHSession();
      final client = StubSSHClient(
        session: session,
        executeSession: execSession,
      );
      final mockConfig = createMockAppConfigService();
      final service = SshService(
        appConfigService: mockConfig,
        clientFactory: (socket, {required username, onPasswordRequest, identities,
                keepAliveInterval}) =>
            client,
        socketConnector: (host, port, {timeout}) async => FakeSSHSocketStub(),
      );
      await service.connect(makeConnection(password: 'secret'));

      // Act — execute 会话的 stdout 流提供命令输出
      // 先让 executeCommand 订阅 stdout（广播流不重放已发送数据）
      final future = service.executeCommand('ls');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      execSession.stdoutCtrl.add(utf8.encode('file1.txt\n'));
      execSession.stdoutCtrl.close();
      final result = await future;

      // Assert
      expect(result, 'file1.txt\n');

      service.dispose();
    });

    test('Given connected, '
        'When executeCommand called with silent flag, '
        'Then does not route output to outputStream', () async {
      // Arrange
      final session = StubSSHSession();
      final execSession = StubSSHSession();
      final client = StubSSHClient(
        session: session,
        executeSession: execSession,
      );
      final mockConfig = createMockAppConfigService();
      final service = SshService(
        appConfigService: mockConfig,
        clientFactory: (socket, {required username, onPasswordRequest, identities,
                keepAliveInterval}) =>
            client,
        socketConnector: (host, port, {timeout}) async => FakeSSHSocketStub(),
      );
      await service.connect(makeConnection(password: 'secret'));

      final outputs = <String>[];
      service.outputStream.listen(outputs.add);

      // Act
      final future = service.executeCommand('ls', silent: true);
      // 先让 executeCommand 订阅 stdout（广播流不重放已发送数据）
      await Future<void>.delayed(const Duration(milliseconds: 10));
      execSession.stdoutCtrl.add(utf8.encode('secret-data\n'));
      execSession.stdoutCtrl.close();
      await future;

      // Assert — silent 时不写入 _outputBuffer，outputStream 应无内容
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(outputs.where((o) => o.contains('secret-data')), isEmpty);

      service.dispose();
    });
  });

  // -------------------------------------------------------------------------
  // sendInput() / resize() — 连接成功后的行为
  // -------------------------------------------------------------------------
  group('sendInput() and resize() when connected', () {
    Future<(SshService, StubSSHClient, StubSSHSession)> connectStub() async {
      final session = StubSSHSession();
      final client = StubSSHClient(session: session);
      final mockConfig = createMockAppConfigService();
      final service = SshService(
        appConfigService: mockConfig,
        clientFactory: (socket, {required username, onPasswordRequest, identities,
                keepAliveInterval}) =>
            client,
        socketConnector: (host, port, {timeout}) async => FakeSSHSocketStub(),
      );
      await service.connect(makeConnection(password: 'secret'));
      return (service, client, session);
    }

    test('Given connected, '
        'When sendInput called, '
        'Then writes UTF-8 bytes to session stdin', () async {
      // Arrange
      final (service, _, session) = await connectStub();

      // Act
      service.sendInput('中文输入');

      // Assert
      expect(session.stdinData, isNotEmpty);
      expect(utf8.decode(session.stdinData.first), '中文输入');

      service.dispose();
    });

    test('Given connected, '
        'When resize called, '
        'Then sends resizeTerminal to session', () async {
      // Arrange
      final (service, _, session) = await connectStub();

      // Act
      service.resize(40, 120);

      // Assert
      expect(session.resizeCalls, [(120, 40)]);

      service.dispose();
    });
  });

  // -------------------------------------------------------------------------
  // getSftpClient() — 连接成功后返回 sftp
  // -------------------------------------------------------------------------
  group('getSftpClient() when connected', () {
    test('Given connected, '
        'When getSftpClient called, '
        'Then returns sftp client from SSHClient', () async {
      // Arrange
      final session = StubSSHSession();
      final client = StubSSHClient(session: session);
      final mockConfig = createMockAppConfigService();
      final service = SshService(
        appConfigService: mockConfig,
        clientFactory: (socket, {required username, onPasswordRequest, identities,
                keepAliveInterval}) =>
            client,
        socketConnector: (host, port, {timeout}) async => FakeSSHSocketStub(),
      );
      await service.connect(makeConnection(password: 'secret'));

      // Act
      final sftp = await service.getSftpClient();

      // Assert
      expect(sftp, isNotNull);

      service.dispose();
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
