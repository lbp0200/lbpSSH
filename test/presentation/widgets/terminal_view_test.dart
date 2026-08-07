import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:lbp_ssh/core/theme/app_theme.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/data/models/terminal_config.dart';
import 'package:lbp_ssh/domain/services/terminal_input_service.dart';
import 'package:lbp_ssh/domain/services/terminal_service.dart';
import 'package:lbp_ssh/l10n/app_localizations.dart';
import 'package:lbp_ssh/presentation/providers/app_config_provider.dart';
import 'package:lbp_ssh/presentation/providers/connection_provider.dart';
import 'package:lbp_ssh/presentation/providers/terminal_provider.dart';
import 'package:lbp_ssh/presentation/widgets/terminal_view.dart';

class _FakeInputService implements TerminalInputService {
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

class _MockConnectionNotifier extends ConnectionNotifier {
  final ConnectionState _state;
  _MockConnectionNotifier(this._state);

  @override
  ConnectionState build() => _state;
}

class _RecordingTerminalNotifier extends TerminalNotifier {
  final TerminalState _state;
  final List<String> switchedSessions = [];
  final List<String> closedSessions = [];
  int createLocalCalls = 0;
  final List<String> createdConnectionIds = [];

  _RecordingTerminalNotifier(this._state);

  @override
  TerminalState build() => _state;

  @override
  void switchToSession(String sessionId) {
    switchedSessions.add(sessionId);
  }

  @override
  void closeSession(String sessionId) {
    closedSessions.add(sessionId);
  }

  @override
  Future<TerminalSession> createLocalTerminal() async {
    createLocalCalls++;
    return makeSession('local', 'local home');
  }

