import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/domain/services/import_export_service.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';

void main() {
  group('ImportExportStatus Tests', () {
    test('should have correct values', () {
      expect(ImportExportStatus.idle.name, 'idle');
      expect(ImportExportStatus.exporting.name, 'exporting');
      expect(ImportExportStatus.importing.name, 'importing');
      expect(ImportExportStatus.success.name, 'success');
      expect(ImportExportStatus.error.name, 'error');
    });
  });

  group('SshConnection Serialization Tests', () {
    test('should serialize connection to JSON', () {
      final connection = SshConnection(
        id: 'conn1',
        name: 'Test Server',
        host: '192.168.1.1',
        port: 22,
        username: 'admin',
        authType: AuthType.password,
        password: 'secret',
      );

      final json = connection.toJson();

      expect(json['id'], 'conn1');
      expect(json['name'], 'Test Server');
      expect(json['host'], '192.168.1.1');
      expect(json['port'], 22);
      expect(json['authType'], 'password');
      expect(json['password'], 'secret');
    });

    test('should deserialize connection from JSON', () {
      final json = {
        'id': 'conn2',
        'name': 'SSH Server',
        'host': '10.0.0.1',
        'port': 2222,
        'username': 'root',
        'authType': 'key',
      };

      final connection = SshConnection.fromJson(json);

      expect(connection.id, 'conn2');
      expect(connection.name, 'SSH Server');
      expect(connection.host, '10.0.0.1');
      expect(connection.port, 2222);
      expect(connection.authType, AuthType.key);
    });

    test('should round-trip serialize correctly', () {
      final original = SshConnection(
        id: 'conn3',
        name: 'Round Trip',
        host: '172.16.0.1',
        port: 22,
        username: 'user',
        authType: AuthType.keyWithPassword,
        privateKeyPath: '/path/to/key',
        keyPassphrase: 'pass',
      );

      final json = original.toJson();
      final deserialized = SshConnection.fromJson(json);

      expect(deserialized.id, original.id);
      expect(deserialized.name, original.name);
      expect(deserialized.host, original.host);
      expect(deserialized.authType, original.authType);
      expect(deserialized.privateKeyPath, original.privateKeyPath);
    });

    test('should handle jumpHost in connection', () {
      final jumpHost = JumpHostConfig(
        host: 'bastion.com',
        port: 22,
        username: 'bastion_user',
        authType: AuthType.password,
        password: 'pass',
      );

      final connection = SshConnection(
        id: 'conn4',
        name: 'Behind Bastion',
        host: 'internal.com',
        port: 22,
        username: 'internal_user',
        authType: AuthType.password,
        jumpHost: jumpHost,
      );

      expect(connection.jumpHost, isNotNull);
      expect(connection.jumpHost!.host, 'bastion.com');
    });

    test('should create copy with modified fields', () {
      final original = SshConnection(
        id: 'conn5',
        name: 'Original',
        host: '1.1.1.1',
        port: 22,
        username: 'user',
        authType: AuthType.password,
      );

      final modified = original.copyWith(name: 'Updated', port: 3333);

      expect(modified.id, 'conn5');
      expect(modified.name, 'Updated');
      expect(modified.port, 3333);
      expect(original.name, 'Original');
    });
  });

  group('JumpHostConfig Tests', () {
    test('should create jump host config', () {
      final config = JumpHostConfig(
        host: 'jump.example.com',
        port: 22,
        username: 'admin',
        authType: AuthType.key,
        privateKeyPath: '/keys/jump',
      );

      expect(config.host, 'jump.example.com');
      expect(config.authType, AuthType.key);
      expect(config.privateKeyPath, '/keys/jump');
    });

    test('should serialize to JSON', () {
      final config = JumpHostConfig(
        host: 'bastion.com',
        port: 2222,
        username: 'user',
        authType: AuthType.password,
        password: 'secret',
      );

      final json = config.toJson();

      expect(json['host'], 'bastion.com');
      expect(json['port'], 2222);
      expect(json['authType'], 'password');
      expect(json['password'], 'secret');
    });

    test('should deserialize from JSON', () {
      final json = {
        'host': 'jump.example.com',
        'port': 22,
        'username': 'admin',
        'authType': 'key',
        'privateKeyPath': '/path/to/key',
      };

      final config = JumpHostConfig.fromJson(json);

      expect(config.host, 'jump.example.com');
      expect(config.authType, AuthType.key);
      expect(config.privateKeyPath, '/path/to/key');
    });
  });

  group('AuthType Tests', () {
    test('should have correct values', () {
      expect(AuthType.password.name, 'password');
      expect(AuthType.key.name, 'key');
      expect(AuthType.keyWithPassword.name, 'keyWithPassword');
    });
  });
}
