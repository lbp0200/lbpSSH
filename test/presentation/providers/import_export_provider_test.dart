import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/domain/services/import_export_service.dart';
import 'package:lbp_ssh/presentation/providers/import_export_provider.dart';
import 'package:lbp_ssh/presentation/providers/service_providers.dart';

class MockImportExportService extends Mock implements ImportExportService {}

void main() {
  late MockImportExportService mockService;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(
      SshConnection(
        id: 'test_id',
        name: 'Test Server',
        host: '192.168.1.1',
        username: 'testuser',
        authType: AuthType.password,
      ),
    );
  });

  setUp(() {
    mockService = MockImportExportService();
    container = ProviderContainer(
      overrides: [importExportServiceProvider.overrideWithValue(mockService)],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('ImportExportNotifier', () {
    group('initial state', () {
      test(
        'Given new provider, When created, Then has idle status with no error',
        () {
          // Act (When)
          final state = container.read(importExportProvider);

          // Assert (Then)
          expect(state.status, ImportExportStatus.idle);
          expect(state.lastError, isNull);
        },
      );
    });

    group('exportToLocalFile', () {
      test(
        'Given successful export, When called, Then returns file and sets success status',
        () async {
          // Arrange (Given)
          final mockFile = File('/tmp/test_export.json');
          when(
            () => mockService.exportToLocalFile(),
          ).thenAnswer((_) async => mockFile);

          // Act (When)
          final result = await container
              .read(importExportProvider.notifier)
              .exportToLocalFile();

          // Assert (Then)
          expect(result, mockFile);
          verify(() => mockService.exportToLocalFile()).called(1);
        },
      );

      test(
        'Given service throws, When called, Then rethrows and sets error',
        () async {
          // Arrange (Given)
          when(
            () => mockService.exportToLocalFile(),
          ).thenThrow(Exception('Export failed'));

          // Act & Assert (When)
          await expectLater(
            () => container
                .read(importExportProvider.notifier)
                .exportToLocalFile(),
            throwsException,
          );
        },
      );
    });

    group('importFromLocalFile', () {
      test(
        'Given successful import, When called, Then returns connections and sets success',
        () async {
          // Arrange (Given)
          final connections = [
            SshConnection(
              id: 'imported_1',
              name: 'Imported',
              host: '10.0.0.1',
              username: 'admin',
              authType: AuthType.password,
            ),
          ];
          when(
            () => mockService.importFromLocalFile(),
          ).thenAnswer((_) async => connections);

          // Act (When)
          final result = await container
              .read(importExportProvider.notifier)
              .importFromLocalFile();

          // Assert (Then)
          expect(result, connections);
          verify(() => mockService.importFromLocalFile()).called(1);
        },
      );

      test(
        'Given service throws, When called, Then rethrows and sets error',
        () async {
          // Arrange (Given)
          when(
            () => mockService.importFromLocalFile(),
          ).thenThrow(Exception('Import failed'));

          // Act & Assert (When)
          await expectLater(
            () => container
                .read(importExportProvider.notifier)
                .importFromLocalFile(),
            throwsException,
          );
        },
      );
    });

    group('importAndSaveConnections', () {
      test(
        'Given connections, When called, Then delegates to service',
        () async {
          // Arrange (Given)
          final connections = [
            SshConnection(
              id: 'c1',
              name: 'Server 1',
              host: '10.0.0.1',
              username: 'admin',
              authType: AuthType.password,
            ),
          ];
          when(
            () => mockService.importAndSaveConnections(
              any(),
              overwrite: any(named: 'overwrite'),
              addPrefix: any(named: 'addPrefix'),
            ),
          ).thenAnswer((_) async {});

          // Act (When)
          await container
              .read(importExportProvider.notifier)
              .importAndSaveConnections(connections);

          // Assert (Then)
          verify(
            () => mockService.importAndSaveConnections(connections),
          ).called(1);
        },
      );

      test(
        'Given custom options, When called, Then passes options to service',
        () async {
          // Arrange (Given)
          final connections = [
            SshConnection(
              id: 'c2',
              name: 'Server 2',
              host: '10.0.0.2',
              username: 'admin',
              authType: AuthType.password,
            ),
          ];
          when(
            () => mockService.importAndSaveConnections(
              any(),
              overwrite: any(named: 'overwrite'),
              addPrefix: any(named: 'addPrefix'),
            ),
          ).thenAnswer((_) async {});

          // Act (When)
          await container
              .read(importExportProvider.notifier)
              .importAndSaveConnections(
                connections,
                overwrite: true,
                addPrefix: false,
              );

          // Assert (Then)
          verify(
            () => mockService.importAndSaveConnections(
              connections,
              overwrite: true,
              addPrefix: false,
            ),
          ).called(1);
        },
      );
    });

    group('getExportStats', () {
      test('When called, Then returns stats from service', () {
        // Arrange (Given)
        const stats = {'totalConnections': 5};
        when(() => mockService.getExportStats()).thenReturn(stats);

        // Act (When)
        final result = container
            .read(importExportProvider.notifier)
            .getExportStats();

        // Assert (Then)
        expect(result, stats);
        verify(() => mockService.getExportStats()).called(1);
      });
    });

    group('generateExportSummary', () {
      test('When called, Then returns summary string', () {
        // Arrange (Given)
        const summary = 'Exported 5 connections';
        when(() => mockService.generateExportSummary()).thenReturn(summary);

        // Act (When)
        final result = container
            .read(importExportProvider.notifier)
            .generateExportSummary();

        // Assert (Then)
        expect(result, summary);
        verify(() => mockService.generateExportSummary()).called(1);
      });
    });

    group('resetStatus', () {
      test('When called, Then resets state to idle', () {
        // Act (When)
        container.read(importExportProvider.notifier).resetStatus();

        // Assert (Then)
        expect(
          container.read(importExportProvider).status,
          ImportExportStatus.idle,
        );
      });
    });

    group('ImportExportStatusData', () {
      test('Given base data, When copyWith status and lastError, '
          'Then returns updated data', () {
        const base = ImportExportStatusData(
          // status 默认即 idle
          lastError: 'old',
        );

        final updated = base.copyWith(
          status: ImportExportStatus.error,
          lastError: 'new error',
        );

        expect(updated.status, ImportExportStatus.error);
        expect(updated.lastError, 'new error');
        expect(base.lastError, 'old'); // 原对象不变
      });

      test(
        'Given data, When copyWith with nulls, Then keeps existing values',
        () {
          const base = ImportExportStatusData(
            status: ImportExportStatus.success,
            lastError: 'keep me',
          );

          final updated = base.copyWith();

          expect(updated.status, ImportExportStatus.success);
          expect(updated.lastError, 'keep me');
        },
      );

      test('Given equal data, When compared, Then operator == is true', () {
        const a = ImportExportStatusData(
          status: ImportExportStatus.error,
          lastError: 'same',
        );
        const b = ImportExportStatusData(
          status: ImportExportStatus.error,
          lastError: 'same',
        );

        expect(a == b, isTrue);
        expect(a.hashCode, b.hashCode);
      });

      test(
        'Given different data, When compared, Then operator == is false',
        () {
          const a = ImportExportStatusData(
            status: ImportExportStatus.error,
            lastError: 'a',
          );
          const b = ImportExportStatusData(
            status: ImportExportStatus.success,
            lastError: 'a',
          );
          const c = ImportExportStatusData(
            status: ImportExportStatus.error,
            lastError: 'b',
          );

          expect(a == b, isFalse);
          expect(a == c, isFalse);
          // 与完全不同的实例比较（默认状态）
          expect(a == const ImportExportStatusData(), isFalse);
        },
      );
    });

    group('importAndSaveConnections error path', () {
      test(
        'Given service throws, When called, Then rethrows and sets error state',
        () async {
          // Arrange (Given)
          when(
            () => mockService.importAndSaveConnections(
              any(),
              overwrite: any(named: 'overwrite'),
              addPrefix: any(named: 'addPrefix'),
            ),
          ).thenThrow(Exception('Save failed'));

          // Act & Assert (When)
          await expectLater(
            () => container
                .read(importExportProvider.notifier)
                .importAndSaveConnections([
                  SshConnection(
                    id: 'c3',
                    name: 'Server 3',
                    host: '10.0.0.3',
                    username: 'admin',
                    authType: AuthType.password,
                  ),
                ]),
            throwsException,
          );

          // Assert (Then) - 状态被设置为 error 且携带错误信息
          final state = container.read(importExportProvider);
          expect(state.status, ImportExportStatus.error);
          expect(state.lastError, contains('导入失败'));
        },
      );
    });

    group('in-flight and cancel states', () {
      test(
        'Given export in progress, When called, Then status is exporting until it completes to success',
        () async {
          // Arrange (Given) - 用一个可手动完成的 Future 制造"进行中"窗口
          final completer = Completer<File?>();
          when(
            () => mockService.exportToLocalFile(),
          ).thenAnswer((_) => completer.future);

          // Act (When) - 发起导出但暂不等待完成
          final pending = container
              .read(importExportProvider.notifier)
              .exportToLocalFile();

          // Assert (Then) - 进行中状态应为 exporting（UI 据此禁用按钮/显示进度）
          expect(
            container.read(importExportProvider).status,
            ImportExportStatus.exporting,
          );

          // 完成导出 -> 应为 success
          final exported = File('/tmp/inflight_export.json');
          completer.complete(exported);
          final result = await pending;
          expect(result, exported);
          expect(
            container.read(importExportProvider).status,
            ImportExportStatus.success,
          );
        },
      );

      test(
        'Given user cancels save dialog (service returns null), When export completes, Then status is idle not success',
        () async {
          // Arrange (Given) - 用户取消"保存位置"选择时 service 返回 null
          when(
            () => mockService.exportToLocalFile(),
          ).thenAnswer((_) async => null);

          // Act (When)
          final result = await container
              .read(importExportProvider.notifier)
              .exportToLocalFile();

          // Assert (Then) - 未真正导出：不得误报为 success，应回到 idle
          expect(result, isNull);
          expect(
            container.read(importExportProvider).status,
            ImportExportStatus.idle,
          );
        },
      );

      test(
        'Given import in progress, When called, Then status is importing until it completes to success',
        () async {
          // Arrange (Given)
          final completer = Completer<List<SshConnection>>();
          when(
            () => mockService.importFromLocalFile(),
          ).thenAnswer((_) => completer.future);

          // Act (When)
          final pending = container
              .read(importExportProvider.notifier)
              .importFromLocalFile();

          // Assert (Then) - 进行中状态应为 importing
          expect(
            container.read(importExportProvider).status,
            ImportExportStatus.importing,
          );

          // 完成导入 -> 应为 success
          final conns = [
            SshConnection(
              id: 'i1',
              name: 'Imported',
              host: '1.1.1.1',
              username: 'u',
              authType: AuthType.password,
            ),
          ];
          completer.complete(conns);
          final result = await pending;
          expect(result, conns);
          expect(
            container.read(importExportProvider).status,
            ImportExportStatus.success,
          );
        },
      );
    });
  });
}
