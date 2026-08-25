import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/core/constants/app_constants.dart';

void main() {
  group('AppConstants', () {
    test('syncSettingsKey is stable', () {
      expect(AppConstants.syncSettingsKey, 'sync_settings');
    });

    test('appConfigKey is stable', () {
      expect(AppConstants.appConfigKey, 'app_config');
    });

    test('defaultSyncIntervalMinutes is 5', () {
      expect(AppConstants.defaultSyncIntervalMinutes, 5);
    });

    test('defaultGistFilename is ssh_connections.json', () {
      expect(AppConstants.defaultGistFilename, 'ssh_connections.json');
    });

    test('configDirName is lbpSSH', () {
      expect(AppConstants.configDirName, 'lbpSSH');
    });

    test('appName is lbpSSH', () {
      expect(AppConstants.appName, 'lbpSSH');
    });

    test('appVersion matches pubspec 1.9.7', () {
      expect(AppConstants.appVersion, '1.9.7');
    });

    test('importPrefix is 导入_', () {
      expect(AppConstants.importPrefix, '导入_');
    });

    test('exportFilePrefix is ssh_connections_export_', () {
      expect(AppConstants.exportFilePrefix, 'ssh_connections_export_');
    });
  });
}