  @override
  Future<TerminalSession> createSession(SshConnection connection) async {
    createdConnectionIds.add(connection.id);
    throw UnimplementedError('测试中不应返回真实 session');
  }
}

class _MockTerminalConfigNotifier extends TerminalConfigNotifier {
  @override
  TerminalConfig build() => TerminalConfig();
}

TerminalSession makeSession(String id, String name) {
  return TerminalSession(
    id: id,
    name: name,
    inputService: _FakeInputService(),
  );
}

void main() {
  setUpAll(() {
    PackageInfo.setMockInitialValues(
      appName: 'lbp_ssh',
      packageName: 'com.lbp.lbp_ssh',
      version: '1.9.3',
      buildNumber: '1',
      buildSignature: '',
    );
  });

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
    required TerminalNotifier terminalNotifier,
    ConnectionNotifier? connectionNotifier,
  }) {
    return ProviderScope(
      overrides: [
        terminalProvider.overrideWith(() => terminalNotifier),
        connectionProvider.overrideWith(
          () =>
              connectionNotifier ??
              _MockConnectionNotifier(
                ConnectionState(connections: testConnections),
              ),
        ),
        terminalConfigProvider.overrideWith(_MockTerminalConfigNotifier.new),
      ],
      child: const MaterialApp(
        localizationsDelegates: [AppLocalizations.delegate],
        supportedLocales: [Locale('en'), Locale('zh')],
        home: Scaffold(body: TerminalTabsView()),
      ),
    );
  }

  Future<void> pumpTabs(
    WidgetTester tester, {
    required TerminalNotifier terminalNotifier,
    ConnectionNotifier? connectionNotifier,
  }) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      createTestWidget(
        terminalNotifier: terminalNotifier,
        connectionNotifier: connectionNotifier,
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 卸载 widget 树并推进时间，让 GraphicsOverlayWidget 的轮询 timer 退出
  Future<void> teardownTabs(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 600));
  }

  group('TerminalTabsView Widget', () {
    group('empty state', () {
      testWidgets(
        'Given no sessions, When rendered, Then shows placeholder and local terminal button',
        (tester) async {
          await pumpTabs(
            tester,
            terminalNotifier: _RecordingTerminalNotifier(
              const TerminalState(),
            ),
          );

          expect(find.text('点击左侧连接以打开终端'), findsOneWidget);
          expect(find.text('创建本地终端'), findsOneWidget);
          await teardownTabs(tester);
        },
      );

      testWidgets(
        'Given no sessions, When local terminal button is tapped, Then createLocalTerminal is called',
        (tester) async {
          final notifier = _RecordingTerminalNotifier(const TerminalState());
          await pumpTabs(tester, terminalNotifier: notifier);

          await tester.tap(find.text('创建本地终端'));
          await tester.pumpAndSettle();

          expect(notifier.createLocalCalls, 1);
          await teardownTabs(tester);
        },
      );
    });

    group('tab bar', () {
      testWidgets(
        'Given sessions, When rendered, Then shows tabs with names and active state',
        (tester) async {
          final notifier = _RecordingTerminalNotifier(
            TerminalState(
              sessions: [
                makeSession('s1', 'Server Alpha'),
                makeSession('s2', 'local home'),
              ],
              activeSessionId: 's1',
            ),
          );
          await pumpTabs(tester, terminalNotifier: notifier);

          expect(find.text('Server Alpha'), findsOneWidget);
          expect(find.text('local home'), findsOneWidget);
          // active tab 的文本用 primary 色
          final activeText = tester.widget<Text>(
            find.text('Server Alpha'),
          );
          expect(
            activeText.style?.color,
            LinearColors.textPrimary,
          );
          final inactiveText = tester.widget<Text>(find.text('local home'));
          expect(inactiveText.style?.color, LinearColors.textTertiary);
          await teardownTabs(tester);
        },
      );

      testWidgets(
        'Given two sessions, When inactive tab is tapped, Then switchToSession is called with its id',
        (tester) async {
          final notifier = _RecordingTerminalNotifier(
            TerminalState(
              sessions: [
                makeSession('s1', 'Server Alpha'),
                makeSession('s2', 'local home'),
              ],
              activeSessionId: 's1',
            ),
          );
          await pumpTabs(tester, terminalNotifier: notifier);

          await tester.tap(find.text('local home'));
          await tester.pumpAndSettle();

          expect(notifier.switchedSessions, ['s2']);
          await teardownTabs(tester);
        },
      );

      testWidgets(
        'Given session tab, When close icon is tapped, Then closeSession is called',
        (tester) async {
          final notifier = _RecordingTerminalNotifier(
            TerminalState(
              sessions: [makeSession('s1', 'Server Alpha')],
              activeSessionId: 's1',
            ),
          );
          await pumpTabs(tester, terminalNotifier: notifier);

          await tester.tap(find.byIcon(Icons.close));
          await tester.pumpAndSettle();

          expect(notifier.closedSessions, ['s1']);
          await teardownTabs(tester);
        },
      );
    });

    group('add menu', () {
      testWidgets(
        'Given add menu, When local terminal is selected, Then createLocalTerminal is called',
        (tester) async {
          final notifier = _RecordingTerminalNotifier(
            TerminalState(
              sessions: [makeSession('s1', 'Server Alpha')],
              activeSessionId: 's1',
            ),
          );
          await pumpTabs(tester, terminalNotifier: notifier);

          await tester.tap(
            find.descendant(
              of: find.byType(PopupMenuButton<String>),
              matching: find.byIcon(Icons.add),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('本地终端'));
          await tester.pumpAndSettle();

          expect(notifier.createLocalCalls, 1);
          await teardownTabs(tester);
        },
      );

      testWidgets(
        'Given no connections, When add menu is opened, Then shows disabled hint',
        (tester) async {
          final notifier = _RecordingTerminalNotifier(
            TerminalState(
              sessions: [makeSession('s1', 'Server Alpha')],
              activeSessionId: 's1',
            ),
          );
          await pumpTabs(
            tester,
            terminalNotifier: notifier,
            connectionNotifier: _MockConnectionNotifier(
              const ConnectionState(),
            ),
          );

          await tester.tap(
            find.descendant(
              of: find.byType(PopupMenuButton<String>),
              matching: find.byIcon(Icons.add),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('暂无保存的连接'), findsOneWidget);
          expect(find.text('本地终端'), findsOneWidget);
          await teardownTabs(tester);
        },
      );

      testWidgets(
        'Given connection without session, When selected from menu, Then createSession is called',
        (tester) async {
          final notifier = _RecordingTerminalNotifier(
            TerminalState(
              sessions: [makeSession('other', 'local home')],
              activeSessionId: 'other',
            ),
          );
          await pumpTabs(tester, terminalNotifier: notifier);

          await tester.tap(
            find.descendant(
              of: find.byType(PopupMenuButton<String>),
              matching: find.byIcon(Icons.add),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Server Alpha'));
          await tester.pumpAndSettle();

          expect(notifier.createdConnectionIds, ['conn-1']);
          await teardownTabs(tester);
        },
      );

      testWidgets(
        'Given connection with existing session, When selected from menu, Then switchToSession is called',
        (tester) async {
          final notifier = _RecordingTerminalNotifier(
            TerminalState(
              sessions: [makeSession('conn-1', 'Server Alpha')],
              activeSessionId: 'conn-1',
            ),
          );
          await pumpTabs(tester, terminalNotifier: notifier);

          await tester.tap(
            find.descendant(
              of: find.byType(PopupMenuButton<String>),
              matching: find.byIcon(Icons.add),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Server Alpha').last);
          await tester.pumpAndSettle();

          expect(notifier.switchedSessions, ['conn-1']);
          expect(notifier.createdConnectionIds, isEmpty);
          await teardownTabs(tester);
        },
      );
    });
  });
}
