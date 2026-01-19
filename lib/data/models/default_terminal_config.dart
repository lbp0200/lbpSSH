import 'package:json_annotation/json_annotation.dart';

part 'default_terminal_config.g.dart';

enum TerminalType {
  @JsonValue('iterm2')
  iterm2,
  @JsonValue('terminal')
  terminal,
  @JsonValue('alacritty')
  alacritty,
  @JsonValue('kitty')
  kitty,
  @JsonValue('wezterm')
  wezterm,
  @JsonValue('powershell')
  powershell,
  @JsonValue('windows_terminal')
  windowsTerminal,
  @JsonValue('cmd')
  cmd,
  @JsonValue('custom')
  custom,
}

@JsonSerializable()
class DefaultTerminalConfig {
  final TerminalType execWindows;
  final String? execWindowsCustom;
  final TerminalType execMac;
  final String? execMacCustom;
  final TerminalType execLinux;
  final String? execLinuxCustom;

  DefaultTerminalConfig({
    this.execWindows = TerminalType.windowsTerminal,
    this.execWindowsCustom,
    this.execMac = TerminalType.iterm2,
    this.execMacCustom,
    this.execLinux = TerminalType.terminal,
    this.execLinuxCustom,
  });

  factory DefaultTerminalConfig.fromJson(Map<String, dynamic> json) =>
      _$DefaultTerminalConfigFromJson(json);

  Map<String, dynamic> toJson() => _$DefaultTerminalConfigToJson(this);

  DefaultTerminalConfig copyWith({
    TerminalType? execWindows,
    String? execWindowsCustom,
    TerminalType? execMac,
    String? execMacCustom,
    TerminalType? execLinux,
    String? execLinuxCustom,
  }) {
    return DefaultTerminalConfig(
      execWindows: execWindows ?? this.execWindows,
      execWindowsCustom: execWindowsCustom ?? this.execWindowsCustom,
      execMac: execMac ?? this.execMac,
      execMacCustom: execMacCustom ?? this.execMacCustom,
      execLinux: execLinux ?? this.execLinux,
      execLinuxCustom: execLinuxCustom ?? this.execLinuxCustom,
    );
  }

  static DefaultTerminalConfig get defaultConfig => DefaultTerminalConfig();

  String getWindowsCommand() {
    if (execWindows == TerminalType.custom && execWindowsCustom != null) {
      return execWindowsCustom!;
    }
    switch (execWindows) {
      case TerminalType.powershell:
        return 'powershell.exe';
      case TerminalType.cmd:
        return 'cmd.exe';
      case TerminalType.windowsTerminal:
      case TerminalType.custom:
      default:
        return 'wt.exe';
    }
  }

  String getMacCommand() {
    if (execMac == TerminalType.custom && execMacCustom != null) {
      return execMacCustom!;
    }
    switch (execMac) {
      case TerminalType.terminal:
        return 'open -b com.apple.terminal';
      case TerminalType.alacritty:
        return 'open -a Alacritty';
      case TerminalType.kitty:
        return 'open -a kitty';
      case TerminalType.wezterm:
        return 'open -a WezTerm';
      case TerminalType.iterm2:
      case TerminalType.custom:
      default:
        return 'open -a iTerm';
    }
  }

  String getLinuxCommand() {
    if (execLinux == TerminalType.custom && execLinuxCustom != null) {
      return execLinuxCustom!;
    }
    switch (execLinux) {
      case TerminalType.alacritty:
        return 'alacritty';
      case TerminalType.kitty:
        return 'kitty';
      case TerminalType.wezterm:
        return 'wezterm';
      case TerminalType.terminal:
      case TerminalType.custom:
      default:
        return 'x-terminal-emulator';
    }
  }
}
