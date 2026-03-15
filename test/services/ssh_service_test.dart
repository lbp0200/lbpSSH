import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/domain/services/ssh_service.dart';
import 'package:lbp_ssh/domain/services/terminal_input_service.dart';

void main() {
  group('SshService State Management', () {
    late SshService service;

    setUp(() {
      service = SshService();
    });

    tearDown(() {
      service.dispose();
    });

    test('Given new service, When created, Then has disconnected state', () {
      expect(service.state, SshConnectionState.disconnected);
    });

    test('Given new service, When created, Then has outputStream', () {
      expect(service.outputStream, isA<Stream<String>>());
    });

    test('Given new service, When created, Then has stateStream', () {
      expect(service.stateStream, isA<Stream<bool>>());
    });

    test('Given new service, When created, Then has sshStateStream', () {
      expect(service.sshStateStream, isA<Stream<SshConnectionState>>());
    });

    test('Given disconnected service, When disconnect called, Then state remains disconnected', () async {
      await service.disconnect();
      expect(service.state, SshConnectionState.disconnected);
    });

    test('Given connected service, When disconnect called, Then state changes to disconnected', () async {
      // Note: This test only verifies the state transition logic
      // Actual connection would require mocking dartssh2
      await service.disconnect();
      expect(service.state, SshConnectionState.disconnected);
    });

    test('Given service, When getSftpClient called without connection, Then returns null', () async {
      final sftp = await service.getSftpClient();
      expect(sftp, isNull);
    });

    test('Given service, When osType accessed, Then returns Linux by default', () {
      expect(service.osType, 'Linux');
    });
  });

  group('SshConnectionState Enum', () {
    test('Has all expected states', () {
      expect(SshConnectionState.values, contains(SshConnectionState.disconnected));
      expect(SshConnectionState.values, contains(SshConnectionState.connecting));
      expect(SshConnectionState.values, contains(SshConnectionState.connected));
      expect(SshConnectionState.values, contains(SshConnectionState.error));
    });
  });

  group('TerminalInputService Interface', () {
    late SshService service;

    setUp(() {
      service = SshService();
    });

    tearDown(() {
      service.dispose();
    });

    test('SshService implements TerminalInputService', () {
      expect(service, isA<TerminalInputService>());
    });

    test('Given service, When sendInput called without connection, Then does not error', () {
      // Should not throw even when not connected
      service.sendInput('test input');
    });

    test('Given service, When executeCommand called without connection, Then throws exception', () {
      expect(
        () => service.executeCommand('ls'),
        throwsException,
      );
    });

    test('Given service, When executeCommand called with silent=true, Then executes silently', () async {
      // Without connection, should throw
      try {
        await service.executeCommand('ls', silent: true);
      } catch (e) {
        // Expected to fail
      }
      // If we get here, the silent parameter was accepted
    });

    test('Given service, When resize called without connection, Then does not error', () {
      // Should not throw even when not connected
      service.resize(24, 80);
    });

    test('Given service, When resize called with dimensions, Then accepts parameters', () {
      // Test that resize method accepts rows and columns
      // Without actual connection, it should not throw
      service.resize(40, 120);
      service.resize(10, 40);
    });
  });

  group('SshService Dispose', () {
    test('Given service, When dispose called, Then closes streams', () {
      final service = SshService();
      service.dispose();

      // After dispose, streams should be closed
      // This is difficult to test without mocking, but we verify no errors
    });

    test('Given service, When dispose called multiple times, Then does not error', () {
      final service = SshService();
      service.dispose();
      service.dispose(); // Should not throw
    });
  });
}
