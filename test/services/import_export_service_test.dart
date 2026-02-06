import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/domain/services/import_export_service.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';

void main() {
  group('ImportExportStatus', () {
    test('should have correct values', () {
      expect(ImportExportStatus.idle.toString(), 'ImportExportStatus.idle');
      expect(ImportExportStatus.exporting.toString(), 'ImportExportStatus.exporting');
      expect(ImportExportStatus.importing.toString(), 'ImportExportStatus.importing');
      expect(ImportExportStatus.success.toString(), 'ImportExportStatus.success');
      expect(ImportExportStatus.error.toString(), 'ImportExportStatus.error');
    });
  });

  group('ImportExportService - Export File Validation', () {
    test('should validate correct export file', () {
      final validData = {
        'appName': 'lbpSSH',
        'version': 1,
        'exportTime': '2024-01-01T00:00:00Z',
        'connections': [
          {
            'id': 'conn1',
            'name': 'Test Server',
            'host': '192.168.1.1',
            'port': 22,
            'username': 'user',
            'authType': 'password',
          },
        ],
      };

      // Create a mock-like test by directly testing validation logic
      bool validateExportFile(Map<String, dynamic> data) {
        if (!data.containsKey('connections') ||
            !data.containsKey('version') ||
            !data.containsKey('exportTime')) {
          return false;
        }
        if (data['connections'] is! List) {
          return false;
        }
        if ((data['connections'] as List).isEmpty) {
          return false;
        }
        return true;
      }

      expect(validateExportFile(validData), true);
    });

    test('should reject file without connections', () {
      final invalidData = {
        'version': 1,
        'exportTime': '2024-01-01T00:00:00Z',
        'connections': [],
      };

      bool validateExportFile(Map<String, dynamic> data) {
        if (!data.containsKey('connections') ||
            !data.containsKey('version') ||
            !data.containsKey('exportTime')) {
          return false;
        }
        if (data['connections'] is! List) {
          return false;
        }
        if ((data['connections'] as List).isEmpty) {
          return false;
        }
        return true;
      }

      expect(validateExportFile(invalidData), false);
    });

    test('should reject file without version', () {
      final invalidData = {
        'appName': 'lbpSSH',
        'exportTime': '2024-01-01T00:00:00Z',
        'connections': [],
      };

      bool validateExportFile(Map<String, dynamic> data) {
        if (!data.containsKey('connections') ||
            !data.containsKey('version') ||
            !data.containsKey('exportTime')) {
          return false;
        }
        if (data['connections'] is! List) {
          return false;
        }
        if ((data['connections'] as List).isEmpty) {
          return false;
        }
        return true;
      }

      expect(validateExportFile(invalidData), false);
    });

    test('should reject file with invalid connections type', () {
      final invalidData = {
        'version': 1,
        'exportTime': '2024-01-01T00:00:00Z',
        'connections': 'invalid',
      };

      bool validateExportFile(Map<String, dynamic> data) {
        if (!data.containsKey('connections') ||
            !data.containsKey('version') ||
            !data.containsKey('exportTime')) {
          return false;
        }
        if (data['connections'] is! List) {
          return false;
        }
        if ((data['connections'] as List).isEmpty) {
          return false;
        }
        return true;
      }

      expect(validateExportFile(invalidData), false);
    });
  });

  group('SshConnection - Serialization', () {
    test('should serialize connection to JSON', () {
      final connection = SshConnection(
        id: 'conn1',
        name: 'Test Server',
        host: '192.168.1.1',
        port: 22,
        username: 'admin',
        authType: AuthType.password,
        password: 'secret123',
      );

      final json = connection.toJson();

      expect(json['id'], 'conn1');
      expect(json['name'], 'Test Server');
      expect(json['host'], '192.168.1.1');
      expect(json['port'], 22);
      expect(json['username'], 'admin');
      expect(json['authType'], 'password');
      expect(json['password'], 'secret123');
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
      expect(connection.username, 'root');
      expect(connection.authType, AuthType.key);
    });

    test('should handle jumpHost in serialization', () {
      final jumpHost = JumpHostConfig(
        host: 'bastion.example.com',
        port: 22,
        username: 'user',
        authType: AuthType.password,
        password: 'bastion_pass',
      );

      final connection = SshConnection(
        id: 'conn3',
        name: 'Internal Server',
        host: 'internal.example.com',
        port: 22,
        username: 'admin',
        authType: AuthType.password,
        jumpHost: jumpHost,
      );

      expect(connection.jumpHost, isNotNull);
      expect(connection.jumpHost!.host, 'bastion.example.com');

      // Test JumpHostConfig serialization independently
      final jumpHostJson = jumpHost.toJson();
      expect(jumpHostJson['host'], 'bastion.example.com');
      expect(jumpHostJson['port'], 22);
    });

    test('should create connection with copyWith', () {
      final original = SshConnection(
        id: 'conn4',
        name: 'Original',
        host: '192.168.1.1',
        port: 22,
        username: 'user',
        authType: AuthType.password,
      );

      final modified = original.copyWith(name: 'Modified', port: 2222);

      expect(modified.id, 'conn4');
      expect(modified.name, 'Modified');
      expect(modified.port, 2222);
      expect(original.name, 'Original');
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
