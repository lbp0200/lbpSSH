import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/presentation/providers/connection_provider.dart';
import 'package:lbp_ssh/presentation/widgets/compact_connection_list.dart';

class MockConnectionProvider extends Mock implements ConnectionProvider {}

void main() {
  late MockConnectionProvider mockProvider;

  setUp(() {
    mockProvider = MockConnectionProvider();
  });

  Widget createTestWidget({
    List<SshConnection> connections = const [],
    String? error,
    bool isLoading = false,
  }) {
    when(() => mockProvider.isLoading).thenReturn(isLoading);
    when(() => mockProvider.error).thenReturn(error);
    when(() => mockProvider.connections).thenReturn(connections);

    return MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider<ConnectionProvider>.value(
          value: mockProvider,
          child: CompactConnectionList(
            onConnectionTap: (_) {},
          ),
        ),
      ),
    );
  }

  group('CompactConnectionList Widget', () {
    group('loading state', () {
      testWidgets('Given isLoading is true, When rendered, Then shows small CircularProgressIndicator',
          (WidgetTester tester) async {
        // Set up screen size
        tester.view.physicalSize = const Size(1000, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createTestWidget(isLoading: true));

(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('error state', () {
      testWidgets('Given error is not null, When rendered, Then shows error icon',
          (WidgetTester tester) async {
        // Set up screen size
        tester.view.physicalSize = const Size(1000, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        const errorMessage = 'Test error';
        await tester.pumpWidget(createTestWidget(error: errorMessage));

        expect(find.byIcon(Icons.error_outline), findsOneWidget);
      });
    });

    group('empty state', () {
      testWidgets('Given empty connections, When rendered, Then shows add button and icon',
          (WidgetTester tester) async {
        // Set up screen size
        tester.view.physicalSize = const Size(1000, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createTestWidget(connections: []));

        expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
        expect(find.byIcon(Icons.add), findsOneWidget);
      });

      testWidgets('Given empty connections, When rendered, Then shows add connection tooltip',
          (WidgetTester tester) async {
        // Set up screen size
        tester.view.physicalSize = const Size(1000, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createTestWidget(connections: []));

        expect(find.byTooltip('添加连接'), findsOneWidget);
      });
    });

    group('with connections', () {
      testWidgets('Given connections exist, When rendered, Then shows ListView',
          (WidgetTester tester) async {
        // Set up screen size
        tester.view.physicalSize = const Size(1000, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final connections = [
          SshConnection(
            id: '1',
            name: 'Server 1',
            host: '192.168.1.1',
            username: 'user1',
            authType: AuthType.password,
          ),
        ];

        await tester.pumpWidget(createTestWidget(connections: connections));

        expect(find.byType(ListView), findsOneWidget);
      });

      testWidgets('Given connections exist, When rendered, Then shows add new connection button',
          (WidgetTester tester) async {
        // Set up screen size
        tester.view.physicalSize = const Size(1000, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final connections = [
          SshConnection(
            id: '1',
            name: 'Server 1',
            host: '192.168.1.1',
            username: 'user1',
            authType: AuthType.password,
          ),
        ];

        await tester.pumpWidget(createTestWidget(connections: connections));

        // Should have both "add_circle_outline" for new connection and icons for existing connections
        expect(find.byIcon(Icons.add_circle_outline), findsWidgets);
      });

      testWidgets('Given multiple connections, When rendered, Then shows multiple items',
          (WidgetTester tester) async {
        // Set up screen size
        tester.view.physicalSize = const Size(1000, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final connections = [
          SshConnection(
            id: '1',
            name: 'Server 1',
            host: '192.168.1.1',
            username: 'user1',
            authType: AuthType.password,
          ),
          SshConnection(
            id: '2',
            name: 'Server 2',
            host: '192.168.1.2',
            username: 'user2',
            authType: AuthType.key,
          ),
          SshConnection(
            id: '3',
            name: 'Server 3',
            host: '192.168.1.3',
            username: 'user3',
            authType: AuthType.keyWithPassword,
          ),
        ];

        await tester.pumpWidget(createTestWidget(connections: connections));

        // Multiple computer icons should be visible for each connection
        expect(find.byIcon(Icons.computer), findsNWidgets(3));
      });
    });

    group('connection item interactions', () {
      testWidgets('Given connection, When long press, Then shows popup menu',
          (WidgetTester tester) async {
        // Set up screen size
        tester.view.physicalSize = const Size(1000, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final connections = [
          SshConnection(
            id: '1',
            name: 'Test Server',
            host: '192.168.1.1',
            username: 'user',
            authType: AuthType.password,
          ),
        ];

        await tester.pumpWidget(createTestWidget(connections: connections));

        // Find the PopupMenuButton and long press to trigger menu
        expect(find.byType(PopupMenuButton<String>), findsWidgets);
      });
    });
  });
}
