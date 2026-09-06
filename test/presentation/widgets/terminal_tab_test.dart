import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/domain/services/terminal_input_service.dart';
import 'package:lbp_ssh/domain/services/terminal_service.dart';
import 'package:lbp_ssh/presentation/widgets/terminal_tab.dart';

/// TerminalInputService 的轻量替身：TerminalSession 构造时持有它，但本测试只读取
/// session.name 与触发回调，不需要真实 I/O。空流 + 无操作即可避免任何真实行为。
class _MockInputService implements TerminalInputService {
  @override
  Stream<String> get outputStream => const Stream.empty();

  @override
  Stream<bool> get stateStream => const Stream.empty();

  @override
  Future<String> executeCommand(String command, {bool silent = false}) async =>
      '';

  @override
  void sendInput(String input) {}

  @override
  void resize(int rows, int columns) {}

  @override
  void dispose() {}
}

void main() {
  /// 构造一个仅用于 UI 展示的真实 session（name 可被读取/断言）。
  TerminalSession makeSession(String name) => TerminalSession(
    id: 'id_$name',
    name: name,
    inputService: _MockInputService(),
  );

  /// Pumps a host containing a single TerminalTab.
  Future<void> pumpTab(
    WidgetTester tester, {
    required String name,
    required bool isActive,
    VoidCallback? onTap,
    VoidCallback? onClose,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalTab(
            session: makeSession(name),
            isActive: isActive,
            onTap: onTap ?? () {},
            onClose: onClose ?? () {},
          ),
        ),
      ),
    );
  }

  group('TerminalTab Widget', () {
    testWidgets(
      'Given a tab for a session, When rendered, Then the session name is displayed',
      (WidgetTester tester) async {
        await pumpTab(tester, name: 'prod-server-01', isActive: false);

        expect(find.text('prod-server-01'), findsOneWidget);
      },
    );

    testWidgets(
      'Given an inactive tab, When tapping the tab body, Then onTap is invoked',
      (WidgetTester tester) async {
        bool tapped = false;
        await pumpTab(
          tester,
          name: 'tab-a',
          isActive: false,
          onTap: () => tapped = true,
        );

        await tester.tap(find.text('tab-a'));
        await tester.pump();

        expect(tapped, isTrue);
      },
    );

    testWidgets(
      'Given an active tab, When tapping the close icon, Then onClose is invoked',
      (WidgetTester tester) async {
        bool closed = false;
        // Active so the close icon is fully opaque/visible.
        await pumpTab(
          tester,
          name: 'tab-c',
          isActive: true,
          onClose: () => closed = true,
        );

        await tester.tap(find.byIcon(Icons.close));
        await tester.pump();

        expect(closed, isTrue);
      },
    );

    testWidgets(
      'Given two tabs (one active, one not), When rendered, Then both names are present',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  TerminalTab(
                    session: makeSession('active-one'),
                    isActive: true,
                    onTap: () {},
                    onClose: () {},
                  ),
                  TerminalTab(
                    session: makeSession('inactive-two'),
                    isActive: false,
                    onTap: () {},
                    onClose: () {},
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.text('active-one'), findsOneWidget);
        expect(find.text('inactive-two'), findsOneWidget);
      },
    );
  });
}
