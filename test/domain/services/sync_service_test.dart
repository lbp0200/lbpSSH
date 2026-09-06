import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lbp_ssh/core/constants/app_constants.dart';
import 'package:lbp_ssh/domain/services/sync_service.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/data/repositories/connection_repository.dart';

class MockConnectionRepository extends Mock implements ConnectionRepository {}

class MockDio extends Mock implements Dio {}

// Register fallback values for mocktail
void registerFallbackValues() {
  registerFallbackValue(SyncConfig(accessToken: 'test_token'));
  registerFallbackValue(
    SshConnection(
      id: 'test_id',
      name: 'Test Server',
      host: '192.168.1.1',
      username: 'testuser',
      authType: AuthType.password,
    ),
  );
  registerFallbackValue(Options());
  registerFallbackValue(RequestOptions());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerFallbackValues();

  // =======================================================================
  // SyncConfig tests
  // =======================================================================
  group('SyncConfig', () {
    test(
      'Given required fields, When creating SyncConfig, Then uses default values for optional fields',
      () {
        final config = SyncConfig(accessToken: 'test_token');

        expect(config.accessToken, 'test_token');
        expect(config.gistId, isNull);
        expect(config.gistFilename, 'ssh_connections.json');
        expect(config.autoSync, false);
        expect(config.syncIntervalMinutes, 5);
      },
    );

    test(
      'Given SyncConfig with all fields, When serializing to JSON, Then produces correct JSON',
      () {
        final config = SyncConfig(
          accessToken: 'token123',
          gistId: 'abc123',
          gistFilename: 'my_config.json',
          autoSync: true,
          syncIntervalMinutes: 60,
        );

        final json = config.toJson();

        expect(json['accessToken'], 'token123');
        expect(json['gistId'], 'abc123');
        expect(json['gistFilename'], 'my_config.json');
        expect(json['autoSync'], true);
        expect(json['syncIntervalMinutes'], 60);
      },
    );

    test(
      'Given valid JSON with all fields, When deserializing, Then creates SyncConfig correctly',
      () {
        final json = {
          'accessToken': 'token456',
          'gistId': 'def456',
          'gistFilename': 'config.json',
          'autoSync': true,
          'syncIntervalMinutes': 45,
        };

        final config = SyncConfig.fromJson(json);

        expect(config.accessToken, 'token456');
        expect(config.gistId, 'def456');
        expect(config.gistFilename, 'config.json');
        expect(config.autoSync, true);
        expect(config.syncIntervalMinutes, 45);
      },
    );

    test(
      'Given JSON with missing optional fields, When deserializing, Then uses default values',
      () {
        final json = <String, dynamic>{};

        final config = SyncConfig.fromJson(json);

        expect(config.accessToken, isNull);
        expect(config.gistId, isNull);
        expect(config.gistFilename, 'ssh_connections.json');
        expect(config.autoSync, false);
        expect(config.syncIntervalMinutes, 5);
      },
    );
  });

  // =======================================================================
  // SyncConflict tests
  // =======================================================================
  group('SyncConflict', () {
    test(
      'Given local and remote connections, When creating SyncConflict, Then stores both connections',
      () {
        final localConnection = SshConnection(
          id: 'conn1',
          name: 'Local Server',
          host: '192.168.1.1',
          username: 'user',
          authType: AuthType.password,
        );
        final remoteConnection = SshConnection(
          id: 'conn1',
          name: 'Remote Server',
          host: '192.168.1.1',
          username: 'user',
          authType: AuthType.password,
        );

        final conflict = SyncConflict(
          connectionId: 'conn1',
          localConnection: localConnection,
          remoteConnection: remoteConnection,
        );

        expect(conflict.connectionId, 'conn1');
        expect(conflict.localConnection.name, 'Local Server');
        expect(conflict.remoteConnection.name, 'Remote Server');
      },
    );
  });

  // =======================================================================
  // SyncConflictException tests
  // =======================================================================
  group('SyncConflictException', () {
    test(
      'Given list of conflicts, When creating SyncConflictException, Then stores conflicts',
      () {
        final conflicts = [
          SyncConflict(
            connectionId: 'conn1',
            localConnection: SshConnection(
              id: 'conn1',
              name: 'Server 1',
              host: '192.168.1.1',
              username: 'user',
              authType: AuthType.password,
            ),
            remoteConnection: SshConnection(
              id: 'conn1',
              name: 'Server 1 Updated',
              host: '192.168.1.1',
              username: 'user',
              authType: AuthType.password,
            ),
          ),
        ];

        final exception = SyncConflictException(conflicts);

        expect(exception.conflicts.length, 1);
        expect(exception.toString(), contains('1'));
      },
    );
  });

  // =======================================================================
  // SyncStatusEnum tests
  // =======================================================================
  group('SyncStatusEnum', () {
    test(
      'Given SyncStatusEnum enum, When accessing name, Then returns correct values',
      () {
        expect(SyncStatusEnum.idle.name, 'idle');
        expect(SyncStatusEnum.syncing.name, 'syncing');
        expect(SyncStatusEnum.success.name, 'success');
        expect(SyncStatusEnum.error.name, 'error');
      },
    );
  });

  // =======================================================================
  // SyncService - config persistence
  // =======================================================================
  group('SyncService - config persistence', () {
    late MockConnectionRepository mockRepository;
    late MockDio mockDio;

    setUp(() {
      mockRepository = MockConnectionRepository();
      mockDio = MockDio();
      SharedPreferences.setMockInitialValues({});
    });

    test('initial status is idle', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(service.status, SyncStatusEnum.idle);
    });

    test('saveConfig stores config and getConfig returns it', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final config = SyncConfig(
        accessToken: 'token123',
        gistId: 'gist123',
        gistFilename: 'my_config.json',
        autoSync: true,
        syncIntervalMinutes: 30,
      );

      await service.saveConfig(config);

      expect(service.getConfig(), isNotNull);
      expect(service.getConfig()!.accessToken, 'token123');
      expect(service.getConfig()!.gistId, 'gist123');
      expect(service.getConfig()!.gistFilename, 'my_config.json');
      expect(service.getConfig()!.autoSync, true);
      expect(service.getConfig()!.syncIntervalMinutes, 30);
    });

    test('saveConfig overwrites previous config', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await service.saveConfig(
        SyncConfig(accessToken: 'tokenA', gistId: 'gistA'),
      );

      await service.saveConfig(
        SyncConfig(accessToken: 'tokenB', gistId: 'gistB', autoSync: true),
      );

      expect(service.getConfig()!.accessToken, 'tokenB');
      expect(service.getConfig()!.gistId, 'gistB');
      expect(service.getConfig()!.autoSync, true);
    });

    test('lastSyncTime is null before any sync', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(service.lastSyncTime, isNull);
    });

    test('loads existing config from prefs', () async {
      SharedPreferences.setMockInitialValues({
        AppConstants.syncSettingsKey: jsonEncode({
          'accessToken': 'token_persisted',
          'gistId': 'gist_persisted',
          'gistFilename': 'custom.json',
          'autoSync': true,
          'syncIntervalMinutes': 60,
        }),
      });
      final service = SyncService(mockRepository, dio: mockDio);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(service.getConfig(), isNotNull);
      expect(service.getConfig()!.accessToken, 'token_persisted');
      expect(service.getConfig()!.gistId, 'gist_persisted');
      expect(service.getConfig()!.gistFilename, 'custom.json');
      expect(service.getConfig()!.autoSync, true);
      expect(service.getConfig()!.syncIntervalMinutes, 60);
    });
  });

  // =======================================================================
  // SyncService - uploadConfig
  // =======================================================================
  group('SyncService - uploadConfig', () {
    late MockConnectionRepository mockRepository;
    late MockDio mockDio;

    setUp(() {
      mockRepository = MockConnectionRepository();
      mockDio = MockDio();
      SharedPreferences.setMockInitialValues({});
    });

    test('uploadConfig throws when no config set', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(
        () => service.uploadConfig(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('同步配置未设置或未授权'),
          ),
        ),
      );
    });

    test('uploadConfig throws when config has no accessToken', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await service.saveConfig(SyncConfig());

      expect(
        () => service.uploadConfig(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('同步配置未设置或未授权'),
          ),
        ),
      );
    });

    test('uploadConfig creates new Gist when no gistId set', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await service.saveConfig(SyncConfig(accessToken: 'token123'));

      when(() => mockRepository.getAllConnections()).thenReturn([]);

      // POST /gists (create)
      when(
        () => mockDio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          data: {'id': 'new_gist_id'},
          statusCode: 201,
          requestOptions: RequestOptions(),
        ),
      );

      await service.uploadConfig();

      expect(service.status, SyncStatusEnum.success);
      // gistId should be auto-saved
      expect(service.getConfig()!.gistId, 'new_gist_id');
    });

    test('uploadConfig updates existing Gist when gistId is set', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await service.saveConfig(
        SyncConfig(accessToken: 'token123', gistId: 'existing_gist_id'),
      );

      when(() => mockRepository.getAllConnections()).thenReturn([]);

      // PATCH /gists/{gist_id} (update)
      when(
        () => mockDio.patch<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          data: {'id': 'existing_gist_id'},
          statusCode: 200,
          requestOptions: RequestOptions(),
        ),
      );

      await service.uploadConfig();

      expect(service.status, SyncStatusEnum.success);
      // gistId unchanged
      expect(service.getConfig()!.gistId, 'existing_gist_id');
    });

    test('uploadConfig sends correct PATCH URL and body', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await service.saveConfig(
        SyncConfig(
          accessToken: 'token123',
          gistId: 'gist_abc',
          gistFilename: 'config.json',
        ),
      );

      when(() => mockRepository.getAllConnections()).thenReturn([]);

      when(
        () => mockDio.patch<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          data: {'id': 'gist_abc'},
          statusCode: 200,
          requestOptions: RequestOptions(),
        ),
      );

      await service.uploadConfig();

      verify(
        () => mockDio.patch<Map<String, dynamic>>(
          'https://api.github.com/gists/gist_abc',
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).called(1);
    });

    test('uploadConfig sends correct POST URL for new Gist', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await service.saveConfig(SyncConfig(accessToken: 'token123'));

      when(() => mockRepository.getAllConnections()).thenReturn([]);

      when(
        () => mockDio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          data: {'id': 'new_gist'},
          statusCode: 201,
          requestOptions: RequestOptions(),
        ),
      );

      await service.uploadConfig();

      verify(
        () => mockDio.post<Map<String, dynamic>>(
          'https://api.github.com/gists',
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).called(1);
    });

    test('status changes during uploadConfig', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await service.saveConfig(
        SyncConfig(accessToken: 'token123', gistId: 'existing_gist'),
      );

      when(() => mockRepository.getAllConnections()).thenReturn([]);

      when(
        () => mockDio.patch<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          data: {'id': 'existing_gist'},
          statusCode: 200,
          requestOptions: RequestOptions(),
        ),
      );

      final future = service.uploadConfig();

      // Status should transition to syncing
      expect(service.status, SyncStatusEnum.syncing);

      await future;
      expect(service.status, SyncStatusEnum.success);
    });

    test('lastSyncTime updates after successful upload', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await service.saveConfig(
        SyncConfig(accessToken: 'token123', gistId: 'existing_gist'),
      );

      when(() => mockRepository.getAllConnections()).thenReturn([]);

      when(
        () => mockDio.patch<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          data: {'id': 'existing_gist'},
          statusCode: 200,
          requestOptions: RequestOptions(),
        ),
      );

      final before = DateTime.now();
      await service.uploadConfig();
      final after = DateTime.now();

      expect(service.lastSyncTime, isNotNull);
      expect(
        service.lastSyncTime!.isAfter(
          before.subtract(const Duration(seconds: 1)),
        ),
        isTrue,
      );
      expect(
        service.lastSyncTime!.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
    });

    test('uploadConfig sets status to error on Dio failure', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await service.saveConfig(
        SyncConfig(accessToken: 'token123', gistId: 'existing_gist'),
      );

      when(() => mockRepository.getAllConnections()).thenReturn([]);

      when(
        () => mockDio.patch<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      await expectLater(service.uploadConfig(), throwsA(isA<DioException>()));
      expect(service.status, SyncStatusEnum.error);
    });

    test(
      'uploadConfig throws when create Gist returns empty response',
      () async {
        SharedPreferences.setMockInitialValues({});
        final service = SyncService(mockRepository, dio: mockDio);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        await service.saveConfig(SyncConfig(accessToken: 'token123'));

        when(() => mockRepository.getAllConnections()).thenReturn([]);

        // POST /gists 返回空 data
        when(
          () => mockDio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response<Map<String, dynamic>>(
            statusCode: 500,
            requestOptions: RequestOptions(),
          ),
        );

        await expectLater(
          service.uploadConfig(),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('创建 Gist 失败：空响应'),
            ),
          ),
        );
        expect(service.status, SyncStatusEnum.error);
      },
    );

    test('uploadConfig throws when create Gist returns no id', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await service.saveConfig(SyncConfig(accessToken: 'token123'));

      when(() => mockRepository.getAllConnections()).thenReturn([]);

      when(
        () => mockDio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          data: <String, dynamic>{},
          statusCode: 200,
          requestOptions: RequestOptions(),
        ),
      );

      await expectLater(
        service.uploadConfig(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('创建 Gist 失败：未返回 ID'),
          ),
        ),
      );
      expect(service.status, SyncStatusEnum.error);
    });
  });

  // =======================================================================
  // SyncService - downloadConfig
  // =======================================================================
  group('SyncService - downloadConfig', () {
    late MockConnectionRepository mockRepository;
    late MockDio mockDio;

    setUp(() {
      mockRepository = MockConnectionRepository();
      mockDio = MockDio();
      SharedPreferences.setMockInitialValues({});
    });

    test('downloadConfig throws when no config set', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(
        () => service.downloadConfig(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('同步配置未设置或未授权'),
          ),
        ),
      );
    });

    test('downloadConfig throws when config has no gistId', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await service.saveConfig(SyncConfig(accessToken: 'token123'));

      expect(
        () => service.downloadConfig(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('未设置 Gist ID'),
          ),
        ),
      );
    });

    test(
      'downloadConfig sets status to success and saves connections',
      () async {
        SharedPreferences.setMockInitialValues({});
        final service = SyncService(mockRepository, dio: mockDio);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        await service.saveConfig(
          SyncConfig(accessToken: 'token123', gistId: 'gist_abc'),
        );

        // Gist API response
        when(
          () => mockDio.get<Map<String, dynamic>>(
            any(),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            data: {
              'id': 'gist_abc',
              'files': {
                'ssh_connections.json': {
                  'content': jsonEncode({
                    'version': 1,
                    'timestamp': DateTime.now().toIso8601String(),
                    'connections': <Map<String, dynamic>>[],
                  }),
                },
              },
            },
            statusCode: 200,
            requestOptions: RequestOptions(),
          ),
        );

        when(() => mockRepository.getAllConnections()).thenReturn([]);
        when(
          () => mockRepository.saveConnections(any()),
        ).thenAnswer((_) async {});

        await service.downloadConfig();

        expect(service.status, SyncStatusEnum.success);
        verify(() => mockRepository.saveConnections(any())).called(1);
      },
    );

    test(
      'downloadConfig with skipConflictCheck skips conflict detection',
      () async {
        SharedPreferences.setMockInitialValues({});
        final service = SyncService(mockRepository, dio: mockDio);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        await service.saveConfig(
          SyncConfig(accessToken: 'token123', gistId: 'gist_abc'),
        );

        // 构造真实冲突：本地更新（version=2, updatedAt=t3），远端更旧（version=1, updatedAt=t2）。
        final t0 = DateTime(2024, 2, 5);
        final t2 = DateTime(2024, 3, 5);
        final t3 = DateTime(2024, 4, 5);

        when(
          () => mockDio.get<Map<String, dynamic>>(
            any(),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            data: {
              'id': 'gist_abc',
              'files': {
                'ssh_connections.json': {
                  'content': jsonEncode({
                    'version': 1,
                    'timestamp': DateTime.now().toIso8601String(),
                    'connections': <Map<String, dynamic>>[
                      {
                        'id': 'local_1',
                        'name': 'Remote',
                        'host': '5.6.7.8',
                        'username': 'remote_user',
                        'authType': 'password',
                        'version': 1,
                        'createdAt': t0.toIso8601String(),
                        'updatedAt': t2.toIso8601String(),
                      },
                    ],
                  }),
                },
              },
            },
            statusCode: 200,
            requestOptions: RequestOptions(),
          ),
        );

        // 本地存在同 id、更新版本的连接 → 若不跳过会触发 SyncConflictException。
        when(() => mockRepository.getAllConnections()).thenReturn([
          SshConnection(
            id: 'local_1',
            name: 'Local',
            host: '1.2.3.4',
            username: 'local_user',
            authType: AuthType.password,
            version: 2,
            createdAt: t0,
            updatedAt: t3,
          ),
        ]);
        when(
          () => mockRepository.saveConnections(any()),
        ).thenAnswer((_) async {});

        // skip=true：跳过冲突检测 → 不抛错、不落盘。
        await service.downloadConfig(skipConflictCheck: true);

        expect(service.status, SyncStatusEnum.success);
        verifyNever(() => mockRepository.saveConnections(any()));
      },
    );

    test('downloadConfig sets status to error on Dio failure', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await service.saveConfig(
        SyncConfig(accessToken: 'token123', gistId: 'gist_abc'),
      );

      when(
        () => mockDio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      await expectLater(service.downloadConfig(), throwsA(isA<DioException>()));
      expect(service.status, SyncStatusEnum.error);
    });

    test('downloadConfig throws when file not found in gist', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await service.saveConfig(
        SyncConfig(
          accessToken: 'token123',
          gistId: 'gist_abc',
          gistFilename: 'nonexistent.json',
        ),
      );

      when(
        () => mockDio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          data: {
            'id': 'gist_abc',
            'files': {
              'other.json': {'content': '{}'},
            },
          },
          statusCode: 200,
          requestOptions: RequestOptions(),
        ),
      );

      await expectLater(
        service.downloadConfig(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('未找到文件'),
          ),
        ),
      );
      expect(service.status, SyncStatusEnum.error);
    });

    test('downloadConfig sends correct Gist API URL', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await service.saveConfig(
        SyncConfig(accessToken: 'token123', gistId: 'gist_xyz'),
      );

      when(
        () => mockDio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          data: {
            'id': 'gist_xyz',
            'files': {
              'ssh_connections.json': {
                'content': jsonEncode({
                  'version': 1,
                  'timestamp': DateTime.now().toIso8601String(),
                  'connections': <Map<String, dynamic>>[],
                }),
              },
            },
          },
          statusCode: 200,
          requestOptions: RequestOptions(),
        ),
      );

      when(() => mockRepository.getAllConnections()).thenReturn([]);
      when(
        () => mockRepository.saveConnections(any()),
      ).thenAnswer((_) async {});

      await service.downloadConfig();

      verify(
        () => mockDio.get<Map<String, dynamic>>(
          'https://api.github.com/gists/gist_xyz',
          options: any(named: 'options'),
        ),
      ).called(1);
    });

    test(
      'downloadConfig(skipConflictCheck: true) does not save connections (test connection must not modify local data)',
      () async {
        SharedPreferences.setMockInitialValues({});
        final service = SyncService(mockRepository, dio: mockDio);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        await service.saveConfig(
          SyncConfig(accessToken: 'token123', gistId: 'gist_xyz'),
        );

        when(
          () => mockDio.get<Map<String, dynamic>>(
            any(),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            data: {
              'id': 'gist_xyz',
              'files': {
                'ssh_connections.json': {
                  'content': jsonEncode({
                    'version': 1,
                    'timestamp': DateTime.now().toIso8601String(),
                    'connections': <Map<String, dynamic>>[],
                  }),
                },
              },
            },
            statusCode: 200,
            requestOptions: RequestOptions(),
          ),
        );

        when(() => mockRepository.getAllConnections()).thenReturn([]);
        when(
          () => mockRepository.saveConnections(any()),
        ).thenAnswer((_) async {});

        await service.downloadConfig(skipConflictCheck: true);

        // 修复前：testConnection 复用 downloadConfig，会把远端连接 saveConnections 覆盖本地。
        verifyNever(() => mockRepository.saveConnections(any()));
      },
    );

    test(
      'downloadConfig throws when Gist does not exist (null data)',
      () async {
        SharedPreferences.setMockInitialValues({});
        final service = SyncService(mockRepository, dio: mockDio);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        await service.saveConfig(
          SyncConfig(accessToken: 'token123', gistId: 'gist_abc'),
        );

        when(
          () => mockDio.get<Map<String, dynamic>>(
            any(),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response<Map<String, dynamic>>(
            statusCode: 404,
            requestOptions: RequestOptions(),
          ),
        );

        await expectLater(
          service.downloadConfig(),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Gist 不存在'),
            ),
          ),
        );
        expect(service.status, SyncStatusEnum.error);
      },
    );

    test('downloadConfig throws when Gist files list is empty', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await service.saveConfig(
        SyncConfig(accessToken: 'token123', gistId: 'gist_abc'),
      );

      when(
        () => mockDio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          data: {'id': 'gist_abc'},
          statusCode: 200,
          requestOptions: RequestOptions(),
        ),
      );

      await expectLater(
        service.downloadConfig(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Gist 文件列表为空'),
          ),
        ),
      );
      expect(service.status, SyncStatusEnum.error);
    });

    test('downloadConfig throws when file content is empty', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await service.saveConfig(
        SyncConfig(accessToken: 'token123', gistId: 'gist_abc'),
      );

      when(
        () => mockDio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          data: {
            'id': 'gist_abc',
            'files': {
              'ssh_connections.json': {'content': ''},
            },
          },
          statusCode: 200,
          requestOptions: RequestOptions(),
        ),
      );

      await expectLater(
        service.downloadConfig(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('文件内容为空'),
          ),
        ),
      );
      expect(service.status, SyncStatusEnum.error);
    });

    test(
      'downloadConfig throws SyncConflictException on version conflict',
      () async {
        SharedPreferences.setMockInitialValues({});
        final service = SyncService(mockRepository, dio: mockDio);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        await service.saveConfig(
          SyncConfig(accessToken: 'token123', gistId: 'gist_abc'),
        );

        // 本地连接：version 1，最近更新
        final now = DateTime.now();
        final local = SshConnection(
          id: 'conn1',
          name: 'Server Alpha',
          host: '192.168.1.10',
          username: 'admin',
          authType: AuthType.password,
          createdAt: now.subtract(const Duration(minutes: 10)),
          updatedAt: now.subtract(const Duration(minutes: 1)),
        );
        when(() => mockRepository.getAllConnections()).thenReturn([local]);

        // 远端连接：同 id、version 2、更新早于本地但晚于本地创建时间
        final remoteJson = local.toJson()
          ..['version'] = 2
          ..['updatedAt'] = now
              .subtract(const Duration(minutes: 5))
              .toIso8601String();

        when(
          () => mockDio.get<Map<String, dynamic>>(
            any(),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response<Map<String, dynamic>>(
            data: {
              'id': 'gist_abc',
              'files': {
                'ssh_connections.json': {
                  'content': jsonEncode({
                    'version': 1,
                    'timestamp': now.toIso8601String(),
                    'connections': [remoteJson],
                  }),
                },
              },
            },
            statusCode: 200,
            requestOptions: RequestOptions(),
          ),
        );

        await expectLater(
          service.downloadConfig(),
          throwsA(isA<SyncConflictException>()),
        );
        expect(service.status, SyncStatusEnum.error);
      },
    );

    test(
      'downloadConfig does not flag conflict when local is older than remote (remote wins, no exception)',
      () async {
        SharedPreferences.setMockInitialValues({});
        final service = SyncService(mockRepository, dio: mockDio);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        await service.saveConfig(
          SyncConfig(accessToken: 'token123', gistId: 'gist_abc'),
        );

        // 本地连接更旧：version 1、updatedAt 早于远端。冲突判定三条件之一
        // （local.updatedAt.isAfter(remote.updatedAt)）为假 → 不构成冲突，
        // 远端胜出并落盘（全量替换）。若谓词过度激进会误抛 SyncConflictException。
        final local = SshConnection(
          id: 'conn1',
          name: 'Local Stale',
          host: '1.2.3.4',
          username: 'local_user',
          authType: AuthType.password,
          createdAt: DateTime(2024, 2, 3),
          updatedAt: DateTime(2024, 2, 5),
        );
        when(() => mockRepository.getAllConnections()).thenReturn([local]);

        // 远端同 id、version 更新、updatedAt 更新 → 应胜出。
        final remoteJson = local.toJson()
          ..['version'] = 2
          ..['updatedAt'] = DateTime(2024, 3, 5).toIso8601String();

        when(
          () => mockDio.get<Map<String, dynamic>>(
            any(),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response<Map<String, dynamic>>(
            data: {
              'id': 'gist_abc',
              'files': {
                'ssh_connections.json': {
                  'content': jsonEncode({
                    'version': 1,
                    'timestamp': DateTime.now().toIso8601String(),
                    'connections': [remoteJson],
                  }),
                },
              },
            },
            statusCode: 200,
            requestOptions: RequestOptions(),
          ),
        );

        when(
          () => mockRepository.saveConnections(any()),
        ).thenAnswer((_) async {});

        // 本地更旧 → 不抛冲突，远端胜出并落盘。
        await service.downloadConfig();

        expect(service.status, SyncStatusEnum.success);
        verify(() => mockRepository.saveConnections(any())).called(1);
      },
    );
  });
}
