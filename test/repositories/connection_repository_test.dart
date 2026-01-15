import 'package:flutter_test/flutter_test.dart';
import 'package:lbpSSH/data/models/ssh_connection.dart';

void main() {
  group('SshConnection Model Serialization', () {
    test('should serialize and deserialize connection with all fields', () {
      final connection = SshConnection(
        id: 'test-id-123',
        name: 'Production Server',
        host: '192.168.1.100',
        port: 22,
        username: 'admin',
        authType: AuthType.password,
        password: 'secretpassword',
        notes: 'Main production server',
      );

      final json = connection.toJson();
      final deserialized = SshConnection.fromJson(json);

      expect(deserialized.id, connection.id);
      expect(deserialized.name, connection.name);
      expect(deserialized.host, connection.host);
      expect(deserialized.port, connection.port);
      expect(deserialized.username, connection.username);
      expect(deserialized.authType, connection.authType);
      expect(deserialized.password, connection.password);
      expect(deserialized.notes, connection.notes);
    });

    test('should serialize and deserialize connection with key auth', () {
      final connection = SshConnection(
        id: 'key-id-456',
        name: 'Key Auth Server',
        host: '10.0.0.1',
        username: 'deploy',
        authType: AuthType.key,
        privateKeyPath: '/home/user/.ssh/id_rsa',
        keyPassphrase: 'keypass',
      );

      final json = connection.toJson();
      final deserialized = SshConnection.fromJson(json);

      expect(deserialized.authType, AuthType.key);
      expect(deserialized.privateKeyPath, '/home/user/.ssh/id_rsa');
      expect(deserialized.keyPassphrase, 'keypass');
    });

    test('should serialize and deserialize connection with jump host', () {
      final jumpHost = JumpHostConfig(
        host: 'jump.example.com',
        port: 2222,
        username: 'jumpuser',
        authType: AuthType.password,
        password: 'jumpsecret',
      );

      final connection = SshConnection(
        id: 'jump-id-789',
        name: 'Internal Server via Jump',
        host: 'internal.server.local',
        username: 'internaluser',
        authType: AuthType.password,
        jumpHost: jumpHost,
      );

      final json = connection.toJson();
      expect(json['jumpHost'], isA<Map<String, dynamic>>());

      final deserialized = SshConnection.fromJson(json);

      expect(deserialized.jumpHost, isNotNull);
      expect(deserialized.jumpHost!.host, 'jump.example.com');
      expect(deserialized.jumpHost!.port, 2222);
    });

    test('should preserve version number during serialization', () {
      final connection = SshConnection(
        id: 'version-test',
        name: 'Version Test',
        host: 'test.local',
        username: 'test',
        authType: AuthType.password,
        version: 42,
      );

      final json = connection.toJson();
      expect(json['version'], 42);

      final deserialized = SshConnection.fromJson(json);
      expect(deserialized.version, 42);
    });

    test('should preserve dates during serialization', () {
      final createdAt = DateTime(2024, 1, 1, 12, 0, 0);
      final updatedAt = DateTime(2024, 6, 15, 18, 30, 0);

      final connection = SshConnection(
        id: 'date-test',
        name: 'Date Test',
        host: 'test.local',
        username: 'test',
        authType: AuthType.password,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      final json = connection.toJson();
      final deserialized = SshConnection.fromJson(json);

      expect(
        deserialized.createdAt.toIso8601String(),
        createdAt.toIso8601String(),
      );
      expect(
        deserialized.updatedAt.toIso8601String(),
        updatedAt.toIso8601String(),
      );
    });

    test('should handle null optional fields', () {
      final connection = SshConnection(
        id: 'null-test',
        name: 'Null Test',
        host: 'test.local',
        username: 'test',
        authType: AuthType.password,
      );

      final json = connection.toJson();
      final deserialized = SshConnection.fromJson(json);

      expect(deserialized.password, null);
      expect(deserialized.privateKeyPath, null);
      expect(deserialized.keyPassphrase, null);
      expect(deserialized.jumpHost, null);
      expect(deserialized.notes, null);
    });
  });

  group('Connection Validation Logic', () {
    test('should validate required fields are present', () {
      final connection = SshConnection(
        id: 'valid-test',
        name: 'Valid Connection',
        host: '192.168.1.1',
        username: 'user',
        authType: AuthType.password,
      );

      expect(connection.id.isNotEmpty, true);
      expect(connection.name.isNotEmpty, true);
      expect(connection.host.isNotEmpty, true);
      expect(connection.username.isNotEmpty, true);
    });

    test('should have valid default port', () {
      final connection = SshConnection(
        id: 'port-test',
        name: 'Port Test',
        host: 'test.local',
        username: 'test',
        authType: AuthType.password,
      );

      expect(connection.port, 22);
    });

    test('should have default version of 1', () {
      final connection = SshConnection(
        id: 'version-test',
        name: 'Version Test',
        host: 'test.local',
        username: 'test',
        authType: AuthType.password,
      );

      expect(connection.version, 1);
    });
  });

  group('CopyWith Functionality', () {
    test('should update only specified fields', () {
      final original = SshConnection(
        id: 'original-id',
        name: 'Original Name',
        host: 'original.host.com',
        port: 22,
        username: 'originaluser',
        authType: AuthType.password,
        version: 1,
      );

      final updated = original.copyWith(name: 'New Name', host: 'new.host.com');

      expect(updated.id, 'original-id');
      expect(updated.name, 'New Name');
      expect(updated.host, 'new.host.com');
      expect(updated.port, 22);
      expect(updated.username, 'originaluser');
      expect(updated.version, 1);
    });

    test('should increment version when specified', () {
      final original = SshConnection(
        id: 'version-inc-test',
        name: 'Version Inc Test',
        host: 'test.local',
        username: 'test',
        authType: AuthType.password,
        version: 5,
      );

      final updated = original.copyWith(version: 10);

      expect(updated.version, 10);
    });

    test('should preserve all fields when nothing specified', () {
      final original = SshConnection(
        id: 'preserve-test',
        name: 'Preserve Test',
        host: 'test.local',
        username: 'testuser',
        authType: AuthType.key,
        privateKeyPath: '/path/to/key',
        keyPassphrase: 'pass',
        version: 3,
      );

      final preserved = original.copyWith();

      expect(preserved.id, original.id);
      expect(preserved.name, original.name);
      expect(preserved.host, original.host);
      expect(preserved.authType, original.authType);
      expect(preserved.privateKeyPath, original.privateKeyPath);
      expect(preserved.version, original.version);
    });
  });

  group('JumpHostConfig Serialization', () {
    test('should serialize and deserialize with all fields', () {
      final config = JumpHostConfig(
        host: 'jump.example.com',
        port: 2222,
        username: 'jumpuser',
        authType: AuthType.keyWithPassword,
        password: 'secret',
        privateKeyPath: '/path/to/key',
      );

      final json = config.toJson();
      final deserialized = JumpHostConfig.fromJson(json);

      expect(deserialized.host, 'jump.example.com');
      expect(deserialized.port, 2222);
      expect(deserialized.username, 'jumpuser');
      expect(deserialized.authType, AuthType.keyWithPassword);
      expect(deserialized.password, 'secret');
      expect(deserialized.privateKeyPath, '/path/to/key');
    });

    test('should handle null optional fields', () {
      final config = JumpHostConfig(
        host: 'jump.example.com',
        username: 'jumpuser',
        authType: AuthType.password,
      );

      final json = config.toJson();
      final deserialized = JumpHostConfig.fromJson(json);

      expect(deserialized.password, null);
      expect(deserialized.privateKeyPath, null);
    });

    test('should have default port of 22', () {
      final config = JumpHostConfig(
        host: 'jump.example.com',
        username: 'jumpuser',
        authType: AuthType.password,
      );

      expect(config.port, 22);
    });
  });
}
