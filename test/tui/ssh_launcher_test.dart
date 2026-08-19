import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/tui/ssh_launcher.dart';

SshConnection _conn({
  String username = 'root',
  String host = '10.0.0.1',
  int port = 22,
}) {
  return SshConnection(
    id: 'test-id',
    name: 'test',
    host: host,
    username: username,
    authType: AuthType.password,
    port: port,
  );
}

void main() {
  group('launchSsh', () {
    test('Given exitCode 0, Then returns succeeded with no error', () async {
      final result = await launchSsh(
        _conn(),
        run: (executable, arguments) async =>
            ProcessResult(0, 0, 'connected', ''),
      );

      expect(result.succeeded, isTrue);
      expect(result.errorMessage, isNull);
    });

    test('Given non-zero exitCode with stderr, '
        'Then returns failed with stderr message', () async {
      final result = await launchSsh(
        _conn(),
        run: (executable, arguments) async =>
            ProcessResult(1, 1, '', 'Permission denied'),
      );

      expect(result.succeeded, isFalse);
      expect(result.errorMessage, 'Permission denied');
    });

    test('Given non-zero exitCode with empty stderr, '
        'Then returns failed with null message', () async {
      final result = await launchSsh(
        _conn(),
        run: (executable, arguments) async => ProcessResult(1, 1, '', ''),
      );

      expect(result.succeeded, isFalse);
      expect(result.errorMessage, isNull);
    });

    test('Given runner throws, Then returns failed with SSH failed message',
        () async {
      final result = await launchSsh(
        _conn(),
        run: (executable, arguments) async => throw Exception('boom'),
      );

      expect(result.succeeded, isFalse);
      expect(result.errorMessage, contains('SSH failed'));
      expect(result.errorMessage, contains('boom'));
    });

    test('Given connection, Then passes ssh args without shell', () async {
      List<String>? capturedArgs;
      String? capturedExecutable;
      await launchSsh(
        _conn(username: 'admin', host: 'example.com', port: 2222),
        run: (executable, arguments) async {
          capturedExecutable = executable;
          capturedArgs = arguments;
          return ProcessResult(0, 0, '', '');
        },
      );

      expect(capturedExecutable, 'ssh');
      expect(capturedArgs, ['-p', '2222', 'admin@example.com']);
    });
  });
}
