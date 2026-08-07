import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:lbp_ssh/data/models/file_item.dart';
import 'package:lbp_ssh/data/models/ssh_config.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/data/models/terminal_config.dart';
import 'package:lbp_ssh/domain/services/kitty_file_transfer_service.dart';
import 'package:lbp_ssh/domain/services/terminal_input_service.dart';
import 'package:lbp_ssh/domain/services/terminal_service.dart';
import 'package:lbp_ssh/presentation/providers/app_config_provider.dart';
import 'package:lbp_ssh/presentation/providers/connection_provider.dart';
import 'package:lbp_ssh/presentation/providers/import_export_provider.dart';
import 'package:lbp_ssh/presentation/providers/sftp_provider.dart';
import 'package:lbp_ssh/presentation/providers/sync_provider.dart';
import 'package:lbp_ssh/presentation/providers/terminal_provider.dart';
import 'package:lbp_ssh/presentation/screens/main_screen.dart';
import 'package:lbp_ssh/presentation/screens/sftp_browser_screen.dart';
import 'package:lbp_ssh/presentation/widgets/collapsible_sidebar.dart';
import 'package:lbp_ssh/presentation/widgets/error_detail_dialog.dart';

class _MockConnectionNotifier extends ConnectionNotifier {
  final ConnectionState _state;
  _MockConnectionNotifier(this._state);

  @override
  ConnectionState build() => _state;
}

class _RecordingTerminalNotifier extends TerminalNotifier {
  final List<String> createdConnectionIds = [];
  int initializeCalls = 0;
  final Object? createError;
  final TerminalSession? existingSession;

  _RecordingTerminalNotifier({this.createError, this.existingSession});

  @override
  TerminalState build() => const TerminalState();

  @override
  Future<void> initialize() async {
    initializeCalls++;
  }

  @override
  TerminalSession? getSession(String sessionId) => existingSession;

  @override
  Future<TerminalSession> createSession(SshConnection connection) async {
    createdConnectionIds.add(connection.id);
    if (createError != null) {
      throw createError!;
    }
    // onSftpTap 路径需要成功返回 session（不触发真实 SSH）
    return TerminalSession(
      id: connection.id,
      name: connection.name,
      inputService: _StubTerminalInputService(),
    );
  }
}

/// 最小 TerminalInputService 实现：仅用于构造 TerminalSession
class _StubTerminalInputService implements TerminalInputService {
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

class _MockTerminalConfigNotifier extends TerminalConfigNotifier {
  @override
  TerminalConfig build() => TerminalConfig();
}

class _MockSshConfigNotifier extends SshConfigNotifier {
  @override
  SshConfig build() => SshConfig();
}

class _MockSyncNotifier extends SyncNotifier {
  @override
  SyncStatus build() => const SyncStatus();
}

class _MockTransferService extends Mock implements KittyFileTransferService {}

/// SFTP notifier：返回预设 tab，避免真实终端会话依赖
class _MockSftpNotifier extends SftpNotifier {
  final SftpTab _tab;

  _MockSftpNotifier(this._tab);

  @override
  SftpState build() => SftpState(tabs: [_tab]);

