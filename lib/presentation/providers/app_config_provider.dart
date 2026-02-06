import 'package:flutter/foundation.dart';
import '../../data/models/terminal_config.dart';
import '../../data/models/default_terminal_config.dart';
import '../../domain/services/app_config_service.dart';

class AppConfigProvider extends ChangeNotifier {
  final AppConfigService _configService;

  AppConfigProvider(this._configService);

  TerminalConfig get terminalConfig => _configService.terminal;
  DefaultTerminalConfig get defaultTerminalConfig =>
      _configService.defaultTerminal;

  Future<void> saveTerminalConfig(TerminalConfig config) async {
    await _configService.saveTerminalConfig(config);
    notifyListeners();
  }

  void updateFontSize(double size) {
    final newConfig = _configService.terminal.copyWith(fontSize: size);
    _configService.saveTerminalConfig(newConfig);
    notifyListeners();
  }

  Future<void> saveDefaultTerminalConfig(DefaultTerminalConfig config) async {
    await _configService.saveDefaultTerminalConfig(config);
    notifyListeners();
  }

  Future<void> resetToDefaults() async {
    await _configService.resetToDefaults();
    notifyListeners();
  }

  String exportConfig() {
    return _configService.exportConfig();
  }

  Future<void> importConfig(String jsonString) async {
    await _configService.importConfig(jsonString);
    notifyListeners();
  }
}
