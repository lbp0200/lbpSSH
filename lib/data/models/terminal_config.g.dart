// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'terminal_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TerminalConfig _$TerminalConfigFromJson(Map<String, dynamic> json) =>
    TerminalConfig(
      fontFamily: json['fontFamily'] as String? ?? 'Menlo',
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 13.0,
      fontWeight: (json['fontWeight'] as num?)?.toInt() ?? 400,
      letterSpacing: (json['letterSpacing'] as num?)?.toDouble() ?? 0.0,
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.0,
      backgroundColor: json['backgroundColor'] as String? ?? '#1E1E1E',
      foregroundColor: json['foregroundColor'] as String? ?? '#FFFFFF',
      cursorColor: json['cursorColor'] as String? ?? '#FFFFFF',
      cursorBlinkInterval:
          (json['cursorBlinkInterval'] as num?)?.toDouble() ?? 500,
      padding: (json['padding'] as num?)?.toInt() ?? 8,
      devicePixelRatio: (json['devicePixelRatio'] as num?)?.toDouble() ?? 1.0,
      shellPath: json['shellPath'] as String? ?? '',
    );

Map<String, dynamic> _$TerminalConfigToJson(TerminalConfig instance) =>
    <String, dynamic>{
      'fontFamily': instance.fontFamily,
      'fontSize': instance.fontSize,
      'fontWeight': instance.fontWeight,
      'letterSpacing': instance.letterSpacing,
      'lineHeight': instance.lineHeight,
      'backgroundColor': instance.backgroundColor,
      'foregroundColor': instance.foregroundColor,
      'cursorColor': instance.cursorColor,
      'cursorBlinkInterval': instance.cursorBlinkInterval,
      'padding': instance.padding,
      'devicePixelRatio': instance.devicePixelRatio,
      'shellPath': instance.shellPath,
    };
