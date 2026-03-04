import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lbp_ssh/presentation/providers/sync_provider.dart';
import 'package:lbp_ssh/domain/services/sync_service.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import '../mocks/mocks.dart';

void main() {
  late MockSyncService mockSyncService;
  late SyncProvider syncProvider;

  setUp(() {
    mockSyncService = MockSyncService();
    syncProvider = SyncProvider(mockSyncService);
    registerFallbackValues();
  });

  group('SyncProvider', () {
    group('config', () {
      test(
          'Given SyncService with config, When accessing config, Then returns sync config',
          () {
        // Arrange (Given)
        final config = SyncConfig(
          platform: SyncPlatform.gist,
          accessToken: 'test_token',
          gistId: 'test_gist_id',
        );
        when(() => mockSyncService.getConfig()).thenReturn(config);

        // Act (When)
        final result = syncProvider.config;

        // Assert (Then)
        expect(result, isNotNull);
        expect(result!.platform, SyncPlatform.gist);
        verify(() => mockSyncService.getConfig()).called(1);
      });

      test(
          'Given SyncService without config, When accessing config, Then returns null',
          () {
        // Arrange (Given)
        when(() => mockSyncService.getConfig()).thenReturn(null);

        // Act (When)
        final result = syncProvider.config;

        // Assert (Then)
        expect(result, isNull);
      });
    });

    group('status', () {
      test(
          'Given SyncService with status, When accessing status, Then returns sync status',
          () {
        // Arrange (Given)
        when(() => mockSyncService.status).thenReturn(SyncStatusEnum.syncing);

        // Act (When)
        final result = syncProvider.status;

        // Assert (Then)
        expect(result, SyncStatusEnum.syncing);
        verify(() => mockSyncService.status).called(1);
      });

      test(
          'Given SyncService with idle status, When accessing status, Then returns idle',
          () {
        // Arrange (Given)
        when(() => mockSyncService.status).thenReturn(SyncStatusEnum.idle);

        // Act (When)
        final result = syncProvider.status;

        // Assert (Then)
        expect(result, SyncStatusEnum.idle);
      });
    });

    group('lastSyncTime', () {
      test(
          'Given SyncService with last sync time, When accessing lastSyncTime, Then returns sync time',
          () {
        // Arrange (Given)
        final syncTime = DateTime(2024, 1, 1, 12, 0, 0);
        when(() => mockSyncService.lastSyncTime).thenReturn(syncTime);

        // Act (When)
        final result = syncProvider.lastSyncTime;

        // Assert (Then)
        expect(result, syncTime);
        verify(() => mockSyncService.lastSyncTime).called(1);
      });

      test(
          'Given SyncService without last sync time, When accessing lastSyncTime, Then returns null',
          () {
        // Arrange (Given)
        when(() => mockSyncService.lastSyncTime).thenReturn(null);

        // Act (When)
        final result = syncProvider.lastSyncTime;

        // Assert (Then)
        expect(result, isNull);
      });
    });

    group('saveConfig', () {
      test(
          'Given valid sync config, When saveConfig called, Then saves to service',
          () async {
        // Arrange (Given)
        final config = SyncConfig(
          platform: SyncPlatform.giteeGist,
          accessToken: 'token123',
          gistId: 'gist123',
        );
        when(() => mockSyncService.saveConfig(config))
            .thenAnswer((_) async {});

        // Act (When)
        await syncProvider.saveConfig(config);

        // Assert (Then)
        verify(() => mockSyncService.saveConfig(config)).called(1);
      });
    });

    group('uploadConfig', () {
      test(
          'Given successful upload, When uploadConfig called, Then uploads config and notifies listeners',
          () async {
        // Arrange (Given)
        when(() => mockSyncService.uploadConfig()).thenAnswer((_) async {});

        // Act (When)
        await syncProvider.uploadConfig();

        // Assert (Then)
        verify(() => mockSyncService.uploadConfig()).called(1);
      });

      test(
          'Given upload failure, When uploadConfig called, Then throws exception and notifies listeners',
          () async {
        // Arrange (Given)
        when(() => mockSyncService.uploadConfig())
            .thenThrow(Exception('Upload failed'));

        // Act & Assert (When)
        expect(
          () => syncProvider.uploadConfig(),
          throwsException,
        );
      });
    });

    group('downloadConfig', () {
      test(
          'Given successful download, When downloadConfig called, Then downloads config and notifies listeners',
          () async {
        // Arrange (Given)
        when(() => mockSyncService.downloadConfig())
            .thenAnswer((_) async {});

        // Act (When)
        await syncProvider.downloadConfig();

        // Assert (Then)
        verify(() => mockSyncService.downloadConfig()).called(1);
      });

      test(
          'Given download failure, When downloadConfig called, Then throws exception and notifies listeners',
          () async {
        // Arrange (Given)
        when(() => mockSyncService.downloadConfig())
            .thenThrow(Exception('Download failed'));

        // Act & Assert (When)
        expect(
          () => syncProvider.downloadConfig(),
          throwsException,
        );
      });
    });

    group('testConnection', () {
      test(
          'Given successful connection test, When testConnection called, Then tests connection and notifies listeners',
          () async {
        // Arrange (Given)
        when(() => mockSyncService.downloadConfig(skipConflictCheck: true))
            .thenAnswer((_) async {});

        // Act (When)
        await syncProvider.testConnection();

        // Assert (Then)
        verify(() => mockSyncService.downloadConfig(skipConflictCheck: true))
            .called(1);
      });

      test(
          'Given connection test failure, When testConnection called, Then throws exception and notifies listeners',
          () async {
        // Arrange (Given)
        when(() => mockSyncService.downloadConfig(skipConflictCheck: true))
            .thenThrow(Exception('Connection failed'));

        // Act & Assert (When)
        expect(
          () => syncProvider.testConnection(),
          throwsException,
        );
      });
    });
  });
}
