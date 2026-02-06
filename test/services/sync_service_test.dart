import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/domain/services/sync_service.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';

void main() {
  group('SyncConfig', () {
    test('should create with default values', () {
      final config = SyncConfig(
        platform: SyncPlatform.gist,
        accessToken: 'test_token',
        gistId: 'test_gist_id',
      );

      expect(config.platform, SyncPlatform.gist);
      expect(config.accessToken, 'test_token');
      expect(config.gistId, 'test_gist_id');
      expect(config.autoSync, false);
      expect(config.syncIntervalMinutes, 5);
    });

    test('should serialize to JSON', () {
      final config = SyncConfig(
        platform: SyncPlatform.giteeGist,
        accessToken: 'token123',
        gistId: 'gist123',
        gistFileName: 'config.json',
        autoSync: true,
        syncIntervalMinutes: 60,
      );

      final json = config.toJson();

      expect(json['platform'], 'giteeGist');
      expect(json['accessToken'], 'token123');
      expect(json['gistId'], 'gist123');
      expect(json['gistFileName'], 'config.json');
      expect(json['autoSync'], true);
      expect(json['syncIntervalMinutes'], 60);
    });

    test('should deserialize from JSON', () {
      final json = {
        'platform': 'gist',
        'accessToken': 'token456',
        'gistId': 'gist456',
        'gistFileName': 'ssh_config.json',
        'autoSync': true,
        'syncIntervalMinutes': 45,
      };

      final config = SyncConfig.fromJson(json);

      expect(config.platform, SyncPlatform.gist);
      expect(config.accessToken, 'token456');
      expect(config.gistId, 'gist456');
      expect(config.gistFileName, 'ssh_config.json');
      expect(config.autoSync, true);
      expect(config.syncIntervalMinutes, 45);
    });

    test('should handle missing optional fields in JSON', () {
      final json = {
        'platform': 'giteeGist',
      };

      final config = SyncConfig.fromJson(json);

      expect(config.platform, SyncPlatform.giteeGist);
      expect(config.accessToken, isNull);
      expect(config.gistId, isNull);
      expect(config.autoSync, false);
      expect(config.syncIntervalMinutes, 5);
    });
  });

  group('SyncConflict', () {
    test('should create sync conflict', () {
      final localConnection = SshConnection(
        id: 'conn1',
        name: 'Local Server',
        host: '192.168.1.1',
        port: 22,
        username: 'user',
        authType: AuthType.password,
      );
      final remoteConnection = SshConnection(
        id: 'conn1',
        name: 'Remote Server',
        host: '192.168.1.1',
        port: 22,
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
    });
  });

  group('SyncConflictException', () {
    test('should create exception with conflicts', () {
      final conflicts = [
        SyncConflict(
          connectionId: 'conn1',
          localConnection: SshConnection(
            id: 'conn1',
            name: 'Server 1',
            host: '192.168.1.1',
            port: 22,
            username: 'user',
            authType: AuthType.password,
          ),
          remoteConnection: SshConnection(
            id: 'conn1',
            name: 'Server 1 Updated',
            host: '192.168.1.1',
            port: 22,
            username: 'user',
            authType: AuthType.password,
          ),
        ),
      ];

      final exception = SyncConflictException(conflicts);

      expect(exception.conflicts.length, 1);
      expect(exception.toString(), contains('1'));
    });
  });

  group('SyncPlatform', () {
    test('should have correct values', () {
      expect(SyncPlatform.gist.name, 'gist');
      expect(SyncPlatform.giteeGist.name, 'giteeGist');
    });
  });

  group('SyncStatusEnum', () {
    test('should have correct values', () {
      expect(SyncStatusEnum.idle.name, 'idle');
      expect(SyncStatusEnum.syncing.name, 'syncing');
      expect(SyncStatusEnum.success.name, 'success');
      expect(SyncStatusEnum.error.name, 'error');
    });
  });
}
