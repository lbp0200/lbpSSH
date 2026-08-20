import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/presentation/providers/import_export_provider.dart';
import 'package:lbp_ssh/presentation/screens/import_export_settings.dart';

class _MockImportExportNotifier extends ImportExportNotifier {
  final ImportExportStatusData _state;
  _MockImportExportNotifier(this._state);

  File? exportResult;
  Object? exportError;
  List<SshConnection> importResult = [];
  Object? importError;
  final List<({List<SshConnection> connections, bool overwrite, bool addPrefix})>
  importAndSaveCalls = [];
  int resetCalls = 0;

  Map<String, dynamic> stats = {
    'totalConnections': 3,
    'passwordAuth': 2,
    'keyAuth': 1,
    'jumpHostConnections': 1,
    'lastUpdated': '2026-08-01 10:00',
  };

  @override
  ImportExportStatusData build() => _state;

  @override
  Future<File?> exportToLocalFile() async {
    if (exportError != null) {
      throw exportError!;
    }
    return exportResult;
  }

  @override
  String generateExportSummary() => '导出 3 个连接（2 个密码认证，1 个密钥认证）';

  @override
  Map<String, dynamic> getExportStats() => stats;

  @override
  Future<List<SshConnection>> importFromLocalFile() async {
    if (importError != null) {
      throw importError!;
    }
    return importResult;
  }

  @override
  Future<void> importAndSaveConnections(
    List<SshConnection> connections, {
    bool overwrite = false,
    bool addPrefix = true,
  }) async {
    // 拷贝入参：页面可能在 await 后清空/复用原列表
    importAndSaveCalls.add((
      connections: List.of(connections),
      overwrite: overwrite,
      addPrefix: addPrefix,
    ));
  }

  @override
  void resetStatus() {
    resetCalls++;
  }
}

