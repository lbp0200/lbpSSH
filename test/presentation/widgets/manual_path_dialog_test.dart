import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/presentation/widgets/manual_path_dialog.dart';

void main() {
  setUpAll(() async {
    // Defensive: silence any platform-channel calls (the dialog itself is
    // pure UI, but match the repo's widget-test convention).
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall methodCall,
        ) async {
          return null;
        });
  });

  /// Pumps a host app with a "Show" button that opens the dialog.
  Future<void> pumpHost(WidgetTester tester, String initialValue) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog<String>(
                context: context,
                builder: (_) => SizedBox(
                  width: 300,
                  child: ManualPathDialog(initialPath: initialValue),
                ),
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();
  }

  group('ManualPathDialog Widget', () {
    testWidgets(
      'Given a dialog with an initial value, When rendered, Then it shows the title and the path field prefilled',
      (WidgetTester tester) async {
        await pumpHost(tester, '/home/user');

        expect(find.text('输入私钥文件路径'), findsOneWidget);
        expect(find.byType(ManualPathDialog), findsOneWidget);
        // Field is prefilled with the initial value.
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.controller!.text, '/home/user');
        // Both action buttons present.
        expect(find.text('确定'), findsOneWidget);
        expect(find.text('取消'), findsOneWidget);
      },
    );

    testWidgets(
      'Given a non-empty path, When pressing 确定, Then the dialog is dismissed (popped)',
      (WidgetTester tester) async {
        await pumpHost(tester, '');

        // Type a value with surrounding whitespace (the dialog trims it).
        await tester.enterText(find.byType(TextField), '  /etc/ssh  ');
        await tester.tap(find.text('确定'));
        await tester.pumpAndSettle();

        // Non-empty (after trim) → pop was called → dialog gone.
        expect(find.byType(ManualPathDialog), findsNothing);
      },
    );

    testWidgets(
      'Given an empty path, When pressing 确定, Then the dialog stays open (no pop)',
      (WidgetTester tester) async {
        await pumpHost(tester, '');

        // Leave the field empty, press 确定.
        await tester.tap(find.text('确定'));
        await tester.pumpAndSettle();

        // Empty → early return, no pop → dialog still present.
        expect(find.byType(ManualPathDialog), findsOneWidget);
      },
    );

    testWidgets(
      'Given a whitespace-only path, When pressing 确定, Then the dialog stays open (trimmed to empty)',
      (WidgetTester tester) async {
        await pumpHost(tester, '');

        // Whitespace-only trims to '' → treated as empty → no pop.
        await tester.enterText(find.byType(TextField), '   ');
        await tester.tap(find.text('确定'));
        await tester.pumpAndSettle();

        expect(find.byType(ManualPathDialog), findsOneWidget);
      },
    );

    testWidgets(
      'Given a dialog open, When pressing 取消, Then the dialog is dismissed (popped)',
      (WidgetTester tester) async {
        await pumpHost(tester, '/tmp');

        // 取消 pops without a value.
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();

        expect(find.byType(ManualPathDialog), findsNothing);
      },
    );
  });
}
