import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kterm/kterm.dart' hide TerminalState;
import 'package:package_info_plus/package_info_plus.dart';

import 'package:lbp_ssh/core/theme/app_theme.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/data/models/terminal_config.dart';
import 'package:lbp_ssh/domain/services/terminal_input_service.dart';
import 'package:lbp_ssh/domain/services/terminal_service.dart';
import 'package:lbp_ssh/domain/services/ssh_service.dart';
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
  final Object? createLocalError;
  final Object? reconnectError;
  int reconnectCalls = 0;
  TerminalSession? getSessionResult;

  _RecordingTerminalNotifier(
    this._state, {
    this.createLocalError,
    this.reconnectError,
  });

  @override
  TerminalState build() => _state;

  @override
  TerminalSession? getSession(String sessionId) => getSessionResult;

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
    if (createLocalError != null) {
      throw createLocalError!;
    }
    return makeSession('local', 'local home');
  }

  @override
  Future<TerminalSession> createSession(SshConnection connection) async {
    createdConnectionIds.add(connection.id);
    throw UnimplementedError('测试中不应返回真实 session');
  }

  @override
  Future<void> reconnectSession(String sessionId) async {
    reconnectCalls++;
    if (reconnectError != null) {
      throw reconnectError!;
    }
  }
}

class _MockTerminalConfigNotifier extends TerminalConfigNotifier {
  TerminalConfig value = TerminalConfig();

  @override
  TerminalConfig build() => value;
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
    TerminalConfigNotifier? configNotifier,
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
        terminalConfigProvider.overrideWith(
          () => configNotifier ?? _MockTerminalConfigNotifier(),
        ),
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
    TerminalConfigNotifier? configNotifier,
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
        configNotifier: configNotifier,
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

      testWidgets(
        'Given createLocalTerminal throws, When empty-state button tapped, '
        'Then shows error dialog',
        (tester) async {
          final notifier = _RecordingTerminalNotifier(
            const TerminalState(),
            createLocalError: Exception('start failed'),
          );
          await pumpTabs(tester, terminalNotifier: notifier);

          await tester.tap(find.text('创建本地终端'));
          await tester.pumpAndSettle();

          expect(find.text('创建终端失败'), findsOneWidget);
          expect(find.textContaining('start failed'), findsWidgets);
          await teardownTabs(tester);
        },
      );

