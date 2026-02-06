import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/terminal_config.dart';
import '../../data/models/default_terminal_config.dart';

class AppConfig {
  TerminalConfig terminal;
  DefaultTerminalConfig defaultTerminal;

  AppConfig({
    TerminalConfig? terminal,
    DefaultTerminalConfig? defaultTerminal,
  })  : terminal = terminal ?? TerminalConfig.defaultConfig,
        defaultTerminal = defaultTerminal ?? DefaultTerminalConfig.defaultConfig;

  Map<String, dynamic> toJson() => {
        'terminal': terminal.toJson(),
        'defaultTerminal': defaultTerminal.toJson(),
      };

  factory AppConfig.fromJson(Map<String, dynamic> json) => AppConfig(
        terminal: json['terminal'] != null
            ? TerminalConfig.fromJson(json['terminal'] as Map<String, dynamic>)
            : null,
        defaultTerminal: json['defaultTerminal'] != null
            ? DefaultTerminalConfig.fromJson(
                json['defaultTerminal'] as Map<String, dynamic>,
              )
            : null,
      );
}

class AppConfigService with ChangeNotifier {
  static AppConfigService? _instance;
  TerminalConfig _terminal = TerminalConfig.defaultConfig;
  DefaultTerminalConfig _defaultTerminal = DefaultTerminalConfig.defaultConfig;

  AppConfigService._internal();

  factory AppConfigService.getInstance() {
    _instance ??= AppConfigService._internal();
    return _instance!;
  }

  TerminalConfig get terminal => _terminal;
  DefaultTerminalConfig get defaultTerminal => _defaultTerminal;

  Future<void> saveTerminalConfig(TerminalConfig config) async {
    _terminal = config;
    await _saveToPrefs();
    notifyListeners();
  }

  Future<void> saveDefaultTerminalConfig(DefaultTerminalConfig config) async {
    _defaultTerminal = config;
    await _saveToPrefs();
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final config = AppConfig(
      terminal: _terminal,
      defaultTerminal: _defaultTerminal,
    );
    await prefs.setString(
      AppConstants.appConfigKey,
      jsonEncode(config.toJson()),
    );
  }

  Future<void> resetToDefaults() async {
    _terminal = TerminalConfig.defaultConfig;
    _defaultTerminal = DefaultTerminalConfig.defaultConfig;
    await _saveToPrefs();
    notifyListeners();
  }

  String exportConfig() {
    final config = AppConfig(
      terminal: _terminal,
      defaultTerminal: _defaultTerminal,
    );
    return jsonEncode(config.toJson());
  }

  Future<void> importConfig(String jsonString) async {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    final config = AppConfig.fromJson(json);
    _terminal = config.terminal;
    _defaultTerminal = config.defaultTerminal;
    await _saveToPrefs();
    notifyListeners();
  }
}
