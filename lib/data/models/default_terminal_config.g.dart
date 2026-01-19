// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'default_terminal_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DefaultTerminalConfig _$DefaultTerminalConfigFromJson(
  Map<String, dynamic> json,
) => DefaultTerminalConfig(
  execWindows:
      $enumDecodeNullable(_$TerminalTypeEnumMap, json['execWindows']) ??
      TerminalType.windowsTerminal,
  execWindowsCustom: json['execWindowsCustom'] as String?,
  execMac:
      $enumDecodeNullable(_$TerminalTypeEnumMap, json['execMac']) ??
      TerminalType.iterm2,
  execMacCustom: json['execMacCustom'] as String?,
  execLinux:
      $enumDecodeNullable(_$TerminalTypeEnumMap, json['execLinux']) ??
      TerminalType.terminal,
  execLinuxCustom: json['execLinuxCustom'] as String?,
);

Map<String, dynamic> _$DefaultTerminalConfigToJson(
  DefaultTerminalConfig instance,
) => <String, dynamic>{
  'execWindows': _$TerminalTypeEnumMap[instance.execWindows]!,
  'execWindowsCustom': instance.execWindowsCustom,
  'execMac': _$TerminalTypeEnumMap[instance.execMac]!,
  'execMacCustom': instance.execMacCustom,
  'execLinux': _$TerminalTypeEnumMap[instance.execLinux]!,
  'execLinuxCustom': instance.execLinuxCustom,
};

const _$TerminalTypeEnumMap = {
  TerminalType.iterm2: 'iterm2',
  TerminalType.terminal: 'terminal',
  TerminalType.alacritty: 'alacritty',
  TerminalType.kitty: 'kitty',
  TerminalType.wezterm: 'wezterm',
  TerminalType.powershell: 'powershell',
  TerminalType.windowsTerminal: 'windows_terminal',
  TerminalType.cmd: 'cmd',
  TerminalType.custom: 'custom',
};
