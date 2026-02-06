import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/domain/services/sync_service.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';

void main() {
  group('SyncConfig Tests', () {
    test('should create with gist platform', () {
      final config = SyncConfig(
        platform: SyncPlatform.gist,
        accessToken: 'github_token',
      );

      expect(config.platform, SyncPlatform.gist);
      expect(config.accessToken, 'github_token');
      expect(config.autoSync, false);
    });

    test('should create with giteeGist platform', () {
      final config = SyncConfig(
        platform: SyncPlatform.giteeGist,
        accessToken: 'gitee_token',
        gistId: 'gitee_gist_id',
        autoSync: true,
        syncIntervalMinutes: 60,
      );

      expect(config.platform, SyncPlatform.giteeGist);
      expect(config.gistId, 'gitee_gist_id');
      expect(config.autoSync, true);
      expect(config.syncIntervalMinutes, 60);
    });

    test('should serialize to JSON', () {
      final config = SyncConfig(
        platform: SyncPlatform.gist,
        accessToken: 'token',
        gistId: 'gist123',
        gistFileName: 'config.json',
        autoSync: true,
        syncIntervalMinutes: 30,
      );

      final json = config.toJson();

      expect(json['platform'], 'gist');
      expect(json['accessToken'], 'token');
      expect(json['gistId'], 'gist123');
      expect(json['gistFileName'], 'config.json');
      expect(json['autoSync'], true);
      expect(json['syncIntervalMinutes'], 30);
    });

    test('should deserialize from JSON', () {
      final json = {
        'platform': 'giteeGist',
        'accessToken': 'my_token',
        'gistId': 'my_gist',
        'gistFileName': 'ssh.json',
        'autoSync': false,
        'syncIntervalMinutes': 45,
      };

      final config = SyncConfig.fromJson(json);

      expect(config.platform, SyncPlatform.giteeGist);
      expect(config.accessToken, 'my_token');
      expect(config.gistId, 'my_gist');
      expect(config.gistFileName, 'ssh.json');
      expect(config.autoSync, false);
      expect(config.syncIntervalMinutes, 45);
    });

    test('should handle missing optional fields', () {
      final json = {
        'platform': 'gist',
      };

      final config = SyncConfig.fromJson(json);

      expect(config.platform, SyncPlatform.gist);
      expect(config.accessToken, isNull);
      expect(config.autoSync, false);
      expect(config.syncIntervalMinutes, 5);
    });
  });

  group('SyncStatusEnum Tests', () {
    test('should have correct values', () {
      expect(SyncStatusEnum.idle.name, 'idle');
      expect(SyncStatusEnum.syncing.name, 'syncing');
      expect(SyncStatusEnum.success.name, 'success');
      expect(SyncStatusEnum.error.name, 'error');
    });
  });

  group('SyncPlatform Tests', () {
    test('should have correct values', () {
      expect(SyncPlatform.gist.name, 'gist');
      expect(SyncPlatform.giteeGist.name, 'giteeGist');
    });
  });

  group('SyncConflict Tests', () {
    test('should create sync conflict', () {
      final localConnection = SshConnection(
        id: 'conn1',
        name: 'Local',
        host: '192.168.1.1',
        port: 22,
        username: 'user',
        authType: AuthType.password,
      );
      final remoteConnection = SshConnection(
        id: 'conn1',
        name: 'Remote',
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
      expect(conflict.localConnection.name, 'Local');
      expect(conflict.remoteConnection.name, 'Remote');
    });
  });

  group('SyncConflictException Tests', () {
    test('should create exception with conflicts', () {
      final conflicts = [
        SyncConflict(
          connectionId: 'conn1',
          localConnection: SshConnection(
            id: 'conn1',
            name: 'Local',
            host: '1.1.1.1',
            port: 22,
            username: 'u',
            authType: AuthType.password,
          ),
          remoteConnection: SshConnection(
            id: 'conn1',
            name: 'Remote',
            host: '1.1.1.1',
            port: 22,
            username: 'u',
            authType: AuthType.password,
          ),
        ),
      ];

      final exception = SyncConflictException(conflicts);

      expect(exception.conflicts.length, 1);
      expect(exception.toString(), contains('1'));
    });
  });
}
