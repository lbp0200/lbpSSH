import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:lbp_ssh/data/models/terminal_config.dart';
import 'package:lbp_ssh/domain/services/terminal_service.dart';
import 'package:lbp_ssh/domain/services/terminal_input_service.dart';
import 'package:lbp_ssh/domain/services/app_config_service.dart';
import 'package:lbp_ssh/domain/services/ssh_service.dart';
import 'package:lbp_ssh/presentation/providers/terminal_provider.dart';
import 'package:lbp_ssh/presentation/providers/service_providers.dart';

// Mock classes
class MockTerminalService extends Mock implements TerminalService {}

class MockTerminalInputService extends Mock implements TerminalInputService {}

class MockAppConfigService extends Mock implements AppConfigService {}

class MockTerminalSession extends Mock implements TerminalSession {}

class MockSshService extends Mock implements SshService {}

void main() {
  late MockTerminalService mockTerminalService;
  late MockAppConfigService mockAppConfigService;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(TerminalConfig.defaultConfig);
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
          const state = TerminalState(
            activeSessionId: 's1',
          );

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
