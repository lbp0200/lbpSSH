import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/data/models/default_terminal_config.dart';

void main() {
  group('DefaultTerminalConfig', () {
    test('should create config with default values', () {
      final config = DefaultTerminalConfig();

      expect(config.execWindows, TerminalType.windowsTerminal);
      expect(config.execWindowsCustom, isNull);
      expect(config.execMac, TerminalType.iterm2);
      expect(config.execMacCustom, isNull);
      expect(config.execLinux, TerminalType.terminal);
      expect(config.execLinuxCustom, isNull);
    });

    test('should create config with custom values', () {
      final config = DefaultTerminalConfig(
        execWindows: TerminalType.powershell,
        execWindowsCustom: 'custom.exe',
        execMac: TerminalType.alacritty,
        execMacCustom: '/usr/bin/alacritty',
        execLinux: TerminalType.kitty,
        execLinuxCustom: '/usr/bin/kitty',
      );

      expect(config.execWindows, TerminalType.powershell);
      expect(config.execWindowsCustom, 'custom.exe');
      expect(config.execMac, TerminalType.alacritty);
      expect(config.execMacCustom, '/usr/bin/alacritty');
      expect(config.execLinux, TerminalType.kitty);
      expect(config.execLinuxCustom, '/usr/bin/kitty');
    });

    test('should serialize to JSON', () {
      final config = DefaultTerminalConfig(
        execWindows: TerminalType.cmd,
        execMac: TerminalType.wezterm,
        execLinux: TerminalType.alacritty,
      );

      final json = config.toJson();

      expect(json['execWindows'], 'cmd');
      expect(json['execMac'], 'wezterm');
      expect(json['execLinux'], 'alacritty');
    });

    test('should deserialize from JSON', () {
      final json = {
        'execWindows': 'powershell',
        'execWindowsCustom': 'pwsh.exe',
        'execMac': 'terminal',
        'execMacCustom': 'open -b com.apple.terminal',
        'execLinux': 'wezterm',
        'execLinuxCustom': 'wezterm',
      };

      final config = DefaultTerminalConfig.fromJson(json);

      expect(config.execWindows, TerminalType.powershell);
      expect(config.execWindowsCustom, 'pwsh.exe');
      expect(config.execMac, TerminalType.terminal);
      expect(config.execMacCustom, 'open -b com.apple.terminal');
      expect(config.execLinux, TerminalType.wezterm);
      expect(config.execLinuxCustom, 'wezterm');
    });

    test('should serialize and deserialize correctly', () {
      final original = DefaultTerminalConfig(
        execWindows: TerminalType.custom,
        execWindowsCustom: 'custom_windows.exe',
        execMac: TerminalType.custom,
        execMacCustom: 'custom_mac.app',
        execLinux: TerminalType.custom,
        execLinuxCustom: 'custom_linux',
      );

      final json = original.toJson();
      final deserialized = DefaultTerminalConfig.fromJson(json);

      expect(deserialized.execWindows, original.execWindows);
      expect(deserialized.execWindowsCustom, original.execWindowsCustom);
      expect(deserialized.execMac, original.execMac);
      expect(deserialized.execMacCustom, original.execMacCustom);
      expect(deserialized.execLinux, original.execLinux);
      expect(deserialized.execLinuxCustom, original.execLinuxCustom);
    });

    test('should create copy with modified fields', () {
      final original = DefaultTerminalConfig();

      final modified = original.copyWith(
        execMac: TerminalType.kitty,
        execLinux: TerminalType.wezterm,
      );

      expect(modified.execMac, TerminalType.kitty);
      expect(modified.execLinux, TerminalType.wezterm);
      expect(modified.execWindows, original.execWindows);
    });

    test('should get correct Windows command for powershell', () {
      final config = DefaultTerminalConfig(execWindows: TerminalType.powershell);
      expect(config.getWindowsCommand(), 'powershell.exe');
    });

    test('should get correct Windows command for cmd', () {
      final config = DefaultTerminalConfig(execWindows: TerminalType.cmd);
      expect(config.getWindowsCommand(), 'cmd.exe');
    });

    test('should get correct Windows command for windowsTerminal', () {
      final config = DefaultTerminalConfig(execWindows: TerminalType.windowsTerminal);
      expect(config.getWindowsCommand(), 'wt.exe');
    });

    test('should get correct Windows command for custom', () {
      final config = DefaultTerminalConfig(
        execWindows: TerminalType.custom,
        execWindowsCustom: 'custom_terminal.exe',
      );
      expect(config.getWindowsCommand(), 'custom_terminal.exe');
    });

    test('should get correct Mac command for terminal', () {
      final config = DefaultTerminalConfig(execMac: TerminalType.terminal);
      expect(config.getMacCommand(), 'open -b com.apple.terminal');
    });

    test('should get correct Mac command for iTerm2', () {
      final config = DefaultTerminalConfig(execMac: TerminalType.iterm2);
      expect(config.getMacCommand(), 'open -a iTerm');
    });

    test('should get correct Mac command for alacritty', () {
      final config = DefaultTerminalConfig(execMac: TerminalType.alacritty);
      expect(config.getMacCommand(), 'open -a Alacritty');
    });

    test('should get correct Mac command for kitty', () {
      final config = DefaultTerminalConfig(execMac: TerminalType.kitty);
      expect(config.getMacCommand(), 'open -a kitty');
    });

    test('should get correct Mac command for wezterm', () {
      final config = DefaultTerminalConfig(execMac: TerminalType.wezterm);
      expect(config.getMacCommand(), 'open -a WezTerm');
    });

    test('should get correct Mac command for custom', () {
      final config = DefaultTerminalConfig(
        execMac: TerminalType.custom,
        execMacCustom: '/Applications/Custom.app',
      );
      expect(config.getMacCommand(), '/Applications/Custom.app');
    });

    test('should get correct Linux command for terminal', () {
      final config = DefaultTerminalConfig(execLinux: TerminalType.terminal);
      expect(config.getLinuxCommand(), 'x-terminal-emulator');
    });

    test('should get correct Linux command for alacritty', () {
      final config = DefaultTerminalConfig(execLinux: TerminalType.alacritty);
      expect(config.getLinuxCommand(), 'alacritty');
    });

    test('should get correct Linux command for kitty', () {
      final config = DefaultTerminalConfig(execLinux: TerminalType.kitty);
      expect(config.getLinuxCommand(), 'kitty');
    });

    test('should get correct Linux command for wezterm', () {
      final config = DefaultTerminalConfig(execLinux: TerminalType.wezterm);
      expect(config.getLinuxCommand(), 'wezterm');
    });

    test('should get correct Linux command for custom', () {
      final config = DefaultTerminalConfig(
        execLinux: TerminalType.custom,
        execLinuxCustom: '/usr/bin/custom',
      );
      expect(config.getLinuxCommand(), '/usr/bin/custom');
    });

    test('should provide defaultConfig', () {
      final defaultConfig = DefaultTerminalConfig.defaultConfig;

      expect(defaultConfig, isA<DefaultTerminalConfig>());
      expect(defaultConfig.execMac, TerminalType.iterm2);
      expect(defaultConfig.execWindows, TerminalType.windowsTerminal);
      expect(defaultConfig.execLinux, TerminalType.terminal);
    });
  });
}
