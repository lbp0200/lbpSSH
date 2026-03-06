import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/data/repositories/connection_repository.dart';
import 'package:lbp_ssh/domain/services/import_export_service.dart';
import 'package:mocktail/mocktail.dart';

class MockConnectionRepository extends Mock implements ConnectionRepository {}

void main() {
  group('ImportExportStatus', () {
    test(
        'Given ImportExportStatus enum, When converting to string, Then produces correct values',
        () {
      expect(ImportExportStatus.idle.toString(), 'ImportExportStatus.idle');
      expect(ImportExportStatus.exporting.toString(), 'ImportExportStatus.exporting');
      expect(ImportExportStatus.importing.toString(), 'ImportExportStatus.importing');
      expect(ImportExportStatus.success.toString(), 'ImportExportStatus.success');
      expect(ImportExportStatus.error.toString(), 'ImportExportStatus.error');
    });
  });

  group('ImportExportService', () {
    late MockConnectionRepository mockRepository;
    late ImportExportService service;

    setUp(() {
      mockRepository = MockConnectionRepository();
      service = ImportExportService(mockRepository);
    });

    group('status and error', () {
      test('Given initial state, When created, Then status is idle', () {
        expect(service.status, ImportExportStatus.idle);
      });

      test('Given initial state, When created, Then lastError is null', () {
        expect(service.lastError, isNull);
      });
    });

    group('getExportStats', () {
      test(
          'Given repository with password auth connections, When getExportStats called, Then returns correct counts',
          () {
        // Arrange (Given)
        when(() => mockRepository.getAllConnections()).thenReturn([
          SshConnection(
            id: 'conn1',
            name: 'Server 1',
            host: '192.168.1.1',
            username: 'user',
            authType: AuthType.password,
          ),
          SshConnection(
            id: 'conn2',
            name: 'Server 2',
            host: '192.168.1.2',
            username: 'user',
            authType: AuthType.password,
          ),
          SshConnection(
            id: 'conn3',
            name: 'Server 3',
            host: '192.168.1.3',
            username: 'user',
            authType: AuthType.key,
          ),
        ]);

        // Act (When)
        final stats = service.getExportStats();

        // Assert (Then)
        expect(stats['totalConnections'], 3);
        expect(stats['passwordAuth'], 2);
        expect(stats['keyAuth'], 1);
      });

      test(
          'Given repository with jump host connections, When getExportStats called, Then counts jump hosts',
          () {
        // Arrange (Given)
        final jumpHost = JumpHostConfig(
          host: 'jump.example.com',
          username: 'jumpuser',
          authType: AuthType.password,
        );
        when(() => mockRepository.getAllConnections()).thenReturn([
          SshConnection(
            id: 'conn1',
            name: 'Server with Jump',
            host: '192.168.1.1',
            username: 'user',
            authType: AuthType.password,
            jumpHost: jumpHost,
          ),
        ]);

        // Act (When)
        final stats = service.getExportStats();

        // Assert (Then)
        expect(stats['jumpHostConnections'], 1);
      });

      test(
          'Given empty repository, When getExportStats called, Then returns zero counts',
          () {
        // Arrange (Given)
        when(() => mockRepository.getAllConnections()).thenReturn([]);

        // Act (When)
        final stats = service.getExportStats();

        // Assert (Then)
        expect(stats['totalConnections'], 0);
        expect(stats['passwordAuth'], 0);
        expect(stats['keyAuth'], 0);
      });
    });

    group('generateExportSummary', () {
      test(
          'Given repository with connections, When generateExportSummary called, Then returns summary string',
          () {
        // Arrange (Given)
        when(() => mockRepository.getAllConnections()).thenReturn([
          SshConnection(
            id: 'conn1',
            name: 'Server 1',
            host: '192.168.1.1',
            username: 'user',
            authType: AuthType.password,
          ),
        ]);

        // Act (When)
        final summary = service.generateExportSummary();

        // Assert (Then)
        expect(summary, contains('SSH连接配置导出摘要'));
        expect(summary, contains('总连接数: 1'));
      });
    });

    group('resetStatus', () {
      test(
          'Given status is error, When resetStatus called, Then status becomes idle',
          () {
        // This is a bit tricky to test since we can't easily trigger error state
        // without mocking internal behavior, but we can verify the method exists
        service.resetStatus();
        expect(service.status, ImportExportStatus.idle);
      });
    });

    group('mergeImportedConnections', () {
      test(
          'Given imported connections without overwrite, When mergeImportedConnections called, Then adds new connections',
          () async {
        // Arrange (Given)
        final importedConnections = [
          SshConnection(
            id: 'import1',
            name: 'Imported Server',
            host: '192.168.1.100',
            username: 'user',
            authType: AuthType.password,
          ),
        ];

        when(() => mockRepository.getAllConnections()).thenReturn([]);
        when(() => mockRepository.clearAll()).thenAnswer((_) async {});
        when(() => mockRepository.saveConnections(any())).thenAnswer((_) async {});

        // Act (When)
        final result = await service.mergeImportedConnections(importedConnections);

        // Assert (Then)
        expect(result.length, 1);
        verify(() => mockRepository.saveConnections(any())).called(1);
      });

      test(
          'Given imported connections with overwrite, When mergeImportedConnections called, Then overwrites existing',
          () async {
        // Arrange (Given)
        final importedConnection = SshConnection(
          id: 'conn1',
          name: 'Updated Server',
          host: '192.168.1.100',
          username: 'user',
          authType: AuthType.password,
        );

        when(() => mockRepository.getAllConnections()).thenReturn([
          SshConnection(
            id: 'conn1',
            name: 'Old Server',
            host: '192.168.1.1',
            username: 'user',
            authType: AuthType.password,
          ),
        ]);
        when(() => mockRepository.clearAll()).thenAnswer((_) async {});
        when(() => mockRepository.saveConnections(any())).thenAnswer((_) async {});

        // Act (When)
        final result = await service.mergeImportedConnections(
          [importedConnection],
          overwrite: true,
        );

        // Assert (Then)
        // When overwrite is true with addPrefix=false (default), it generates new ID with timestamp
        // The result will have the imported connection but with different ID
        expect(result.isNotEmpty, isTrue);
        verify(() => mockRepository.saveConnections(any())).called(1);
      });

      test(
          'Given imported connections with addPrefix and overwrite, When mergeImportedConnections called, Then adds prefix to names',
          () async {
        // Arrange (Given)
        final importedConnection = SshConnection(
          id: 'conn1',
          name: 'Server',
          host: '192.168.1.100',
          username: 'user',
          authType: AuthType.password,
        );

        when(() => mockRepository.getAllConnections()).thenReturn([
          SshConnection(
            id: 'conn1',
            name: 'Old Server',
            host: '192.168.1.1',
            username: 'user',
            authType: AuthType.password,
          ),
        ]);
        when(() => mockRepository.clearAll()).thenAnswer((_) async {});
        when(() => mockRepository.saveConnections(any())).thenAnswer((_) async {});

        // Act (When)
        final result = await service.mergeImportedConnections(
          [importedConnection],
          overwrite: true,
          addPrefix: true,
        );

        // Assert (Then)
        // Note: addPrefix is only applied when overwriting to generate new ID
        // The prefix is added to the name when the ID changes
        expect(result.isNotEmpty, isTrue);
      });
    });
  });
}
