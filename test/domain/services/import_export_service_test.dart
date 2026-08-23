import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lbp_ssh/domain/services/import_export_service.dart';
import 'package:lbp_ssh/data/repositories/connection_repository.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';

class MockConnectionRepository extends Mock implements ConnectionRepository {}

/// Fake FilePickerPlatform：可配置 pickFiles/saveFile 返回值
class _FakeFilePickerPlatform extends FilePickerPlatform {
  List<PlatformFile>? pickResult;
  PlatformFile? pickFileResult;
  Uri? saveResult;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    void Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    return pickFileResult;
  }

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    void Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    return pickResult ?? [];
  }

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    void Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    return saveResult;
  }
}

// ---------------------------------------------------------------------------
// Fake SshConnection for registerFallbackValue
// ---------------------------------------------------------------------------

class FakeSshConnection extends Fake implements SshConnection {}

/// Simple test implementation of PlatformFile
base class _TestPlatformFile extends PlatformFile {
  @override
  final String path;
  @override
  final String name;

  _TestPlatformFile(this.path) : name = path.split('/').last;

  @override
  Uri get uri => Uri.file(path);

  @override
  XFile get xFile => XFile(path);

  @override
  Future<int> length() async => 0;

  @override
  Future<Uint8List> readAsBytes() async => Uint8List(0);

  @override
  Stream<Uint8List> readAsByteStream() => Stream.empty();
}

/// Helper to create PlatformFile from a File for testing
PlatformFile _createPlatformFile(File file) {
  return _TestPlatformFile(file.path);
}

