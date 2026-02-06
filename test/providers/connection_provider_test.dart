import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';

void main() {
  group('SshConnection Model Tests', () {
    test('should create connection with required fields', () {
      final connection = SshConnection(
        id: 'conn1',
        name: 'Test Server',
        host: '192.168.1.1',
        port: 22,
        username: 'user',
        authType: AuthType.password,
      );

      expect(connection.id, 'conn1');
      expect(connection.name, 'Test Server');
      expect(connection.host, '192.168.1.1');
      expect(connection.port, 22);
      expect(connection.username, 'user');
      expect(connection.authType, AuthType.password);
      expect(connection.password, isNull);
      expect(connection.jumpHost, isNull);
      expect(connection.version, 1);
    });

    test('should create connection with all fields', () {
      final connection = SshConnection(
        id: 'conn2',
        name: 'Full Server',
        host: '10.0.0.1',
        port: 2222,
        username: 'admin',
        authType: AuthType.keyWithPassword,
        password: null,
        privateKeyPath: '/path/to/key',
        privateKeyContent: 'key_content',
        keyPassphrase: 'passphrase',
        jumpHost: null,
        notes: 'Test notes',
        version: 2,
      );

      expect(connection.id, 'conn2');
      expect(connection.name, 'Full Server');
      expect(connection.port, 2222);
      expect(connection.authType, AuthType.keyWithPassword);
      expect(connection.privateKeyPath, '/path/to/key');
      expect(connection.notes, 'Test notes');
      expect(connection.version, 2);
    });

    test('should serialize to JSON', () {
      final connection = SshConnection(
        id: 'conn3',
        name: 'JSON Server',
        host: '172.16.0.1',
        port: 22,
        username: 'root',
        authType: AuthType.password,
        password: 'secret',
      );

      final json = connection.toJson();

      expect(json['id'], 'conn3');
      expect(json['name'], 'JSON Server');
      expect(json['host'], '172.16.0.1');
      expect(json['port'], 22);
      expect(json['authType'], 'password');
      expect(json['password'], 'secret');
    });

    test('should deserialize from JSON', () {
      final json = {
        'id': 'conn4',
        'name': 'From JSON',
        'host': '192.168.100.1',
        'port': 22,
        'username': 'user',
        'authType': 'key',
      };

      final connection = SshConnection.fromJson(json);

      expect(connection.id, 'conn4');
      expect(connection.name, 'From JSON');
      expect(connection.host, '192.168.100.1');
      expect(connection.authType, AuthType.key);
    });

    test('should create copy with modified fields', () {
      final original = SshConnection(
        id: 'conn5',
        name: 'Original',
        host: '192.168.1.1',
        port: 22,
        username: 'user',
        authType: AuthType.password,
      );

      final modified = original.copyWith(
        name: 'Modified',
        port: 3333,
        authType: AuthType.key,
      );

      expect(modified.id, 'conn5');
      expect(modified.name, 'Modified');
      expect(modified.port, 3333);
      expect(modified.authType, AuthType.key);
      expect(original.name, 'Original');
    });

    test('should have default port of 22', () {
      final connection = SshConnection(
        id: 'conn6',
        name: 'Default Port',
        host: 'test.com',
        port: 22,
        username: 'user',
        authType: AuthType.password,
      );

      expect(connection.port, 22);
    });
  });

  group('JumpHostConfig Model Tests', () {
    test('should create jump host config', () {
      final jumpHost = JumpHostConfig(
        host: 'bastion.example.com',
        port: 22,
        username: 'bastion_user',
        authType: AuthType.password,
        password: 'bastion_pass',
      );

      expect(jumpHost.host, 'bastion.example.com');
      expect(jumpHost.port, 22);
      expect(jumpHost.username, 'bastion_user');
      expect(jumpHost.authType, AuthType.password);
      expect(jumpHost.password, 'bastion_pass');
    });

    test('should serialize jump host to JSON', () {
      final jumpHost = JumpHostConfig(
        host: 'bastion.com',
        port: 2222,
        username: 'admin',
        authType: AuthType.key,
        privateKeyPath: '/path/to/key',
      );

      final json = jumpHost.toJson();

      expect(json['host'], 'bastion.com');
      expect(json['port'], 2222);
      expect(json['username'], 'admin');
      expect(json['authType'], 'key');
      expect(json['privateKeyPath'], '/path/to/key');
    });

    test('should deserialize jump host from JSON', () {
      final json = {
        'host': 'jump.example.com',
        'port': 22,
        'username': 'jump_user',
        'authType': 'password',
        'password': 'pass123',
      };

      final jumpHost = JumpHostConfig.fromJson(json);

      expect(jumpHost.host, 'jump.example.com');
      expect(jumpHost.authType, AuthType.password);
      expect(jumpHost.password, 'pass123');
    });

    test('should create jump host copy', () {
      final original = JumpHostConfig(
        host: 'original.com',
        port: 22,
        username: 'user',
        authType: AuthType.password,
      );

      final modified = original.copyWith(host: 'modified.com', port: 3333);

      expect(modified.host, 'modified.com');
      expect(modified.port, 3333);
      expect(original.host, 'original.com');
    });
  });

  group('AuthType Enum', () {
    test('should have correct values', () {
      expect(AuthType.password.name, 'password');
      expect(AuthType.key.name, 'key');
      expect(AuthType.keyWithPassword.name, 'keyWithPassword');
    });
  });
}
