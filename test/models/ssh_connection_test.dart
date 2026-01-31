import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';

void main() {
  group('SshConnection', () {
    test('should create connection with default values', () {
      final connection = SshConnection(
        id: 'test-id',
        name: 'Test Connection',
        host: '192.168.1.1',
        username: 'user',
        authType: AuthType.password,
      );

      expect(connection.id, 'test-id');
      expect(connection.name, 'Test Connection');
      expect(connection.host, '192.168.1.1');
      expect(connection.port, 22);
      expect(connection.username, 'user');
      expect(connection.authType, AuthType.password);
      expect(connection.password, null);
      expect(connection.version, 1);
    });

    test('should create connection with custom port', () {
      final connection = SshConnection(
        id: 'test-id',
        name: 'Test Connection',
        host: '192.168.1.1',
        port: 2222,
        username: 'user',
        authType: AuthType.password,
      );

      expect(connection.port, 2222);
    });

    test('should create connection with password auth', () {
      final connection = SshConnection(
        id: 'test-id',
        name: 'Test Connection',
        host: '192.168.1.1',
        username: 'user',
        authType: AuthType.password,
        password: 'secret123',
      );

      expect(connection.authType, AuthType.password);
      expect(connection.password, 'secret123');
    });

    test('should create connection with key auth', () {
      final connection = SshConnection(
        id: 'test-id',
        name: 'Test Connection',
        host: '192.168.1.1',
        username: 'user',
        authType: AuthType.key,
        privateKeyPath: '/path/to/key',
      );

      expect(connection.authType, AuthType.key);
      expect(connection.privateKeyPath, '/path/to/key');
    });

    test('should create connection with key and passphrase', () {
      final connection = SshConnection(
        id: 'test-id',
        name: 'Test Connection',
        host: '192.168.1.1',
        username: 'user',
        authType: AuthType.keyWithPassword,
        privateKeyPath: '/path/to/key',
        keyPassphrase: 'passphrase',
      );

      expect(connection.authType, AuthType.keyWithPassword);
      expect(connection.keyPassphrase, 'passphrase');
    });

    test('should create connection with jump host', () {
      final jumpHost = JumpHostConfig(
        host: 'jump.example.com',
        port: 22,
        username: 'jumpuser',
        authType: AuthType.password,
        password: 'jumppass',
      );

      final connection = SshConnection(
        id: 'test-id',
        name: 'Test Connection',
        host: '192.168.1.1',
        username: 'user',
        authType: AuthType.password,
        jumpHost: jumpHost,
      );

      expect(connection.jumpHost, isNotNull);
      expect(connection.jumpHost!.host, 'jump.example.com');
    });

    test('should serialize to JSON', () {
      final connection = SshConnection(
        id: 'test-id',
        name: 'Test Connection',
        host: '192.168.1.1',
        port: 22,
        username: 'user',
        authType: AuthType.password,
        password: 'secret123',
        notes: 'Test notes',
      );

      final json = connection.toJson();

      expect(json['id'], 'test-id');
      expect(json['name'], 'Test Connection');
      expect(json['host'], '192.168.1.1');
      expect(json['port'], 22);
      expect(json['username'], 'user');
      expect(json['authType'], 'password');
      expect(json['password'], 'secret123');
      expect(json['notes'], 'Test notes');
    });

    test('should deserialize from JSON', () {
      final json = {
        'id': 'test-id',
        'name': 'Test Connection',
        'host': '192.168.1.1',
        'port': 22,
        'username': 'user',
        'authType': 'password',
        'password': 'secret123',
        'version': 1,
        'createdAt': '2024-01-01T00:00:00.000',
        'updatedAt': '2024-01-01T00:00:00.000',
      };

      final connection = SshConnection.fromJson(json);

      expect(connection.id, 'test-id');
      expect(connection.name, 'Test Connection');
      expect(connection.host, '192.168.1.1');
      expect(connection.port, 22);
    });

    test('should create copy with modified fields', () {
      final original = SshConnection(
        id: 'test-id',
        name: 'Original Name',
        host: '192.168.1.1',
        username: 'user',
        authType: AuthType.password,
      );

      final copy = original.copyWith(name: 'New Name', port: 2222);

      expect(copy.id, 'test-id');
      expect(copy.name, 'New Name');
      expect(copy.host, '192.168.1.1');
      expect(copy.port, 2222);
      expect(copy.username, 'user');
    });
  });

  group('JumpHostConfig', () {
    test('should create jump host with default values', () {
      final config = JumpHostConfig(
        host: 'jump.example.com',
        username: 'user',
        authType: AuthType.password,
      );

      expect(config.host, 'jump.example.com');
      expect(config.port, 22);
      expect(config.username, 'user');
      expect(config.authType, AuthType.password);
    });

    test('should serialize jump host to JSON', () {
      final config = JumpHostConfig(
        host: 'jump.example.com',
        port: 2222,
        username: 'user',
        authType: AuthType.key,
        privateKeyPath: '/path/to/key',
      );

      final json = config.toJson();

      expect(json['host'], 'jump.example.com');
      expect(json['port'], 2222);
      expect(json['username'], 'user');
      expect(json['authType'], 'key');
      expect(json['privateKeyPath'], '/path/to/key');
    });

    test('should deserialize jump host from JSON', () {
      final json = {
        'host': 'jump.example.com',
        'port': 2222,
        'username': 'user',
        'authType': 'key',
        'privateKeyPath': '/path/to/key',
      };

      final config = JumpHostConfig.fromJson(json);

      expect(config.host, 'jump.example.com');
      expect(config.port, 2222);
      expect(config.authType, AuthType.key);
    });
  });

  group('AuthType', () {
    test('should have correct values', () {
      expect(AuthType.password.toString(), 'AuthType.password');
      expect(AuthType.key.toString(), 'AuthType.key');
      expect(AuthType.keyWithPassword.toString(), 'AuthType.keyWithPassword');
    });
  });
}
