import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart' show Terminal;
import 'package:mocktail/mocktail.dart';

import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/data/models/terminal_config.dart';
import 'package:lbp_ssh/domain/services/terminal_service.dart';
import 'package:lbp_ssh/domain/services/terminal_input_service.dart';
import 'package:lbp_ssh/domain/services/app_config_service.dart';
import 'package:lbp_ssh/domain/services/local_terminal_service.dart';
import 'package:lbp_ssh/domain/services/ssh_service.dart';
import 'package:lbp_ssh/presentation/providers/terminal_provider.dart';
import 'package:lbp_ssh/presentation/providers/service_providers.dart';

/// 绑定一个临时端口后立即关闭，用于触发真实的连接拒绝（SocketException）。
Future<int> _closedLocalPort() async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = server.port;
  await server.close();
  return port;
}

// Mock classes
class MockTerminalService extends Mock implements TerminalService {}

class MockTerminalInputService extends Mock implements TerminalInputService {}

class MockAppConfigService extends Mock implements AppConfigService {}

class MockTerminalSession extends Mock implements TerminalSession {}

class MockSshService extends Mock implements SshService {}

class MockTerminal extends Mock implements Terminal {}

/// 可成功 start() 的本地终端替身：测试环境 PTY 原生库未打包，
/// 真实 LocalTerminalService.start() 必然抛错，此替身用于覆盖成功路径。
class StubLocalTerminalService extends LocalTerminalService {
  bool startCalled = false;
  final resizeCalls = <(int, int)>[];

  @override
  Future<void> start() async {
    startCalled = true;
  }

  @override
  void resize(int rows, int columns) {
    resizeCalls.add((rows, columns));
  }
}

