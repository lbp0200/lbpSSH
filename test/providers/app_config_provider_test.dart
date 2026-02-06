import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/data/models/terminal_config.dart';
import 'package:lbp_ssh/data/models/default_terminal_config.dart';

void main() {
  group('TerminalConfig Tests', () {
    test('should create with default values', () {
      final config = TerminalConfig();

      expect(config.fontFamily, 'Menlo');
      expect(config.fontSize, 13.0);
      expect(config.fontWeight, 400);
      expect(config.backgroundColor, '#1E1E1E');
      expect(config.foregroundColor, '#FFFFFF');
      expect(config.shellPath, '');
    });

    test('should create with custom values', () {
      final config = TerminalConfig(
        fontFamily: 'Fira Code',
        fontSize: 14.0,
        fontWeight: 600,
        letterSpacing: 0.5,
        lineHeight: 1.2,
        backgroundColor: '#000000',
        foregroundColor: '#00FF00',
        cursorColor: '#FFFFFF',
        cursorBlinkInterval: 750,
        padding: 12,
        devicePixelRatio: 2.0,
        shellPath: '/bin/zsh',
      );

      expect(config.fontFamily, 'Fira Code');
      expect(config.fontSize, 14.0);
      expect(config.fontWeight, 600);
      expect(config.backgroundColor, '#000000');
      expect(config.shellPath, '/bin/zsh');
    });

    test('should serialize to JSON', () {
      final config = TerminalConfig(
        fontFamily: 'Consolas',
        fontSize: 16.0,
        fontWeight: 400,
      );

      final json = config.toJson();

      expect(json['fontFamily'], 'Consolas');
      expect(json['fontSize'], 16.0);
      expect(json['fontWeight'], 400);
    });

    test('should deserialize from JSON', () {
      final json = {
        'fontFamily': 'JetBrains Mono',
        'fontSize': 15.0,
        'fontWeight': 500,
        'letterSpacing': 0.0,
        'lineHeight': 1.0,
        'backgroundColor': '#1E1E2E',
        'foregroundColor': '#CDD6F4',
        'cursorColor': '#F5E0DC',
        'cursorBlinkInterval': 500,
        'padding': 8,
        'devicePixelRatio': 1.0,
        'shellPath': '/usr/bin/fish',
      };

      final config = TerminalConfig.fromJson(json);

      expect(config.fontFamily, 'JetBrains Mono');
      expect(config.fontSize, 15.0);
      expect(config.shellPath, '/usr/bin/fish');
    });

    test('should round-trip serialize correctly', () {
      final original = TerminalConfig(
        fontFamily: 'Source Code Pro',
        fontSize: 12.0,
        fontWeight: 400,
        letterSpacing: 0.0,
        lineHeight: 1.5,
        backgroundColor: '#2D2D2D',
        foregroundColor: '#E0E0E0',
        cursorColor: '#FFFFFF',
        cursorBlinkInterval: 1000,
        padding: 16,
        devicePixelRatio: 1.5,
        shellPath: '/bin/bash',
      );

      final json = original.toJson();
      final deserialized = TerminalConfig.fromJson(json);

      expect(deserialized.fontFamily, original.fontFamily);
      expect(deserialized.fontSize, original.fontSize);
      expect(deserialized.backgroundColor, original.backgroundColor);
      expect(deserialized.shellPath, original.shellPath);
    });

    test('should create copy with modified fields', () {
      final original = TerminalConfig(fontSize: 13.0);
      final modified = original.copyWith(fontSize: 18.0, backgroundColor: '#000000');

      expect(modified.fontSize, 18.0);
      expect(modified.backgroundColor, '#000000');
      expect(original.fontSize, 13.0);
    });

    test('should provide defaultConfig', () {
      final defaultConfig = TerminalConfig.defaultConfig;

      expect(defaultConfig.fontFamily, 'Menlo');
      expect(defaultConfig.fontSize, 13.0);
    });
  });

  group('DefaultTerminalConfig Tests', () {
    test('should create with default values', () {
      final config = DefaultTerminalConfig();

      expect(config.execWindows, TerminalType.windowsTerminal);
      expect(config.execMac, TerminalType.iterm2);
      expect(config.execLinux, TerminalType.terminal);
      expect(config.execWindowsCustom, isNull);
    });

    test('should create with custom values', () {
      final config = DefaultTerminalConfig(
        execWindows: TerminalType.powershell,
        execWindowsCustom: 'pwsh.exe',
        execMac: TerminalType.alacritty,
        execMacCustom: '/usr/bin/alacritty',
        execLinux: TerminalType.wezterm,
        execLinuxCustom: '/usr/bin/wezterm',
      );

      expect(config.execWindows, TerminalType.powershell);
      expect(config.execMac, TerminalType.alacritty);
      expect(config.execLinux, TerminalType.wezterm);
    });

    test('should serialize to JSON', () {
      final config = DefaultTerminalConfig(
        execMac: TerminalType.kitty,
      );

      final json = config.toJson();

      expect(json['execMac'], 'kitty');
    });

    test('should deserialize from JSON', () {
      final json = {
        'execWindows': 'cmd',
        'execMac': 'terminal',
        'execLinux': 'alacritty',
      };

      final config = DefaultTerminalConfig.fromJson(json);

      expect(config.execWindows, TerminalType.cmd);
      expect(config.execMac, TerminalType.terminal);
      expect(config.execLinux, TerminalType.alacritty);
    });

    test('should create copy with modified fields', () {
      final original = DefaultTerminalConfig();
      final modified = original.copyWith(execMac: TerminalType.wezterm);

      expect(modified.execMac, TerminalType.wezterm);
      expect(original.execMac, TerminalType.iterm2);
    });

    test('should get correct Mac command for iTerm2', () {
      final config = DefaultTerminalConfig(execMac: TerminalType.iterm2);
      expect(config.getMacCommand(), 'open -a iTerm');
    });

    test('should get correct Mac command for alacritty', () {
      final config = DefaultTerminalConfig(execMac: TerminalType.alacritty);
      expect(config.getMacCommand(), 'open -a Alacritty');
    });

    test('should get correct Mac command for custom', () {
      final config = DefaultTerminalConfig(
        execMac: TerminalType.custom,
        execMacCustom: '/Applications/Custom.app',
      );
      expect(config.getMacCommand(), '/Applications/Custom.app');
    });

    test('should get correct Windows command for powershell', () {
      final config = DefaultTerminalConfig(execWindows: TerminalType.powershell);
      expect(config.getWindowsCommand(), 'powershell.exe');
    });

    test('should get correct Linux command for kitty', () {
      final config = DefaultTerminalConfig(execLinux: TerminalType.kitty);
      expect(config.getLinuxCommand(), 'kitty');
    });
  });

  group('TerminalType Enum Tests', () {
    test('should have correct values', () {
      expect(TerminalType.iterm2.name, 'iterm2');
      expect(TerminalType.terminal.name, 'terminal');
      expect(TerminalType.alacritty.name, 'alacritty');
      expect(TerminalType.kitty.name, 'kitty');
      expect(TerminalType.wezterm.name, 'wezterm');
      expect(TerminalType.powershell.name, 'powershell');
      expect(TerminalType.windowsTerminal.name, 'windowsTerminal');
      expect(TerminalType.cmd.name, 'cmd');
      expect(TerminalType.custom.name, 'custom');
    });
  });
}
