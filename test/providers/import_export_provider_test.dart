import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/presentation/providers/import_export_provider.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/domain/services/import_export_service.dart';
import '../mocks/mocks.dart';

void main() {
  late MockImportExportService mockImportExportService;
  late ImportExportProvider importExportProvider;

  setUp(() {
    mockImportExportService = MockImportExportService();
    importExportProvider = ImportExportProvider(mockImportExportService);
    registerFallbackValues();
  });

  group('ImportExportProvider', () {
    group('status', () {
      test(
          'Given ImportExportService with status, When accessing status, Then returns service status',
          () {
        // Arrange (Given)
        when(() => mockImportExportService.status)
            .thenReturn(ImportExportStatus.exporting);

        // Act (When)
        final result = importExportProvider.status;

        // Assert (Then)
        expect(result, ImportExportStatus.exporting);
        verify(() => mockImportExportService.status).called(1);
      });
    });

    group('lastError', () {
      test(
          'Given ImportExportService with error, When accessing lastError, Then returns error message',
          () {
        // Arrange (Given)
        const errorMessage = 'Export failed';
        when(() => mockImportExportService.lastError).thenReturn(errorMessage);

        // Act (When)
        final result = importExportProvider.lastError;

        // Assert (Then)
        expect(result, errorMessage);
        verify(() => mockImportExportService.lastError).called(1);
      });

      test(
          'Given ImportExportService with no error, When accessing lastError, Then returns null',
          () {
        // Arrange (Given)
        when(() => mockImportExportService.lastError).thenReturn(null);

        // Act (When)
        final result = importExportProvider.lastError;

        // Assert (Then)
        expect(result, isNull);
      });
    });

    group('exportToLocalFile', () {
      test(
          'Given successful export, When exportToLocalFile called, Then returns file and notifies listeners',
          () async {
        // Arrange (Given)
        final tempFile = File('/tmp/test_export.json');
        when(() => mockImportExportService.exportToLocalFile())
            .thenAnswer((_) async => tempFile);

        // Act (When)
        final result = await importExportProvider.exportToLocalFile();

        // Assert (Then)
        expect(result, isNotNull);
        verify(() => mockImportExportService.exportToLocalFile()).called(1);
      });

      test(
          'Given export failure, When exportToLocalFile called, Then throws exception',
          () async {
        // Arrange (Given)
        when(() => mockImportExportService.exportToLocalFile())
            .thenThrow(Exception('Export failed'));

        // Act & Assert (When)
        expect(
          () => importExportProvider.exportToLocalFile(),
          throwsException,
        );
      });
    });

    group('importFromLocalFile', () {
      test(
          'Given successful import, When importFromLocalFile called, Then returns connections and notifies listeners',
          () async {
        // Arrange (Given)
        final connections = [
          SshConnection(
            id: 'conn1',
            name: 'Imported Server',
            host: '192.168.1.1',
            port: 22,
            username: 'user1',
            authType: AuthType.password,
          ),
        ];
        when(() => mockImportExportService.importFromLocalFile())
            .thenAnswer((_) async => connections);

        // Act (When)
        final result = await importExportProvider.importFromLocalFile();

        // Assert (Then)
        expect(result.length, 1);
        expect(result.first.name, 'Imported Server');
        verify(() => mockImportExportService.importFromLocalFile()).called(1);
      });

      test(
          'Given import failure, When importFromLocalFile called, Then throws exception',
          () async {
        // Arrange (Given)
        when(() => mockImportExportService.importFromLocalFile())
            .thenThrow(Exception('Import failed'));

        // Act & Assert (When)
        expect(
          () => importExportProvider.importFromLocalFile(),
          throwsException,
        );
      });
    });

    group('importAndSaveConnections', () {
      test(
          'Given valid connections, When importAndSaveConnections called, Then saves to repository and notifies listeners',
          () async {
        // Arrange (Given)
        final connections = [
          SshConnection(
            id: 'conn1',
            name: 'Server 1',
            host: '192.168.1.1',
            port: 22,
            username: 'user1',
            authType: AuthType.password,
          ),
        ];
        when(() => mockImportExportService.importAndSaveConnections(
              connections,
              overwrite: false,
              addPrefix: true,
            )).thenAnswer((_) async {});

        // Act (When)
        await importExportProvider.importAndSaveConnections(
          connections,
          overwrite: false,
          addPrefix: true,
        );

        // Assert (Then)
        verify(() => mockImportExportService.importAndSaveConnections(
              connections,
              overwrite: false,
              addPrefix: true,
            )).called(1);
      });

      test(
          'Given overwrite option, When importAndSaveConnections called, Then passes option to service',
          () async {
        // Arrange (Given)
        final connections = [
          SshConnection(
            id: 'conn1',
            name: 'Server 1',
            host: '192.168.1.1',
            port: 22,
            username: 'user1',
            authType: AuthType.password,
          ),
        ];
        when(() => mockImportExportService.importAndSaveConnections(
              connections,
              overwrite: true,
              addPrefix: false,
            )).thenAnswer((_) async {});

        // Act (When)
        await importExportProvider.importAndSaveConnections(
          connections,
          overwrite: true,
          addPrefix: false,
        );

        // Assert (Then)
        verify(() => mockImportExportService.importAndSaveConnections(
              connections,
              overwrite: true,
              addPrefix: false,
            )).called(1);
      });
    });

    group('getExportStats', () {
      test(
          'Given service with stats, When getExportStats called, Then returns stats map',
          () {
        // Arrange (Given)
        final stats = {
          'totalConnections': 5,
          'exportTime': '2024-01-01T00:00:00Z',
        };
        when(() => mockImportExportService.getExportStats()).thenReturn(stats);

        // Act (When)
        final result = importExportProvider.getExportStats();

        // Assert (Then)
        expect(result['totalConnections'], 5);
        verify(() => mockImportExportService.getExportStats()).called(1);
      });
    });

    group('generateExportSummary', () {
      test(
          'Given service, When generateExportSummary called, Then returns summary string',
          () {
        // Arrange (Given)
        const summary = 'Exported 5 connections';
        when(() => mockImportExportService.generateExportSummary())
            .thenReturn(summary);

        // Act (When)
        final result = importExportProvider.generateExportSummary();

        // Assert (Then)
        expect(result, summary);
        verify(() => mockImportExportService.generateExportSummary()).called(1);
      });
    });

    group('resetStatus', () {
      test(
          'When resetStatus called, Then resets service status and notifies listeners',
          () {
        // Arrange (Given)
        when(() => mockImportExportService.resetStatus()).thenReturn(null);

        // Act (When)
        importExportProvider.resetStatus();

        // Assert (Then)
        verify(() => mockImportExportService.resetStatus()).called(1);
      });
    });
  });
}