void main() {
  late MockTerminalService mockTerminalService;
  late MockAppConfigService mockAppConfigService;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(TerminalConfig.defaultConfig);
    registerFallbackValue(MockTerminalInputService());
    registerFallbackValue(
      SshConnection(
        id: 'fallback',
        name: 'fallback',
        host: '127.0.0.1',
        username: 'fallback',
        authType: AuthType.password,
      ),
    );
  });

  setUp(() {
    mockTerminalService = MockTerminalService();
    mockAppConfigService = MockAppConfigService();

    // Setup default mock behavior
    when(
      () => mockAppConfigService.terminal,
    ).thenReturn(TerminalConfig.defaultConfig);
    when(() => mockTerminalService.getAllSessions()).thenReturn([]);

    container = ProviderContainer(
      overrides: [
        terminalServiceProvider.overrideWithValue(mockTerminalService),
        appConfigServiceProvider.overrideWithValue(mockAppConfigService),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('TerminalNotifier', () {
    group('initial state', () {
      test('Given new provider, When created, Then has empty sessions', () {
        final state = container.read(terminalProvider);
        expect(state.sessions, isEmpty);
        expect(state.activeSessionId, isNull);
        expect(state.activeSession, isNull);
      });
    });

    group('switchToSession', () {
      test(
        'Given existing session, When switchToSession called, Then updates activeSessionId',
        () {
          // Arrange (Given)
          final mockSession = MockTerminalSession();
          when(() => mockSession.id).thenReturn('session1');
          when(
            () => mockTerminalService.getSession('session1'),
          ).thenReturn(mockSession);
          when(
            () => mockTerminalService.getAllSessions(),
          ).thenReturn([mockSession]);

          // Recreate container with sessions available
          container = ProviderContainer(
            overrides: [
              terminalServiceProvider.overrideWithValue(mockTerminalService),
              appConfigServiceProvider.overrideWithValue(mockAppConfigService),
            ],
          );

          // Act (When)
          container.read(terminalProvider.notifier).switchToSession('session1');

          // Assert (Then)
          final state = container.read(terminalProvider);
          expect(state.activeSessionId, 'session1');
          verify(() => mockTerminalService.getSession('session1')).called(1);
        },
      );

      test(
        'Given non-existing session, When switchToSession called, Then keeps activeSessionId unchanged',
        () {
          // Arrange (Given)
          when(
            () => mockTerminalService.getSession('nonexistent'),
          ).thenReturn(null);

          // Act (When)
          container
              .read(terminalProvider.notifier)
              .switchToSession('nonexistent');

          // Assert (Then)
          final state = container.read(terminalProvider);
          expect(state.activeSessionId, isNull);
        },
      );
    });

    group('closeSession', () {
      test(
        'Given session exists, When closeSession called, Then closes session and updates activeSessionId',
        () {
          // Arrange (Given)
          final mockSession = MockTerminalSession();
          when(() => mockSession.id).thenReturn('session1');
          when(
            () => mockTerminalService.getSession('session1'),
          ).thenReturn(mockSession);
          when(() => mockTerminalService.getAllSessions()).thenReturn([]);

          container = ProviderContainer(
            overrides: [
              terminalServiceProvider.overrideWithValue(mockTerminalService),
              appConfigServiceProvider.overrideWithValue(mockAppConfigService),
            ],
          );
          container.read(terminalProvider.notifier).switchToSession('session1');

          // Act (When)
          container.read(terminalProvider.notifier).closeSession('session1');

          // Assert (Then)
          verify(() => mockTerminalService.closeSession('session1')).called(1);
          final state = container.read(terminalProvider);
          expect(state.activeSessionId, isNull);
        },
      );
    });

    group('getSession', () {
      test(
        'Given session exists, When getSession called, Then returns session',
        () {
          // Arrange (Given)
          final mockSession = MockTerminalSession();
          when(() => mockSession.id).thenReturn('session1');
          when(
            () => mockTerminalService.getSession('session1'),
          ).thenReturn(mockSession);

          // Act (When)
          final result = container
              .read(terminalProvider.notifier)
              .getSession('session1');

          // Assert (Then)
          expect(result, isNotNull);
          expect(result!.id, 'session1');
        },
      );

      test(
        'Given session does not exist, When getSession called, Then returns null',
        () {
          // Arrange (Given)
          when(
            () => mockTerminalService.getSession('nonexistent'),
          ).thenReturn(null);

          // Act (When)
          final result = container
              .read(terminalProvider.notifier)
              .getSession('nonexistent');

          // Assert (Then)
          expect(result, isNull);
        },
      );
    });

    group('session management', () {
      test(
        'Given no sessions, When accessing sessions, Then returns empty list',
        () {
          // Act (When)
          final state = container.read(terminalProvider);

          // Assert (Then)
          expect(state.sessions, isEmpty);
        },
      );
    });

    group('activeSession getter', () {
      test(
        'Given no activeSessionId, When accessing activeSession, Then returns null',
        () {
          // Arrange (Given)
          const state = TerminalState();

          // Act (When) & Assert (Then)
          expect(state.activeSession, isNull);
        },
      );

      test(
        'Given activeSessionId without matching session, When accessing activeSession, Then returns null',
        () {
          // Arrange (Given)
          const state = TerminalState(activeSessionId: 'ghost');

          // Act (When) & Assert (Then)
          expect(state.activeSession, isNull);
        },
      );

      test(
        'Given activeSessionId with matching session, When accessing activeSession, Then returns that session',
        () {
          // Arrange (Given)
          final session = TerminalSession(
            id: 's1',
            name: 'S1',
            inputService: _MockInputService(),
          );
          const state = TerminalState(activeSessionId: 's1');

          // 直接构造带 sessions 的实例
          final withSession = TerminalState(
            sessions: [session],
            activeSessionId: 's1',
          );

          // Act (When) & Assert (Then)
          expect(withSession.activeSession, same(session));
          expect(state.activeSession, isNull);
        },
      );
    });

    group('disposeServices', () {
      test(
        'Given no services registered, When disposeServices called, Then does not throw',
        () {
          // Act (When) & Assert (Then)
          expect(
            container.read(terminalProvider.notifier).disposeServices,
            returnsNormally,
          );
        },
      );
    });

    group('TerminalState.copyWith', () {
      test(
        'Given clearActive true, When copyWith called, Then activeSessionId is cleared',
        () {
          // Arrange (Given)
          const state = TerminalState(activeSessionId: 's1');

          // Act (When)
          final result = state.copyWith(clearActive: true);

          // Assert (Then)
          expect(result.activeSessionId, isNull);
        },
      );

      test(
        'Given new activeSessionId, When copyWith called, Then replaces activeSessionId',
        () {
          // Arrange (Given)
          const state = TerminalState(activeSessionId: 's1');

          // Act (When)
          final result = state.copyWith(activeSessionId: 's2');

          // Assert (Then)
          expect(result.activeSessionId, 's2');
        },
      );

      test(
        'Given no new activeSessionId, When copyWith called with clearActive false, '
        'Then keeps existing activeSessionId',
        () {
          // Arrange (Given)
          const state = TerminalState(activeSessionId: 's1');

          // Act (When)
          final result = state.copyWith();

          // Assert (Then) — clearActive 默认 false，沿用原 activeSessionId
          expect(result.activeSessionId, 's1');
        },
      );
    });

    group('TerminalState equality', () {
      test(
        'Given identical fields, When compared, Then equal with same hashCode',
        () {
          // Arrange (Given)
          const a = TerminalState(activeSessionId: 's1');
          const b = TerminalState(activeSessionId: 's1');

          // Act (When) & Assert (Then)
          expect(a, b);
          expect(a.hashCode, b.hashCode);
        },
      );

      test(
        'Given different activeSessionId, When compared, Then not equal',
        () {
          // Arrange (Given)
          const a = TerminalState(activeSessionId: 's1');
          const b = TerminalState(activeSessionId: 's2');

          // Act (When) & Assert (Then)
          expect(a == b, isFalse);
        },
      );

      test('Given different sessions, When compared, Then not equal', () {
        // Arrange (Given)
        const a = TerminalState();
        const b = TerminalState(activeSessionId: 's1');

        // Act (When) & Assert (Then)
        expect(a == b, isFalse);
      });
    });

    group('closeSession with remaining sessions', () {
      test('Given closing the active session with remaining sessions, '
          'Then activates the first remaining session', () {
        // Arrange (Given)
        final session1 = MockTerminalSession();
        final session2 = MockTerminalSession();
        when(() => session1.id).thenReturn('s1');
        when(() => session2.id).thenReturn('s2');
        when(() => mockTerminalService.getSession('s1')).thenReturn(session1);
        when(
          () => mockTerminalService.getAllSessions(),
        ).thenReturn([session1, session2]);

        container = ProviderContainer(
          overrides: [
            terminalServiceProvider.overrideWithValue(mockTerminalService),
            appConfigServiceProvider.overrideWithValue(mockAppConfigService),
          ],
        );
        container.read(terminalProvider.notifier).switchToSession('s1');
        expect(container.read(terminalProvider).activeSessionId, 's1');

        // 关闭后只剩 session2
        when(() => mockTerminalService.getAllSessions()).thenReturn([session2]);

        // Act (When)
        container.read(terminalProvider.notifier).closeSession('s1');

        // Assert (Then)
        verify(() => mockTerminalService.closeSession('s1')).called(1);
        final state = container.read(terminalProvider);
        expect(state.sessions, [session2]);
        expect(state.activeSessionId, 's2');
      });

      test(
        'Given closing a non-active session, Then keeps activeSessionId unchanged',
        () {
          // Arrange (Given)
          final session1 = MockTerminalSession();
          final session2 = MockTerminalSession();
          when(() => session1.id).thenReturn('s1');
          when(() => session2.id).thenReturn('s2');
          when(() => mockTerminalService.getSession('s1')).thenReturn(session1);
          when(() => mockTerminalService.getSession('s2')).thenReturn(session2);
          when(
            () => mockTerminalService.getAllSessions(),
          ).thenReturn([session1, session2]);

          container = ProviderContainer(
            overrides: [
              terminalServiceProvider.overrideWithValue(mockTerminalService),
              appConfigServiceProvider.overrideWithValue(mockAppConfigService),
            ],
          );
          container.read(terminalProvider.notifier).switchToSession('s1');

          when(
            () => mockTerminalService.getAllSessions(),
          ).thenReturn([session1]);

          // Act (When)
          container.read(terminalProvider.notifier).closeSession('s2');

          // Assert (Then)
          verify(() => mockTerminalService.closeSession('s2')).called(1);
          final state = container.read(terminalProvider);
          expect(state.activeSessionId, 's1');
          expect(state.sessions, [session1]);
        },
      );
    });

    group('getSshService', () {
      test(
        'Given no service registered, When getSshService called, Then returns null',
        () {
          // Act (When)
          final result = container
              .read(terminalProvider.notifier)
              .getSshService('none');

          // Assert (Then)
          expect(result, isNull);
        },
      );
    });

    group('reconnectSession', () {
      test('Given no matching session in state, When reconnectSession called, '
          'Then returns without changing state', () async {
        // Arrange (Given)
        final oldSession = MockTerminalSession();
        when(() => oldSession.id).thenReturn('s1');
        when(() => mockTerminalService.getSession('s1')).thenReturn(oldSession);
        when(() => mockTerminalService.getAllSessions()).thenReturn([]);

        // Act (When)
        await container.read(terminalProvider.notifier).reconnectSession('s1');

        // Assert (Then) — state.sessions 为空，提前返回，不创建新服务
        verify(() => mockTerminalService.getSession('s1')).called(1);
        final state = container.read(terminalProvider);
        expect(state.sessions, isEmpty);
        expect(state.activeSessionId, isNull);
      });

      test('Given existing session with valid serverInfo, '
          'When reconnectSession called, '
          'Then reconnects via ssh service and updates state', () async {
        // Arrange — mock SSH 服务（connect 成功）
        final mockSshService = MockSshService();
        when(() => mockSshService.connect(any())).thenAnswer((_) async {});
        when(
          () => mockSshService.executeCommand(
            any(),
            silent: any(named: 'silent'),
          ),
        ).thenAnswer((_) async => '/home/user');
        when(() => mockSshService.dispose()).thenReturn(null);

        final mockSession = MockTerminalSession();
        when(() => mockSession.id).thenReturn('ssh-session');
        when(() => mockSession.name).thenReturn('MyServer');
        when(() => mockSession.serverInfo).thenReturn('root@127.0.0.1');
        when(() => mockSession.setWorkingDirectory(any())).thenReturn(null);
        when(
          () => mockTerminalService.createSession(
            id: any(named: 'id'),
            name: any(named: 'name'),
            inputService: any(named: 'inputService'),
            terminalConfig: any(named: 'terminalConfig'),
            serverInfo: any(named: 'serverInfo'),
          ),
        ).thenReturn(mockSession);
        when(
          () => mockTerminalService.getAllSessions(),
        ).thenReturn([mockSession]);
        when(
          () => mockTerminalService.getSession(any()),
        ).thenReturn(mockSession);

        container = ProviderContainer(
          overrides: [
            terminalServiceProvider.overrideWithValue(mockTerminalService),
            appConfigServiceProvider.overrideWithValue(mockAppConfigService),
            sshServiceFactoryProvider.overrideWithValue(() => mockSshService),
          ],
        );

        // 先建立一个 SSH 会话，让 state.sessions 非空
        final conn = SshConnection(
          id: 'conn1',
          name: 'MyServer',
          host: '127.0.0.1',
          username: 'root',
          authType: AuthType.password,
          password: 'secret',
        );
        await container.read(terminalProvider.notifier).createSession(conn);

        // Act — 重连已存在的会话（id 匹配 mockSession.id）
        await container
            .read(terminalProvider.notifier)
            .reconnectSession('ssh-session');

        // Assert — 通过 serverInfo 解析 host/username 发起连接，state 更新
        // createSession + reconnectSession 各连接一次
        verify(() => mockSshService.connect(any())).called(2);
        final state = container.read(terminalProvider);
        expect(state.sessions, [mockSession]);
        expect(state.activeSessionId, 'ssh-session');
      });
    });

    group('createLocalTerminal / initialize', () {
      // 测试环境中 flutter_pty 原生库未打包，LocalTerminalService.start()
      // 必然抛错——用这条确定性路径覆盖 createLocalTerminal 的
      // 前半段（会话注册、目录初始化）与 initialize() 的静默吞错。
      void stubCreateSession() {
        final mockSession = MockTerminalSession();
        when(
          () => mockTerminalService.createSession(
            id: any(named: 'id'),
            name: any(named: 'name'),
            inputService: any(named: 'inputService'),
            terminalConfig: any(named: 'terminalConfig'),
            isLocal: any(named: 'isLocal'),
          ),
        ).thenReturn(mockSession);
        when(
          () => mockSession.setWorkingDirectoryAndUpdateName(any()),
        ).thenReturn(null);
      }

      test('Given LocalTerminalService start fails, '
          'When initialize called, Then does not throw', () async {
        stubCreateSession();

        // Act (When) — start() 抛错被 initialize() 静默吞掉
        await expectLater(
          container.read(terminalProvider.notifier).initialize(),
          completes,
        );
      });

      test('Given LocalTerminalService start fails, '
          'When createLocalTerminal called, Then rethrows', () async {
        stubCreateSession();

        // Act (When) & Assert (Then) — 错误向上传播
        await expectLater(
          container.read(terminalProvider.notifier).createLocalTerminal(),
          throwsA(anything),
        );
      });

      test(
        'Given failed createLocalTerminal, '
        'When disposeServices called, Then disposes registered services',
        () async {
          stubCreateSession();
          await container.read(terminalProvider.notifier).initialize();

          // Act (When) — _services 中已注册失败的 localService
          expect(
            container.read(terminalProvider.notifier).disposeServices,
            returnsNormally,
          );
        },
      );
    });

    group('createLocalTerminal with custom shellPath', () {
      test('Given terminal config with non-empty shellPath, '
          'When createLocalTerminal called, '
          'Then applies shell path before start fails', () async {
        // Arrange (Given)
        when(
          () => mockAppConfigService.terminal,
        ).thenReturn(TerminalConfig(shellPath: '/bin/zsh'));

        final mockSession = MockTerminalSession();
        when(
          () => mockTerminalService.createSession(
            id: any(named: 'id'),
            name: any(named: 'name'),
            inputService: any(named: 'inputService'),
            terminalConfig: any(named: 'terminalConfig'),
            isLocal: any(named: 'isLocal'),
          ),
        ).thenReturn(mockSession);
        when(
          () => mockSession.setWorkingDirectoryAndUpdateName(any()),
        ).thenReturn(null);

        // Act (When) — shellPath 非空会执行 setShellPath(第84行)，
        // 随后 start() 抛错（PTY 原生库未打包）向上传播
        await expectLater(
          container.read(terminalProvider.notifier).createLocalTerminal(),
          throwsA(anything),
        );
      });
    });

    group('createLocalTerminal success path', () {
      late StubLocalTerminalService stubLocal;

      setUp(() {
        // post-frame 回调需要 WidgetsBinding（testWidgets 自动初始化）
        TestWidgetsFlutterBinding.ensureInitialized();
        stubLocal = StubLocalTerminalService();
      });

      /// 配置 mock 会话/终端并重建 container（注入可成功 start 的本地服务工厂）
      MockTerminalSession stubSuccessSetup({
        int viewWidth = 120,
        int viewHeight = 40,
      }) {
        final mockSession = MockTerminalSession();
        final mockTerminal = MockTerminal();
        when(() => mockSession.id).thenReturn('local-session');
        when(() => mockSession.terminal).thenReturn(mockTerminal);
        when(() => mockTerminal.viewWidth).thenReturn(viewWidth);
        when(() => mockTerminal.viewHeight).thenReturn(viewHeight);
        when(
          () => mockTerminalService.createSession(
            id: any(named: 'id'),
            name: any(named: 'name'),
            inputService: any(named: 'inputService'),
            terminalConfig: any(named: 'terminalConfig'),
            isLocal: any(named: 'isLocal'),
          ),
        ).thenReturn(mockSession);
        when(
          () => mockSession.setWorkingDirectoryAndUpdateName(any()),
        ).thenReturn(null);
        when(
          () => mockTerminalService.getAllSessions(),
        ).thenReturn([mockSession]);

        container = ProviderContainer(
          overrides: [
            terminalServiceProvider.overrideWithValue(mockTerminalService),
            appConfigServiceProvider.overrideWithValue(mockAppConfigService),
            localTerminalServiceFactoryProvider.overrideWithValue(
              () => stubLocal,
            ),
          ],
        );
        return mockSession;
      }

      testWidgets('Given local service starts successfully, '
          'When createLocalTerminal called, '
          'Then state has active session and service is registered', (
        tester,
      ) async {
        // Arrange
        final mockSession = stubSuccessSetup();

        // Act
        final session = await container
            .read(terminalProvider.notifier)
            .createLocalTerminal();

        // Assert — sessionId 由 UUID 生成，activeSessionId 非空即可
        expect(session, same(mockSession));
        expect(stubLocal.startCalled, isTrue);
        final state = container.read(terminalProvider);
        expect(state.activeSessionId, isNotNull);
        expect(state.sessions, [mockSession]);
      });

      testWidgets('Given session with positive view size, '
          'When post-frame callback runs, '
          'Then local service receives resize with view dimensions', (
        tester,
      ) async {
        // Arrange — viewWidth/viewHeight 使用默认值 120/40
        stubSuccessSetup();

        // Act — post-frame 回调需显式调度帧才触发（纯逻辑测试无 widget 渲染）
        await container.read(terminalProvider.notifier).createLocalTerminal();
        tester.binding.scheduleFrame();
        await tester.pump();

        // Assert
        expect(stubLocal.resizeCalls, [(40, 120)]);
      });

      testWidgets('Given session with zero view size, '
          'When post-frame callback runs, '
          'Then resize is skipped', (tester) async {
        // Arrange
        stubSuccessSetup(viewWidth: 0, viewHeight: 0);

        // Act — 显式调度帧以触发 post-frame 回调
        await container.read(terminalProvider.notifier).createLocalTerminal();
        tester.binding.scheduleFrame();
        await tester.pump();

        // Assert
        expect(stubLocal.resizeCalls, isEmpty);
      });

      testWidgets('Given onDirectoryChange callback fires, '
          'Then session name is updated and state refreshes', (tester) async {
        // Arrange
        final mockSession = stubSuccessSetup();
        await container.read(terminalProvider.notifier).createLocalTerminal();

        // Act — 触发目录变化回调
        stubLocal.onDirectoryChange?.call('/new/dir');

        // Assert
        verify(
          () => mockSession.setWorkingDirectoryAndUpdateName('/new/dir'),
        ).called(1);
        expect(container.read(terminalProvider).sessions, [mockSession]);
      });

      testWidgets('Given onActualDirectoryChange callback fires, '
          'Then session name is updated and state refreshes', (tester) async {
        // Arrange
        final mockSession = stubSuccessSetup();
        await container.read(terminalProvider.notifier).createLocalTerminal();

        // Act — 触发实际目录变化回调
        stubLocal.onActualDirectoryChange?.call('/actual/dir');

        // Assert
        verify(
          () => mockSession.setWorkingDirectoryAndUpdateName('/actual/dir'),
        ).called(1);
        expect(container.read(terminalProvider).sessions, [mockSession]);
      });
    });

    group('createSession (SSH) failure path', () {
      test('Given unreachable server, When createSession called, '
          'Then closes session and rethrows', () async {
        // Arrange (Given)
        final mockSession = MockTerminalSession();
        when(() => mockSession.id).thenReturn('ssh-session');
        when(
          () => mockTerminalService.createSession(
            id: any(named: 'id'),
            name: any(named: 'name'),
            inputService: any(named: 'inputService'),
            terminalConfig: any(named: 'terminalConfig'),
            serverInfo: any(named: 'serverInfo'),
          ),
        ).thenReturn(mockSession);
        when(
          () => mockTerminalService.getAllSessions(),
        ).thenReturn([mockSession]);
        when(() => mockTerminalService.closeSession(any())).thenReturn(null);
        when(
          () => mockTerminalService.getSession(any()),
        ).thenReturn(mockSession);

        final port = await _closedLocalPort();
        final conn = SshConnection(
          id: 'conn1',
          name: 'MyServer',
          host: '127.0.0.1',
          port: port,
          username: 'root',
          authType: AuthType.password,
          password: 'secret',
          connectTimeout: 1000,
        );

        // Act (When) & Assert (Then) — connect 失败 → closeSession + rethrow
        await expectLater(
          container.read(terminalProvider.notifier).createSession(conn),
          throwsA(isA<Exception>()),
        );
        verify(() => mockTerminalService.closeSession(any())).called(1);
      });
    });

    group('createSession (SSH) success path', () {
      late MockSshService mockSshService;

      /// 配置 mock 会话与成功 SSH 服务，重建 container
      MockTerminalSession stubSuccessSetup({String pwd = '/home/user'}) {
        mockSshService = MockSshService();
        when(() => mockSshService.connect(any())).thenAnswer((_) async {});
        when(
          () => mockSshService.executeCommand(
            any(),
            silent: any(named: 'silent'),
          ),
        ).thenAnswer((_) async => pwd);

        final mockSession = MockTerminalSession();
        when(() => mockSession.id).thenReturn('ssh-session');
        when(() => mockSession.setWorkingDirectory(any())).thenReturn(null);
        when(
          () => mockTerminalService.createSession(
            id: any(named: 'id'),
            name: any(named: 'name'),
            inputService: any(named: 'inputService'),
            terminalConfig: any(named: 'terminalConfig'),
            serverInfo: any(named: 'serverInfo'),
          ),
        ).thenReturn(mockSession);
        when(
          () => mockTerminalService.getAllSessions(),
        ).thenReturn([mockSession]);
        when(
          () => mockTerminalService.getSession(any()),
        ).thenReturn(mockSession);

        container = ProviderContainer(
          overrides: [
            terminalServiceProvider.overrideWithValue(mockTerminalService),
            appConfigServiceProvider.overrideWithValue(mockAppConfigService),
            sshServiceFactoryProvider.overrideWithValue(() => mockSshService),
          ],
        );
        return mockSession;
      }

      test('Given SSH connect succeeds, '
          'When createSession called, '
          'Then sets working directory from pwd and updates state', () async {
        // Arrange — pwd 使用默认值 '/home/user'
        stubSuccessSetup();

        final conn = SshConnection(
          id: 'conn1',
          name: 'MyServer',
          host: '127.0.0.1',
          username: 'root',
          authType: AuthType.password,
          password: 'secret',
        );

        // Act
        final session = await container
            .read(terminalProvider.notifier)
            .createSession(conn);

        // Assert — pwd 结果写入会话工作目录
        verify(() => mockSshService.connect(conn)).called(1);
        verify(
          () => mockSshService.executeCommand('pwd', silent: true),
        ).called(1);
        verify(() => session.setWorkingDirectory('/home/user')).called(1);

        final state = container.read(terminalProvider);
        expect(state.sessions, [session]);
        expect(state.activeSessionId, isNotNull);
      });

      test('Given SSH connect succeeds but pwd fails, '
          'When createSession called, '
          'Then keeps default directory and still updates state', () async {
        // Arrange — pwd 抛错
        stubSuccessSetup();
        when(
          () => mockSshService.executeCommand(
            any(),
            silent: any(named: 'silent'),
          ),
        ).thenThrow(Exception('pwd failed'));

        final conn = SshConnection(
          id: 'conn1',
          name: 'MyServer',
          host: '127.0.0.1',
          username: 'root',
          authType: AuthType.password,
          password: 'secret',
        );

        // Act
        final session = await container
            .read(terminalProvider.notifier)
            .createSession(conn);

        // Assert — pwd 失败时静默使用默认目录，会话仍建立
        verifyNever(() => session.setWorkingDirectory(any()));
        final state = container.read(terminalProvider);
        expect(state.sessions, [session]);
      });
    });
  });
}

class _MockInputService implements TerminalInputService {
  @override
  Stream<String> get outputStream => const Stream.empty();

  @override
  Stream<bool> get stateStream => const Stream.empty();

  @override
  Future<String> executeCommand(String command, {bool silent = false}) async =>
      '';

  @override
  void sendInput(String input) {}

  @override
  void resize(int rows, int columns) {}

  @override
  void dispose() {}
}
