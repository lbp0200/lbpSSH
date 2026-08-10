import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lbp_ssh/data/models/ssh_config.dart';
import 'package:lbp_ssh/data/models/terminal_config.dart';
import 'package:lbp_ssh/presentation/providers/app_config_provider.dart';
import 'package:lbp_ssh/presentation/screens/terminal_settings_page.dart';

class _MockTerminalConfigNotifier extends TerminalConfigNotifier {
  TerminalConfig? lastSaved;
  bool throwOnSave = false;

  @override
  TerminalConfig build() => TerminalConfig();

  @override
  Future<void> updateConfig(TerminalConfig config) async {
    if (throwOnSave) throw Exception('模拟保存失败');
    lastSaved = config;
    state = config;
  }
}

class _MockSshConfigNotifier extends SshConfigNotifier {
  SshConfig? lastSaved;
  bool throwOnSave = false;

  @override
  SshConfig build() => SshConfig();

  @override
  Future<void> updateConfig(SshConfig config) async {
    if (throwOnSave) throw Exception('模拟保存失败');
    lastSaved = config;
    state = config;
  }
}

void main() {
  late _MockTerminalConfigNotifier mockTerminalNotifier;
  late _MockSshConfigNotifier mockSshNotifier;

  Widget createTestWidget({
    bool terminalSaveFails = false,
    bool sshSaveFails = false,
  }) {
    mockTerminalNotifier = _MockTerminalConfigNotifier()
      ..throwOnSave = terminalSaveFails;
    mockSshNotifier = _MockSshConfigNotifier()..throwOnSave = sshSaveFails;
    return ProviderScope(
      overrides: [
        terminalConfigProvider.overrideWith(() => mockTerminalNotifier),
        sshConfigProvider.overrideWith(() => mockSshNotifier),
      ],
      child: const MaterialApp(
        home: Scaffold(body: TerminalSettingsPage()),
      ),
    );
  }

  /// 页面内容较长，使用高视口让 SingleChildScrollView 全部渲染
  Future<void> pumpPage(
    WidgetTester tester, {
    bool terminalSaveFails = false,
    bool sshSaveFails = false,
  }) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      createTestWidget(
        terminalSaveFails: terminalSaveFails,
        sshSaveFails: sshSaveFails,
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 按 label 文本定位并输入内容
  Future<void> enterField(WidgetTester tester, String label, String value) async {
    final finder = find.ancestor(
      of: find.text(label),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(finder, value);
    await tester.pump();
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

    testWidgets(
      'Given default font size, When 放大 tapped, Then font size increases',
      (tester) async {
        await pumpPage(tester);

        await tester.tap(find.text('放大'));
        await tester.pumpAndSettle();

        expect(
          tester.widget<Slider>(find.byType(Slider)).value,
          19.0,
        );
        expect(find.text('19px'), findsOneWidget);
      },
    );

    testWidgets(
      'Given font size increased, When 缩小 tapped, Then font size decreases',
      (tester) async {
        await pumpPage(tester);

        await tester.tap(find.text('放大'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('缩小'));
        await tester.pumpAndSettle();

        expect(
          tester.widget<Slider>(find.byType(Slider)).value,
          17.0,
        );
        expect(find.text('17px'), findsOneWidget);
      },
    );

    testWidgets(
      'Given font size changed, When 默认 button tapped, Then resets to 14px',
      (tester) async {
        await pumpPage(tester);

        await tester.tap(find.text('放大'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('默认 (14px)'));
        await tester.pumpAndSettle();

        expect(
          tester.widget<Slider>(find.byType(Slider)).value,
          14.0,
        );
      },
    );

    testWidgets(
      'Given preset chip, When 18px tapped, Then font size becomes 18',
      (tester) async {
        await pumpPage(tester);

        await tester.tap(find.text('18px'));
        await tester.pumpAndSettle();

        expect(
          tester.widget<Slider>(find.byType(Slider)).value,
          18.0,
        );
        expect(find.text('18px'), findsNWidgets(2)); // 显示 + 预设 chip
      },
    );

    testWidgets(
      'Given weight field, When 700 entered, Then preview uses w700',
      (tester) async {
        await pumpPage(tester);

        await enterField(tester, '字重', '700');

        final fox = tester.widget<Text>(
          find.text('The quick brown fox jumps over the lazy dog.'),
        );
        expect(fox.style?.fontWeight, FontWeight.w700);
      },
    );

    testWidgets(
      'Given weight field, When out-of-range 50 entered, Then weight unchanged',
      (tester) async {
        await pumpPage(tester);

        await enterField(tester, '字重', '50');

        final fox = tester.widget<Text>(
          find.text('The quick brown fox jumps over the lazy dog.'),
        );
        expect(fox.style?.fontWeight, FontWeight.w400);
      },
    );

    testWidgets(
      'Given letterSpacing field, When 0.5 entered, Then preview spacing updates',
      (tester) async {
        await pumpPage(tester);

        await enterField(tester, '字母间距', '0.5');

        final line = tester.widget<Text>(
          find.text(r'user@hostname:~$').first,
        );
        expect(line.style?.letterSpacing, 0.5);
      },
    );

    testWidgets(
      'Given lineHeight field, When 1.5 entered, Then preview height updates',
      (tester) async {
        await pumpPage(tester);

        await enterField(tester, '行高', '1.5');

        final line = tester.widget<Text>(
          find.text(r'user@hostname:~$').first,
        );
        expect(line.style?.height, 1.5);
      },
    );

    testWidgets(
      'Given bg color field, When color entered, Then preview bg updates',
      (tester) async {
        await pumpPage(tester);

        await enterField(tester, '背景颜色', '#112233');

        final colored = find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).color == const Color(0xFF112233),
        );
        expect(colored, findsOneWidget);
      },
    );

    testWidgets(
      'Given fg color field, When color entered, Then preview fg updates',
      (tester) async {
        await pumpPage(tester);

        await enterField(tester, '前景颜色', '#ABCDEF');

        final line = tester.widget<Text>(
          find.text(r'user@hostname:~$').first,
        );
        expect(line.style?.color, const Color(0xFFABCDEF));
      },
    );

    testWidgets(
      'Given cursor color field, When color entered, Then cursor block updates',
      (tester) async {
        await pumpPage(tester);

        await enterField(tester, '光标颜色', '#00FF00');

        final cursor = find.byWidgetPredicate(
          (w) => w is Container && w.color == const Color(0xFF00FF00),
        );
        expect(cursor, findsOneWidget);
      },
    );

    testWidgets(
      'Given font size changed, When 重置 tapped, Then reverts to default',
      (tester) async {
        await pumpPage(tester);

        await tester.tap(find.text('放大'));
        await tester.pumpAndSettle();
        expect(find.text('19px'), findsOneWidget);

        await tester.tap(find.text('重置').first);
        await tester.pumpAndSettle();

        expect(find.text('17px'), findsOneWidget);
        expect(
          tester.widget<Slider>(find.byType(Slider)).value,
          17.0,
        );
      },
    );

    testWidgets(
      'Given modified config, When 保存显示设置 tapped, '
      'Then config saved and snackbar shown',
      (tester) async {
        await pumpPage(tester);

        await tester.tap(find.text('放大'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('保存显示设置'));
        await tester.pumpAndSettle();

        expect(find.text('设置已保存'), findsOneWidget);
        expect(mockTerminalNotifier.lastSaved?.fontSize, 19.0);

        // 等待 SnackBar 自动关闭，避免残留 Timer
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Given save fails, When 保存显示设置 tapped, Then shows failure snackbar',
      (tester) async {
        await pumpPage(tester, terminalSaveFails: true);

        await tester.tap(find.text('保存显示设置'));
        await tester.pumpAndSettle();

        expect(find.textContaining('保存失败'), findsOneWidget);

        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Given keepalive changed, When 保存 SSH 设置 tapped, '
      'Then ssh config saved and snackbar shown',
      (tester) async {
        await pumpPage(tester);

        await enterField(tester, 'Keepalive 间隔', '60');

        await tester.tap(find.text('保存 SSH 设置'));
        await tester.pumpAndSettle();

        expect(find.text('SSH 设置已保存'), findsOneWidget);
        expect(mockSshNotifier.lastSaved?.keepaliveInterval, 60000);

        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Given keepalive zero entered, When saved, Then keepalive unchanged',
      (tester) async {
        await pumpPage(tester);

        await enterField(tester, 'Keepalive 间隔', '0');

        await tester.tap(find.text('保存 SSH 设置'));
        await tester.pumpAndSettle();

        expect(mockSshNotifier.lastSaved?.keepaliveInterval, 30000);

        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Given ssh save fails, When 保存 SSH 设置 tapped, Then failure snackbar',
      (tester) async {
        await pumpPage(tester, sshSaveFails: true);

        await tester.tap(find.text('保存 SSH 设置'));
        await tester.pumpAndSettle();

        expect(find.textContaining('保存失败'), findsOneWidget);

        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Given shell dropdown, When bash selected, Then shellPath saved',
      (tester) async {
        await pumpPage(tester);

        // 第二个 String 下拉框是 Shell（第一个是字体家族）
        await tester.tap(find.byType(DropdownButtonFormField<String>).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('bash (/bin/bash)').last);
        await tester.pumpAndSettle();

        await tester.tap(find.text('保存显示设置'));
        await tester.pumpAndSettle();

        expect(mockTerminalNotifier.lastSaved?.shellPath, '/bin/bash');

        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Given custom shell path, When entered, Then shellPath saved',
      (tester) async {
        await pumpPage(tester);

        await enterField(tester, '自定义 Shell 路径', '/usr/bin/zsh');

        await tester.tap(find.text('保存显示设置'));
        await tester.pumpAndSettle();

        expect(mockTerminalNotifier.lastSaved?.shellPath, '/usr/bin/zsh');

        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Given font dropdown, When Fira Code selected, Then preview fontFamily updates',
      (tester) async {
        await pumpPage(tester);

        await tester.tap(find.byType(DropdownButtonFormField<String>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Fira Code').last);
        await tester.pumpAndSettle();

        final fox = tester.widget<Text>(
          find.text('The quick brown fox jumps over the lazy dog.'),
        );
        expect(fox.style?.fontFamily, 'Fira Code');
      },
    );

    testWidgets(
      'Given custom font name, When entered, Then preview fontFamily updates',
      (tester) async {
        await pumpPage(tester);

        final customFontField = find.ancestor(
          of: find.text('输入自定义字体名称'),
          matching: find.byType(TextFormField),
        );
        await tester.enterText(customFontField, 'MyFont');
        await tester.pump();

        final fox = tester.widget<Text>(
          find.text('The quick brown fox jumps over the lazy dog.'),
        );
        expect(fox.style?.fontFamily, 'MyFont');
      },
    );
  });
}