      testWidgets(
        'Given createLocalTerminal throws, When add menu local terminal selected, '
        'Then shows error dialog',
        (tester) async {
          final notifier = _RecordingTerminalNotifier(
            TerminalState(
              sessions: [makeSession('s1', 'Server Alpha')],
              activeSessionId: 's1',
            ),
            createLocalError: Exception('start failed'),
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

          expect(find.text('创建终端失败'), findsOneWidget);
          expect(find.textContaining('start failed'), findsWidgets);
          await teardownTabs(tester);
        },
      );
    });

    group('notification stream', () {
      testWidgets(
        'Given active session emits notification, When rendered, '
        'Then shows snackbar with notification content',
        (tester) async {
          final session = makeSession('s1', 'Server Alpha');
          final notifier = _RecordingTerminalNotifier(
            TerminalState(sessions: [session], activeSessionId: 's1'),
          );
          await pumpTabs(tester, terminalNotifier: notifier);

          // 触发终端通知（kterm 的 onNotification 回调）
          session.terminal.onNotification?.call('磁盘告警', '空间不足');
          await tester.pumpAndSettle();

          expect(find.text('磁盘告警\n空间不足'), findsOneWidget);
          await teardownTabs(tester);
        },
      );
    });

    group('drag & drop file upload', () {
      /// 通过 mock desktop_drop 方法通道派发平台拖拽事件
      Future<void> dispatchDrop(
        WidgetTester tester,
        String method,
        Object? args,
      ) async {
        const codec = StandardMethodCodec();
        tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'desktop_drop',
          codec.encodeMethodCall(MethodCall(method, args)),
          (_) {},
        );
        await tester.pump();
      }

      /// 派发「拖入 + 放下文件」完整序列
      Future<void> dropFiles(
        WidgetTester tester,
        List<Map<String, dynamic>> items,
      ) async {
        await dispatchDrop(tester, 'entered', [700.0, 400.0]);
        await dispatchDrop(
          tester,
          'performOperation_macos',
          items,
        );
        await tester.pump();
      }

      testWidgets(
        'Given active session, When drag entered, '
        'Then upload overlay is shown',
        (tester) async {
          final notifier = _RecordingTerminalNotifier(
            TerminalState(
              sessions: [makeSession('s1', 'Server Alpha')],
              activeSessionId: 's1',
            ),
          );
          await pumpTabs(tester, terminalNotifier: notifier);

          await dispatchDrop(tester, 'entered', [700.0, 400.0]);

          expect(find.text('释放以上传文件到服务器'), findsOneWidget);
          await teardownTabs(tester);
        },
      );

      testWidgets(
        'Given upload overlay shown, When drag exited, '
        'Then overlay is hidden',
        (tester) async {
          final notifier = _RecordingTerminalNotifier(
            TerminalState(
              sessions: [makeSession('s1', 'Server Alpha')],
              activeSessionId: 's1',
            ),
          );
          await pumpTabs(tester, terminalNotifier: notifier);

          await dispatchDrop(tester, 'entered', [700.0, 400.0]);
          expect(find.text('释放以上传文件到服务器'), findsOneWidget);

          await dispatchDrop(tester, 'exited', null);
          expect(find.text('释放以上传文件到服务器'), findsNothing);
          await teardownTabs(tester);
        },
      );

      testWidgets(
        'Given session not resolvable, When files dropped, '
        'Then shows connect-first snackbar',
        (tester) async {
          final notifier = _RecordingTerminalNotifier(
            TerminalState(
              sessions: [makeSession('s1', 'Server Alpha')],
              activeSessionId: 's1',
            ),
          );
          await pumpTabs(tester, terminalNotifier: notifier);

          await dropFiles(tester, [
            {'path': '/tmp/file.txt', 'apple-bookmark': null, 'isDirectory': false},
          ]);

          expect(find.text('请先连接到服务器'), findsOneWidget);
          await teardownTabs(tester);
        },
      );

      testWidgets(
        'Given session exists, When file dropped, '
        'Then upload failure snackbar is shown (no kitty support)',
        (tester) async {
          final session = makeSession('s1', 'Server Alpha');
          final notifier = _RecordingTerminalNotifier(
            TerminalState(sessions: [session], activeSessionId: 's1'),
          )..getSessionResult = session;
          await pumpTabs(tester, terminalNotifier: notifier);

          await dropFiles(tester, [
            {'path': '/tmp/file.txt', 'apple-bookmark': null, 'isDirectory': false},
          ]);

          // sendFile → checkProtocolSupport → executeCommand('ki version') 返回空
          // → 判定不支持 → 抛异常 → catch → 上传失败 snackbar
          expect(find.textContaining('上传失败'), findsOneWidget);
          await teardownTabs(tester);
        },
      );

      testWidgets(
        'Given empty file list, When dropped, '
        'Then no upload is attempted',
        (tester) async {
          final session = makeSession('s1', 'Server Alpha');
          final notifier = _RecordingTerminalNotifier(
            TerminalState(sessions: [session], activeSessionId: 's1'),
          )..getSessionResult = session;
          await pumpTabs(tester, terminalNotifier: notifier);

          await dispatchDrop(tester, 'entered', [700.0, 400.0]);
          await dispatchDrop(
            tester,
            'performOperation_macos',
            <Map<dynamic, dynamic>>[],
          );
          await tester.pump();

          expect(find.textContaining('上传失败'), findsNothing);
          expect(find.textContaining('上传成功'), findsNothing);
          await teardownTabs(tester);
        },
      );
    });

    group('reconnect', () {
      testWidgets(
        'Given disconnected SSH session, When reconnect pressed, '
        'Then shows reconnecting snackbar and calls reconnectSession',
        (tester) async {
          final session = makeSession('s1', 'Server Alpha');
          // 模拟 SSH 会话：非本地、已断开
          session.connectionState = SshConnectionState.disconnected;
          final notifier = _RecordingTerminalNotifier(
            TerminalState(sessions: [session], activeSessionId: 's1'),
          );
          await pumpTabs(tester, terminalNotifier: notifier);

          await tester.tap(find.text('Reconnect'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(notifier.reconnectCalls, 1);
          expect(find.text('Reconnecting...'), findsOneWidget);
          await teardownTabs(tester);
        },
      );

      testWidgets(
        'Given reconnectSession throws, When reconnect pressed, '
        'Then shows reconnect failed snackbar',
        (tester) async {
          final session = makeSession('s1', 'Server Alpha');
          session.connectionState = SshConnectionState.disconnected;
          final notifier = _RecordingTerminalNotifier(
            TerminalState(sessions: [session], activeSessionId: 's1'),
            reconnectError: Exception('conn refused'),
          );
          await pumpTabs(tester, terminalNotifier: notifier);

          await tester.tap(find.text('Reconnect'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(notifier.reconnectCalls, 1);
          // 「正在重连」snackbar 持续 2 秒，失败消息需等其过期后才显示
          await tester.pump(const Duration(seconds: 2));
          await tester.pumpAndSettle();
          expect(find.textContaining('Reconnect failed'), findsOneWidget);
          await teardownTabs(tester);
        },
      );
    });

    group('selection copy', () {
      testWidgets(
        'Given terminal text written, When selection is set, '
        'Then selected text is copied to clipboard',
        (tester) async {
          // 拦截剪贴板调用，避免真实平台通道等待
          final clipboardCalls = <String>[];
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            (call) async {
              if (call.method == 'Clipboard.setData') {
                clipboardCalls.add(
                  (call.arguments as Map<dynamic, dynamic>)['text'] as String,
                );
              }
              return null;
            },
          );
          addTearDown(() {
            tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
              SystemChannels.platform,
              null,
            );
          });

          final session = makeSession('s1', 'Server Alpha');
          final notifier = _RecordingTerminalNotifier(
            TerminalState(sessions: [session], activeSessionId: 's1'),
          );
          await pumpTabs(tester, terminalNotifier: notifier);

          // 向终端写入文本并设置选区，触发 _onSelectionChanged 复制到剪贴板
          session.terminal.write('hello');
          await tester.pump();
          final line = session.terminal.buffer.currentLine;
          session.controller.setSelection(
            CellAnchor(0, owner: line),
            CellAnchor(5, owner: line),
          );
          await tester.pump();

          expect(clipboardCalls, contains('hello'));
          await teardownTabs(tester);
        },
      );

      testWidgets(
        'Given selection cleared, When controller notifies, '
        'Then no clipboard write and no error',
        (tester) async {
          // 拦截剪贴板调用
          final clipboardCalls = <String>[];
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            (call) async {
              if (call.method == 'Clipboard.setData') {
                clipboardCalls.add(
                  (call.arguments as Map<dynamic, dynamic>)['text'] as String,
                );
              }
              return null;
            },
          );
          addTearDown(() {
            tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
              SystemChannels.platform,
              null,
            );
          });

          final session = makeSession('s1', 'Server Alpha');
          final notifier = _RecordingTerminalNotifier(
            TerminalState(sessions: [session], activeSessionId: 's1'),
          );
          await pumpTabs(tester, terminalNotifier: notifier);

          // 先设置选区再清除，覆盖 _onSelectionChanged 的 null 分支
          session.terminal.write('hello');
          await tester.pump();
          final line = session.terminal.buffer.currentLine;
          session.controller.setSelection(
            CellAnchor(0, owner: line),
            CellAnchor(5, owner: line),
          );
          await tester.pump();
          expect(clipboardCalls, contains('hello'));

          session.controller.clearSelection();
          await tester.pump();

          expect(tester.takeException(), isNull);
          await teardownTabs(tester);
        },
      );
    });

    group('config change', () {
      testWidgets(
        'Given font size changed, When config updates, '
        'Then terminal rebuilds without error',
        (tester) async {
          final session = makeSession('s1', 'Server Alpha');
          final notifier = _RecordingTerminalNotifier(
            TerminalState(sessions: [session], activeSessionId: 's1'),
          );
          final configNotifier = _MockTerminalConfigNotifier();
          await pumpTabs(
            tester,
            terminalNotifier: notifier,
            configNotifier: configNotifier,
          );

          // 修改字体大小触发字体度量缓存失效重算
          configNotifier.value = configNotifier.value.copyWith(fontSize: 20);
          configNotifier.state = configNotifier.value;
          await tester.pump();

          expect(tester.takeException(), isNull);
          await teardownTabs(tester);
        },
      );

      testWidgets(
        'Given line height changed, When config updates, '
        'Then terminal rebuilds without error',
        (tester) async {
          final session = makeSession('s1', 'Server Alpha');
          final notifier = _RecordingTerminalNotifier(
            TerminalState(sessions: [session], activeSessionId: 's1'),
          );
          final configNotifier = _MockTerminalConfigNotifier();
          await pumpTabs(
            tester,
            terminalNotifier: notifier,
            configNotifier: configNotifier,
          );

          // 修改行高触发字体度量缓存失效重算（fontFamily/fontSize 不变）
          configNotifier.value = configNotifier.value.copyWith(lineHeight: 1.8);
          configNotifier.state = configNotifier.value;
          await tester.pump();

          expect(tester.takeException(), isNull);
          await teardownTabs(tester);
        },
      );
    });

    group('status bar fallback', () {
      testWidgets(
        'Given activeSessionId not in sessions, When rendered, '
        'Then falls back to first session without error',
        (tester) async {
          final session = makeSession('s1', 'Server Alpha');
          final notifier = _RecordingTerminalNotifier(
            TerminalState(sessions: [session], activeSessionId: 'ghost'),
          );
          await pumpTabs(tester, terminalNotifier: notifier);

          expect(tester.takeException(), isNull);
          expect(find.text('请选择一个连接'), findsOneWidget);
          await teardownTabs(tester);
        },
      );
    });

    group('tab hover', () {
      testWidgets(
        'Given inactive tab, When mouse hovers over it, '
        'Then close button becomes visible',
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

          final closeButton = find.ancestor(
            of: find.byIcon(Icons.close).at(1),
            matching: find.byType(AnimatedOpacity),
          );

          // 悬停前：非激活 tab 的关闭按钮透明度为 0
          expect(tester.widget<AnimatedOpacity>(closeButton).opacity, 0.0);

          // 用鼠标指针悬停到第二个 tab
          final gesture = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          await gesture.addPointer(location: Offset.zero);
          await tester.pump();
          await gesture.moveTo(tester.getCenter(find.text('local home')));
          await tester.pump();

          expect(tester.widget<AnimatedOpacity>(closeButton).opacity, 1.0);

          await gesture.removePointer();
          await tester.pump();
          await teardownTabs(tester);
        },
      );
    });
  });
}
