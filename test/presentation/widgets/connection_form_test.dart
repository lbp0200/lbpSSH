import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/presentation/providers/connection_provider.dart';
import 'package:lbp_ssh/presentation/screens/connection_form.dart';

class _MockConnectionNotifier extends ConnectionNotifier {
  final ConnectionState _state;
  _MockConnectionNotifier(this._state);

  @override
  ConnectionState build() => _state;
}

void main() {
  Widget createTestWidget({SshConnection? connection}) {
    const state = ConnectionState();

    return MaterialApp(
      home: ProviderScope(
        overrides: [
          connectionProvider.overrideWith(
            () => _MockConnectionNotifier(state),
          ),
        ],
        child: ConnectionFormScreen(connection: connection),
      ),
    );
  }

  /// 表单内容较长,使用高视口让 ListView 全部渲染,避免滚动查找
  Future<void> pumpForm(WidgetTester tester, {SshConnection? connection}) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createTestWidget(connection: connection));
    await tester.pump();
  }

  group('ConnectionFormScreen', () {
    testWidgets(
      'Given no connection, When rendered, Then shows add title and default port',
      (tester) async {
        await pumpForm(tester);

        expect(find.text('添加连接'), findsOneWidget);
        // 默认端口 22
        expect(find.text('22'), findsOneWidget);
        expect(find.text('保存'), findsOneWidget);
      },
    );

    testWidgets(
      'Given existing connection, When rendered, Then shows edit title and pre-filled values',
      (tester) async {
        final connection = SshConnection(
          id: '1',
          name: '生产服务器',
          host: '192.168.1.100',
          port: 2222,
          username: 'root',
          authType: AuthType.password,
        );

        await pumpForm(tester, connection: connection);

        expect(find.text('编辑连接'), findsOneWidget);
        expect(find.text('生产服务器'), findsOneWidget);
        expect(find.text('192.168.1.100'), findsOneWidget);
        expect(find.text('2222'), findsOneWidget);
        expect(find.text('root'), findsOneWidget);
      },
    );

    testWidgets(
      'Given empty form, When save pressed, Then shows validation errors',
      (tester) async {
        await pumpForm(tester);

        await tester.tap(find.text('保存'));
        await tester.pump();

        expect(find.text('请输入连接名称'), findsOneWidget);
        expect(find.text('请输入主机地址'), findsOneWidget);
        expect(find.text('请输入用户名'), findsOneWidget);
      },
    );

    testWidgets(
      'Given password auth selected, When rendered, Then shows password field',
      (tester) async {
        await pumpForm(tester);

        expect(find.text('密码'), findsWidgets);
      },
    );

    testWidgets(
      'Given auth type switched to key, When rendered, Then shows key fields',
      (tester) async {
        await pumpForm(tester);

        // 切换到密钥认证
        await tester.tap(find.text('认证方式'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('密钥认证').last);
        await tester.pumpAndSettle();

        expect(find.text('私钥文件'), findsWidgets);
      },
    );

    testWidgets(
      'Given jump host toggle enabled, When rendered, Then shows jump host fields',
      (tester) async {
        await pumpForm(tester);

        await tester.tap(find.text('使用跳板机'));
        await tester.pumpAndSettle();

        expect(find.text('跳板机地址'), findsOneWidget);
      },
    );

    testWidgets(
      'Given jump host toggle enabled, When save with empty jump host, Then shows jump host validation error',
      (tester) async {
        await pumpForm(tester);

        await tester.tap(find.text('使用跳板机'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('保存'));
        await tester.pump();

        expect(find.text('请输入跳板机地址'), findsOneWidget);
        expect(find.text('请输入跳板机用户名'), findsOneWidget);
      },
    );

    testWidgets(
      'Given SOCKS5 proxy toggle enabled, When rendered, Then shows proxy fields',
      (tester) async {
        await pumpForm(tester);

        await tester.tap(find.text('使用 SOCKS5 代理'));
        await tester.pumpAndSettle();

        expect(find.text('代理主机'), findsOneWidget);
        // 默认端口提示
        expect(find.textContaining('默认 1080'), findsOneWidget);
        // 可选配置提示
        expect(find.textContaining('用户名和密码为可选配置'), findsOneWidget);
      },
    );

    testWidgets(
      'Given SOCKS5 proxy toggle enabled, When save with empty proxy host, Then shows proxy validation error',
      (tester) async {
        await pumpForm(tester);

        await tester.tap(find.text('使用 SOCKS5 代理'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('保存'));
        await tester.pump();

        expect(find.text('请输入代理主机'), findsOneWidget);
      },
    );
  });
}
