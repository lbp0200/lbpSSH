import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/domain/services/ssh_config_service.dart';
import 'package:lbp_ssh/presentation/providers/connection_provider.dart';
import 'package:lbp_ssh/presentation/screens/connection_form.dart';

/// 创建一个 exists() 为 true 但 readAsString 抛错的"不可读"文件（跨平台）。
/// POSIX 用 chmod 000；Windows 用 icacls 仅拒绝"读数据"权限 (RD)——
/// 若拒绝泛读权限 (R)，File.exists() 也会失败，应用会走"文件不存在"分支。
void makeFileUnreadable(File file) {
  if (Platform.isWindows) {
    Process.runSync('icacls', [file.path, '/deny', 'Everyone:(RD)']);
  } else {
    Process.runSync('chmod', ['000', file.path]);
  }
}

/// 恢复文件权限，保证测试结束后临时目录可被递归删除。
void restoreFilePermissions(File file) {
  if (Platform.isWindows) {
    Process.runSync('icacls', [file.path, '/remove:d', 'Everyone']);
  }
}

/// Fake FilePickerPlatform：可配置 pickFiles 返回值
class _FakeFilePickerPlatform extends FilePickerPlatform {
  FilePickerResult? pickResult;
  Object? pickError;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    void Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
    bool cancelUploadOnWindowBlur = true,
    AndroidSAFOptions? androidSafOptions,
  }) async {
    if (pickError != null) throw pickError!;
    return pickResult;
  }
}

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

/// 保存时抛错的 notifier，用于测试保存失败的错误对话框
class _ThrowingConnectionNotifier extends _MockConnectionNotifier {
  _ThrowingConnectionNotifier(super.state);

  @override
  Future<void> addConnection(SshConnection connection) async {
    throw Exception('模拟保存失败');
  }
}

