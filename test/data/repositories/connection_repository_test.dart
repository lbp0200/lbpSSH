import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/core/constants/app_constants.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/data/repositories/connection_repository.dart';

/// Creates a connection with required fields for testing.
SshConnection createTestConnection({
  String? id,
  String? name,
  String? host,
  int? port,
  String? username,
  AuthType? authType,
}) {
  return SshConnection(
    id: id ?? 'test-id',
    name: name ?? 'Test Server',
    host: host ?? '192.168.1.1',
    port: port ?? 22,
    username: username ?? 'user',
    authType: authType ?? AuthType.password,
  );
}

void main() {
  group('ConnectionRepository', () {
    late ConnectionRepository repo;
    late File configFile;

    setUp(() async {
      // Create a fresh temp file per test.
      final tempDir = await Directory.systemTemp.createTemp(
        'lbp_ssh_repo_test_',
      );
      configFile = File('${tempDir.path}/ssh_connections.json');
      await configFile.writeAsString('[]');

      repo = ConnectionRepository(configFile: configFile);
      await repo.init();
    });

    tearDown(() async {
      await repo.close();
      final dir = configFile.parent;
      try {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      } catch (_) {}
    });

    test('getAllConnections returns cached connections', () async {
      final connection = createTestConnection(id: 'conn-1', name: 'Server 1');
      await repo.saveConnection(connection);

      final result = repo.getAllConnections();

      expect(result.length, 1);
      expect(result.first.id, 'conn-1');
      expect(result.first.name, 'Server 1');
    });

    test('getConnectionById returns correct connection', () async {
      final connection = createTestConnection(id: 'conn-2', name: 'Server 2');
      await repo.saveConnection(connection);

      final result = repo.getConnectionById('conn-2');

      expect(result, isNotNull);
      expect(result!.id, 'conn-2');
      expect(result.name, 'Server 2');
    });

    test('getConnectionById returns null for unknown ID', () {
      final result = repo.getConnectionById('non-existent-id');
      expect(result, isNull);
    });

    test('deleteConnection removes from cache', () async {
      final connection = createTestConnection(id: 'conn-3', name: 'Server 3');
      await repo.saveConnection(connection);
      expect(repo.getConnectionById('conn-3'), isNotNull);

      await repo.deleteConnection('conn-3');

      expect(repo.getConnectionById('conn-3'), isNull);
    });

    test('saveConnections replaces all connections', () async {
      final list = [
        createTestConnection(id: 'conn-a', name: 'A'),
        createTestConnection(id: 'conn-b', name: 'B'),
      ];

      await repo.saveConnections(list);

      final result = repo.getAllConnections();
      expect(result.length, 2);
      expect(result.map((c) => c.id).toSet(), {'conn-a', 'conn-b'});
    });

    test('clearAll empties repository', () async {
      await repo.saveConnection(createTestConnection(id: 'x', name: 'X'));
      await repo.saveConnection(createTestConnection(id: 'y', name: 'Y'));
      expect(repo.getAllConnections().length, 2);

      await repo.clearAll();

      expect(repo.getAllConnections(), isEmpty);
    });

    test('close succeeds without throwing', () async {
      await repo.close();
    });

    test('saveConnection increments version and updates updatedAt', () async {
      final connection = createTestConnection(id: 'v1', name: 'Version Test');

      await repo.saveConnection(connection);
      final afterFirstSave = repo.getConnectionById('v1')!;
      expect(afterFirstSave.version, connection.version + 1);

      await repo.saveConnection(afterFirstSave);
      final afterSecondSave = repo.getConnectionById('v1')!;
      expect(afterSecondSave.version, connection.version + 2);
      expect(
        afterSecondSave.updatedAt.compareTo(afterFirstSave.updatedAt) >= 0,
        isTrue,
      );
    });

    test('saveConnection writes atomically and leaves no temp file behind', () async {
      final connection = createTestConnection(id: 'atom-1', name: 'Atomic');
      await repo.saveConnection(connection);

      // 主文件内容为合法 JSON（连接已持久化）
      expect(configFile.readAsStringSync(), contains('atom-1'));

      // 原子写入不应残留 .part 临时文件
      final tempFile = File('${configFile.path}.part');
      expect(tempFile.existsSync(), isFalse);
    });

    test('init with existing file loads connections from file', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'lbp_ssh_repo_test_',
      );
      addTearDown(() => tempDir.delete(recursive: true));
      final jsonFile = File('${tempDir.path}/existing.json');

      // Populate file with a connection first using a repo
      final setupRepo = ConnectionRepository(configFile: jsonFile);
      await setupRepo.init();
      await setupRepo.saveConnection(
        createTestConnection(id: 'loaded-1', name: 'Loaded'),
      );
      await setupRepo.close();

      // Create new repo with same file — should load from file
      final newRepo = ConnectionRepository(configFile: jsonFile);
      await newRepo.init();
      addTearDown(() => newRepo.close());

      final result = newRepo.getAllConnections();
      expect(result.length, 1);
      expect(result.first.id, 'loaded-1');
    });

    test('init with corrupted file resets to empty', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'lbp_ssh_repo_test_',
      );
      addTearDown(() => tempDir.delete(recursive: true));
      final jsonFile = File('${tempDir.path}/bad.json');
      await jsonFile.writeAsString('not valid json at all');

      final repo2 = ConnectionRepository(configFile: jsonFile);
      await repo2.init();
      addTearDown(() => repo2.close());

      final result = repo2.getAllConnections();
      expect(result, isEmpty);
    });

    test('saveConnection encrypts sensitive fields in file', () async {
      final connection = SshConnection(
        id: 'sec-1',
        name: 'Secure',
        host: '10.0.0.1',
        username: 'user',
        authType: AuthType.password,
        password: 'secret-pw',
      );

      await repo.saveConnection(connection);

      // 文件内容不应包含明文密码
      final raw = await configFile.readAsString();
      expect(raw.contains('secret-pw'), isFalse);
    });

    test('saved connection with password round-trips after reload', () async {
      final connection = SshConnection(
        id: 'sec-2',
        name: 'Secure 2',
        host: '10.0.0.2',
        username: 'user',
        authType: AuthType.keyWithPassword,
        privateKeyContent: 'BEGIN RSA PRIVATE KEY content',
        keyPassphrase: 'passphrase-123',
      );

      await repo.saveConnection(connection);

      // 重新加载仓库，验证敏感字段解密还原
      final newRepo = ConnectionRepository(configFile: configFile);
      await newRepo.init();
      addTearDown(() => newRepo.close());

      final loaded = newRepo.getConnectionById('sec-2')!;
      expect(loaded.password, isNull);
      expect(loaded.privateKeyContent, 'BEGIN RSA PRIVATE KEY content');
      expect(loaded.keyPassphrase, 'passphrase-123');
    });

    test('saved connection with jump host password round-trips', () async {
      final connection = SshConnection(
        id: 'jh-1',
        name: 'Jump',
        host: '10.0.0.3',
        username: 'user',
        authType: AuthType.password,
        password: 'main-pw',
        jumpHost: JumpHostConfig(
          host: 'bastion.example.com',
          username: 'jump-user',
          authType: AuthType.password,
          password: 'jump-pw',
        ),
      );

      await repo.saveConnection(connection);

      final raw = await configFile.readAsString();
      expect(raw.contains('jump-pw'), isFalse);

      final newRepo = ConnectionRepository(configFile: configFile);
      await newRepo.init();
      addTearDown(() => newRepo.close());

      final loaded = newRepo.getConnectionById('jh-1')!;
      expect(loaded.jumpHost?.password, 'jump-pw');
      expect(loaded.password, 'main-pw');
    });

    test('saved connection with socks5 proxy password round-trips', () async {
      final connection = SshConnection(
        id: 's5-1',
        name: 'Proxy',
        host: '10.0.0.4',
        username: 'user',
        authType: AuthType.password,
        password: 'main-pw',
        socks5Proxy: Socks5ProxyConfig(
          host: 'proxy.example.com',
          username: 'proxy-user',
          password: 'proxy-pw',
        ),
      );

      await repo.saveConnection(connection);

      final raw = await configFile.readAsString();
      expect(raw.contains('proxy-pw'), isFalse);

      final newRepo = ConnectionRepository(configFile: configFile);
      await newRepo.init();
      addTearDown(() => newRepo.close());

      final loaded = newRepo.getConnectionById('s5-1')!;
      expect(loaded.socks5Proxy?.password, 'proxy-pw');
      expect(loaded.password, 'main-pw');
    });

    test('saved connection with all sensitive fields (top-level + nested) '
        'never stores plaintext at rest and round-trips', () async {
      final connection = SshConnection(
        id: 'all-1',
        name: 'All Secrets',
        host: '10.0.0.6',
        username: 'user',
        authType: AuthType.keyWithPassword,
        password: 'main-pw',
        privateKeyContent: 'SECRET-KEY-CONTENT',
        keyPassphrase: 'SECRET-PASSPHRASE',
        jumpHost: JumpHostConfig(
          host: 'bastion.example.com',
          username: 'jump-user',
          authType: AuthType.password,
          password: 'jump-pw',
        ),
        socks5Proxy: Socks5ProxyConfig(
          host: 'proxy.example.com',
          username: 'proxy-user',
          password: 'proxy-pw',
        ),
      );

      await repo.saveConnection(connection);

      final raw = await configFile.readAsString();
      for (final secret in const [
        'main-pw',
        'SECRET-KEY-CONTENT',
        'SECRET-PASSPHRASE',
        'jump-pw',
        'proxy-pw',
      ]) {
        expect(
          raw.contains(secret),
          isFalse,
          reason: 'plaintext "$secret" must not be stored on disk',
        );
      }

      final newRepo = ConnectionRepository(configFile: configFile);
      await newRepo.init();
      addTearDown(() => newRepo.close());

      final loaded = newRepo.getConnectionById('all-1')!;
      expect(loaded.password, 'main-pw');
      expect(loaded.privateKeyContent, 'SECRET-KEY-CONTENT');
      expect(loaded.keyPassphrase, 'SECRET-PASSPHRASE');
      expect(loaded.jumpHost?.password, 'jump-pw');
      expect(loaded.socks5Proxy?.password, 'proxy-pw');
    });

    test(
      'saveConnection updates jump host and socks5 without password',
      () async {
        final connection = SshConnection(
          id: 'none-1',
          name: 'No Secrets',
          host: '10.0.0.5',
          username: 'user',
          authType: AuthType.password,
          jumpHost: JumpHostConfig(
            host: 'bastion.example.com',
            username: 'jump-user',
            authType: AuthType.password,
          ),
          socks5Proxy: Socks5ProxyConfig(host: 'proxy.example.com'),
        );

        await repo.saveConnection(connection);

        final newRepo = ConnectionRepository(configFile: configFile);
        await newRepo.init();
        addTearDown(() => newRepo.close());

        final loaded = newRepo.getConnectionById('none-1')!;
        expect(loaded.jumpHost?.host, 'bastion.example.com');
        expect(loaded.socks5Proxy?.host, 'proxy.example.com');
      },
    );
  });

  group('ConnectionRepository without configFile', () {
    late Directory supportDir;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            null,
          );
      try {
        if (await supportDir.exists()) {
          await supportDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    Future<ConnectionRepository> makeRepo() async {
      supportDir = await Directory.systemTemp.createTemp('lbp_ssh_support_');
      // mock path_provider: getApplicationSupportDirectory → supportDir
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async {
              if (call.method == 'getApplicationSupportDirectory') {
                return supportDir.path;
              }
              return null;
            },
          );
      final repo = ConnectionRepository();
      await repo.init();
      return repo;
    }

    test('init creates config dir and empty config file', () async {
      final repo = await makeRepo();

      final configDir = Directory(
        '${supportDir.path}/${AppConstants.configDirName}',
      );
      expect(await configDir.exists(), isTrue);
      final configFile = File('${configDir.path}/ssh_connections.json');
      expect(await configFile.exists(), isTrue);
      expect(await configFile.readAsString(), '[]');

      await repo.close();
    });

    test('init with existing file loads connections', () async {
      supportDir = await Directory.systemTemp.createTemp('lbp_ssh_support_');
      final configDir = Directory(
        '${supportDir.path}/${AppConstants.configDirName}',
      );
      await configDir.create(recursive: true);
      await File('${configDir.path}/ssh_connections.json').writeAsString(
        '[{"id":"pre-1","name":"Pre Loaded","host":"10.0.0.9",'
        '"username":"u","authType":"password","port":22}]',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async {
              if (call.method == 'getApplicationSupportDirectory') {
                return supportDir.path;
              }
              return null;
            },
          );

      final repo = ConnectionRepository();
      await repo.init();

      expect(repo.getConnectionById('pre-1'), isNotNull);
      expect(repo.getConnectionById('pre-1')!.name, 'Pre Loaded');

      await repo.close();
    });
  });
}
