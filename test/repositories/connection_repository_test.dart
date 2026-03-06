import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';

void main() {
  group('SshConnection Model', () {
    test('Given all fields, When serializing, Then deserializes correctly', () {
      final connection = SshConnection(
        id: 'test-id',
        name: 'Test Server',
        host: '192.168.1.1',
        port: 22,
        username: 'admin',
        authType: AuthType.password,
        password: 'secretpassword',
        notes: 'Test notes',
      );

      final json = connection.toJson();
      final restored = SshConnection.fromJson(json);

      expect(restored.id, connection.id);
      expect(restored.name, connection.name);
      expect(restored.host, connection.host);
      expect(restored.port, connection.port);
      expect(restored.username, connection.username);
      expect(restored.authType, connection.authType);
      expect(restored.password, connection.password);
      expect(restored.notes, connection.notes);
    });

    test('Given key authentication, When serializing, Then preserves key fields', () {
      final connection = SshConnection(
        id: 'key-auth',
        name: 'Key Server',
        host: '192.168.1.1',
        port: 22,
        username: 'admin',
        authType: AuthType.key,
        privateKeyContent: '-----BEGIN OPENSSH PRIVATE KEY-----\ntest\n-----END OPENSSH PRIVATE KEY-----',
        keyPassphrase: 'passphrase',
      );

      final json = connection.toJson();
      final restored = SshConnection.fromJson(json);

      expect(restored.authType, AuthType.key);
      expect(restored.privateKeyContent, contains('BEGIN OPENSSH PRIVATE KEY'));
      expect(restored.keyPassphrase, 'passphrase');
    });

    test('Given SSH Config auth, When serializing, Then preserves config host', () {
      final connection = SshConnection(
        id: 'ssh-config',
        name: 'SSH Config Server',
        host: '192.168.1.1',
        port: 22,
        username: 'admin',
        authType: AuthType.sshConfig,
        sshConfigHost: 'my-server',
      );

      final json = connection.toJson();
      final restored = SshConnection.fromJson(json);

      expect(restored.authType, AuthType.sshConfig);
      expect(restored.sshConfigHost, 'my-server');
    });

    test('copyWith creates new instance with updated fields', () {
      final original = SshConnection(
        id: 'original',
        name: 'Original Name',
        host: '192.168.1.1',
        port: 22,
        username: 'admin',
        authType: AuthType.password,
      );

      final copied = original.copyWith(name: 'New Name', host: '192.168.2.2');

      expect(copied.id, original.id);
      expect(copied.name, 'New Name');
      expect(copied.host, '192.168.2.2');
      expect(copied.port, original.port);
      expect(copied.username, original.username);
    });

    test('copyWith preserves null optional fields', () {
      final original = SshConnection(
        id: 'test',
        name: 'Test',
        host: '1.1.1.1',
        username: 'u',
        authType: AuthType.password,
      );

      final copied = original.copyWith(name: 'Updated');

      expect(copied.password, isNull);
      expect(copied.privateKeyPath, isNull);
      expect(copied.notes, isNull);
    });

    test('copyWith increments version when not specified', () {
      final original = SshConnection(
        id: 'test',
        name: 'Test',
        host: '1.1.1.1',
        username: 'u',
        authType: AuthType.password,
        version: 1,
      );

      final copied = original.copyWith(name: 'Updated');

      expect(copied.version, original.version);
    });

    test('defaults port to 22 when not specified', () {
      final connection = SshConnection(
        id: 'test',
        name: 'Test',
        host: '1.1.1.1',
        username: 'u',
        authType: AuthType.password,
      );

      expect(connection.port, 22);
    });

    test('defaults version to 1 when not specified', () {
      final connection = SshConnection(
        id: 'test',
        name: 'Test',
        host: '1.1.1.1',
        username: 'u',
        authType: AuthType.password,
      );

      expect(connection.version, 1);
    });
  });

  group('JumpHostConfig Model', () {
    test('serialization preserves all fields', () {
      final config = JumpHostConfig(
        host: 'jump.example.com',
        port: 2222,
        username: 'jumpuser',
        authType: AuthType.keyWithPassword,
        privateKeyPath: '/path/to/key',
        password: 'keypassword',
      );

      final json = config.toJson();
      final restored = JumpHostConfig.fromJson(json);

      expect(restored.host, config.host);
      expect(restored.port, config.port);
      expect(restored.username, config.username);
      expect(restored.authType, config.authType);
      expect(restored.privateKeyPath, config.privateKeyPath);
      expect(restored.password, config.password);
    });

    test('defaults port to 22', () {
      final config = JumpHostConfig(
        host: 'jump.example.com',
        username: 'user',
        authType: AuthType.password,
      );

      expect(config.port, 22);
    });
  });

  group('Socks5ProxyConfig Model', () {
    test('serialization preserves all fields', () {
      final config = Socks5ProxyConfig(
        host: 'proxy.example.com',
        port: 1080,
        username: 'proxyuser',
        password: 'proxypass',
      );

      final json = config.toJson();
      final restored = Socks5ProxyConfig.fromJson(json);

      expect(restored.host, config.host);
      expect(restored.port, config.port);
      expect(restored.username, config.username);
      expect(restored.password, config.password);
    });

    test('username and password are optional', () {
      final config = Socks5ProxyConfig(
        host: 'proxy.example.com',
        port: 1080,
      );

      final json = config.toJson();
      final restored = Socks5ProxyConfig.fromJson(json);

      expect(restored.username, isNull);
      expect(restored.password, isNull);
    });
  });
}
