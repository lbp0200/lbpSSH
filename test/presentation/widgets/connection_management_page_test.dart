import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lbp_ssh/core/theme/app_theme.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/presentation/providers/connection_provider.dart';
import 'package:lbp_ssh/presentation/screens/connection_form.dart';
import 'package:lbp_ssh/presentation/screens/connection_management_page.dart';

class _MockConnectionNotifier extends ConnectionNotifier {
  final ConnectionState _state;
  _MockConnectionNotifier(this._state);

  @override
  ConnectionState build() => _state;
}

class _RecordingConnectionNotifier extends ConnectionNotifier {
  final ConnectionState _state;
  final List<String> deletedConnectionIds = [];

  _RecordingConnectionNotifier(this._state);

  @override
  ConnectionState build() => _state;

  @override
  Future<void> deleteConnection(String id) async {
    deletedConnectionIds.add(id);
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
    SshConnection(
      id: 'conn-2',
      name: 'Server Beta',
      host: '192.168.1.20',
      username: 'root',
      port: 2222,
      authType: AuthType.key,
    ),
  ];

  Widget createTestWidget({ConnectionNotifier? notifier}) {
    return ProviderScope(
      overrides: [
        connectionProvider.overrideWith(
          () => notifier ?? _MockConnectionNotifier(const ConnectionState()),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(body: ConnectionManagementPage()),
      ),
    );
  }

  Future<void> pumpPage(
    WidgetTester tester, {
    ConnectionNotifier? notifier,
  }) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(createTestWidget(notifier: notifier));
    await tester.pumpAndSettle();
  }

  group('ConnectionManagementPage Widget', () {
    group('state rendering', () {
      testWidgets(
        'Given empty connections, When rendered, Then shows empty state with add button',
        (tester) async {
          await pumpPage(tester);

          expect(find.text('已保存的连接'), findsOneWidget);
          expect(find.text('暂无连接配置'), findsOneWidget);
          expect(find.text('添加第一个连接'), findsOneWidget);
          expect(find.byIcon(Icons.cloud_off), findsOneWidget);
        },
      );

      testWidgets(
        'Given isLoading, When rendered, Then shows progress indicator',
        (tester) async {
          tester.view.physicalSize = const Size(1200, 900);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });
          // 无限动画下不能用 pumpAndSettle
          await tester.pumpWidget(
            createTestWidget(
              notifier: _MockConnectionNotifier(
                const ConnectionState(isLoading: true),
              ),
            ),
          );
          await tester.pump();

          expect(find.byType(CircularProgressIndicator), findsOneWidget);
        },
      );

      testWidgets('Given error, When rendered, Then shows error message', (
        tester,
      ) async {
        await pumpPage(
          tester,
          notifier: _MockConnectionNotifier(
            const ConnectionState(error: '加载失败: boom'),
          ),
        );

        expect(find.text('加载失败: boom'), findsOneWidget);
      });

      testWidgets(
        'Given connections, When rendered, Then shows connection list items',
        (tester) async {
          await pumpPage(
            tester,
            notifier: _MockConnectionNotifier(
              ConnectionState(connections: testConnections),
            ),
          );

          expect(find.text('Server Alpha'), findsOneWidget);
          expect(find.text('admin@192.168.1.10:22'), findsOneWidget);
          expect(find.text('Server Beta'), findsOneWidget);
          expect(find.text('root@192.168.1.20:2222'), findsOneWidget);
        },
      );
    });

    group('navigation', () {
      testWidgets(
        'Given empty state, When add button is tapped, Then navigates to ConnectionFormScreen',
        (tester) async {
          await pumpPage(tester);

          await tester.tap(find.text('添加第一个连接'));
          await tester.pumpAndSettle();

          expect(find.byType(ConnectionFormScreen), findsOneWidget);
        },
      );

      testWidgets(
        'Given top bar add button, When tapped, Then navigates to ConnectionFormScreen',
        (tester) async {
          await pumpPage(
            tester,
            notifier: _MockConnectionNotifier(
              ConnectionState(connections: testConnections),
            ),
          );

          await tester.tap(find.text('添加连接'));
          await tester.pumpAndSettle();

          expect(find.byType(ConnectionFormScreen), findsOneWidget);
        },
      );

      testWidgets(
        'Given connection item, When tapped, Then navigates to ConnectionFormScreen with it',
        (tester) async {
          await pumpPage(
            tester,
            notifier: _MockConnectionNotifier(
              ConnectionState(connections: testConnections),
            ),
          );

          await tester.tap(find.text('Server Alpha'));
          await tester.pumpAndSettle();

          expect(find.byType(ConnectionFormScreen), findsOneWidget);
        },
      );

      testWidgets('Given connection item, When edit menu tapped, '
          'Then navigates to ConnectionFormScreen with it', (tester) async {
        await pumpPage(
          tester,
          notifier: _MockConnectionNotifier(
            ConnectionState(connections: testConnections),
          ),
        );

        // 打开第一项的更多菜单并选择「编辑」
        await tester.tap(find.byIcon(Icons.more_vert).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('编辑'));
        await tester.pumpAndSettle();

        expect(find.byType(ConnectionFormScreen), findsOneWidget);
      });
    });

    group('hover behavior', () {
      testWidgets('Given connection item, When mouse hovers over it, '
          'Then connection info text switches to secondary color', (
        tester,
      ) async {
        await pumpPage(
          tester,
          notifier: _MockConnectionNotifier(
            ConnectionState(connections: testConnections),
          ),
        );

        // 未悬停时使用 textTertiary
        Text infoText() =>
            tester.widget<Text>(find.text('admin@192.168.1.10:22'));
        expect(infoText().style?.color, LinearColors.textTertiary);

        // 悬停
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        addTearDown(gesture.removePointer);
        await tester.pump();
        await gesture.moveTo(tester.getCenter(find.text('Server Alpha')));
        await tester.pumpAndSettle();

        expect(infoText().style?.color, LinearColors.textSecondary);

        // 移出后恢复
        await gesture.moveTo(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(infoText().style?.color, LinearColors.textTertiary);
      });
    });

    group('delete flow', () {
      testWidgets(
        'Given connection, When delete is confirmed, Then deleteConnection is called and snackbar shown',
        (tester) async {
          final notifier = _RecordingConnectionNotifier(
            ConnectionState(connections: testConnections),
          );
          await pumpPage(tester, notifier: notifier);

          // 打开第一项的更多菜单
          await tester.tap(find.byIcon(Icons.more_vert).first);
          await tester.pumpAndSettle();

          await tester.tap(find.text('删除'));
          await tester.pumpAndSettle();

          // 确认对话框
          expect(find.text('确认删除'), findsOneWidget);
          expect(find.textContaining('Server Alpha'), findsWidgets);

          await tester.tap(find.text('删除').last);
          await tester.pumpAndSettle();

          expect(notifier.deletedConnectionIds, ['conn-1']);
          expect(find.text('连接已删除'), findsOneWidget);
        },
      );

      testWidgets(
        'Given delete dialog, When cancelled, Then deleteConnection is not called',
        (tester) async {
          final notifier = _RecordingConnectionNotifier(
            ConnectionState(connections: testConnections),
          );
          await pumpPage(tester, notifier: notifier);

          await tester.tap(find.byIcon(Icons.more_vert).first);
          await tester.pumpAndSettle();
          await tester.tap(find.text('删除'));
          await tester.pumpAndSettle();

          await tester.tap(find.text('取消'));
          await tester.pumpAndSettle();

          expect(notifier.deletedConnectionIds, isEmpty);
        },
      );
    });
  });
}
