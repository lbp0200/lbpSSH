import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';

void main() {
  group('SshService - Jump Host', () {
    test('should create connection with jump host configuration', () {
      // 创建跳板机配置
      final jumpHost = JumpHostConfig(
        host: 'jump.example.com',
        port: 22,
        username: 'jumpuser',
        authType: AuthType.password,
        password: 'jump_password',
      );

      // 创建包含跳板机的SSH连接
      final connection = SshConnection(
        id: 'test-id',
        name: 'Test Jump Host Connection',
        host: 'target.example.com',
        port: 22,
        username: 'targetuser',
        authType: AuthType.password,
        password: 'target_password',
        jumpHost: jumpHost,
      );

      // 验证跳板机配置
      expect(connection.jumpHost, isNotNull);
      expect(connection.jumpHost!.host, equals('jump.example.com'));
      expect(connection.jumpHost!.username, equals('jumpuser'));
      expect(connection.jumpHost!.authType, equals(AuthType.password));
      expect(connection.jumpHost!.password, equals('jump_password'));
    });

    test('should create connection with key auth jump host', () {
      // 创建使用密钥认证的跳板机配置
      final jumpHost = JumpHostConfig(
        host: 'jump.example.com',
        port: 22,
        username: 'jumpuser',
        authType: AuthType.key,
        privateKeyPath: '/home/user/.ssh/jump_key',
      );

      final connection = SshConnection(
        id: 'test-id',
        name: 'Test Jump Host Key Auth',
        host: 'target.example.com',
        port: 22,
        username: 'targetuser',
        authType: AuthType.key,
        privateKeyContent:
            '-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----',
        jumpHost: jumpHost,
      );

      // 验证跳板机密钥认证配置
      expect(connection.jumpHost!.authType, equals(AuthType.key));
      expect(
        connection.jumpHost!.privateKeyPath,
        equals('/home/user/.ssh/jump_key'),
      );
    });

    test('should validate jump host configuration', () {
      // 测试跳板机配置验证
      expect(() {
        JumpHostConfig(
          host: 'jump.example.com',
          port: 22,
          username: 'jumpuser',
          authType: AuthType.password,
          // password 为 null，应该在业务逻辑中处理
        );
      }, returnsNormally);
    });
  });
}
