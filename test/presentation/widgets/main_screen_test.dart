import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lbp_ssh/data/models/ssh_config.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/data/models/terminal_config.dart';
import 'package:lbp_ssh/domain/services/terminal_service.dart';
import 'package:lbp_ssh/presentation/providers/app_config_provider.dart';
import 'package:lbp_ssh/presentation/providers/connection_provider.dart';
import 'package:lbp_ssh/presentation/providers/import_export_provider.dart';
import 'package:lbp_ssh/presentation/providers/sync_provider.dart';
import 'package:lbp_ssh/presentation/providers/terminal_provider.dart';
import 'package:lbp_ssh/presentation/screens/main_screen.dart';
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

  _RecordingTerminalNotifier({this.createError});

  @override
  TerminalState build() => const TerminalState();

  @override
  Future<void> initialize() async {
    initializeCalls++;
  }

  @override
  Future<TerminalSession> createSession(SshConnection connection) async {
    createdConnectionIds.add(connection.id);
    if (createError != null) {
      throw createError!;
    }
    throw UnimplementedError('测试中不应返回真实 session');
  }
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

  Widget createTestWidget({TerminalNotifier? terminalNotifier}) {
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
  });
}
