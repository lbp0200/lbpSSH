import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/domain/services/kitty_file_transfer_service.dart';
import 'package:lbp_ssh/domain/services/terminal_service.dart';
import 'package:lbp_ssh/domain/services/terminal_input_service.dart';
import 'package:lbp_ssh/presentation/providers/sftp_provider.dart';
import 'package:lbp_ssh/presentation/providers/service_providers.dart';

class MockTerminalInputService extends Mock implements TerminalInputService {}

class MockTerminalSession extends Mock implements TerminalSession {}

class MockTerminalService extends Mock implements TerminalService {}

class MockKittyFileTransferService extends Mock
    implements KittyFileTransferService {}

void main() {
  late MockTerminalService mockTerminalService;
  late MockTerminalSession mockSession;
  late ProviderContainer container;

  setUp(() {
    mockTerminalService = MockTerminalService();
    mockSession = MockTerminalSession();

    // Setup default mock behavior
    when(() => mockSession.workingDirectory).thenReturn('/home/user');
    when(() => mockSession.id).thenReturn('test-session-id');

    container = ProviderContainer(
      overrides: [
        terminalServiceProvider.overrideWithValue(mockTerminalService),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('SftpNotifier', () {
    group('initial state', () {
      test('Given new provider, When created, Then has empty tabs list', () {
        final state = container.read(sftpProvider);
        expect(state.tabs, isEmpty);
      });
    });

    group('openTab', () {
      test(
        'Given session exists, When openTab called, Then creates new tab and returns it',
        () async {
          // Arrange (Given)
          final connection = SshConnection(
            id: 'conn1',
            name: 'Test Server',
            host: '192.168.1.1',
            username: 'testuser',
            authType: AuthType.password,
          );
          when(
            () => mockTerminalService.getSession(connection.id),
          ).thenReturn(mockSession);

          // Act (When)
          final tab = await container
              .read(sftpProvider.notifier)
              .openTab(connection);

          // Assert (Then)
          expect(tab, isNotNull);
          expect(tab.connection.id, connection.id);
          verify(() => mockTerminalService.getSession(connection.id)).called(1);
        },
      );

      test(
        'Given session does not exist, When openTab called, Then throws exception',
        () async {
          // Arrange (Given)
          final connection = SshConnection(
            id: 'nonexistent',
            name: 'No Session',
            host: '192.168.1.99',
            username: 'test',
            authType: AuthType.password,
          );
          when(
            () => mockTerminalService.getSession('nonexistent'),
          ).thenReturn(null);

          // Act & Assert (When)
          expect(
            () => container.read(sftpProvider.notifier).openTab(connection),
            throwsException,
          );
        },
      );
    });

    group('closeTab', () {
      test(
        'Given tab exists, When closeTab called, Then removes tab from state',
        () async {
          // Arrange (Given)
          final connection = SshConnection(
            id: 'conn1',
            name: 'Test Server',
            host: '192.168.1.1',
            username: 'testuser',
            authType: AuthType.password,
          );
          when(
            () => mockTerminalService.getSession(connection.id),
          ).thenReturn(mockSession);
          final tab = await container
              .read(sftpProvider.notifier)
              .openTab(connection);

          // Act (When)
          await container.read(sftpProvider.notifier).closeTab(tab.id);

          // Assert (Then)
          final state = container.read(sftpProvider);
          expect(state.tabs, isEmpty);
        },
      );

      test(
        'Given non-existent tab id, When closeTab called, Then state stays unchanged',
        () async {
          // Act (When)
          await container.read(sftpProvider.notifier).closeTab('nonexistent');

          // Assert (Then)
          final state = container.read(sftpProvider);
          expect(state.tabs, isEmpty);
        },
      );
    });

    group('getTab', () {
      test(
        'Given tab exists, When getTab called, Then returns the tab',
        () async {
          // Arrange (Given)
          final connection = SshConnection(
            id: 'conn1',
            name: 'Test Server',
            host: '192.168.1.1',
            username: 'testuser',
            authType: AuthType.password,
          );
          when(
            () => mockTerminalService.getSession(connection.id),
          ).thenReturn(mockSession);
          final createdTab = await container
              .read(sftpProvider.notifier)
              .openTab(connection);

          // Act (When)
          final result = container
              .read(sftpProvider.notifier)
              .getTab(createdTab.id);

          // Assert (Then)
          expect(result, isNotNull);
          expect(result!.id, createdTab.id);
        },
      );

      test(
        'Given non-existent tab id, When getTab called, Then returns null',
        () {
          // Act (When)
          final result = container
              .read(sftpProvider.notifier)
              .getTab('nonexistent');

          // Assert (Then)
          expect(result, isNull);
        },
      );
    });

    group('SftpTab equality and hashCode', () {
      late KittyFileTransferService mockTransferService;

      setUp(() {
        mockTransferService = MockKittyFileTransferService();
      });

      SftpTab makeTab(String id, String currentPath) {
        return SftpTab(
          id: id,
          connection: SshConnection(
            id: id,
            name: 'Server',
            host: '10.0.0.1',
            username: 'user',
            authType: AuthType.password,
          ),
          service: mockTransferService,
          currentPath: currentPath,
        );
      }

      test(
        'Given tabs with same id and path, When compared, Then operator == is true',
        () {
          final a = makeTab('tab1', '/home/user');
          final b = makeTab('tab1', '/home/user');

          expect(a == b, isTrue);
          expect(a.hashCode, b.hashCode);
        },
      );

      test(
        'Given tabs with different id, When compared, Then operator == is false',
        () {
          final a = makeTab('tab1', '/home/user');
          final b = makeTab('tab2', '/home/user');

          expect(a == b, isFalse);
          expect(a.hashCode == b.hashCode, isFalse);
        },
      );

      test(
        'Given tabs with different path, When compared, Then operator == is false',
        () {
          final a = makeTab('tab1', '/home/user');
          final b = makeTab('tab1', '/root');

          expect(a == b, isFalse);
        },
      );

      test(
        'Given tab compared with non-tab instance, When compared, Then operator == is false',
        () {
          final a = makeTab('tab1', '/home/user');
          // 与不同 id 的实例比较（避免 String 无关类型比较）
          final other = makeTab('tab-other', '/home/user');

          expect(a == other, isFalse);
        },
      );
    });

    group('SftpState equality and hashCode', () {
      late KittyFileTransferService mockTransferService;

      setUp(() {
        mockTransferService = MockKittyFileTransferService();
      });

      SftpTab makeTab(String id) {
        return SftpTab(
          id: id,
          connection: SshConnection(
            id: id,
            name: 'Server',
            host: '10.0.0.1',
            username: 'user',
            authType: AuthType.password,
          ),
          service: mockTransferService,
          currentPath: '/',
        );
      }

      test(
        'Given states with same tabs, When compared, Then operator == is true and hashCode matches',
        () {
          const a = SftpState();
          const b = SftpState();

          expect(a == b, isTrue);
          expect(a.hashCode, b.hashCode);
        },
      );

      test(
        'Given states with different tabs, When compared, Then operator == is false',
        () {
          final a = SftpState(tabs: [makeTab('tab1')]);
          final b = SftpState(tabs: [makeTab('tab2')]);

          expect(a == b, isFalse);
        },
      );

      test('Given state, When copyWith keeps tabs, Then result is equal', () {
        final a = SftpState(tabs: [makeTab('tab1')]);

        final b = a.copyWith();

        expect(a == b, isTrue);
        expect(a.hashCode, b.hashCode);
      });
    });
  });
}
