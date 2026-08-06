import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lbp_ssh/data/models/ssh_config.dart';
import 'package:lbp_ssh/data/models/terminal_config.dart';
import 'package:lbp_ssh/presentation/providers/app_config_provider.dart';
import 'package:lbp_ssh/presentation/screens/terminal_settings_page.dart';

class _MockTerminalConfigNotifier extends TerminalConfigNotifier {
  @override
  TerminalConfig build() => TerminalConfig();
}

class _MockSshConfigNotifier extends SshConfigNotifier {
  @override
  SshConfig build() => SshConfig();
}

void main() {
  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        terminalConfigProvider.overrideWith(_MockTerminalConfigNotifier.new),
        sshConfigProvider.overrideWith(_MockSshConfigNotifier.new),
      ],
      child: const MaterialApp(
        home: Scaffold(body: TerminalSettingsPage()),
      ),
    );
  }

  group('TerminalSettingsPage Widget', () {
    testWidgets(
      'Given default config, When rendered, Then renders settings without exceptions',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // 修复回归：SwitchListTile 不再被 ColoredBox 遮 ink（debug 断言会在此抛出）
        expect(tester.takeException(), isNull);
        expect(find.byType(SwitchListTile), findsOneWidget);
        expect(find.text('启用 Kitty 协议'), findsOneWidget);
        expect(find.text('终端兼容性设置'), findsOneWidget);
      },
    );

    testWidgets(
      'Given rendered page, When Kitty protocol switch is toggled, Then value updates',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final switchFinder = find.byType(SwitchListTile);
        await tester.ensureVisible(switchFinder);
        await tester.pumpAndSettle();

        final switchListTile = tester.widget<SwitchListTile>(switchFinder);
        expect(switchListTile.value, isTrue); // 默认 enableKittyProtocol = true

        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        final updated = tester.widget<SwitchListTile>(
          find.byType(SwitchListTile),
        );
        expect(updated.value, isFalse);
      },
    );
  });
}
