import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:lbp_ssh/core/constants/app_constants.dart';
import 'package:lbp_ssh/domain/services/sync_service.dart';
import 'package:lbp_ssh/presentation/providers/sync_provider.dart';
import 'package:lbp_ssh/presentation/screens/sync_settings.dart';

class _RecordingSyncNotifier extends SyncNotifier {
  final SyncStatus _state;
  final List<SyncConfig> savedConfigs = [];
  int uploadCalls = 0;
  int downloadCalls = 0;
  int testConnectionCalls = 0;
  bool failOperations = false;
  bool failSave = false;

  _RecordingSyncNotifier(this._state);

  @override
  SyncStatus build() => _state;

  @override
  Future<void> saveConfig(SyncConfig config) async {
    if (failSave) {
      throw Exception('save failed');
    }
    savedConfigs.add(config);
  }

  @override
  Future<void> uploadConfig() async {
    uploadCalls++;
    if (failOperations) {
      throw Exception('network error');
    }
  }

  @override
  Future<void> downloadConfig() async {
    downloadCalls++;
    if (failOperations) {
      throw Exception('network error');
    }
  }

  @override
  Future<void> testConnection() async {
    testConnectionCalls++;
    if (failOperations) {
      throw Exception('network error');
    }
  }
}

void main() {
  setUpAll(() {
    PackageInfo.setMockInitialValues(
      appName: 'lbp_ssh',
      packageName: 'com.lbp.lbp_ssh',
      version: '1.9.3',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  final savedConfig = SyncConfig(
    accessToken: 'ghp_testtoken',
    gistId: 'abc123',
    gistFilename: 'my_connections.json',
    autoSync: true,
    syncIntervalMinutes: 10,
  );

  Widget createTestWidget({SyncNotifier? notifier}) {
    return ProviderScope(
      overrides: [
        syncProvider.overrideWith(
          () => notifier ?? _RecordingSyncNotifier(const SyncStatus()),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SyncSettingsScreen()),
      ),
    );
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    SyncNotifier? notifier,
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

  group('SyncSettingsScreen Widget', () {
    group('config rendering', () {
      testWidgets(
        'Given no saved config, When rendered, Then uses default filename and empty token',
        (tester) async {
          await pumpScreen(tester);

          expect(find.text('GitHub Token'), findsWidgets);
          // token 输入框为空（无占位符）
          final tokenField = tester.widget<TextFormField>(
            find.byType(TextFormField).first,
          );
          expect(tokenField.controller!.text, isEmpty);
          // 文件名输入框回填默认值（hint 里也有同名文本，故检查 controller）
          final filenameField = tester.widget<TextFormField>(
            find.byType(TextFormField).at(2),
          );
          expect(
            filenameField.controller!.text,
            AppConstants.defaultGistFilename,
          );
        },
      );

      testWidgets(
        'Given saved config, When rendered, Then fills fields and shows last sync time',
        (tester) async {
          final lastSync = DateTime(2026, 8, 1, 10, 30);
          await pumpScreen(
            tester,
            notifier: _RecordingSyncNotifier(
              SyncStatus(
                config: savedConfig,
                lastSyncTime: lastSync,
              ),
            ),
          );

          final fields = tester
              .widgetList<TextFormField>(find.byType(TextFormField))
              .toList();
          expect(fields[0].controller!.text, '***'); // token 占位
          expect(fields[1].controller!.text, 'abc123');
          expect(fields[2].controller!.text, 'my_connections.json');
          expect(find.text('最后同步时间: $lastSync'), findsOneWidget);
        },
      );

      testWidgets(
        'Given autoSync enabled in config, When rendered, Then switch is on and interval shown',
        (tester) async {
          await pumpScreen(
            tester,
            notifier: _RecordingSyncNotifier(
              SyncStatus(config: savedConfig),
            ),
          );

          final switchTile = tester.widget<SwitchListTile>(
            find.byType(SwitchListTile),
          );
          expect(switchTile.value, isTrue);
          expect(find.text('10'), findsOneWidget);
        },
      );

      testWidgets(
        'Given syncing status, When rendered, Then upload/download buttons are disabled',
        (tester) async {
          tester.view.physicalSize = const Size(1200, 900);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });
          // 无限动画下不能用 pumpAndSettle
          await tester.pumpWidget(
            createTestWidget(
              notifier: _RecordingSyncNotifier(
                const SyncStatus(status: SyncStatusEnum.syncing),
              ),
            ),
          );
          await tester.pump();

          final uploadButton = tester.widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, '上传配置'),
          );
          final downloadButton = tester.widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, '下载配置'),
          );
          expect(uploadButton.onPressed, isNull);
          expect(downloadButton.onPressed, isNull);
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
        },
      );
    });

    group('token visibility', () {
      testWidgets(
        'Given token field, When visibility icon is tapped, Then obscures toggle',
        (tester) async {
          await pumpScreen(tester);

          expect(find.byIcon(Icons.visibility), findsOneWidget);
          await tester.tap(find.byIcon(Icons.visibility));
          await tester.pumpAndSettle();

          expect(find.byIcon(Icons.visibility_off), findsOneWidget);
        },
      );
    });

    group('save config', () {
      testWidgets(
        'Given empty form, When save is tapped, Then shows token validation error',
        (tester) async {
          await pumpScreen(tester);

          await tester.tap(find.text('保存配置'));
          await tester.pumpAndSettle();

          expect(find.text('请输入 Token'), findsOneWidget);
        },
      );

      testWidgets(
        'Given filled form, When save is tapped, Then saveConfig is called with new values',
        (tester) async {
          final notifier = _RecordingSyncNotifier(const SyncStatus());
          await pumpScreen(tester, notifier: notifier);

          await tester.enterText(
            find.byType(TextFormField).first,
            'ghp_newtoken',
          );
          await tester.tap(find.text('保存配置'));
          await tester.pumpAndSettle();

          expect(notifier.savedConfigs, hasLength(1));
          final saved = notifier.savedConfigs.first;
          expect(saved.accessToken, 'ghp_newtoken');
          expect(saved.gistFilename, AppConstants.defaultGistFilename);
          expect(saved.autoSync, isFalse);
          expect(find.text('配置已保存'), findsOneWidget);
        },
      );

      testWidgets(
        'Given config with token placeholder, When saved, Then keeps original token',
        (tester) async {
          final notifier = _RecordingSyncNotifier(
            SyncStatus(config: savedConfig),
          );
          await pumpScreen(tester, notifier: notifier);

          // token 字段是 '***' 占位符，直接保存
          await tester.tap(find.text('保存配置'));
          await tester.pumpAndSettle();

          expect(notifier.savedConfigs, hasLength(1));
          expect(notifier.savedConfigs.first.accessToken, 'ghp_testtoken');
        },
      );
    });

    group('sync actions', () {
      testWidgets(
        'Given no config, When test connection is tapped, Then shows hint snackbar',
        (tester) async {
          await pumpScreen(tester);

          await tester.ensureVisible(find.text('测试连接'));
          await tester.tap(find.text('测试连接'));
          await tester.pumpAndSettle();

          expect(find.text('请先配置并保存设置'), findsOneWidget);
        },
      );

      testWidgets(
        'Given saved config, When test connection is tapped, Then testConnection is called',
        (tester) async {
          final notifier = _RecordingSyncNotifier(
            SyncStatus(config: savedConfig),
          );
          await pumpScreen(tester, notifier: notifier);

          await tester.ensureVisible(find.text('测试连接'));
          await tester.tap(find.text('测试连接'));
          await tester.pumpAndSettle();

          expect(notifier.testConnectionCalls, 1);
          expect(find.text('连接测试成功'), findsOneWidget);
        },
      );

      testWidgets(
        'Given no config, When upload is tapped, Then shows hint snackbar',
        (tester) async {
          await pumpScreen(tester);

          await tester.ensureVisible(find.text('上传配置'));
          await tester.tap(find.text('上传配置'));
          await tester.pumpAndSettle();

          expect(find.text('请先配置同步设置'), findsOneWidget);
        },
      );

      testWidgets(
        'Given saved config, When upload is tapped, Then uploadConfig is called',
        (tester) async {
          final notifier = _RecordingSyncNotifier(
            SyncStatus(config: savedConfig),
          );
          await pumpScreen(tester, notifier: notifier);

          await tester.ensureVisible(find.text('上传配置'));
          await tester.tap(find.text('上传配置'));
          await tester.pumpAndSettle();

          expect(notifier.uploadCalls, 1);
          expect(find.text('配置已上传'), findsOneWidget);
        },
      );

      testWidgets(
        'Given upload fails, When upload is tapped, Then shows error dialog',
        (tester) async {
          final notifier = _RecordingSyncNotifier(
            SyncStatus(config: savedConfig),
          )..failOperations = true;
          await pumpScreen(tester, notifier: notifier);

          await tester.ensureVisible(find.text('上传配置'));
          await tester.tap(find.text('上传配置'));
          await tester.pumpAndSettle();

          expect(find.text('上传失败'), findsOneWidget);
          expect(find.textContaining('network error'), findsWidgets);
        },
      );

      testWidgets(
        'Given saved config, When download is tapped, Then downloadConfig is called',
        (tester) async {
          final notifier = _RecordingSyncNotifier(
            SyncStatus(config: savedConfig),
          );
          await pumpScreen(tester, notifier: notifier);

          await tester.ensureVisible(find.text('下载配置'));
          await tester.tap(find.text('下载配置'));
          await tester.pumpAndSettle();

          expect(notifier.downloadCalls, 1);
          expect(find.text('配置已下载'), findsOneWidget);
        },
      );

      testWidgets(
        'Given no config, When download is tapped, Then shows hint snackbar',
        (tester) async {
          await pumpScreen(tester);

          await tester.ensureVisible(find.text('下载配置'));
          await tester.tap(find.text('下载配置'));
          await tester.pumpAndSettle();

          expect(find.text('请先配置同步设置'), findsOneWidget);
        },
      );

      testWidgets(
        'Given download fails, When download is tapped, Then shows error dialog',
        (tester) async {
          final notifier = _RecordingSyncNotifier(
            SyncStatus(config: savedConfig),
          )..failOperations = true;
          await pumpScreen(tester, notifier: notifier);

          await tester.ensureVisible(find.text('下载配置'));
          await tester.tap(find.text('下载配置'));
          await tester.pumpAndSettle();

          expect(find.text('下载失败'), findsOneWidget);
          expect(find.textContaining('network error'), findsWidgets);
        },
      );

      testWidgets(
        'Given test connection fails, When test connection tapped, '
        'Then shows error dialog',
        (tester) async {
          final notifier = _RecordingSyncNotifier(
            SyncStatus(config: savedConfig),
          )..failOperations = true;
          await pumpScreen(tester, notifier: notifier);

          await tester.ensureVisible(find.text('测试连接'));
          await tester.tap(find.text('测试连接'));
          await tester.pumpAndSettle();

          expect(find.text('连接测试失败'), findsOneWidget);
          expect(find.textContaining('network error'), findsWidgets);
        },
      );
    });

    group('save failure', () {
      testWidgets(
        'Given save throws, When save is tapped, Then shows failure snackbar',
        (tester) async {
          final notifier = _RecordingSyncNotifier(
            SyncStatus(config: savedConfig),
          )..failSave = true;
          await pumpScreen(tester, notifier: notifier);

          await tester.tap(find.text('保存配置'));
          await tester.pumpAndSettle();

          expect(find.textContaining('保存失败'), findsOneWidget);
        },
      );
    });

    group('auto sync toggle', () {
      testWidgets(
        'Given autoSync off, When switch toggled, Then interval field appears',
        (tester) async {
          await pumpScreen(tester);

          final switchTile = find.byType(SwitchListTile);
          expect(tester.widget<SwitchListTile>(switchTile).value, isFalse);

          await tester.ensureVisible(switchTile);
          await tester.tap(switchTile);
          await tester.pumpAndSettle();

          expect(tester.widget<SwitchListTile>(switchTile).value, isTrue);
          expect(find.text('同步间隔（分钟）'), findsOneWidget);
        },
      );

      testWidgets(
        'Given autoSync on, When interval entered, '
        'Then saved config uses the interval',
        (tester) async {
          final notifier = _RecordingSyncNotifier(
            SyncStatus(config: savedConfig),
          );
          await pumpScreen(tester, notifier: notifier);

          // 输入间隔前先关闭自动同步再打开，确保间隔字段可见
          final switchTile = find.byType(SwitchListTile);
          await tester.ensureVisible(switchTile);
          await tester.tap(switchTile); // off -> 间隔字段消失
          await tester.pumpAndSettle();
          await tester.tap(switchTile); // on -> 间隔字段出现
          await tester.pumpAndSettle();

          await tester.enterText(
            find.widgetWithText(TextFormField, '同步间隔（分钟）'),
            '30',
          );
          await tester.tap(find.text('保存配置'));
          await tester.pumpAndSettle();

          expect(notifier.savedConfigs, hasLength(1));
          expect(notifier.savedConfigs.first.syncIntervalMinutes, 30);
        },
      );
    });

    group('create token', () {
      testWidgets(
        'Given create token button, When tapped, Then opens token creation URL',
        (tester) async {
          // Mock url_launcher 平台通道
          final launchedUrls = <String>[];
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/url_launcher'),
            (call) async {
              if (call.method == 'launch') {
                launchedUrls.add(
                  (call.arguments as Map<dynamic, dynamic>)['url'] as String,
                );
                return true;
              }
              if (call.method == 'canLaunch') {
                return true;
              }
              return null;
            },
          );
          addTearDown(() {
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/url_launcher'),
              null,
            );
          });

          await pumpScreen(tester);

          await tester.ensureVisible(find.text('创建 Token'));
          await tester.tap(find.text('创建 Token'));
          await tester.pumpAndSettle();

          expect(
            launchedUrls,
            contains(
              'https://github.com/settings/tokens/new?scopes=gist',
            ),
          );
        },
      );
    });
  });
}