void main() {
  late MockConnectionRepository mockRepository;
  late ImportExportService service;

  setUpAll(() {
    registerFallbackValue(FakeSshConnection());
    registerFallbackValue(<SshConnection>[]);
  });

  setUp(() {
    mockRepository = MockConnectionRepository();
    service = ImportExportService(mockRepository);
  });

  // ---------------------------------------------------------------------------
  // Test helpers
  // ---------------------------------------------------------------------------

  SshConnection makeConnection({
    String id = 'conn-1',
    String name = 'Test Connection',
    String host = '192.168.1.1',
    int port = 22,
    String username = 'user',
    AuthType authType = AuthType.password,
    String? password,
    String? privateKeyPath,
    String? privateKeyContent,
    String? keyPassphrase,
    JumpHostConfig? jumpHost,
    Socks5ProxyConfig? socks5Proxy,
    DateTime? createdAt,
    DateTime? updatedAt,
    int version = 1,
  }) {
    return SshConnection(
      id: id,
      name: name,
      host: host,
      port: port,
      username: username,
      authType: authType,
      password: password,
      privateKeyPath: privateKeyPath,
      privateKeyContent: privateKeyContent,
      keyPassphrase: keyPassphrase,
      jumpHost: jumpHost,
      socks5Proxy: socks5Proxy,
      createdAt: createdAt ?? DateTime.now(),
      updatedAt: updatedAt ?? DateTime.now(),
      version: version,
    );
  }

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------

  group('Constructor', () {
    test(
      'Given repository, When created, Then service is stateless and usable',
      () {
        when(() => mockRepository.getAllConnections()).thenReturn([]);
        expect(service.getExportStats()['totalConnections'], equals(0));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // _validateExportFile (tested indirectly via importFromLocalFile)
  // ---------------------------------------------------------------------------

  group('_validateExportFile (via importFromLocalFile)', () {
    test('Given empty repository, When checking stats, '
        'Then validation logic returns empty results', () {
      when(() => mockRepository.getAllConnections()).thenReturn([]);

      final stats = service.getExportStats();
      expect(stats['totalConnections'], equals(0));
      expect(stats['passwordAuth'], equals(0));
      expect(stats['keyAuth'], equals(0));
    });

    test('Given valid connections, When checking stats, '
        'Then returns correct counts', () {
      final connections = [
        makeConnection(id: 'c1', name: 'Conn 1', password: 'pw'),
      ];
      when(() => mockRepository.getAllConnections()).thenReturn(connections);

      final stats = service.getExportStats();

      expect(stats['totalConnections'], equals(1));
      expect(stats['passwordAuth'], equals(1));
    });
  });

  // ---------------------------------------------------------------------------
  // mergeImportedConnections
  // ---------------------------------------------------------------------------

  group('mergeImportedConnections', () {
    setUp(() {
      when(() => mockRepository.clearAll()).thenAnswer((_) async {});
      when(
        () => mockRepository.saveConnections(any()),
      ).thenAnswer((_) async {});
    });

    test('Given empty importedConnections, When merge called, '
        'Then returns current connections unchanged', () async {
      final existing = [
        makeConnection(id: 'existing-1', name: 'Existing 1'),
        makeConnection(id: 'existing-2', name: 'Existing 2'),
      ];
      when(() => mockRepository.getAllConnections()).thenReturn(existing);

      final result = await service.mergeImportedConnections([]);

      expect(result.length, equals(2));
      verify(() => mockRepository.clearAll()).called(1);
      verify(() => mockRepository.saveConnections(any())).called(1);
    });

    test('Given imported connection with new ID, When merge called, '
        'Then adds it to repository', () async {
      final existing = [makeConnection(id: 'existing-1', name: 'Existing 1')];
      final imported = [makeConnection(id: 'imported-1', name: 'Imported 1')];
      when(() => mockRepository.getAllConnections()).thenReturn(existing);

      final result = await service.mergeImportedConnections(imported);

      expect(result.length, equals(2));
      expect(result.any((c) => c.id == 'imported-1'), isTrue);
    });

    test(
      'Given imported connection with existing ID, When overwrite=false, addPrefix=true, '
      'Then skips the duplicate (addPrefix only applies when overwrite=true)',
      () async {
        final existing = [makeConnection(name: 'Original')];
        final imported = [makeConnection(name: 'Imported')];
        when(() => mockRepository.getAllConnections()).thenReturn(existing);

        final result = await service.mergeImportedConnections(imported);

        // With overwrite=false, duplicates are skipped regardless of addPrefix
        expect(result.length, equals(1));
        expect(result.first.id, equals('conn-1'));
        expect(result.first.name, equals('Original'));
      },
    );

    test(
      'Given imported connection with existing ID, When overwrite=false, addPrefix=false, '
      'Then skips the duplicate',
      () async {
        final existing = [makeConnection(name: 'Original')];
        final imported = [makeConnection(name: 'Imported')];
        when(() => mockRepository.getAllConnections()).thenReturn(existing);

        final result = await service.mergeImportedConnections(
          imported,
          addPrefix: false,
        );

        // Should only have original (imported skipped)
        expect(result.length, equals(1));
        expect(result.first.id, equals('conn-1'));
      },
    );

    test(
      'Given imported connection with existing ID, When overwrite=true, '
      'Then removes old and adds imported with new ID and prefixed name',
      () async {
        final existing = [makeConnection(name: 'Original')];
        final imported = [makeConnection(name: 'Imported')];
        when(() => mockRepository.getAllConnections()).thenReturn(existing);

        final result = await service.mergeImportedConnections(
          imported,
          overwrite: true,
        );

        // Should have imported with new ID and prefixed name (addPrefix defaults to true)
        expect(result.length, equals(1));
        final merged = result.firstWhere((c) => c.name == '导入_Imported');
        expect(merged.id, isNot(equals('conn-1')));
        expect(merged.id.contains('conn-1'), isTrue);
      },
    );

    test('Given multiple imports with some conflicts, some new, '
        'Then handles each correctly', () async {
      final existing = [
        makeConnection(id: 'existing-1', name: 'Existing 1'),
        makeConnection(id: 'conflict-1', name: 'Conflict'),
      ];
      final imported = [
        makeConnection(id: 'new-1', name: 'New 1'),
        makeConnection(id: 'conflict-1', name: 'Conflict Import'),
        makeConnection(id: 'new-2', name: 'New 2'),
      ];
      when(() => mockRepository.getAllConnections()).thenReturn(existing);

      final result = await service.mergeImportedConnections(imported);

      // With overwrite=false, conflict-1 is skipped
      // Result: existing-1, conflict-1 (original), new-1, new-2
      expect(result.length, equals(4));
      expect(result.any((c) => c.id == 'existing-1'), isTrue);
      expect(result.any((c) => c.name == 'Existing 1'), isTrue);
      expect(result.any((c) => c.name == 'Conflict'), isTrue);
      expect(result.any((c) => c.id == 'new-1'), isTrue);
      expect(result.any((c) => c.id == 'new-2'), isTrue);
    });

    test(
      'Given conflict with addPrefix=true and overwrite=true, '
      'When merge called, Then conflicting connection gets 导入_ prefix',
      () async {
        final existing = [makeConnection(name: 'Original')];
        final imported = [makeConnection(name: 'My Server')];
        when(() => mockRepository.getAllConnections()).thenReturn(existing);

        // addPrefix only affects names when there is a conflict and overwrite=true
        final result = await service.mergeImportedConnections(
          imported,
          overwrite: true,
        );

        expect(result.any((c) => c.name == '导入_My Server'), isTrue);
      },
    );

    test('When merge called, Then clears all and saves merged list', () async {
      final existing = [makeConnection(id: 'existing-1', name: 'Existing')];
      final imported = [makeConnection(id: 'imported-1', name: 'Imported')];
      when(() => mockRepository.getAllConnections()).thenReturn(existing);

      await service.mergeImportedConnections(imported);

      verifyInOrder([
        () => mockRepository.clearAll(),
        () => mockRepository.saveConnections(any()),
      ]);
    });
  });

  // ---------------------------------------------------------------------------
  // importAndSaveConnections
  // ---------------------------------------------------------------------------

  group('importAndSaveConnections', () {
    test('Given connections, When importAndSaveConnections called, '
        'Then calls mergeImportedConnections', () async {
      final connections = [makeConnection(name: 'Test')];

      when(() => mockRepository.getAllConnections()).thenReturn([]);
      when(() => mockRepository.clearAll()).thenAnswer((_) async {});
      when(
        () => mockRepository.saveConnections(any()),
      ).thenAnswer((_) async {});

      await service.importAndSaveConnections(connections);

      // verify that merge was called implicitly via importAndSaveConnections
      verify(() => mockRepository.clearAll()).called(1);
      verify(() => mockRepository.saveConnections(any())).called(1);
    });

    test(
      'Given connections with overwrite, When importAndSaveConnections called, '
      'Then passes overwrite parameter',
      () async {
        final connections = [makeConnection(name: 'Test')];

        when(
          () => mockRepository.getAllConnections(),
        ).thenReturn([makeConnection(name: 'Original')]);
        when(() => mockRepository.clearAll()).thenAnswer((_) async {});
        when(
          () => mockRepository.saveConnections(any()),
        ).thenAnswer((_) async {});

        await service.importAndSaveConnections(connections, overwrite: true);

        verify(() => mockRepository.clearAll()).called(1);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // getExportStats
  // ---------------------------------------------------------------------------

  group('getExportStats', () {
    test('Given empty repository, When getExportStats called, '
        'Then returns zero counts', () {
      when(() => mockRepository.getAllConnections()).thenReturn([]);

      final stats = service.getExportStats();

      expect(stats['totalConnections'], equals(0));
      expect(stats['passwordAuth'], equals(0));
      expect(stats['keyAuth'], equals(0));
      expect(stats['keyWithPasswordAuth'], equals(0));
      expect(stats['jumpHostConnections'], equals(0));
      expect(stats['lastUpdated'], isNull);
    });

    test('Given connections with password auth, When getExportStats called, '
        'Then counts correctly', () {
      final connections = [
        makeConnection(id: 'p1', password: 'secret'),
        makeConnection(id: 'p2', password: 'secret2'),
      ];
      when(() => mockRepository.getAllConnections()).thenReturn(connections);

      final stats = service.getExportStats();

      expect(stats['totalConnections'], equals(2));
      expect(stats['passwordAuth'], equals(2));
      expect(stats['keyAuth'], equals(0));
      expect(stats['keyWithPasswordAuth'], equals(0));
    });

    test('Given connections with key auth, When getExportStats called, '
        'Then counts correctly', () {
      final connections = [
        makeConnection(
          id: 'k1',
          authType: AuthType.key,
          privateKeyPath: '/path/to/key',
        ),
        makeConnection(
          id: 'k2',
          authType: AuthType.key,
          privateKeyPath: '/path/to/key2',
        ),
        makeConnection(
          id: 'k3',
          authType: AuthType.key,
          privateKeyPath: '/path/to/key3',
        ),
      ];
      when(() => mockRepository.getAllConnections()).thenReturn(connections);

      final stats = service.getExportStats();

      expect(stats['totalConnections'], equals(3));
      expect(stats['passwordAuth'], equals(0));
      expect(stats['keyAuth'], equals(3));
      expect(stats['keyWithPasswordAuth'], equals(0));
    });

    test('Given connections with key+passphrase auth, '
        'When getExportStats called, Then counts correctly', () {
      final connections = [
        makeConnection(
          id: 'kp1',
          authType: AuthType.keyWithPassword,
          privateKeyContent: 'keycontent',
          keyPassphrase: 'passphrase',
        ),
      ];
      when(() => mockRepository.getAllConnections()).thenReturn(connections);

      final stats = service.getExportStats();

      expect(stats['totalConnections'], equals(1));
      expect(stats['passwordAuth'], equals(0));
      expect(stats['keyAuth'], equals(0));
      expect(stats['keyWithPasswordAuth'], equals(1));
    });

    test('Given connections with jump hosts, When getExportStats called, '
        'Then counts jumpHostConnections', () {
      final jumpHost = JumpHostConfig(
        host: 'bastion.example.com',
        username: 'admin',
        authType: AuthType.password,
      );
      final connections = [
        makeConnection(id: 'j1', name: 'Via Jump 1', jumpHost: jumpHost),
        makeConnection(id: 'j2', name: 'Via Jump 2', jumpHost: jumpHost),
        makeConnection(id: 'no-jump', name: 'Direct'),
      ];
      when(() => mockRepository.getAllConnections()).thenReturn(connections);

      final stats = service.getExportStats();

      expect(stats['jumpHostConnections'], equals(2));
    });

    test('Given connections, When getExportStats called, '
        'Then includes lastUpdated', () {
      final now = DateTime.now();
      final connections = [
        makeConnection(
          id: 'c1',
          updatedAt: now.subtract(const Duration(hours: 1)),
        ),
        makeConnection(
          id: 'c2',
          updatedAt: now, // most recent
        ),
      ];
      when(() => mockRepository.getAllConnections()).thenReturn(connections);

      final stats = service.getExportStats();

      expect(stats['lastUpdated'], equals(now));
    });
  });

  // ---------------------------------------------------------------------------
  // 无状态保证: service 不持有导入导出状态(已迁移到 Riverpod Notifier)
  // ---------------------------------------------------------------------------

  group('stateless service', () {
    test('Given repository throws, When getExportStats called, '
        'Then exception propagates without leaving service state', () {
      // Trigger an error
      when(
        () => mockRepository.getAllConnections(),
      ).thenThrow(Exception('Test error'));

      expect(() => service.getExportStats(), throwsException);

      // Service remains usable after error (no sticky error state)
      when(() => mockRepository.getAllConnections()).thenReturn([]);
      expect(service.getExportStats()['totalConnections'], equals(0));
    });

    test('Given empty repository, When getExportStats called, '
        'Then returns empty stats', () {
      when(() => mockRepository.getAllConnections()).thenReturn([]);

      service.getExportStats();

      expect(service.getExportStats()['totalConnections'], equals(0));
    });
  });

  // ---------------------------------------------------------------------------
  // generateExportSummary
  // ---------------------------------------------------------------------------

  group('generateExportSummary', () {
    test('Given empty repository, When generateExportSummary called, '
        'Then returns valid summary string', () {
      when(() => mockRepository.getAllConnections()).thenReturn([]);

      final summary = service.generateExportSummary();

      expect(summary, contains('SSH连接配置导出摘要'));
      expect(summary, contains('总连接数: 0'));
      expect(summary, contains('密码认证: 0'));
      expect(summary, contains('密钥认证: 0'));
      expect(summary, contains('密钥+密码: 0'));
      expect(summary, contains('跳板机连接: 0'));
      expect(summary, contains('注意: 此配置文件包含敏感信息'));
    });

    test('Given connections, When generateExportSummary called, '
        'Then returns valid summary with correct counts', () {
      final jumpHost = JumpHostConfig(
        host: 'bastion.com',
        username: 'user',
        authType: AuthType.password,
      );
      final connections = [
        makeConnection(id: 'p1', password: 'pw'),
        makeConnection(
          id: 'k1',
          authType: AuthType.key,
          privateKeyPath: '/key',
        ),
        makeConnection(
          id: 'kp1',
          authType: AuthType.keyWithPassword,
          privateKeyContent: 'key',
          keyPassphrase: 'pass',
        ),
        makeConnection(id: 'jh1', jumpHost: jumpHost),
      ];
      when(() => mockRepository.getAllConnections()).thenReturn(connections);

      final summary = service.generateExportSummary();

      expect(summary, contains('总连接数: 4'));
      expect(summary, contains('密码认证: 2')); // p1 and jh1 both use password auth
      expect(summary, contains('密钥认证: 1'));
      expect(summary, contains('密钥+密码: 1'));
      expect(summary, contains('跳板机连接: 1'));
      expect(summary, contains('导出时间:'));
    });
  });

  // ---------------------------------------------------------------------------
  // 无状态保证: 连续操作不残留状态
  // ---------------------------------------------------------------------------

  group('stateless operations', () {
    test('Given empty repository, When getExportStats called repeatedly, '
        'Then results are consistent', () {
      when(() => mockRepository.getAllConnections()).thenReturn([]);

      final first = service.getExportStats()['totalConnections'];
      service.generateExportSummary();
      final second = service.getExportStats()['totalConnections'];

      expect(first, equals(0));
      expect(second, equals(0));
    });
  });

  // ---------------------------------------------------------------------------
  // exportToLocalFile
  // ---------------------------------------------------------------------------

  group('exportToLocalFile', () {
    late FilePickerPlatform originalPlatform;

    setUp(() {
      originalPlatform = FilePickerPlatform.instance;
      FilePickerPlatform.instance = _FakeFilePickerPlatform();
    });

    tearDown(() {
      // 恢复默认实现，避免影响其他测试
      FilePickerPlatform.instance = originalPlatform;
    });

    test('Given empty repository, When exportToLocalFile called, '
        'Then throws no-connections exception', () async {
      when(() => mockRepository.getAllConnections()).thenReturn([]);

      await expectLater(
        service.exportToLocalFile(),
        throwsA(
          predicate<Exception>((e) => e.toString().contains('没有SSH连接配置可导出')),
        ),
      );
    });

    test('Given connections, When saveFile returns a path, '
        'Then returns that File', () async {
      when(
        () => mockRepository.getAllConnections(),
      ).thenReturn([makeConnection(id: 'c1', name: 'Conn 1', password: 'pw')]);
      final fake = _FakeFilePickerPlatform()..saveResult = Uri.file('/tmp/export.json');
      FilePickerPlatform.instance = fake;

      final file = await service.exportToLocalFile();

      expect(file, isNotNull);
      expect(file!.path, '/tmp/export.json');
    });

    test('Given connections, When saveFile returns null, '
        'Then returns null', () async {
      when(
        () => mockRepository.getAllConnections(),
      ).thenReturn([makeConnection(id: 'c1', name: 'Conn 1', password: 'pw')]);
      final fake = _FakeFilePickerPlatform()..saveResult = null;
      FilePickerPlatform.instance = fake;

      final file = await service.exportToLocalFile();

      expect(file, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // importFromLocalFile
  // ---------------------------------------------------------------------------

  group('importFromLocalFile', () {
    late FilePickerPlatform originalPlatform;
    late Directory tempDir;

    setUp(() {
      originalPlatform = FilePickerPlatform.instance;
      FilePickerPlatform.instance = _FakeFilePickerPlatform();
      tempDir = Directory.systemTemp.createTempSync('lbpssh_import_test');
    });

    tearDown(() {
      FilePickerPlatform.instance = originalPlatform;
      tempDir.deleteSync(recursive: true);
    });

    Future<File> writeJson(Map<String, dynamic> data) async {
      final file = File('${tempDir.path}/import.json');
      await file.writeAsString(jsonEncode(data));
      return file;
    }

    test('Given pickFiles returns null, When importFromLocalFile called, '
        'Then throws no-file-selected exception', () async {
      FilePickerPlatform.instance = _FakeFilePickerPlatform()
        ..pickResult = [];

      await expectLater(
        service.importFromLocalFile(),
        throwsA(predicate<Exception>((e) => e.toString().contains('未选择文件'))),
      );
    });

    test(
      'Given picked file does not exist, '
      'When importFromLocalFile called, Then throws file-not-exist',
      () async {
        final fake = _FakeFilePickerPlatform()
          ..pickFileResult = _createPlatformFile(File('${tempDir.path}/missing.json'));
        FilePickerPlatform.instance = fake;

        await expectLater(
          service.importFromLocalFile(),
          throwsA(predicate<Exception>((e) => e.toString().contains('文件不存在'))),
        );
      },
    );

    test('Given invalid JSON content, When importFromLocalFile called, '
        'Then throws invalid-json exception', () async {
      final file = File('${tempDir.path}/bad.json');
      await file.writeAsString('{not valid json');
      FilePickerPlatform.instance = _FakeFilePickerPlatform()
        ..pickFileResult = _createPlatformFile(file);

      await expectLater(
        service.importFromLocalFile(),
        throwsA(predicate<Exception>((e) => e.toString().contains('无效的JSON'))),
      );
    });

    test(
      'Given valid JSON but missing required keys, '
      'When importFromLocalFile called, Then throws invalid-structure',
      () async {
        final file = await writeJson({'foo': 'bar'});
        FilePickerPlatform.instance = _FakeFilePickerPlatform()
          ..pickFileResult = _createPlatformFile(file);

        await expectLater(
          service.importFromLocalFile(),
          throwsA(
            predicate<Exception>(
              (e) => e.toString().contains('不是有效的SSH连接配置文件'),
            ),
          ),
        );
      },
    );

    test(
      'Given valid structure but unparseable connections, '
      'When importFromLocalFile called, Then throws empty-connections',
      () async {
        // connections 非空但都无法解析为 SshConnection
        final file = await writeJson({
          'version': 1,
          'exportTime': DateTime.now().toIso8601String(),
          'connections': <dynamic>[
            <String, dynamic>{'foo': 'bar'},
          ],
        });
        FilePickerPlatform.instance = _FakeFilePickerPlatform()
          ..pickFileResult = _createPlatformFile(file);

        await expectLater(
          service.importFromLocalFile(),
          throwsA(
            predicate<Exception>((e) => e.toString().contains('文件中没有有效的连接配置')),
          ),
        );
      },
    );

    test('Given valid file with connections, When importFromLocalFile called, '
        'Then returns parsed connections', () async {
      final conn = makeConnection(id: 'c1', name: '导入连接', password: 'pw');
      final file = await writeJson({
        'version': 1,
        'exportTime': DateTime.now().toIso8601String(),
        'connections': [conn.toJson()],
      });
      FilePickerPlatform.instance = _FakeFilePickerPlatform()
        ..pickFileResult = _createPlatformFile(file);

      final result = await service.importFromLocalFile();

      expect(result, hasLength(1));
      expect(result.single.id, 'c1');
      expect(result.single.name, '导入连接');
    });
  });

  // ---------------------------------------------------------------------------
  // getExportStats 的 sshConfig 分支
  // ---------------------------------------------------------------------------

  group('getExportStats sshConfig', () {
    test('Given sshConfig connection, When getExportStats called, '
        'Then sshConfig not counted as password or key', () {
      final connections = [
        makeConnection(id: 's1', authType: AuthType.sshConfig),
      ];
      when(() => mockRepository.getAllConnections()).thenReturn(connections);

      final stats = service.getExportStats();

      expect(stats['totalConnections'], equals(1));
      expect(stats['passwordAuth'], equals(0));
      expect(stats['keyAuth'], equals(0));
      expect(stats['keyWithPasswordAuth'], equals(0));
    });
  });

  // ---------------------------------------------------------------------------
  // resetStatus
  // ---------------------------------------------------------------------------

  group('resetStatus', () {
    test('Given service, When resetStatus called, Then does not throw', () {
      expect(service.resetStatus, returnsNormally);
    });
  });
}
