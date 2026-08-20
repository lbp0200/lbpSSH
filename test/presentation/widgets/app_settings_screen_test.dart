import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lbp_ssh/data/models/ssh_config.dart';
import 'package:lbp_ssh/data/models/terminal_config.dart';
import 'package:lbp_ssh/presentation/providers/app_config_provider.dart';
import 'package:lbp_ssh/presentation/providers/connection_provider.dart';
import 'package:lbp_ssh/presentation/providers/import_export_provider.dart';
import 'package:lbp_ssh/presentation/providers/sync_provider.dart';
import 'package:lbp_ssh/presentation/screens/app_settings_screen.dart';
import 'package:lbp_ssh/presentation/screens/connection_management_page.dart';
import 'package:lbp_ssh/presentation/screens/import_export_settings.dart';
import 'package:lbp_ssh/presentation/screens/sync_settings.dart';
import 'package:lbp_ssh/presentation/screens/terminal_settings_page.dart';

class _MockConnectionNotifier extends ConnectionNotifier {
  final ConnectionState _state;
  _MockConnectionNotifier(this._state);

  @override
  ConnectionState build() => _state;
}

class _MockImportExportNotifier extends ImportExportNotifier {
  @override
  ImportExportStatusData build() => const ImportExportStatusData();

  @override
  Map<String, dynamic> getExportStats() => {
    'totalConnections': 0,
    'passwordAuth': 0,
    'keyAuth': 0,
    'jumpHostConnections': 0,
    'lastUpdated': null,
  };
}

class _MockTerminalConfigNotifier extends TerminalConfigNotifier {
  @override
  TerminalConfig build() => TerminalConfig();
}

class _MockSshConfigNotifier extends SshConfigNotifier {
  @override
  SshConfig build() => SshConfig();
}

class _MockSyncNotifier extends SyncNotifier {
  @override
  SyncStatus build() => const SyncStatus();
}

void main() {
  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        connectionProvider.overrideWith(
          () => _MockConnectionNotifier(const ConnectionState()),
        ),
        terminalConfigProvider.overrideWith(_MockTerminalConfigNotifier.new),
        sshConfigProvider.overrideWith(_MockSshConfigNotifier.new),
        importExportProvider.overrideWith(_MockImportExportNotifier.new),
        syncProvider.overrideWith(_MockSyncNotifier.new),
      ],
      child: const MaterialApp(home: AppSettingsScreen()),
    );
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();
  }

  group('AppSettingsScreen Widget', () {
    testWidgets(
      'Given settings screen, When rendered, Then shows terminal settings tab by default',
      (tester) async {
        await pumpScreen(tester);

        expect(find.text('终端设置'), findsWidgets); // nav 项 + AppBar 标题
        expect(find.byType(TerminalSettingsPage), findsOneWidget);
      },
    );

    testWidgets(
      'Given settings screen, When connection management tab is tapped, Then shows it',
      (tester) async {
        await pumpScreen(tester);

        await tester.tap(find.text('连接管理'));
        await tester.pumpAndSettle();

        expect(find.text('已保存的连接'), findsOneWidget);
        expect(find.byType(ConnectionManagementPage), findsOneWidget);
      },
    );

    testWidgets(
      'Given settings screen, When import export tab is tapped, Then shows it',
      (tester) async {
        await pumpScreen(tester);

        await tester.tap(find.text('导入导出'));
        await tester.pumpAndSettle();

        expect(find.text('当前SSH连接统计'), findsOneWidget);
        expect(find.byType(ImportExportSettingsScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Given settings screen, When sync tab is tapped, Then shows it',
      (tester) async {
        await pumpScreen(tester);

        await tester.tap(find.text('同步设置'));
        await tester.pumpAndSettle();

        expect(find.text('GitHub Token'), findsWidgets);
        expect(find.byType(SyncSettingsScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Given tab switched, When switching back to terminal settings, Then returns to it',
      (tester) async {
        await pumpScreen(tester);

        await tester.tap(find.text('同步设置'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('终端设置').first);
        await tester.pumpAndSettle();

        expect(find.text('终端兼容性设置'), findsOneWidget);
        expect(find.byType(TerminalSettingsPage), findsOneWidget);
      },
    );

    testWidgets(
      'Given settings screen, When nav item hovered and unhovered, '
      'Then hover state updates without error',
      (tester) async {
        await pumpScreen(tester);

        // 创建鼠标手势以触发 MouseRegion.onEnter/onExit
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        addTearDown(gesture.removePointer);

        // 触发 MouseRegion.onEnter
        final navItem = find.text('连接管理');
        await gesture.moveTo(tester.getCenter(navItem));
        await tester.pumpAndSettle();

        // 触发 MouseRegion.onExit（移动到其他导航项）
        final otherItem = find.text('终端设置').first;
        await gesture.moveTo(tester.getCenter(otherItem));
        await tester.pumpAndSettle();

        // 交互不应产生异常
        expect(tester.takeException(), isNull);
      },
    );
  });
}
