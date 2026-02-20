import 'package:json_annotation/json_annotation.dart';

part 'terminal_config.g.dart';

@JsonSerializable()
class TerminalConfig {
  final String fontFamily;
  final double fontSize;
  final int fontWeight;
  final double letterSpacing;
  final double lineHeight;
  final String backgroundColor;
  final String foregroundColor;
  final String cursorColor;
  final double cursorBlinkInterval;
  final int padding;
  final double devicePixelRatio;
  final String shellPath;
  final bool enableKittyProtocol;

  TerminalConfig({
    this.fontFamily = 'Menlo',
    this.fontSize = 13.0,
    this.fontWeight = 400,
    this.letterSpacing = 0.0,
    this.lineHeight = 1.0,
    this.backgroundColor = '#1E1E1E',
    this.foregroundColor = '#FFFFFF',
    this.cursorColor = '#FFFFFF',
    this.cursorBlinkInterval = 500,
    this.padding = 8,
    this.devicePixelRatio = 1.0,
    this.shellPath = '',
    this.enableKittyProtocol = true,
  });

  factory TerminalConfig.fromJson(Map<String, dynamic> json) =>
      _$TerminalConfigFromJson(json);

  Map<String, dynamic> toJson() => _$TerminalConfigToJson(this);

  TerminalConfig copyWith({
    String? fontFamily,
    double? fontSize,
    int? fontWeight,
    double? letterSpacing,
    double? lineHeight,
    String? backgroundColor,
    String? foregroundColor,
    String? cursorColor,
    double? cursorBlinkInterval,
    int? padding,
    double? devicePixelRatio,
    String? shellPath,
    bool? enableKittyProtocol,
  }) {
    return TerminalConfig(
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      lineHeight: lineHeight ?? this.lineHeight,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      foregroundColor: foregroundColor ?? this.foregroundColor,
      cursorColor: cursorColor ?? this.cursorColor,
      cursorBlinkInterval: cursorBlinkInterval ?? this.cursorBlinkInterval,
      padding: padding ?? this.padding,
      devicePixelRatio: devicePixelRatio ?? this.devicePixelRatio,
      shellPath: shellPath ?? this.shellPath,
      enableKittyProtocol: enableKittyProtocol ?? this.enableKittyProtocol,
    );
  }

  static TerminalConfig get defaultConfig => TerminalConfig();
}
