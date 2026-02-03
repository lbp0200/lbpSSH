// Simple widget test for lbpSSH application
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lbp_ssh/main.dart';

void main() {
  group('lbpSSH Simple Widget Tests', () {
    testWidgets('MyApp widget should be rendered without errors', (
      WidgetTester tester,
    ) async {
      // Test that the MyApp widget can be built and rendered
      await tester.pumpWidget(const MyApp());

      // Verify that our app widget is rendered
      expect(find.byType(MyApp), findsOneWidget);

      // Verify that Material widget is rendered (basic Flutter app structure)
      expect(find.byType(Material), findsOneWidget);
    });

    testWidgets('MyApp should have MaterialApp structure', (
      WidgetTester tester,
    ) async {
      // Test basic MaterialApp structure
      await tester.pumpWidget(const MyApp());

      // Should contain MaterialApp (which contains Material)
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(Material), findsOneWidget);
    });
  });
}
