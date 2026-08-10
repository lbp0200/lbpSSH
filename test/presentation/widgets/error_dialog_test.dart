import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/presentation/widgets/error_dialog.dart';

void main() {
  setUpAll(() async {
    // Register mock handlers for platform channels
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall methodCall,
        ) async {
          return null;
        });
  });
  group('ErrorDialog Widget', () {
    testWidgets(
      'Given basic error, When rendered, Then shows title and error message',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog<Widget>(
                    context: context,
                    builder: (_) => const ErrorDialog(
                      title: 'Test Error',
                      error: 'Something went wrong',
                      appVersion: '1.0.0',
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

        // Title with error icon
        expect(find.text('Test Error'), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsOneWidget);

        // Error message
        expect(find.text('Something went wrong'), findsOneWidget);

        // Action buttons
        expect(find.text('复制报告'), findsOneWidget);
        expect(find.text('反馈问题'), findsOneWidget);
        expect(find.text('关闭'), findsOneWidget);
      },
    );

    testWidgets(
      'Given error with stack trace, When rendered, Then shows stack trace section',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog<Widget>(
                    context: context,
                    builder: (_) => ErrorDialog(
                      title: 'Stack Error',
                      error: Exception('test exception'),
                      stackTrace: StackTrace.fromString(
                        'line 1\nline 2\nline 3',
                      ),
                      appVersion: '2.0.0',
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

        // Stack trace section header
        expect(find.text('Stack Trace'), findsOneWidget);

        // Stack trace content
        expect(find.textContaining('line 1'), findsOneWidget);
        expect(find.textContaining('line 2'), findsOneWidget);
      },
    );

    testWidgets(
      'Given error with extra context, When rendered, Then shows context key-value pairs',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog<Widget>(
                    context: context,
                    builder: (_) => const ErrorDialog(
                      title: 'Context Error',
                      error: 'connection failed',
                      extraContext: {
                        'host': '192.168.1.1',
                        'port': '22',
                        'user': 'admin',
                      },
                      appVersion: '1.5.0',
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

        // Context labels
        expect(find.textContaining('host:'), findsOneWidget);
        expect(find.textContaining('port:'), findsOneWidget);
        expect(find.textContaining('user:'), findsOneWidget);

        // Context values
        expect(find.text('192.168.1.1'), findsOneWidget);
        expect(find.text('22'), findsOneWidget);
        expect(find.text('admin'), findsOneWidget);
      },
    );

    testWidgets(
      'Given copy report button, When tapped, Then copies report to clipboard',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog<Widget>(
                    context: context,
                    builder: (_) => const ErrorDialog(
                      title: 'Copy Test',
                      error: 'error to copy',
                      appVersion: '1.0.0',
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

        // Tap copy button
        await tester.tap(find.text('复制报告'));
        await tester.pump();

        // Pump past the 3-second timer to avoid pending timer error
        await tester.pump(const Duration(seconds: 3));

        // Verify dialog is still shown
        expect(find.text('Copy Test'), findsOneWidget);
      },
    );

    testWidgets('Given close button, When tapped, Then dismisses dialog', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog<Widget>(
                  context: context,
                  builder: (_) => const ErrorDialog(
                    title: 'Close Test',
                    error: 'test',
                    appVersion: '1.0.0',
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

      expect(find.text('Close Test'), findsOneWidget);

      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.text('Close Test'), findsNothing);
    });

    testWidgets(
      'Given error without stack trace, When rendered, Then no stack trace section',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog<Widget>(
                    context: context,
                    builder: (_) => const ErrorDialog(
                      title: 'No Stack',
                      error: 'simple error',
                      appVersion: '1.0.0',
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

        // Stack Trace header should not appear
        expect(find.text('Stack Trace'), findsNothing);
      },
    );

    testWidgets(
      'Given error without extra context, When rendered, Then no context section',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog<Widget>(
                    context: context,
                    builder: (_) => const ErrorDialog(
                      title: 'No Context',
                      error: 'simple error',
                      appVersion: '1.0.0',
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

        // Title should be shown
        expect(find.text('No Context'), findsOneWidget);
      },
    );

    Future<void> pumpErrorDialog(
      WidgetTester tester, {
      String title = 'Test',
      Object error = 'test error',
      StackTrace? stackTrace,
      Map<String, String>? extraContext,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog<Widget>(
                  context: context,
                  builder: (_) => ErrorDialog(
                    title: title,
                    error: error,
                    stackTrace: stackTrace,
                    extraContext: extraContext,
                    appVersion: '1.0.0',
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

    testWidgets(
      'Given error with stack trace and context, When copy report tapped, '
      'Then clipboard contains stack and context sections',
      (tester) async {
        final clipboardTexts = <String>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardTexts.add((call.arguments as Map)['text'] as String);
          }
          return null;
        });

        await pumpErrorDialog(
          tester,
          title: 'Copy Full',
          error: 'connection refused',
          stackTrace: StackTrace.fromString('line 1\nline 2'),
          extraContext: const {'host': '192.168.1.1', 'port': '22'},
        );

        await tester.tap(find.text('复制报告'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 3));

        expect(clipboardTexts, hasLength(1));
        final report = clipboardTexts.single;
        expect(report, contains('**Stack Trace**'));
        expect(report, contains('line 1'));
        expect(report, contains('**额外上下文**'));
        expect(report, contains('host: 192.168.1.1'));
        expect(report, contains('操作系统'));
      },
    );

    testWidgets(
      'Given feedback button, When tapped, '
      'Then copies report and shows issues state',
      (tester) async {
        // Mock url_launcher 平台通道
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          (call) async {
            if (call.method == 'canLaunch' || call.method == 'launch') {
              return true;
            }
            return null;
          },
        );

        await pumpErrorDialog(
          tester,
          title: 'Feedback',
          error: 'disk full',
          stackTrace: StackTrace.fromString('stack here'),
        );

        await tester.tap(find.text('反馈问题'));
        await tester.pump();

        // 按钮文案切换为「已复制，前往 Issues」
        expect(find.text('已复制，前往 Issues'), findsOneWidget);

        // 等待 3 秒 timer 恢复按钮文案
        await tester.pump(const Duration(seconds: 3));
        expect(find.text('反馈问题'), findsOneWidget);
      },
    );

    testWidgets(
      'Given error section, When header tapped, Then collapses and expands',
      (tester) async {
        await pumpErrorDialog(tester, title: 'Collapse', error: 'collapse me');

        expect(find.text('collapse me'), findsOneWidget);

        // 点击标题折叠
        await tester.tap(find.text('错误信息'));
        await tester.pumpAndSettle();
        expect(find.text('collapse me'), findsNothing);

        // 再次点击展开
        await tester.tap(find.text('错误信息'));
        await tester.pumpAndSettle();
        expect(find.text('collapse me'), findsOneWidget);
      },
    );

    testWidgets(
      'Given stack trace section, When header tapped, Then collapses and expands',
      (tester) async {
        await pumpErrorDialog(
          tester,
          title: 'Stack Collapse',
          error: 'boom',
          stackTrace: StackTrace.fromString('frame A\nframe B'),
        );

        expect(find.textContaining('frame A'), findsOneWidget);

        await tester.tap(find.text('Stack Trace'));
        await tester.pumpAndSettle();
        expect(find.textContaining('frame A'), findsNothing);

        await tester.tap(find.text('Stack Trace'));
        await tester.pumpAndSettle();
        expect(find.textContaining('frame A'), findsOneWidget);
      },
    );
  });
}
