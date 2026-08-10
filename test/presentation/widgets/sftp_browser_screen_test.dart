import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lbp_ssh/data/models/file_item.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/domain/services/kitty_file_transfer_service.dart'
    hide FileType;
import 'package:lbp_ssh/presentation/providers/sftp_provider.dart';
import 'package:lbp_ssh/presentation/screens/sftp_browser_screen.dart';

class _MockTransferService extends Mock implements KittyFileTransferService {}

/// Fake FilePickerPlatform：可配置 pickFiles/getDirectoryPath 返回值
class _FakeFilePickerPlatform extends FilePickerPlatform {
  FilePickerResult? pickResult;
  String? directoryPath;

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
    return pickResult;
  }

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    bool lockParentWindow = false,
    String? initialDirectory,
    AndroidSAFOptions? androidSafOptions,
  }) async {
    return directoryPath;
  }
}

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

    testWidgets(
      'Given directory loaded, When create folder button pressed, Then shows dialog and creates folder',
      (tester) async {
        when(() => transferService.listCurrentDirectory()).thenAnswer(
          (_) async => [FileItem(name: 'a.txt', path: '/a.txt', isDirectory: false)],
        );
        when(() => transferService.createDirectory(any())).thenAnswer(
          (_) async {},
        );

        final tab = SftpTab(
          id: 'tab1',
          connection: connection,
          service: transferService,
          currentPath: '/',
        );

        await tester.pumpWidget(createTestWidget(_MockSftpNotifier(tab)));
        await tester.pumpAndSettle();

        // 点击新建文件夹按钮,弹出输入对话框
        await tester.tap(find.byTooltip('新建文件夹'));
        await tester.pumpAndSettle();

        expect(find.text('新建文件夹'), findsWidgets);

        // 输入名称并确认
        await tester.enterText(find.byType(TextField), 'backup');
        await tester.tap(find.text('确定'));
        await tester.pumpAndSettle();

        verify(() => transferService.createDirectory('backup')).called(1);
      },
    );

    testWidgets(
      'Given directory loaded, When item long-pressed, Then shows menu with download and delete',
      (tester) async {
        when(() => transferService.listCurrentDirectory()).thenAnswer(
          (_) async => [FileItem(name: 'a.txt', path: '/a.txt', isDirectory: false)],
        );

        final tab = SftpTab(
          id: 'tab1',
          connection: connection,
          service: transferService,
          currentPath: '/',
        );

        await tester.pumpWidget(createTestWidget(_MockSftpNotifier(tab)));
        await tester.pumpAndSettle();

        // 长按文件项打开菜单
        await tester.longPress(find.text('a.txt'));
        await tester.pumpAndSettle();

        expect(find.text('下载'), findsOneWidget);
        expect(find.text('删除'), findsOneWidget);
      },
    );

    testWidgets(
      'Given item menu open, When delete confirmed, Then removes file',
      (tester) async {
        when(() => transferService.listCurrentDirectory()).thenAnswer(
          (_) async => [FileItem(name: 'a.txt', path: '/a.txt', isDirectory: false)],
        );
        when(() => transferService.removeFile(any())).thenAnswer(
          (_) async {},
        );

        final tab = SftpTab(
          id: 'tab1',
          connection: connection,
          service: transferService,
          currentPath: '/',
        );

        await tester.pumpWidget(createTestWidget(_MockSftpNotifier(tab)));
        await tester.pumpAndSettle();

        // 长按 → 删除 → 确认对话框 → 确认
        await tester.longPress(find.text('a.txt'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('删除').last);
        await tester.pumpAndSettle();

        expect(find.text('确认删除'), findsOneWidget);
        expect(find.textContaining('确定要删除 "a.txt" 吗'), findsOneWidget);

        await tester.tap(find.text('删除').last);
        await tester.pumpAndSettle();

        verify(() => transferService.removeFile('/a.txt')).called(1);
      },
    );

    testWidgets(
      'Given directory item, When tapped, Then changes directory and refreshes',
      (tester) async {
        when(() => transferService.listCurrentDirectory()).thenAnswer(
          (_) async => [
            FileItem(
              name: 'docs',
              path: '/home/user/docs',
              isDirectory: true,
            ),
          ],
        );
        when(() => transferService.changeDirectory('docs')).thenAnswer(
          (_) async {},
        );

        final tab = SftpTab(
          id: 'tab1',
          connection: connection,
          service: transferService,
          currentPath: '/home/user',
        );

        await tester.pumpWidget(createTestWidget(_MockSftpNotifier(tab)));
        await tester.pumpAndSettle();

        await tester.tap(find.text('docs'));
        await tester.pumpAndSettle();

        verify(() => transferService.changeDirectory('docs')).called(1);
      },
    );

    testWidgets(
      'Given non-root path, When back button pressed, Then goes up and refreshes',
      (tester) async {
        when(() => transferService.listCurrentDirectory()).thenAnswer(
          (_) async => [
            FileItem(
              name: 'parent.txt',
              path: '/parent.txt',
              isDirectory: false,
            ),
          ],
        );
        when(() => transferService.goUp()).thenAnswer((_) async {});

        final tab = SftpTab(
          id: 'tab1',
          connection: connection,
          service: transferService,
          currentPath: '/home/user',
        );

        await tester.pumpWidget(createTestWidget(_MockSftpNotifier(tab)));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        verify(() => transferService.goUp()).called(1);
      },
    );

    testWidgets(
      'Given list refresh throws, When rendered, Then shows error and retry',
      (tester) async {
        when(() => transferService.listCurrentDirectory()).thenThrow(
          Exception('boom'),
        );

        final tab = SftpTab(
          id: 'tab1',
          connection: connection,
          service: transferService,
          currentPath: '/home/user',
        );

        await tester.pumpWidget(createTestWidget(_MockSftpNotifier(tab)));
        await tester.pumpAndSettle();

        expect(find.textContaining('boom'), findsOneWidget);
        expect(find.text('重试'), findsOneWidget);
      },
    );

    testWidgets(
      'Given create folder dialog, When cancel pressed, Then no folder created',
      (tester) async {
        when(() => transferService.listCurrentDirectory()).thenAnswer(
          (_) async => [FileItem(name: 'a.txt', path: '/a.txt', isDirectory: false)],
        );

        final tab = SftpTab(
          id: 'tab1',
          connection: connection,
          service: transferService,
          currentPath: '/',
        );

        await tester.pumpWidget(createTestWidget(_MockSftpNotifier(tab)));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('新建文件夹'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();

        verifyNever(() => transferService.createDirectory(any()));
      },
    );

    testWidgets(
      'Given createDirectory throws, When folder created, Then shows error snackbar',
      (tester) async {
        when(() => transferService.listCurrentDirectory()).thenAnswer(
          (_) async => [FileItem(name: 'a.txt', path: '/a.txt', isDirectory: false)],
        );
        when(() => transferService.createDirectory(any())).thenThrow(
          Exception('mkdir failed'),
        );

        final tab = SftpTab(
          id: 'tab1',
          connection: connection,
          service: transferService,
          currentPath: '/',
        );

        await tester.pumpWidget(createTestWidget(_MockSftpNotifier(tab)));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('新建文件夹'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'backup');
        await tester.tap(find.text('确定'));
        await tester.pumpAndSettle();

        expect(find.textContaining('mkdir failed'), findsOneWidget);
      },
    );

    testWidgets(
      'Given delete dialog, When cancel pressed, Then file not removed',
      (tester) async {
        when(() => transferService.listCurrentDirectory()).thenAnswer(
          (_) async => [FileItem(name: 'a.txt', path: '/a.txt', isDirectory: false)],
        );

        final tab = SftpTab(
          id: 'tab1',
          connection: connection,
          service: transferService,
          currentPath: '/',
        );

        await tester.pumpWidget(createTestWidget(_MockSftpNotifier(tab)));
        await tester.pumpAndSettle();

        await tester.longPress(find.text('a.txt'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('删除').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();

        verifyNever(() => transferService.removeFile(any()));
      },
    );

    testWidgets(
      'Given directory item, When delete confirmed, Then removes directory',
      (tester) async {
        when(() => transferService.listCurrentDirectory()).thenAnswer(
          (_) async => [
            FileItem(
              name: 'docs',
              path: '/home/user/docs',
              isDirectory: true,
            ),
          ],
        );
        when(() => transferService.removeDirectory(any())).thenAnswer(
          (_) async {},
        );

        final tab = SftpTab(
          id: 'tab1',
          connection: connection,
          service: transferService,
          currentPath: '/home/user',
        );

        await tester.pumpWidget(createTestWidget(_MockSftpNotifier(tab)));
        await tester.pumpAndSettle();

        await tester.longPress(find.text('docs'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('删除').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('删除').last);
        await tester.pumpAndSettle();

        verify(() => transferService.removeDirectory('/home/user/docs'))
            .called(1);
      },
    );

    testWidgets(
      'Given removeFile throws, When delete confirmed, Then shows error snackbar',
      (tester) async {
        when(() => transferService.listCurrentDirectory()).thenAnswer(
          (_) async => [FileItem(name: 'a.txt', path: '/a.txt', isDirectory: false)],
        );
        when(() => transferService.removeFile(any())).thenThrow(
          Exception('rm failed'),
        );

        final tab = SftpTab(
          id: 'tab1',
          connection: connection,
          service: transferService,
          currentPath: '/',
        );

        await tester.pumpWidget(createTestWidget(_MockSftpNotifier(tab)));
        await tester.pumpAndSettle();

        await tester.longPress(find.text('a.txt'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('删除').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('删除').last);
        await tester.pumpAndSettle();

        expect(find.textContaining('rm failed'), findsOneWidget);
      },
    );

    testWidgets(
      'Given directory item, When download menu tapped, Then does not download',
      (tester) async {
        when(() => transferService.listCurrentDirectory()).thenAnswer(
          (_) async => [
            FileItem(
              name: 'docs',
              path: '/docs',
              isDirectory: true,
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

        await tester.longPress(find.text('docs'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('下载'));
        await tester.pumpAndSettle();

        verifyNever(() => transferService.downloadFile(any(), any()));
      },
    );

    testWidgets(
      'Given various file extensions, When rendered, Then shows matching icons',
      (tester) async {
        when(() => transferService.listCurrentDirectory()).thenAnswer(
          (_) async => [
            FileItem(name: 'photo.png', path: '/photo.png', isDirectory: false),
            FileItem(name: 'doc.pdf', path: '/doc.pdf', isDirectory: false),
            FileItem(name: 'data.zip', path: '/data.zip', isDirectory: false),
            FileItem(name: 'notes.md', path: '/notes.md', isDirectory: false),
            FileItem(name: 'misc.xyz', path: '/misc.xyz', isDirectory: false),
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

        expect(find.byIcon(Icons.image), findsOneWidget);
        expect(find.byIcon(Icons.picture_as_pdf), findsOneWidget);
        expect(find.byIcon(Icons.archive), findsOneWidget);
        expect(find.byIcon(Icons.description), findsOneWidget);
        expect(find.byIcon(Icons.insert_drive_file), findsOneWidget);
      },
    );

    testWidgets(
      'Given large files, When rendered, Then formats size in MB and GB',
      (tester) async {
        when(() => transferService.listCurrentDirectory()).thenAnswer(
          (_) async => [
            FileItem(
              name: 'big.bin',
              path: '/big.bin',
              isDirectory: false,
              size: 5 * 1024 * 1024, // 5 MB
            ),
            FileItem(
              name: 'huge.bin',
              path: '/huge.bin',
              isDirectory: false,
              size: 3 * 1024 * 1024 * 1024, // 3 GB
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

        expect(find.text('5.0 MB'), findsOneWidget);
        expect(find.text('3.0 GB'), findsOneWidget);
      },
    );

    testWidgets(
      'Given upload file picked, When upload pressed, Then sends file and shows success',
      (tester) async {
        when(() => transferService.listCurrentDirectory()).thenAnswer(
          (_) async => <FileItem>[],
        );
        when(
          () => transferService.sendFile(
            localPath: any(named: 'localPath'),
            remoteFileName: any(named: 'remoteFileName'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((_) async {});

        final fake = _FakeFilePickerPlatform()
          ..pickResult = FilePickerResult([
            PlatformFile(name: 'up.txt', size: 100, path: '/tmp/up.txt'),
          ]);
        final original = FilePickerPlatform.instance;
        FilePickerPlatform.instance = fake;
        addTearDown(() => FilePickerPlatform.instance = original);

        final tab = SftpTab(
          id: 'tab1',
          connection: connection,
          service: transferService,
          currentPath: '/',
        );

        await tester.pumpWidget(createTestWidget(_MockSftpNotifier(tab)));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('上传'));
        await tester.pumpAndSettle();

        verify(
          () => transferService.sendFile(
            localPath: any(named: 'localPath'),
            remoteFileName: any(named: 'remoteFileName'),
            onProgress: any(named: 'onProgress'),
          ),
        ).called(1);
        expect(find.text('上传成功'), findsOneWidget);
      },
    );

    testWidgets(
      'Given upload in progress, When cancel tapped, '
      'Then progress dialog closes and no success message shown',
      (tester) async {
        // sendFile 挂起，让进度对话框保持打开
        final uploadCompleter = Completer<void>();
        when(() => transferService.listCurrentDirectory()).thenAnswer(
          (_) async => <FileItem>[],
        );
        when(
          () => transferService.sendFile(
            localPath: any(named: 'localPath'),
            remoteFileName: any(named: 'remoteFileName'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((_) => uploadCompleter.future);

        final fake = _FakeFilePickerPlatform()
          ..pickResult = FilePickerResult([
            PlatformFile(name: 'up.txt', size: 100, path: '/tmp/up.txt'),
          ]);
        final original = FilePickerPlatform.instance;
        FilePickerPlatform.instance = fake;
        addTearDown(() => FilePickerPlatform.instance = original);

        final tab = SftpTab(
          id: 'tab1',
          connection: connection,
          service: transferService,
          currentPath: '/',
        );

        await tester.pumpWidget(createTestWidget(_MockSftpNotifier(tab)));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('上传'));
        await tester.pumpAndSettle();

        // 进度对话框可见
        expect(find.text('取消'), findsOneWidget);

        // 点击取消 → onCancel 关闭流并关闭对话框
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();

        expect(find.text('取消'), findsNothing);
        expect(find.text('上传成功'), findsNothing);

        // 完成挂起的传输，避免残留未完成 future
        uploadCompleter.complete();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Given download in progress, When cancel tapped, '
      'Then progress dialog closes and no success message shown',
      (tester) async {
        final downloadCompleter = Completer<void>();
        when(() => transferService.listCurrentDirectory()).thenAnswer(
          (_) async => [
            FileItem(name: 'a.txt', path: '/a.txt', isDirectory: false),
          ],
        );
        when(
          () => transferService.downloadFile(
            any(),
            any(),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((_) => downloadCompleter.future);

        final fake = _FakeFilePickerPlatform()..directoryPath = '/tmp';
        final original = FilePickerPlatform.instance;
        FilePickerPlatform.instance = fake;
        addTearDown(() => FilePickerPlatform.instance = original);

        final tab = SftpTab(
          id: 'tab1',
          connection: connection,
          service: transferService,
          currentPath: '/',
        );

        await tester.pumpWidget(createTestWidget(_MockSftpNotifier(tab)));
        await tester.pumpAndSettle();

        await tester.longPress(find.text('a.txt'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('下载'));
        await tester.pumpAndSettle();

        // 进度对话框可见
        expect(find.text('取消'), findsOneWidget);

        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();

        expect(find.text('取消'), findsNothing);
        expect(find.text('下载成功'), findsNothing);

        downloadCompleter.complete();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Given directory picked, When download menu tapped, '
      'Then downloads file and shows success',
      (tester) async {
        when(() => transferService.listCurrentDirectory()).thenAnswer(
          (_) async => [FileItem(name: 'a.txt', path: '/a.txt', isDirectory: false)],
        );
        when(
          () => transferService.downloadFile(
            any(),
            any(),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((_) async {});

        final fake = _FakeFilePickerPlatform()..directoryPath = '/tmp';
        final original = FilePickerPlatform.instance;
        FilePickerPlatform.instance = fake;
        addTearDown(() => FilePickerPlatform.instance = original);

        final tab = SftpTab(
          id: 'tab1',
          connection: connection,
          service: transferService,
          currentPath: '/',
        );

        await tester.pumpWidget(createTestWidget(_MockSftpNotifier(tab)));
        await tester.pumpAndSettle();

        await tester.longPress(find.text('a.txt'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('下载'));
        await tester.pumpAndSettle();

        verify(
          () => transferService.downloadFile(
            '/a.txt',
            '/tmp/a.txt',
            onProgress: any(named: 'onProgress'),
          ),
        ).called(1);
        expect(find.text('下载成功'), findsOneWidget);
      },
    );

    testWidgets(
      'Given upload file picked and sendFile throws, '
      'When upload pressed, Then shows upload failure',
      (tester) async {
        when(() => transferService.listCurrentDirectory()).thenAnswer(
          (_) async => <FileItem>[],
        );
        when(
          () => transferService.sendFile(
            localPath: any(named: 'localPath'),
            remoteFileName: any(named: 'remoteFileName'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenThrow(Exception('disk full'));

        final fake = _FakeFilePickerPlatform()
          ..pickResult = FilePickerResult([
            PlatformFile(name: 'fail.txt', size: 10, path: '/tmp/fail.txt'),
          ]);
        final original = FilePickerPlatform.instance;
        FilePickerPlatform.instance = fake;
        addTearDown(() => FilePickerPlatform.instance = original);

        final tab = SftpTab(
          id: 'tab1',
          connection: connection,
          service: transferService,
          currentPath: '/',
        );

        await tester.pumpWidget(createTestWidget(_MockSftpNotifier(tab)));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('上传'));
        await tester.pumpAndSettle();

        expect(find.textContaining('上传失败'), findsOneWidget);
      },
    );

    testWidgets(
      'Given download file picked and downloadFile throws, '
      'When download pressed, Then shows download failure',
      (tester) async {
        when(() => transferService.listCurrentDirectory()).thenAnswer(
          (_) async => [
            FileItem(name: 'b.txt', path: '/b.txt', isDirectory: false),
          ],
        );
        when(
          () => transferService.downloadFile(
            any(),
            any(),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenThrow(Exception('connection lost'));

        final fake = _FakeFilePickerPlatform()..directoryPath = '/tmp';
        final original = FilePickerPlatform.instance;
        FilePickerPlatform.instance = fake;
        addTearDown(() => FilePickerPlatform.instance = original);

        final tab = SftpTab(
          id: 'tab1',
          connection: connection,
          service: transferService,
          currentPath: '/',
        );

        await tester.pumpWidget(createTestWidget(_MockSftpNotifier(tab)));
        await tester.pumpAndSettle();

        await tester.longPress(find.text('b.txt'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('下载'));
        await tester.pumpAndSettle();

        expect(find.textContaining('下载失败'), findsOneWidget);
      },
    );

    testWidgets(
      'Given sendFile invokes onProgress, '
      'When upload pressed, Then progress stream is fed',
      (tester) async {
        when(() => transferService.listCurrentDirectory()).thenAnswer(
          (_) async => <FileItem>[],
        );
        when(
          () => transferService.sendFile(
            localPath: any(named: 'localPath'),
            remoteFileName: any(named: 'remoteFileName'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((invocation) async {
          // 模拟分块进度回调
          final callback =
              invocation.namedArguments[#onProgress]
                  as void Function(TransferProgress);
          callback(
            TransferProgress(
              fileName: 'up.txt',
              transferredBytes: 50,
              totalBytes: 100,
              percent: 50,
              bytesPerSecond: 0,
            ),
          );
        });

        final fake = _FakeFilePickerPlatform()
          ..pickResult = FilePickerResult([
            PlatformFile(name: 'up.txt', size: 100, path: '/tmp/up.txt'),
          ]);
        final original = FilePickerPlatform.instance;
        FilePickerPlatform.instance = fake;
        addTearDown(() => FilePickerPlatform.instance = original);

        final tab = SftpTab(
          id: 'tab1',
          connection: connection,
          service: transferService,
          currentPath: '/',
        );

        await tester.pumpWidget(createTestWidget(_MockSftpNotifier(tab)));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('上传'));
        await tester.pumpAndSettle();

        // 进度流被消费后对话框展示进度，上传完成后显示成功
        expect(find.text('上传成功'), findsOneWidget);
      },
    );
  });
}