void main() {
  late _MockConnectionNotifier mockNotifier;

  setUpAll(() {
    PackageInfo.setMockInitialValues(
      appName: 'lbp_ssh',
      packageName: 'com.lbp.lbp_ssh',
      version: '1.9.4',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  Widget createTestWidget({SshConnection? connection, bool saveFails = false}) {
    const state = ConnectionState();
    mockNotifier = saveFails
        ? _ThrowingConnectionNotifier(state)
        : _MockConnectionNotifier(state);

    return MaterialApp(
      home: ProviderScope(
        overrides: [connectionProvider.overrideWith(() => mockNotifier)],
        child: ConnectionFormScreen(connection: connection),
      ),
    );
  }

  /// 表单内容较长,使用高视口让 ListView 全部渲染,避免滚动查找
  Future<void> pumpForm(
    WidgetTester tester, {
    SshConnection? connection,
    bool saveFails = false,
  }) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      createTestWidget(connection: connection, saveFails: saveFails),
    );
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
    final file = File('${tempDir.path}/id_ed25519')..writeAsStringSync(content);
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

    testWidgets('Given existing connection with jump host, When rendered, '
        'Then jump host fields are prefilled', (tester) async {
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
    });

    testWidgets('Given existing connection with socks5 proxy, When rendered, '
        'Then proxy fields are prefilled', (tester) async {
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
    });

    testWidgets('Given key auth, When manual path dialog opened and cancelled, '
        'Then no key is loaded', (tester) async {
      await pumpForm(tester);
      await switchAuthType(tester, '密钥认证');

      await tester.tap(find.text('输入路径'));
      await tester.pumpAndSettle();

      expect(find.text('输入私钥文件路径'), findsOneWidget);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(find.text('输入私钥文件路径'), findsNothing);
    });

    testWidgets('Given key auth, When manual path points to non-existent file, '
        'Then shows file-not-exist message', (tester) async {
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
    });

    testWidgets('Given key auth, When manual path points to a valid key file, '
        'Then key is loaded and shown as loaded', (tester) async {
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
    });

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
      'Given key auth, When manual path points to an unreadable file, '
      'Then shows read-failure message',
      (tester) async {
        // 创建无读权限的文件，exists() 为 true 但 readAsString 抛错
        final tempDir = Directory.systemTemp.createTempSync('lbpssh_noread');
        final file = File('${tempDir.path}/noperm')
          ..writeAsStringSync('secret key');
        makeFileUnreadable(file);
        addTearDown(() {
          restoreFilePermissions(file);
          try {
            tempDir.deleteSync(recursive: true);
          } catch (_) {}
        });

        await pumpForm(tester);
        await switchAuthType(tester, '密钥认证');

        await tester.tap(find.text('输入路径'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextFormField),
          ),
          file.path,
        );
        await confirmManualPath(tester);

        // File.exists() 为 true，readAsString 权限不足抛错 → 读取失败消息
        expect(find.textContaining('读取文件失败'), findsOneWidget);
        await drainSnackBars(tester);
      },
    );

    for (final (label, header) in [
      ('RSA', '-----BEGIN RSA PRIVATE KEY-----'),
      ('DSA', '-----BEGIN DSA PRIVATE KEY-----'),
      ('EC', '-----BEGIN EC PRIVATE KEY-----'),
    ]) {
      testWidgets(
        'Given key auth, When manual path points to a valid $label key file, '
        'Then key is loaded and shown as loaded',
        (tester) async {
          final keyFile = createTempKeyFile(
            '$header\n'
            'test-content\n'
            '-----END $label PRIVATE KEY-----',
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
    }

    /// 点击「选择文件」按钮并等待 FilePicker + 真实文件 IO 完成
    Future<void> pickKeyFile(WidgetTester tester) async {
      await tester.tap(find.text('选择文件'));
      for (var i = 0; i < 10; i++) {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
      }
      await tester.pumpAndSettle();
    }

    group('FilePicker key selection', () {
      late FilePickerPlatform originalPlatform;

      setUp(() {
        originalPlatform = FilePickerPlatform.instance;
      });

      tearDown(() {
        FilePickerPlatform.instance = originalPlatform;
      });

      testWidgets('Given key auth, When FilePicker returns a valid key file, '
          'Then key is loaded and shown as loaded', (tester) async {
        final keyFile = createTempKeyFile(
          '-----BEGIN OPENSSH PRIVATE KEY-----\n'
          'test-content\n'
          '-----END OPENSSH PRIVATE KEY-----',
        );
        FilePickerPlatform.instance = _FakeFilePickerPlatform()
          ..pickResult = FilePickerResult([
            PlatformFile(name: 'id_ed25519', path: keyFile.path, size: 0),
          ]);

        await pumpForm(tester);
        await switchAuthType(tester, '密钥认证');

        await pickKeyFile(tester);

        expect(find.textContaining('私钥文件已加载'), findsOneWidget);
        await drainSnackBars(tester);
      });

      testWidgets(
        'Given key auth, When FilePicker returns a valid RSA key file, '
        'Then key is loaded and shown as loaded',
        (tester) async {
          final keyFile = createTempKeyFile(
            '-----BEGIN RSA PRIVATE KEY-----\n'
            'test-content\n'
            '-----END RSA PRIVATE KEY-----',
          );
          FilePickerPlatform.instance = _FakeFilePickerPlatform()
            ..pickResult = FilePickerResult([
              PlatformFile(name: 'id_rsa', path: keyFile.path, size: 0),
            ]);

          await pumpForm(tester);
          await switchAuthType(tester, '密钥认证');

          await pickKeyFile(tester);

          expect(find.textContaining('私钥文件已加载'), findsOneWidget);
          await drainSnackBars(tester);
        },
      );

      testWidgets('Given key auth, When FilePicker is cancelled, '
          'Then no key is loaded and no snackbar is shown', (tester) async {
        FilePickerPlatform.instance = _FakeFilePickerPlatform();

        await pumpForm(tester);
        await switchAuthType(tester, '密钥认证');

        await pickKeyFile(tester);

        expect(find.textContaining('私钥文件已加载'), findsNothing);
        expect(find.text('文件不存在或无法访问'), findsNothing);
        expect(find.textContaining('文件不是有效的私钥格式'), findsNothing);
      });

      testWidgets(
        'Given key auth, When FilePicker returns a non-existent file, '
        'Then shows file-not-exist message',
        (tester) async {
          FilePickerPlatform.instance = _FakeFilePickerPlatform()
            ..pickResult = FilePickerResult([
              PlatformFile(
                name: 'key.pem',
                path: '/non/existent/key.pem',
                size: 0,
              ),
            ]);

          await pumpForm(tester);
          await switchAuthType(tester, '密钥认证');

          await pickKeyFile(tester);

          expect(find.text('文件不存在或无法访问'), findsOneWidget);
          await drainSnackBars(tester);
        },
      );

      testWidgets(
        'Given key auth, When FilePicker returns an invalid key file, '
        'Then shows invalid-key-format message',
        (tester) async {
          final keyFile = createTempKeyFile('not a valid key');
          FilePickerPlatform.instance = _FakeFilePickerPlatform()
            ..pickResult = FilePickerResult([
              PlatformFile(name: 'bad_key', path: keyFile.path, size: 0),
            ]);

          await pumpForm(tester);
          await switchAuthType(tester, '密钥认证');

          await pickKeyFile(tester);

          expect(find.textContaining('文件不是有效的私钥格式'), findsOneWidget);
          await drainSnackBars(tester);
        },
      );

      testWidgets('Given key auth, When FilePicker returns an unreadable file, '
          'Then shows read-failure error dialog', (tester) async {
        // 创建无读权限的文件，exists() 为 true 但 readAsString 抛错
        final tempDir = Directory.systemTemp.createTempSync('lbpssh_noread');
        final file = File('${tempDir.path}/noperm')
          ..writeAsStringSync('secret key');
        makeFileUnreadable(file);
        addTearDown(() {
          restoreFilePermissions(file);
          try {
            tempDir.deleteSync(recursive: true);
          } catch (_) {}
        });
        FilePickerPlatform.instance = _FakeFilePickerPlatform()
          ..pickResult = FilePickerResult([
            PlatformFile(name: 'key_noperm', path: file.path, size: 0),
          ]);

        await pumpForm(tester);
        await switchAuthType(tester, '密钥认证');

        await pickKeyFile(tester);

        // File(path).exists() 为 true，readAsString 抛错 → 错误对话框
        expect(find.text('读取文件失败'), findsOneWidget);
        await tester.tap(find.text('关闭'));
        await tester.pumpAndSettle();
      });

      testWidgets('Given key auth, When FilePicker platform throws, '
          'Then shows pick-failure error dialog', (tester) async {
        FilePickerPlatform.instance = _FakeFilePickerPlatform()
          ..pickError = Exception('picker exploded');

        await pumpForm(tester);
        await switchAuthType(tester, '密钥认证');

        await pickKeyFile(tester);

        expect(find.text('选择文件失败'), findsOneWidget);
        await tester.tap(find.text('关闭'));
        await tester.pumpAndSettle();
      });
    });

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
      'Given SOCKS5 proxy with username and password, When save pressed, '
      'Then connection includes proxy credentials',
      (tester) async {
        await pumpForm(tester);

        await enterField(tester, '连接名称', '代理服务器');
        await enterField(tester, '主机地址', '192.168.1.80');
        await enterField(tester, '用户名', 'root');

        // 启用 SOCKS5 代理并填写用户名 + 密码
        await tester.tap(find.text('使用 SOCKS5 代理'));
        await tester.pumpAndSettle();
        await enterField(tester, '代理主机', '127.0.0.1');
        await enterField(tester, '端口', '1080', last: true);
        await enterField(tester, '用户名', 'proxyuser', last: true);
        await enterField(tester, '密码', 'proxypass', last: true);

        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();

        expect(mockNotifier.added, hasLength(1));
        final conn = mockNotifier.added.single;
        expect(conn.socks5Proxy!.host, '127.0.0.1');
        expect(conn.socks5Proxy!.username, 'proxyuser');
        expect(conn.socks5Proxy!.password, 'proxypass');
      },
    );

    testWidgets('Given valid form with loaded key, When save pressed, '
        'Then connection includes privateKeyContent', (tester) async {
      const validKey =
          '-----BEGIN OPENSSH PRIVATE KEY-----\n'
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
    });

    testWidgets('Given existing connection, When save pressed, '
        'Then connection is updated with same id', (tester) async {
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
    });

    testWidgets(
      'Given password auth with password and notes filled, When save pressed, '
      'Then connection includes password and notes',
      (tester) async {
        await pumpForm(tester);

        await enterField(tester, '连接名称', '密码服务器');
        await enterField(tester, '主机地址', '192.168.1.50');
        await enterField(tester, '用户名', 'root');
        await enterField(tester, '密码', 'secret123');
        await enterField(tester, '备注', '生产环境主服务器');

        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();

        expect(mockNotifier.added, hasLength(1));
        final conn = mockNotifier.added.single;
        expect(conn.authType, AuthType.password);
        expect(conn.password, 'secret123');
        expect(conn.notes, '生产环境主服务器');
      },
    );

    testWidgets(
      'Given keyWithPassword auth with loaded key and passphrase, '
      'When save pressed, Then connection includes passphrase and key content',
      (tester) async {
        const validKey =
            '-----BEGIN OPENSSH PRIVATE KEY-----\n'
            'test-content\n'
            '-----END OPENSSH PRIVATE KEY-----';
        final keyFile = createTempKeyFile(validKey);

        await pumpForm(tester);
        await switchAuthType(tester, '密钥+密码认证');

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
        await enterField(tester, '密钥密码', 'passphrase123');

        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();

        expect(mockNotifier.added, hasLength(1));
        final conn = mockNotifier.added.single;
        expect(conn.authType, AuthType.keyWithPassword);
        expect(conn.keyPassphrase, 'passphrase123');
        expect(conn.privateKeyContent, validKey);
        await drainSnackBars(tester);
      },
    );

    testWidgets('Given jump host with password filled, When save pressed, '
        'Then connection includes jump host password', (tester) async {
      await pumpForm(tester);

      await enterField(tester, '连接名称', '隧道服务器');
      await enterField(tester, '主机地址', '192.168.1.200');
      await enterField(tester, '用户名', 'root');

      await tester.tap(find.text('使用跳板机'));
      await tester.pumpAndSettle();
      await enterField(tester, '跳板机地址', '10.0.0.1');
      await enterField(tester, '跳板机用户名', 'jumpuser', last: true);
      await enterField(tester, '跳板机密码', 'jumpsecret');

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(mockNotifier.added, hasLength(1));
      final conn = mockNotifier.added.single;
      expect(conn.jumpHost!.password, 'jumpsecret');
    });

    testWidgets('Given jump host enabled, When jump auth switched to key, '
        'Then jump password field hides and shows again on password', (
      tester,
    ) async {
      await pumpForm(tester);

      await tester.tap(find.text('使用跳板机'));
      await tester.pumpAndSettle();
      expect(find.text('跳板机密码'), findsOneWidget);

      // 跳板机认证方式下拉框（页面中第二个 AuthType 下拉框）
      await tester.tap(find.byType(DropdownButtonFormField<AuthType>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('密钥认证').last);
      await tester.pumpAndSettle();

      expect(find.text('跳板机密码'), findsNothing);

      // 切回密码认证
      await tester.tap(find.byType(DropdownButtonFormField<AuthType>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('密码认证').last);
      await tester.pumpAndSettle();

      expect(find.text('跳板机密码'), findsOneWidget);
    });

    testWidgets('Given sshConfig auth selected, When rendered, '
        'Then shows refresh button regardless of config file', (tester) async {
      await pumpForm(tester);
      await switchAuthType(tester, 'SSH Config');

      // 无论 ~/.ssh/config 是否存在，刷新列表按钮都会显示
      expect(find.text('刷新列表'), findsOneWidget);
    });

    testWidgets('Given sshConfig auth without selection, When save pressed, '
        'Then connection has sshConfig auth and null sshConfigHost', (
      tester,
    ) async {
      await pumpForm(tester);

      await enterField(tester, '连接名称', '配置服务器');
      await enterField(tester, '主机地址', '192.168.1.60');
      await enterField(tester, '用户名', 'root');
      await switchAuthType(tester, 'SSH Config');

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(mockNotifier.added, hasLength(1));
      final conn = mockNotifier.added.single;
      expect(conn.authType, AuthType.sshConfig);
      expect(conn.sshConfigHost, isNull);
    });

    testWidgets(
      'Given sshConfig auth with config entries, When host selected from dropdown, '
      'Then host, port and username are auto-filled',
      (tester) async {
        final entries = SshConfigService.readConfigFile();

        await pumpForm(tester);
        await switchAuthType(tester, 'SSH Config');

        if (entries.isEmpty) {
          // 无 ~/.ssh/config → 显示空态警告
          expect(find.textContaining('未找到 ~/.ssh/config 文件'), findsOneWidget);
          return;
        }

        final first = entries.first;

        // 打开 SSH Config 主机下拉框并选择第一个条目
        await tester.tap(find.byType(DropdownButtonFormField<String?>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text(first.hostName).last);
        await tester.pumpAndSettle();

        // 自动填充主机
        final hostField = tester.widget<TextFormField>(
          find.ancestor(
            of: find.text('主机地址'),
            matching: find.byType(TextFormField),
          ),
        );
        expect(hostField.controller?.text, first.getConnectHost());

        // 自动填充端口
        if (first.port != null) {
          final portField = tester.widget<TextFormField>(
            find.ancestor(
              of: find.text('端口'),
              matching: find.byType(TextFormField),
            ),
          );
          expect(portField.controller?.text, first.port.toString());
        }

        // 自动填充用户名
        if (first.user != null) {
          final userField = tester.widget<TextFormField>(
            find.ancestor(
              of: find.text('用户名'),
              matching: find.byType(TextFormField),
            ),
          );
          expect(userField.controller?.text, first.user);
        }
      },
    );

    testWidgets('Given sshConfig auth, When refresh tapped, '
        'Then reloads entries without error', (tester) async {
      await pumpForm(tester);
      await switchAuthType(tester, 'SSH Config');

      await tester.tap(find.text('刷新列表'));
      await tester.pumpAndSettle();

      // 刷新后按配置存在与否展示下拉框或空态提示
      final entries = SshConfigService.readConfigFile();
      if (entries.isEmpty) {
        expect(find.textContaining('未找到 ~/.ssh/config 文件'), findsOneWidget);
      } else {
        expect(find.text('选择 SSH Config 主机'), findsOneWidget);
      }
    });

    testWidgets('Given addConnection throws, When save pressed, '
        'Then shows error dialog with 保存失败', (tester) async {
      await pumpForm(tester, saveFails: true);

      await enterField(tester, '连接名称', '失败服务器');
      await enterField(tester, '主机地址', '192.168.1.70');
      await enterField(tester, '用户名', 'root');

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.text('保存失败'), findsOneWidget);
      expect(find.textContaining('模拟保存失败'), findsOneWidget);

      // 关闭对话框
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(find.text('保存失败'), findsNothing);
    });

    testWidgets('Given existing connection with key auth, When rendered, '
        'Then shows loaded key status', (tester) async {
      const validKey =
          '-----BEGIN OPENSSH PRIVATE KEY-----\n'
          'test-content\n'
          '-----END OPENSSH PRIVATE KEY-----';
      final connection = SshConnection(
        id: '1',
        name: '密钥服务器',
        host: '10.0.0.2',
        username: 'root',
        authType: AuthType.key,
        privateKeyContent: validKey,
        privateKeyPath: '/Users/test/.ssh/id_ed25519',
      );

      await pumpForm(tester, connection: connection);

      expect(find.textContaining('私钥已加载'), findsOneWidget);
    });

    testWidgets('Given manual path dialog with empty input, When 确定 tapped, '
        'Then dialog stays open', (tester) async {
      await pumpForm(tester);
      await switchAuthType(tester, '密钥认证');

      await tester.tap(find.text('输入路径'));
      await tester.pumpAndSettle();

      // 不输入路径直接点确定，对话框不应关闭
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();

      expect(find.text('输入私钥文件路径'), findsOneWidget);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('输入私钥文件路径'), findsNothing);
    });
  });
}
