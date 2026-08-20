import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lbp_ssh/data/models/ssh_config.dart';
import 'package:lbp_ssh/data/models/terminal_config.dart';
import 'package:lbp_ssh/presentation/providers/app_config_provider.dart';
import 'package:lbp_ssh/presentation/providers/connection_provider.dart';
import 'package:lbp_ssh/presentation/providers/import_export_provider.dart';
import 'package:lbp_ssh/presentation/providers/sync_provider.dart';
import 'package:lbp_ssh/presentation/screens/app_settings_screen.dart';
import 'package:lbp_ssh/presentation/widgets/collapsible_sidebar.dart';

class _MockConnectionNotifier extends ConnectionNotifier {
  final ConnectionState _state;
  _MockConnectionNotifier(this._state);

  @override
  ConnectionState build() => _state;
}

class _RecordingConnectionNotifier extends ConnectionNotifier {
  final ConnectionState _state;
  final List<String> searchQueries = [];
  int clearSearchCalls = 0;

  _RecordingConnectionNotifier(this._state);

  @override
  ConnectionState build() => _state;

  @override
  void setSearchQuery(String query) {
    searchQueries.add(query);
  }

  @override
  void clearSearch() {
    clearSearchCalls++;
  }
}

class _MockTerminalConfigNotifier extends TerminalConfigNotifier {
  @override
  TerminalConfig build() => TerminalConfig();
}

class _MockSshConfigNotifier extends SshConfigNotifier {
  @override
  SshConfig build() => SshConfig();
}

class _MockSyncNotifier extends SyncNotifier {
  @override
  SyncStatus build() => const SyncStatus();
}

void main() {
  Widget createTestWidget({ConnectionNotifier? notifier}) {
    return ProviderScope(
      overrides: [
        connectionProvider.overrideWith(
          () => notifier ?? _MockConnectionNotifier(const ConnectionState()),
        ),
        terminalConfigProvider.overrideWith(
          _MockTerminalConfigNotifier.new,
        ),
        sshConfigProvider.overrideWith(_MockSshConfigNotifier.new),
        importExportProvider.overrideWith(ImportExportNotifier.new),
        syncProvider.overrideWith(_MockSyncNotifier.new),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: CollapsibleSidebar(),
        ),
      ),
    );
  }

  Future<void> pumpSidebar(
    WidgetTester tester, {
    ConnectionNotifier? notifier,
  }) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(createTestWidget(notifier: notifier));
    await tester.pumpAndSettle();
  }

  group('CollapsibleSidebar Widget', () {
    group('expanded state', () {
      testWidgets(
        'Given sidebar is expanded, When rendered, Then shows search and settings buttons',
        (tester) async {
          await pumpSidebar(tester);

          expect(find.byTooltip('搜索'), findsOneWidget);
          expect(find.byTooltip('设置'), findsOneWidget);
          expect(find.byTooltip('折叠'), findsOneWidget);
          expect(find.byTooltip('展开'), findsNothing);
          expect(find.byType(TextField), findsNothing);
        },
      );

      testWidgets(
        'Given sidebar is expanded, When rendered, Then sidebar width is 280',
        (tester) async {
          await pumpSidebar(tester);

          final width = tester.getSize(find.byType(CollapsibleSidebar)).width;
          expect(width, 280);
        },
      );
    });

    group('collapse/expand interaction', () {
      testWidgets(
        'Given expanded sidebar, When collapse button is tapped, Then enters compact mode',
        (tester) async {
          await pumpSidebar(tester);

          await tester.tap(find.byTooltip('折叠'));
          await tester.pumpAndSettle();

          expect(find.byTooltip('展开'), findsOneWidget);
          expect(find.byTooltip('折叠'), findsNothing);
          expect(find.byTooltip('搜索'), findsOneWidget);
          expect(find.byTooltip('设置'), findsOneWidget);
          final width = tester.getSize(find.byType(CollapsibleSidebar)).width;
          expect(width, 60);
        },
      );

      testWidgets(
        'Given compact sidebar, When expand button is tapped, Then returns to expanded mode',
        (tester) async {
          await pumpSidebar(tester);

          await tester.tap(find.byTooltip('折叠'));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('展开'));
          await tester.pumpAndSettle();

          expect(find.byTooltip('折叠'), findsOneWidget);
          final width = tester.getSize(find.byType(CollapsibleSidebar)).width;
          expect(width, 280);
        },
      );
    });

    group('search interaction', () {
      testWidgets(
        'Given expanded sidebar, When search button is tapped, Then shows search field',
        (tester) async {
          await pumpSidebar(tester);

          await tester.tap(find.byTooltip('搜索'));
          await tester.pumpAndSettle();

          expect(find.byType(TextField), findsOneWidget);
          expect(find.text('搜索连接...'), findsOneWidget);
        },
      );

      testWidgets(
        'Given search field is open, When text is entered, Then setSearchQuery is called',
        (tester) async {
          final notifier = _RecordingConnectionNotifier(
            const ConnectionState(),
          );
          await pumpSidebar(tester, notifier: notifier);

          await tester.tap(find.byTooltip('搜索'));
          await tester.pumpAndSettle();

          await tester.enterText(find.byType(TextField), 'prod');
          await tester.pumpAndSettle();

          expect(notifier.searchQueries, ['prod']);
        },
      );

      testWidgets(
        'Given search field is open, When close button is tapped, Then search is cleared and field hides',
        (tester) async {
          final notifier = _RecordingConnectionNotifier(
            const ConnectionState(),
          );
          await pumpSidebar(tester, notifier: notifier);

          await tester.tap(find.byTooltip('搜索'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), 'prod');

          await tester.tap(find.byIcon(Icons.close));
          await tester.pumpAndSettle();

          expect(notifier.clearSearchCalls, 1);
          expect(find.byType(TextField), findsNothing);
        },
      );

      testWidgets(
        'Given compact sidebar, When search button is tapped, Then expands and shows search field',
        (tester) async {
          await pumpSidebar(tester);

          await tester.tap(find.byTooltip('折叠'));
          await tester.pumpAndSettle();

          await tester.tap(find.byTooltip('搜索'));
          await tester.pumpAndSettle();

          expect(find.byType(TextField), findsOneWidget);
          final width = tester.getSize(find.byType(CollapsibleSidebar)).width;
          expect(width, 280);
        },
      );
    });

    group('settings navigation', () {
      testWidgets(
        'Given sidebar, When settings button is tapped, Then navigates to AppSettingsScreen',
        (tester) async {
          await pumpSidebar(tester);

          await tester.tap(find.byTooltip('设置'));
          await tester.pumpAndSettle();

          expect(find.byType(AppSettingsScreen), findsOneWidget);
          expect(find.text('终端设置'), findsWidgets);
        },
      );
    });
  });
}
