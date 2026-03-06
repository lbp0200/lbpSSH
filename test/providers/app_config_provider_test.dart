import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/presentation/providers/app_config_provider.dart';
import 'package:lbp_ssh/data/models/terminal_config.dart';
import 'package:lbp_ssh/data/models/default_terminal_config.dart';
import '../mocks/mocks.dart';

void main() {
  late MockAppConfigService mockAppConfigService;
  late AppConfigProvider appConfigProvider;

  setUp(() {
    mockAppConfigService = MockAppConfigService();
    appConfigProvider = AppConfigProvider(mockAppConfigService);
    registerFallbackValues();
  });

  group('AppConfigProvider', () {
    group('terminalConfig', () {
      test(
          'Given AppConfigService with terminal config, When accessing terminalConfig, Then returns terminal config',
          () {
        // Arrange (Given)
        const expectedFontSize = 14.0;
        final expectedConfig = TerminalConfig(fontSize: expectedFontSize);
        when(() => mockAppConfigService.terminal).thenReturn(expectedConfig);

        // Act (When)
        final result = appConfigProvider.terminalConfig;

        // Assert (Then)
        expect(result.fontSize, expectedFontSize);
        verify(() => mockAppConfigService.terminal).called(1);
      });
    });

    group('defaultTerminalConfig', () {
      test(
          'Given AppConfigService with default terminal config, When accessing defaultTerminalConfig, Then returns default terminal config',
          () {
        // Arrange (Given)
        final expectedConfig = DefaultTerminalConfig(
          execMac: TerminalType.alacritty,
        );
        when(() => mockAppConfigService.defaultTerminal)
            .thenReturn(expectedConfig);

        // Act (When)
        final result = appConfigProvider.defaultTerminalConfig;

        // Assert (Then)
        expect(result.execMac, TerminalType.alacritty);
        verify(() => mockAppConfigService.defaultTerminal).called(1);
      });
    });

    group('saveTerminalConfig', () {
      test(
          'Given valid terminal config, When saveTerminalConfig called, Then calls service and notifies listeners',
          () async {
        // Arrange (Given)
        final config = TerminalConfig(fontSize: 16.0);
        when(() => mockAppConfigService.saveTerminalConfig(config))
            .thenAnswer((_) async {});

        // Act (When)
        await appConfigProvider.saveTerminalConfig(config);

        // Assert (Then)
        verify(() => mockAppConfigService.saveTerminalConfig(config)).called(1);
      });
    });

    group('updateFontSize', () {
      test(
          'Given new font size, When updateFontSize called, Then updates config and notifies listeners',
          () {
        // Arrange (Given)
        const newSize = 18.0;
        final originalConfig = TerminalConfig(fontSize: 14.0);
        when(() => mockAppConfigService.terminal).thenReturn(originalConfig);
        when(() => mockAppConfigService.saveTerminalConfig(any()))
            .thenAnswer((_) async {});

        // Act (When)
        appConfigProvider.updateFontSize(newSize);

        // Assert (Then)
        verify(() => mockAppConfigService.saveTerminalConfig(any())).called(1);
      });
    });

    group('saveDefaultTerminalConfig', () {
      test(
          'Given valid default terminal config, When saveDefaultTerminalConfig called, Then calls service and notifies listeners',
          () async {
        // Arrange (Given)
        final config = DefaultTerminalConfig(execMac: TerminalType.wezterm);
        when(() => mockAppConfigService.saveDefaultTerminalConfig(config))
            .thenAnswer((_) async {});

        // Act (When)
        await appConfigProvider.saveDefaultTerminalConfig(config);

        // Assert (Then)
        verify(() => mockAppConfigService.saveDefaultTerminalConfig(config))
            .called(1);
      });
    });

    group('resetToDefaults', () {
      test(
          'When resetToDefaults called, Then calls service and notifies listeners',
          () async {
        // Arrange (Given)
        when(() => mockAppConfigService.resetToDefaults())
            .thenAnswer((_) async {});

        // Act (When)
        await appConfigProvider.resetToDefaults();

        // Assert (Then)
        verify(() => mockAppConfigService.resetToDefaults()).called(1);
      });
    });

    group('exportConfig', () {
      test(
          'Given AppConfigService with config, When exportConfig called, Then returns exported config string',
          () {
        // Arrange (Given)
        const expectedJson = '{"terminal": {...}}';
        when(() => mockAppConfigService.exportConfig()).thenReturn(expectedJson);

        // Act (When)
        final result = appConfigProvider.exportConfig();

        // Assert (Then)
        expect(result, expectedJson);
        verify(() => mockAppConfigService.exportConfig()).called(1);
      });
    });

    group('importConfig', () {
      test(
          'Given valid JSON string, When importConfig called, Then calls service and notifies listeners',
          () async {
        // Arrange (Given)
        const jsonString = '{"terminal": {...}}';
        when(() => mockAppConfigService.importConfig(jsonString))
            .thenAnswer((_) async {});

        // Act (When)
        await appConfigProvider.importConfig(jsonString);

        // Assert (Then)
        verify(() => mockAppConfigService.importConfig(jsonString)).called(1);
      });
    });
  });
}
