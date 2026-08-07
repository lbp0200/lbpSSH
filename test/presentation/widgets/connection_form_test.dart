import 'dart:io';

import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/presentation/providers/connection_provider.dart';
import 'package:lbp_ssh/presentation/screens/connection_form.dart';

class _MockConnectionNotifier extends ConnectionNotifier {
  final ConnectionState _state;
  _MockConnectionNotifier(this._state);

  final List<SshConnection> added = [];
  final List<SshConnection> updated = [];

  @override
  ConnectionState build() => _state;

  @override
  Future<void> addConnection(SshConnection connection) async {
    added.add(connection);
  }

  @override
  Future<void> updateConnection(SshConnection connection) async {
    updated.add(connection);
  }
}

void main() {
  late _MockConnectionNotifier mockNotifier;

  Widget createTestWidget({SshConnection? connection}) {
    const state = ConnectionState();
    mockNotifier = _MockConnectionNotifier(state);

    return MaterialApp(
      home: ProviderScope(
        overrides: [
          connectionProvider.overrideWith(() => mockNotifier),
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

  /// 按输入框的 label 文本定位并输入内容
  Future<void> enterField(
    WidgetTester tester,
    String label,
    String value, {
    bool last = false,
  }) async {
    final finder = find.ancestor(
      of: find.text(label),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(last ? finder.last : finder.first, value);
    await tester.pump();
  }

  /// 切换到指定认证方式
  Future<void> switchAuthType(WidgetTester tester, String label) async {
    await tester.tap(find.byType(DropdownButtonFormField<AuthType>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  /// 同步创建临时私钥文件（FakeAsync 下真实异步 IO 无法完成）
  File createTempKeyFile(String content) {
    final tempDir = Directory.systemTemp.createTempSync('lbpssh_test');
    final file = File('${tempDir.path}/id_ed25519')
      ..writeAsStringSync(content);
    addTearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {
        // 忽略清理失败
      }
    });
    return file;
  }

  /// 点击对话框「确定」并等待真实文件 IO 完成
  ///
  /// 1. tap 触发 onPressed（同步执行 Navigator.pop）
  /// 2. 交替 pump 与 runAsync：pump 推进 FakeAsync 微任务/帧（让每个 await
  ///    的续体运行、启动下一段真实 IO），runAsync 给真实事件循环时间完成 IO。
  ///    `_loadPrivateKeyFromPath` 的 exists → readAsString 是链式真实 IO，
  ///    单次 runAsync 不足以走完全程。
  Future<void> confirmManualPath(WidgetTester tester) async {
    await tester.tap(find.text('确定'));
    for (var i = 0; i < 10; i++) {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
    }
    await tester.pumpAndSettle();
  }

  /// 推进时钟让 SnackBar 自动关闭，避免测试结束残留 Timer
  Future<void> drainSnackBars(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
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
        await tester.tap(find.byType(DropdownButtonFormField<AuthType>).first);
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

    testWidgets(
      'Given password auth, When visibility icon tapped, Then password becomes visible',
      (tester) async {
        await pumpForm(tester);

        // 初始为隐藏状态(visibility 图标表示点击可查看)
        expect(find.byIcon(Icons.visibility), findsOneWidget);
        expect(find.byIcon(Icons.visibility_off), findsNothing);

        // 点击眼睛图标切换为明文
        await tester.tap(find.byIcon(Icons.visibility));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.visibility_off), findsOneWidget);
        expect(find.byIcon(Icons.visibility), findsNothing);
      },
    );

    testWidgets(
      'Given key auth selected, When save without key file, Then shows key validation error',
      (tester) async {
        await pumpForm(tester);

        // 切换到密钥认证
        await switchAuthType(tester, '密钥认证');

        await tester.tap(find.text('保存'));
        await tester.pump();

        expect(find.text('请选择私钥文件'), findsOneWidget);
      },
    );

    testWidgets(
      'Given existing connection with jump host, When rendered, '
      'Then jump host fields are prefilled',
      (tester) async {
        final connection = SshConnection(
          id: '1',
          name: '生产服务器',
          host: '192.168.1.100',
          username: 'root',
          authType: AuthType.password,
          sshConfigHost: 'my-ssh-host',
          jumpHost: JumpHostConfig(
            host: '10.0.0.1',
            port: 2222,
            username: 'jumpuser',
            authType: AuthType.key,
          ),
        );

        await pumpForm(tester, connection: connection);

        expect(find.text('跳板机地址'), findsOneWidget);
        expect(find.text('10.0.0.1'), findsOneWidget);
        expect(find.text('2222'), findsOneWidget);
        expect(find.text('jumpuser'), findsOneWidget);
      },
    );

    testWidgets(
      'Given existing connection with socks5 proxy, When rendered, '
      'Then proxy fields are prefilled',
      (tester) async {
        final connection = SshConnection(
          id: '1',
          name: '生产服务器',
          host: '192.168.1.100',
          username: 'root',
          authType: AuthType.password,
          socks5Proxy: Socks5ProxyConfig(
            host: '127.0.0.1',
            username: 'proxyuser',
            password: 'proxypass',
          ),
        );

        await pumpForm(tester, connection: connection);

        expect(find.text('代理主机'), findsOneWidget);
        expect(find.text('127.0.0.1'), findsOneWidget);
        expect(find.text('proxyuser'), findsOneWidget);
      },
    );

    testWidgets(
      'Given key auth, When manual path dialog opened and cancelled, '
      'Then no key is loaded',
      (tester) async {
        await pumpForm(tester);
        await switchAuthType(tester, '密钥认证');

        await tester.tap(find.text('输入路径'));
        await tester.pumpAndSettle();

        expect(find.text('输入私钥文件路径'), findsOneWidget);

        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();

        expect(find.text('输入私钥文件路径'), findsNothing);
      },
    );

    testWidgets(
      'Given key auth, When manual path points to non-existent file, '
      'Then shows file-not-exist message',
      (tester) async {
        await pumpForm(tester);
        await switchAuthType(tester, '密钥认证');

        await tester.tap(find.text('输入路径'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextFormField),
          ),
          '/non/existent/key.pem',
        );
        await confirmManualPath(tester);

        expect(find.text('文件不存在或无法访问'), findsOneWidget);
        await drainSnackBars(tester);
      },
    );

    testWidgets(
      'Given key auth, When manual path points to a valid key file, '
      'Then key is loaded and shown as loaded',
      (tester) async {
        final keyFile = createTempKeyFile(
          '-----BEGIN OPENSSH PRIVATE KEY-----\n'
          'test-content\n'
          '-----END OPENSSH PRIVATE KEY-----',
        );

        await pumpForm(tester);
        await switchAuthType(tester, '密钥认证');

        await tester.tap(find.text('输入路径'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextFormField),
          ),
          keyFile.path,
        );
        await confirmManualPath(tester);

        expect(find.textContaining('私钥已加载'), findsOneWidget);
        await drainSnackBars(tester);
      },
    );

    testWidgets(
      'Given key auth, When manual path points to an invalid key file, '
      'Then shows invalid-key-format message',
      (tester) async {
        final keyFile = createTempKeyFile('not a valid key');

        await pumpForm(tester);
        await switchAuthType(tester, '密钥认证');

        await tester.tap(find.text('输入路径'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextFormField),
          ),
          keyFile.path,
        );
        await confirmManualPath(tester);

        expect(find.textContaining('文件不是有效的私钥格式'), findsOneWidget);
        await drainSnackBars(tester);
      },
    );

    testWidgets(
      'Given keyWithPassword auth, When passphrase visibility tapped, '
      'Then passphrase becomes visible',
      (tester) async {
        await pumpForm(tester);
        await switchAuthType(tester, '密钥+密码认证');

        expect(find.text('密钥密码'), findsOneWidget);
        expect(find.byIcon(Icons.visibility), findsWidgets);

        await tester.tap(find.byIcon(Icons.visibility).first);
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.visibility_off), findsWidgets);
      },
    );

    testWidgets(
      'Given valid form with jump host and socks5 proxy, When save pressed, '
      'Then connection is added with all configs',
      (tester) async {
        await pumpForm(tester);

        await enterField(tester, '连接名称', '测试服务器');
        await enterField(tester, '主机地址', '192.168.1.200');
        await enterField(tester, '用户名', 'root');

        // 启用跳板机并填写
        await tester.tap(find.text('使用跳板机'));
        await tester.pumpAndSettle();
        await enterField(tester, '跳板机地址', '10.0.0.1');
        await enterField(tester, '跳板机用户名', 'jumpuser', last: true);

        // 启用 SOCKS5 代理并填写
        await tester.tap(find.text('使用 SOCKS5 代理'));
        await tester.pumpAndSettle();
        await enterField(tester, '代理主机', '127.0.0.1');
        // SOCKS5 端口默认未预填，需显式填写（空端口会触发校验失败）
        await enterField(tester, '端口', '1080', last: true);
        await enterField(tester, '用户名', 'proxyuser', last: true);

        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();

        expect(mockNotifier.added, hasLength(1));
        final conn = mockNotifier.added.single;
        expect(conn.name, '测试服务器');
        expect(conn.host, '192.168.1.200');
        expect(conn.username, 'root');
        expect(conn.jumpHost!.host, '10.0.0.1');
        expect(conn.jumpHost!.port, 22);
        expect(conn.jumpHost!.username, 'jumpuser');
        expect(conn.socks5Proxy!.host, '127.0.0.1');
        expect(conn.socks5Proxy!.username, 'proxyuser');
      },
    );

    testWidgets(
      'Given valid form with loaded key, When save pressed, '
      'Then connection includes privateKeyContent',
      (tester) async {
        const validKey = '-----BEGIN OPENSSH PRIVATE KEY-----\n'
            'test-content\n'
            '-----END OPENSSH PRIVATE KEY-----';
        final keyFile = createTempKeyFile(validKey);

        await pumpForm(tester);
        await switchAuthType(tester, '密钥认证');

        await tester.tap(find.text('输入路径'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextFormField),
          ),
          keyFile.path,
        );
        await confirmManualPath(tester);

        await enterField(tester, '连接名称', '密钥服务器');
        await enterField(tester, '主机地址', '10.1.1.1');
        await enterField(tester, '用户名', 'root');

        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();

        expect(mockNotifier.added, hasLength(1));
        final conn = mockNotifier.added.single;
        expect(conn.authType, AuthType.key);
        expect(conn.privateKeyContent, validKey);
        await drainSnackBars(tester);
      },
    );

    testWidgets(
      'Given existing connection, When save pressed, '
      'Then connection is updated with same id',
      (tester) async {
        final connection = SshConnection(
          id: '1',
          name: '旧名称',
          host: '192.168.1.100',
          username: 'root',
          authType: AuthType.password,
        );

        await pumpForm(tester, connection: connection);
        await enterField(tester, '连接名称', '新名称');

        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();

        expect(mockNotifier.updated, hasLength(1));
        final conn = mockNotifier.updated.single;
        expect(conn.id, '1');
        expect(conn.name, '新名称');
      },
    );
  });
}
