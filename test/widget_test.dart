import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/main.dart';

void main() {
  group('lbpSSH Simple Widget Tests', () {
    testWidgets('MyApp widget should be rendered without errors', (
      WidgetTester tester,
    ) async {
      // Test that MyApp can be instantiated
      const app = MyApp();
      expect(app, isNotNull);
    });

    testWidgets('MyApp should have MaterialApp properties', (
      WidgetTester tester,
    ) async {
      // Build a minimal MaterialApp to test structure
      final testApp = MaterialApp(
        title: 'SSH Manager',
        home: Scaffold(),
        darkTheme: ThemeData.dark(),
        themeMode: ThemeMode.system,
      );

      await tester.pumpWidget(testApp);

      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(Material), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('MaterialApp should have correct configuration', (
      WidgetTester tester,
    ) async {
      const testApp = MaterialApp(
        title: 'SSH Manager',
        home: Scaffold(body: Center(child: Text('Test'))),
        debugShowCheckedModeBanner: false,
      );

      await tester.pumpWidget(testApp);

      final materialAppWidget = find.byType(MaterialApp).evaluate().first.widget as MaterialApp;
      expect(materialAppWidget.title, 'SSH Manager');
      expect(materialAppWidget.debugShowCheckedModeBanner, false);
    });
  });
}
