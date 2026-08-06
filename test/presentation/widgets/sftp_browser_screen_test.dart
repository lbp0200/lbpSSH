import 'dart:async';

import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lbp_ssh/data/models/file_item.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/domain/services/kitty_file_transfer_service.dart';
import 'package:lbp_ssh/presentation/providers/sftp_provider.dart';
import 'package:lbp_ssh/presentation/screens/sftp_browser_screen.dart';

class _MockTransferService extends Mock implements KittyFileTransferService {}

/// 正常打开标签页的 mock:直接返回预设 tab,跳过 terminalProvider 依赖
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

/// 打开标签页失败(未连接)的 mock
class _FailingSftpNotifier extends SftpNotifier {
  @override
  SftpState build() => const SftpState();

  @override
  Future<SftpTab> openTab(
    SshConnection connection, {
    String? password,
  }) async {
    throw Exception('终端会话不存在');
  }
}

void main() {
  late SshConnection connection;
  late KittyFileTransferService transferService;

  setUp(() {
    connection = SshConnection(
      id: '1',
      name: 'Test Server',
      host: '10.0.0.1',
      username: 'root',
      authType: AuthType.password,
    );
    transferService = _MockTransferService();
    // _refresh() 读取 currentPath 更新路径,需 stub
    when(() => transferService.currentPath).thenReturn('/home/user');
  });

  Widget createTestWidget(SftpNotifier notifier) {
    return MaterialApp(
      home: ProviderScope(
        overrides: [
          sftpProvider.overrideWith(() => notifier),
        ],
        child: SftpBrowserScreen(connection: connection),
      ),
    );
  }

  group('SftpBrowserScreen', () {
    testWidgets(
      'Given loading directory, When rendered, Then shows progress indicator',
      (tester) async {
        final completer = Completer<List<FileItem>>();
        when(
          () => transferService.listCurrentDirectory(),
        ).thenAnswer((_) => completer.future);

        final tab = SftpTab(
          id: 'tab1',
          connection: connection,
          service: transferService,
          currentPath: '/home/user',
        );

        await tester.pumpWidget(createTestWidget(_MockSftpNotifier(tab)));
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        completer.complete([]);
        await tester.pumpAndSettle();
        expect(find.text('目录为空'), findsOneWidget);
      },
    );

    testWidgets(
      'Given empty directory, When rendered, Then shows empty message',
      (tester) async {
        when(
          () => transferService.listCurrentDirectory(),
        ).thenAnswer((_) async => []);

        final tab = SftpTab(
          id: 'tab1',
          connection: connection,
          service: transferService,
          currentPath: '/home/user',
        );

        await tester.pumpWidget(createTestWidget(_MockSftpNotifier(tab)));
        await tester.pumpAndSettle();

        expect(find.text('/home/user'), findsOneWidget);
        expect(find.text('目录为空'), findsOneWidget);
      },
    );

    testWidgets(
      'Given directory with items, When rendered, Then shows file list',
      (tester) async {
        when(() => transferService.listCurrentDirectory()).thenAnswer(
          (_) async => [
            FileItem(
              name: 'docs',
              path: '/home/user/docs',
              isDirectory: true,
            ),
            FileItem(
              name: 'notes.txt',
              path: '/home/user/notes.txt',
              isDirectory: false,
              size: 2048,
            ),
          ],
        );

        final tab = SftpTab(
          id: 'tab1',
          connection: connection,
          service: transferService,
          currentPath: '/home/user',
        );

        await tester.pumpWidget(createTestWidget(_MockSftpNotifier(tab)));
        await tester.pumpAndSettle();

        expect(find.text('docs'), findsOneWidget);
        expect(find.text('notes.txt'), findsOneWidget);
        // 目录排在前,文件在后(txt 使用 description 图标)
        final dirIcon = tester.getTopLeft(find.byIcon(Icons.folder));
        final fileIcon = tester.getTopLeft(find.byIcon(Icons.description));
        expect(dirIcon.dy, lessThan(fileIcon.dy));
      },
    );

    testWidgets(
      'Given connection fails, When rendered, Then shows error and retry',
      (tester) async {
        await tester.pumpWidget(createTestWidget(_FailingSftpNotifier()));
        await tester.pumpAndSettle();

        expect(find.textContaining('终端会话不存在'), findsOneWidget);
        expect(find.text('重试'), findsOneWidget);
      },
    );

    testWidgets(
      'Given directory loaded, When refresh pressed, Then reloads list',
      (tester) async {
        when(() => transferService.listCurrentDirectory()).thenAnswer(
          (_) async => [
            FileItem(
              name: 'a.txt',
              path: '/a.txt',
              isDirectory: false,
            ),
          ],
        );

        final tab = SftpTab(
          id: 'tab1',
          connection: connection,
          service: transferService,
          currentPath: '/',
        );

        await tester.pumpWidget(createTestWidget(_MockSftpNotifier(tab)));
        await tester.pumpAndSettle();

        expect(find.text('a.txt'), findsOneWidget);

        // 刷新后目录变化
        when(() => transferService.listCurrentDirectory()).thenAnswer(
          (_) async => [
            FileItem(
              name: 'b.txt',
              path: '/b.txt',
              isDirectory: false,
            ),
          ],
        );
        // AppBar 与工具栏都有刷新按钮,取 AppBar 中的第一个
        await tester.tap(find.byIcon(Icons.refresh).first);
        await tester.pumpAndSettle();

        expect(find.text('b.txt'), findsOneWidget);
        expect(find.text('a.txt'), findsNothing);
      },
    );
  });
}