void main() {
  final importedConnections = [
    SshConnection(
      id: 'imported-1',
      name: 'Imported Server',
      host: '10.0.0.1',
      username: 'ops',
      authType: AuthType.key,
    ),
  ];

  Widget createTestWidget({ImportExportNotifier? notifier}) {
    return ProviderScope(
      overrides: [
        importExportProvider.overrideWith(
          () =>
              notifier ??
              _MockImportExportNotifier(const ImportExportStatusData()),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(body: ImportExportSettingsScreen()),
      ),
    );
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    ImportExportNotifier? notifier,
  }) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(createTestWidget(notifier: notifier));
    await tester.pumpAndSettle();
  }

  group('ImportExportSettingsScreen Widget', () {
    group('stats card', () {
      testWidgets(
        'Given stats with jump hosts, When rendered, Then shows connection stats',
        (tester) async {
          await pumpScreen(tester);

          expect(find.text('当前SSH连接统计'), findsOneWidget);
          expect(find.text('总连接数'), findsOneWidget);
          expect(find.text('3'), findsOneWidget);
          expect(find.text('密码认证'), findsOneWidget);
          expect(find.text('2'), findsOneWidget);
          expect(find.text('密钥认证'), findsOneWidget);
          expect(find.text('跳板机连接'), findsOneWidget);
        },
      );

      testWidgets(
        'Given no jump hosts, When rendered, Then hides jump host row',
        (tester) async {
          final notifier = _MockImportExportNotifier(
            const ImportExportStatusData(),
          )..stats = {
            'totalConnections': 1,
            'passwordAuth': 1,
            'keyAuth': 0,
            'jumpHostConnections': 0,
            'lastUpdated': null,
          };
          await pumpScreen(tester, notifier: notifier);

          expect(find.text('跳板机连接'), findsNothing);
        },
      );
    });

    group('export', () {
      testWidgets(
        'Given export succeeds, When export button is tapped, Then shows success dialog with summary',
        (tester) async {
          final notifier = _MockImportExportNotifier(
            const ImportExportStatusData(),
          )..exportResult = File('/tmp/export.json');
          await pumpScreen(tester, notifier: notifier);

          await tester.tap(find.widgetWithText(ElevatedButton, '导出配置'));
          await tester.pumpAndSettle();

          expect(find.text('导出成功'), findsOneWidget);
          expect(find.textContaining('导出 3 个连接'), findsOneWidget);
          expect(find.text('/tmp/export.json'), findsOneWidget);
        },
      );

      testWidgets(
        'Given export returns null, When export button is tapped, Then no dialog is shown',
        (tester) async {
          await pumpScreen(tester);

          await tester.tap(find.widgetWithText(ElevatedButton, '导出配置'));
          await tester.pumpAndSettle();

          expect(find.text('导出成功'), findsNothing);
        },
      );

      testWidgets(
        'Given export fails, When export button is tapped, Then shows error snackbar',
        (tester) async {
          final notifier = _MockImportExportNotifier(
            const ImportExportStatusData(),
          )..exportError = Exception('disk full');
          await pumpScreen(tester, notifier: notifier);

          await tester.tap(find.widgetWithText(ElevatedButton, '导出配置'));
          await tester.pumpAndSettle();

          expect(find.textContaining('导出失败'), findsOneWidget);
          expect(find.textContaining('disk full'), findsOneWidget);
        },
      );
    });

    group('import', () {
      testWidgets(
        'Given import returns empty, When import button is tapped, Then shows no-config snackbar',
        (tester) async {
          await pumpScreen(tester);

          await tester.tap(find.widgetWithText(ElevatedButton, '导入配置'));
          await tester.pumpAndSettle();

          expect(find.text('文件中没有有效的连接配置'), findsOneWidget);
        },
      );

      testWidgets(
        'Given import returns connections, When import button is tapped, Then shows preview with actions',
        (tester) async {
          final notifier = _MockImportExportNotifier(
            const ImportExportStatusData(),
          )..importResult = importedConnections;
          await pumpScreen(tester, notifier: notifier);

          await tester.tap(find.widgetWithText(ElevatedButton, '导入配置'));
          await tester.pumpAndSettle();

          expect(find.text('导入预览'), findsOneWidget);
          expect(find.text('Imported Server'), findsOneWidget);
          expect(find.text('ops@10.0.0.1:22'), findsOneWidget);
          expect(find.text('添加前缀'), findsOneWidget);
          expect(find.text('覆盖现有'), findsOneWidget);
        },
      );

      testWidgets(
        'Given preview shown, When add-prefix flow is confirmed, Then importAndSaveConnections is called without overwrite',
        (tester) async {
          final notifier = _MockImportExportNotifier(
            const ImportExportStatusData(),
          )..importResult = importedConnections;
          await pumpScreen(tester, notifier: notifier);

          await tester.tap(find.widgetWithText(ElevatedButton, '导入配置'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('添加前缀'));
          await tester.pumpAndSettle();

          expect(find.text('确认添加'), findsOneWidget);

          await tester.tap(find.widgetWithText(ElevatedButton, '添加'));
          await tester.pumpAndSettle();
          expect(notifier.importAndSaveCalls, hasLength(1));
          final call = notifier.importAndSaveCalls.single;
          expect(call.connections, hasLength(1));
          expect(call.connections.first.id, 'imported-1');
          expect(call.overwrite, isFalse);
          expect(call.addPrefix, isTrue);
        },
      );

      testWidgets(
        'Given preview shown, When overwrite flow is confirmed, Then importAndSaveConnections is called with overwrite',
        (tester) async {
          final notifier = _MockImportExportNotifier(
            const ImportExportStatusData(),
          )..importResult = importedConnections;
          await pumpScreen(tester, notifier: notifier);

          await tester.tap(find.widgetWithText(ElevatedButton, '导入配置'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('覆盖现有'));
          await tester.pumpAndSettle();

          expect(find.text('确认覆盖'), findsOneWidget);

          await tester.tap(find.widgetWithText(ElevatedButton, '覆盖'));
          await tester.pumpAndSettle();

          final call = notifier.importAndSaveCalls.single;
          expect(call.connections, hasLength(1));
          expect(call.overwrite, isTrue);
          expect(call.addPrefix, isFalse);
        },
      );

      testWidgets(
        'Given preview shown, When dialog is cancelled, Then importAndSaveConnections is not called',
        (tester) async {
          final notifier = _MockImportExportNotifier(
            const ImportExportStatusData(),
          )..importResult = importedConnections;
          await pumpScreen(tester, notifier: notifier);

          await tester.tap(find.widgetWithText(ElevatedButton, '导入配置'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('添加前缀'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('取消'));
          await tester.pumpAndSettle();

          expect(notifier.importAndSaveCalls, isEmpty);
        },
      );

      testWidgets(
        'Given preview shown, When clear button is tapped, Then preview is hidden and resetStatus is called',
        (tester) async {
          final notifier = _MockImportExportNotifier(
            const ImportExportStatusData(),
          )..importResult = importedConnections;
          await pumpScreen(tester, notifier: notifier);

          await tester.tap(find.widgetWithText(ElevatedButton, '导入配置'));
          await tester.pumpAndSettle();
          expect(find.text('导入预览'), findsOneWidget);

          await tester.tap(find.byTooltip('清除预览'));
          await tester.pumpAndSettle();

          expect(find.text('导入预览'), findsNothing);
          expect(notifier.resetCalls, 1);
          // 页面持有的是副本，clear 不污染调用方传入的列表
          expect(importedConnections, hasLength(1));
        },
      );

      testWidgets(
        'Given preview with multiple connections of different auth types, '
        'When preview shown, Then renders auth icons and separators',
        (tester) async {
          final notifier = _MockImportExportNotifier(
            const ImportExportStatusData(),
          )..importResult = [
            SshConnection(
              id: 'c1',
              name: 'Key Server',
              host: '10.0.0.1',
              username: 'ops',
              authType: AuthType.key,
            ),
            SshConnection(
              id: 'c2',
              name: 'KeyPass Server',
              host: '10.0.0.2',
              username: 'ops',
              authType: AuthType.keyWithPassword,
            ),
            SshConnection(
              id: 'c3',
              name: 'SshConfig Server',
              host: '10.0.0.3',
              username: 'ops',
              authType: AuthType.sshConfig,
            ),
          ];
          await pumpScreen(tester, notifier: notifier);

          await tester.tap(find.widgetWithText(ElevatedButton, '导入配置'));
          await tester.pumpAndSettle();

          // 三种认证类型的图标（页面其他区域可能也有 key 图标）
          expect(find.byIcon(Icons.key), findsAtLeastNWidgets(1));
          expect(find.byIcon(Icons.vpn_key), findsAtLeastNWidgets(1));
          expect(find.byIcon(Icons.settings), findsAtLeastNWidgets(1));
          // 列表项之间的分隔线（3 项 → 2 条分隔线）
          expect(find.byType(Divider), findsNWidgets(2));
        },
      );

      testWidgets(
        'Given import fails, When import button is tapped, Then shows error snackbar',
        (tester) async {
          final notifier = _MockImportExportNotifier(
            const ImportExportStatusData(),
          )..importError = Exception('bad file');
          await pumpScreen(tester, notifier: notifier);

          await tester.tap(find.widgetWithText(ElevatedButton, '导入配置'));
          await tester.pumpAndSettle();

          expect(find.textContaining('导入失败'), findsOneWidget);
          expect(find.textContaining('bad file'), findsOneWidget);
        },
      );
    });
  });
}
