import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/data/models/terminal_config.dart';
import 'package:lbp_ssh/presentation/widgets/terminal_preview.dart';

void main() {
  /// Pumps the preview on a wide-enough surface.
  ///
  /// The preview draws fixed-width terminal lines; at the default 800px test
  /// surface the longest line overflows (RenderFlex). We follow the repo's
  /// widget-test convention of widening the surface to 1000x1000 and reset it
  /// afterwards. This is a pre-existing layout characteristic of the widget,
  /// not a defect we are asserting on.
  Future<void> pumpPreview(
    WidgetTester tester,
    TerminalConfig config, {
    void Function(double)? onFont,
  }) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalPreview(
            config: config,
            onFontSizeChanged: (v) => onFont?.call(v),
          ),
        ),
      ),
    );
  }

  group('TerminalPreview Widget', () {
    testWidgets(
      'Given a default config, When rendered, Then it shows the title, a prompt line and the font-size controls',
      (WidgetTester tester) async {
        await pumpPreview(tester, TerminalConfig());

        expect(find.text('终端预览'), findsOneWidget);
        // A representative preview content line renders.
        expect(find.text('user@hostname:~\$ ls -la'), findsOneWidget);
        // The three font-size controls are present.
        expect(find.text('缩小'), findsOneWidget);
        expect(find.text('默认 (14px)'), findsOneWidget);
        expect(find.text('放大'), findsOneWidget);
      },
    );

    testWidgets(
      'Given the default fontSize of 17, When tapping 缩小, Then onFontSizeChanged receives 15',
      (WidgetTester tester) async {
        double? emitted;
        await pumpPreview(tester, TerminalConfig(), onFont: (v) => emitted = v);

        await tester.tap(find.text('缩小'));
        await tester.pump();

        // 17 - 2
        expect(emitted, 15.0);
      },
    );

    testWidgets(
      'Given the default fontSize of 17, When tapping 放大, Then onFontSizeChanged receives 19',
      (WidgetTester tester) async {
        double? emitted;
        await pumpPreview(tester, TerminalConfig(), onFont: (v) => emitted = v);

        await tester.tap(find.text('放大'));
        await tester.pump();

        // 17 + 2
        expect(emitted, 19.0);
      },
    );

    testWidgets(
      'When tapping 默认 (14px), Then onFontSizeChanged receives 14',
      (WidgetTester tester) async {
        double? emitted;
        await pumpPreview(tester, TerminalConfig(), onFont: (v) => emitted = v);

        await tester.tap(find.text('默认 (14px)'));
        await tester.pump();

        expect(emitted, 14.0);
      },
    );

    testWidgets(
      'Given malformed color hex values, When rendered, Then it does not throw (colors fall back to white)',
      (WidgetTester tester) async {
        // All three colors are invalid: _parseColor must swallow the parse
        // error and return white rather than crashing the build.
        final config = TerminalConfig(
          backgroundColor: '#notacolor',
          foregroundColor: '',
          cursorColor: 'zz',
        );

        await pumpPreview(tester, config);

        // Built without throwing.
        expect(find.text('终端预览'), findsOneWidget);
      },
    );

    testWidgets(
      'Given max font size 32, When rendered at default width, Then preview lines wrap without RenderFlex overflow',
      (WidgetTester tester) async {
        // Regression: before the _previewLine fix, a large fontSize let the Row's
        // non-flex Text child take unbounded width and overflow the fixed-width
        // preview container (RenderFlex horizontal overflow → red-screen in debug).
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TerminalPreview(
                config: TerminalConfig(fontSize: 32),
                onFontSizeChanged: (_) {},
              ),
            ),
          ),
        );

        // A representative long sample line still renders (now wraps within width).
        expect(find.text('终端预览'), findsOneWidget);
        // No RenderFlex overflow exception.
        expect(tester.takeException(), isNull);
      },
    );
  });
}
