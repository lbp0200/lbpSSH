import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/data/repositories/connection_repository.dart';
import 'package:lbp_ssh/domain/services/app_config_service.dart';
import 'package:lbp_ssh/domain/services/import_export_service.dart';
import 'package:lbp_ssh/domain/services/sync_service.dart';
import 'package:lbp_ssh/domain/services/terminal_service.dart';
import 'package:lbp_ssh/presentation/providers/service_providers.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  group('service providers', () {
    test(
      'Given container, When reading connectionRepositoryProvider, Then returns a ConnectionRepository',
      () {
        final repo = container.read(connectionRepositoryProvider);

        expect(repo, isA<ConnectionRepository>());
      },
    );

    test(
      'Given container, When reading terminalServiceProvider, Then returns a TerminalService',
      () {
        final service = container.read(terminalServiceProvider);

        expect(service, isA<TerminalService>());
      },
    );

    test(
      'Given container, When reading appConfigServiceProvider, Then returns an AppConfigService singleton',
      () {
        final service1 = container.read(appConfigServiceProvider);
        final service2 = container.read(appConfigServiceProvider);

        expect(service1, isA<AppConfigService>());
        expect(service1, same(service2));
      },
    );

    test(
      'Given container, When reading syncServiceProvider, Then returns a SyncService',
      () {
        final service = container.read(syncServiceProvider);

        expect(service, isA<SyncService>());
      },
    );

    test(
      'Given container, When reading importExportServiceProvider, Then returns an ImportExportService',
      () {
        final service = container.read(importExportServiceProvider);

        expect(service, isA<ImportExportService>());
      },
    );

    test(
      'Given container, When reading service providers repeatedly, Then returns the same instances (cached)',
      () {
        final repo1 = container.read(connectionRepositoryProvider);
        final repo2 = container.read(connectionRepositoryProvider);
        final sync1 = container.read(syncServiceProvider);
        final sync2 = container.read(syncServiceProvider);

        expect(repo1, same(repo2));
        expect(sync1, same(sync2));
      },
    );
  });
}
