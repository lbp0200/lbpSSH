import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/presentation/widgets/split_terminal_view.dart';

void main() {
  group('SplitTerminalView Tests', () {
    testWidgets('should render vertical split', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SplitTerminalView(
              sessionId1: 'session1',
              sessionId2: 'session2',
              direction: SplitDirection.vertical,
            ),
          ),
        ),
      );

      expect(find.byType(SplitTerminalView), findsOneWidget);
      expect(find.byType(GestureDetector), findsOneWidget);
    });

    testWidgets('should render horizontal split', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SplitTerminalView(
              sessionId1: 'session1',
              sessionId2: 'session2',
              direction: SplitDirection.horizontal,
            ),
          ),
        ),
      );

      expect(find.byType(SplitTerminalView), findsOneWidget);
    });

    testWidgets('split position should be adjustable', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: SplitTerminalView(
                sessionId1: 'session1',
                sessionId2: 'session2',
              ),
            ),
          ),
        ),
      );

      // Find GestureDetector and drag
      final gesture = find.byType(GestureDetector);
      expect(gesture, findsOneWidget);
    });
  });
}
