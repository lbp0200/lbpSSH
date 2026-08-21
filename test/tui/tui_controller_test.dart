import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/data/repositories/connection_repository.dart';
import 'package:lbp_ssh/tui/tui_controller.dart';
import 'package:lbp_ssh/tui/tui_state.dart';

SshConnection _conn({
  String id = 'conn-1',
  String name = 'server-1',
  String host = '10.0.0.1',
  String username = 'root',
  AuthType authType = AuthType.password,
  String? password,
  String? privateKeyPath,
  String? keyPassphrase,
}) {
  return SshConnection(
    id: id,
    name: name,
    host: host,
    username: username,
    authType: authType,
    password: password,
    privateKeyPath: privateKeyPath,
    keyPassphrase: keyPassphrase,
  );
}

void main() {
  late ConnectionRepository repo;
  late File configFile;
  late TuiController controller;

  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp('lbp_ssh_tui_');
    configFile = File('${tempDir.path}/ssh_connections.json');
    await configFile.writeAsString('[]');
    repo = ConnectionRepository(configFile: configFile);
    await repo.init();
    controller = TuiController(repository: repo);
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

  group('TuiController list navigation', () {
    test('Given empty list, When down pressed, Then selection stays at 0', () {
      controller.handleKey('down');
      expect(controller.state.sel, 0);
    });

    test('Given list with connections, When j pressed, Then selection moves '
        'down', () {
      controller.state = TuiState(
        connections: [
          _conn(id: 'c1'),
          _conn(id: 'c2', name: 'server-2', host: '10.0.0.2'),
        ],
      );
      controller.handleKey('j');
      expect(controller.state.sel, 1);
      controller.handleKey('j');
      // 到达末尾后不再移动
      expect(controller.state.sel, 1);
    });

    test(
      'Given selection at bottom, When k pressed, Then selection moves up',
      () {
        controller.state = TuiState(
          connections: [
            _conn(id: 'c1'),
            _conn(id: 'c2', name: 'server-2', host: '10.0.0.2'),
          ],
          sel: 1,
        );
        controller.handleKey('k');
        expect(controller.state.sel, 0);
        controller.handleKey('k');
        // 已在顶部不再移动
        expect(controller.state.sel, 0);
      },
    );

    test('Given list with connections, When enter pressed, Then sets '
        'sshRequest and stops running', () {
      final conn = _conn(id: 'c1');
      controller.state = TuiState(connections: [conn]);
      controller.handleKey('enter');
      expect(controller.sshRequest, same(conn));
      expect(controller.running, isFalse);
    });

    test('Given empty list, When enter pressed, Then no sshRequest set', () {
      controller.handleKey('enter');
      expect(controller.sshRequest, isNull);
      expect(controller.running, isTrue);
    });

    test(
      'Given list, When a pressed, Then switches to form screen for add',
      () {
        controller.state = TuiState(connections: [_conn(id: 'c1')]);
        controller.handleKey('a');
        expect(controller.state.screen, 'form');
        expect(controller.state.editConn, isNull);
      },
    );

    test('Given list with selection, When e pressed, Then switches to form '
        'screen for edit with pre-filled values', () {
      final conn = _conn(
        id: 'c1',
        name: 'my-server',
        host: '192.168.1.10',
        username: 'admin',
        password: 'secret',
      );
      controller.state = TuiState(connections: [conn]);
      controller.handleKey('e');
      expect(controller.state.screen, 'form');
      expect(controller.state.editConn, same(conn));
      expect(controller.state.formValue('name'), 'my-server');
      expect(controller.state.formValue('host'), '192.168.1.10');
      expect(controller.state.formValue('password'), 'secret');
    });

    test('Given list with selection, When d pressed, Then deletes the '
        'selected connection', () async {
      await repo.saveConnection(_conn(id: 'c1'));
      await repo.saveConnection(_conn(id: 'c2', name: 'server-2'));
      controller.state = TuiState(connections: repo.getAllConnections());
      controller.handleKey('d');
      expect(repo.getConnectionById('c1'), isNull);
      expect(repo.getConnectionById('c2'), isNotNull);
      expect(controller.state.sel, 0);
    });
  });

  group('TuiController search', () {
    test('Given list, When / pressed, Then enters search mode', () {
      controller.handleKey('/');
      expect(controller.state.isSearching, isTrue);
      expect(controller.state.searchQuery, '');
    });

    test('Given search mode, When char typed, Then searchQuery appended', () {
      controller.handleKey('/');
      controller.handleKey('p');
      controller.handleKey('r');
      expect(controller.state.searchQuery, 'pr');
      expect(controller.state.sel, 0);
    });

    test(
      'Given search mode, When esc pressed, Then exits search and clears',
      () {
        controller.handleKey('/');
        controller.handleKey('p');
        controller.handleKey('esc');
        expect(controller.state.isSearching, isFalse);
        expect(controller.state.searchQuery, '');
      },
    );

    test(
      'Given search mode, When backspace pressed, Then removes last char',
      () {
        controller.handleKey('/');
        controller.handleKey('p');
        controller.handleKey('r');
        controller.handleKey('backspace');
        expect(controller.state.searchQuery, 'p');
      },
    );

    test('Given search mode, When filtered and enter pressed, Then does not '
        'select connection (enter only handled outside search)', () {
      final prod = _conn(id: 'p1', name: 'production');
      final dev = _conn(id: 'd1', name: 'dev', host: '10.0.0.2');
      controller.state = TuiState(connections: [prod, dev]);
      controller.handleKey('/');
      for (final ch in 'prod'.split('')) {
        controller.handleKey(ch);
      }
      controller.handleKey('enter');
      // 搜索模式下 enter 不处理，仍处于搜索态
      expect(controller.sshRequest, isNull);
      expect(controller.state.isSearching, isTrue);
      expect(controller.state.filteredConnections, [prod]);
    });

    test('Given search mode, When esc then enter pressed, Then selects the '
        'matching connection', () {
      final prod = _conn(id: 'p1', name: 'production');
      final dev = _conn(id: 'd1', name: 'dev', host: '10.0.0.2');
      controller.state = TuiState(connections: [prod, dev]);
      controller.handleKey('/');
      for (final ch in 'prod'.split('')) {
        controller.handleKey(ch);
      }
      controller.handleKey('esc');
      controller.handleKey('enter');
      expect(controller.sshRequest, same(prod));
      expect(controller.running, isFalse);
    });
  });

  group('TuiController form editing', () {
    test('Given form screen, When tab pressed, Then cycles field index', () {
      controller.state = TuiState(screen: 'form');
      controller.handleKey('tab');
      expect(controller.state.formFieldIndex, 1);
      controller.handleKey('tab');
      expect(controller.state.formFieldIndex, 2);
    });

    test(
      'Given form screen, When esc pressed, Then returns to list screen',
      () {
        controller.state = TuiState(
          connections: [_conn(id: 'c1')],
          screen: 'form',
          sel: 1,
        );
        controller.handleKey('esc');
        expect(controller.state.screen, 'list');
        expect(controller.state.sel, 1);
      },
    );

    test('Given form with typed chars, When enter pressed, Then saves '
        'connection and returns to list', () async {
      controller.state = TuiState(screen: 'form');
      controller.handleKey('m');
      controller.handleKey('y');
      controller.handleKey('tab');
      controller.handleKey('h');
      controller.handleKey('o');
      controller.handleKey('s');
      controller.handleKey('t');
      controller.handleKey('tab');
      controller.handleKey('t');
      controller.handleKey('a');
      controller.handleKey('b');
      controller.handleKey('tab');
      controller.handleKey('u');
      controller.handleKey('s');
      controller.handleKey('e');
      controller.handleKey('r');
      controller.handleKey('enter');

      expect(controller.state.screen, 'list');
      final conns = repo.getAllConnections();
      expect(conns, hasLength(1));
      expect(conns.first.name, 'my');
      expect(conns.first.host, 'host');
      expect(conns.first.username, 'user');
    });

    test('Given form with empty required fields, When enter pressed, Then '
        'does not save and stays on form', () {
      controller.state = TuiState(screen: 'form');
      controller.handleKey('enter');
      expect(controller.state.screen, 'form');
      expect(repo.getAllConnections(), isEmpty);
    });

    test(
      'Given form field, When backspace pressed, Then removes last char',
      () {
        controller.state = TuiState(screen: 'form');
        controller.handleKey('a');
        controller.handleKey('b');
        controller.handleKey('backspace');
        expect(controller.state.formValue('name'), 'a');
      },
    );

    test('Given form on authType field, When space pressed, Then cycles '
        'auth type and resets field index', () {
      controller.state = TuiState(
        screen: 'form',
        formFieldIndex: 4, // authType
      );
      controller.handleKey(' ');
      expect(controller.state.formAuthType, AuthType.key);
      // space 切换后 formFieldIndex 重置为 0（回到第一个字段）
      expect(controller.state.formFieldIndex, 0);

      // 重新聚焦 authType 字段继续切换
      controller.state.formFieldIndex = 4;
      controller.handleKey(' ');
      expect(controller.state.formAuthType, AuthType.keyWithPassword);

      controller.state.formFieldIndex = 4;
      controller.handleKey(' ');
      expect(controller.state.formAuthType, AuthType.sshConfig);

      controller.state.formFieldIndex = 4;
      controller.handleKey(' ');
      expect(controller.state.formAuthType, AuthType.password);
    });

    test('Given form on non-authType field, When space pressed, Then appends '
        'space to value', () {
      controller.state = TuiState(screen: 'form');
      controller.handleKey('a');
      controller.handleKey(' ');
      expect(controller.state.formValue('name'), 'a ');
    });

    test('Given authType key, When form field visibility checked, Then '
        'password and privateKeyPath hidden', () {
      controller.state = TuiState(formAuthType: AuthType.key);
      expect(controller.formFieldVisible('password'), isFalse);
      expect(controller.formFieldVisible('privateKeyPath'), isTrue);
      expect(controller.formFieldVisible('keyPassphrase'), isFalse);
      expect(controller.visibleFormFields(), isNot(contains('password')));
    });

    test('Given authType password, When form field visibility checked, Then '
        'password visible and privateKeyPath hidden', () {
      controller.state = TuiState();
      expect(controller.formFieldVisible('password'), isTrue);
      expect(controller.formFieldVisible('privateKeyPath'), isFalse);
    });

    test('Given authType keyWithPassword, When form field visibility checked, '
        'Then all sensitive fields visible', () {
      controller.state = TuiState(formAuthType: AuthType.keyWithPassword);
      expect(controller.formFieldVisible('password'), isTrue);
      expect(controller.formFieldVisible('privateKeyPath'), isTrue);
      expect(controller.formFieldVisible('keyPassphrase'), isTrue);
    });

    test('Given authType sshConfig, When form field visibility checked, Then '
        'sensitive fields hidden', () {
      controller.state = TuiState(formAuthType: AuthType.sshConfig);
      expect(controller.formFieldVisible('password'), isFalse);
      expect(controller.formFieldVisible('privateKeyPath'), isFalse);
      expect(controller.formFieldVisible('keyPassphrase'), isFalse);
    });
  });
}