  @override
  Future<SftpTab> openTab(
    SshConnection connection, {
    String? password,
  }) async {
    return _tab;
  }
}

void main() {
  final testConnections = [
    SshConnection(
      id: 'conn-1',
      name: 'Server Alpha',
      host: '192.168.1.10',
      username: 'admin',
      authType: AuthType.password,
    ),
  ];

  Widget createTestWidget({
    TerminalNotifier? terminalNotifier,
    SftpNotifier? sftpNotifier,
  }) {
    final transferService = _MockTransferService();
    when(() => transferService.currentPath).thenReturn('/home/user');
    when(() => transferService.listCurrentDirectory()).thenAnswer(
      (_) async => <FileItem>[],
    );
    final sftpTab = SftpTab(
      id: 'sftp-tab',
      connection: testConnections.first,
      service: transferService,
      currentPath: '/home/user',
    );
    return ProviderScope(
      overrides: [
        connectionProvider.overrideWith(
          () => _MockConnectionNotifier(
            ConnectionState(connections: testConnections),
          ),
        ),
        terminalProvider.overrideWith(
          () => terminalNotifier ?? _RecordingTerminalNotifier(),
        ),
        sftpProvider.overrideWith(
          () => sftpNotifier ?? _MockSftpNotifier(sftpTab),
        ),
        terminalConfigProvider.overrideWith(_MockTerminalConfigNotifier.new),
        sshConfigProvider.overrideWith(_MockSshConfigNotifier.new),
        importExportProvider.overrideWith(ImportExportNotifier.new),
        syncProvider.overrideWith(_MockSyncNotifier.new),
      ],
      child: const MaterialApp(
        home: MainScreen(),
      ),
    );
  }

  Future<void> pumpMainScreen(
    WidgetTester tester, {
    TerminalNotifier? terminalNotifier,
  }) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      createTestWidget(terminalNotifier: terminalNotifier),
    );
    await tester.pumpAndSettle();
  }

  group('MainScreen Widget', () {
    testWidgets(
      'Given no sessions, When rendered, Then shows sidebar and empty terminal placeholder',
      (tester) async {
        final terminalNotifier = _RecordingTerminalNotifier();
        await pumpMainScreen(tester, terminalNotifier: terminalNotifier);

        expect(find.byType(CollapsibleSidebar), findsOneWidget);
        expect(find.text('点击左侧连接以打开终端'), findsOneWidget);
        expect(find.text('创建本地终端'), findsOneWidget);
        // 连接列表可见
        expect(find.text('Server Alpha'), findsOneWidget);
        // postFrameCallback 里调用了 initialize（mock 为空操作）
        expect(terminalNotifier.initializeCalls, 1);
      },
    );

    testWidgets(
      'Given connection in sidebar, When connection is tapped, Then createSession is called with it',
      (tester) async {
        final terminalNotifier = _RecordingTerminalNotifier();
        await pumpMainScreen(tester, terminalNotifier: terminalNotifier);

        await tester.tap(find.text('Server Alpha'));
        await tester.pumpAndSettle();

        expect(terminalNotifier.createdConnectionIds, ['conn-1']);
      },
    );

    testWidgets(
      'Given createSession throws, When connection is tapped, Then shows error dialog',
      (tester) async {
        final terminalNotifier = _RecordingTerminalNotifier(
          createError: Exception('connection refused'),
        );
        await pumpMainScreen(tester, terminalNotifier: terminalNotifier);

        await tester.tap(find.text('Server Alpha'));
        await tester.pumpAndSettle();

        expect(find.byType(ErrorDetailDialog), findsOneWidget);
        expect(find.textContaining('connection refused'), findsWidgets);
      },
    );

    testWidgets(
      'Given no existing session, When SFTP button is tapped, '
      'Then creates session and opens SFTP browser',
      (tester) async {
        final terminalNotifier = _RecordingTerminalNotifier();
        await pumpMainScreen(tester, terminalNotifier: terminalNotifier);

        await tester.tap(find.byIcon(Icons.folder_copy_outlined));
        await tester.pumpAndSettle();

        // 无会话 → createSession 被调用
        expect(terminalNotifier.createdConnectionIds, ['conn-1']);
        expect(find.byType(SftpBrowserScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Given existing session, When SFTP button is tapped, '
      'Then does not create a new session and opens SFTP browser',
      (tester) async {
        final terminalNotifier = _RecordingTerminalNotifier(
          existingSession: TerminalSession(
            id: 'conn-1',
            name: 'Server Alpha',
            inputService: _StubTerminalInputService(),
          ),
        );
        await pumpMainScreen(tester, terminalNotifier: terminalNotifier);

        await tester.tap(find.byIcon(Icons.folder_copy_outlined));
        await tester.pumpAndSettle();

        // 已有会话 → 不重复创建
        expect(terminalNotifier.createdConnectionIds, isEmpty);
        expect(find.byType(SftpBrowserScreen), findsOneWidget);
      },
    );
  });
}
