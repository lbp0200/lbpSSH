import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/terminal_config.dart';
import '../../data/models/default_terminal_config.dart';

enum SyncPlatform { github, gitee, gist, giteeGist }

enum SyncStatusEnum { idle, syncing, success, error }

class SyncConfig {
  final SyncPlatform platform;
  final String? accessToken;
  final String? repositoryOwner;
  final String? repositoryName;
  final String? branch;
  final String? filePath;
  final String? gistId;
  final String? gistFileName;
  final bool autoSync;
  final int syncIntervalMinutes;

  SyncConfig({
    required this.platform,
    this.accessToken,
    this.repositoryOwner,
    this.repositoryName,
    this.branch = 'main',
    this.filePath,
    this.gistId,
    this.gistFileName,
    this.autoSync = false,
    this.syncIntervalMinutes = AppConstants.defaultSyncIntervalMinutes,
  });

  Map<String, dynamic> toJson() => {
    'platform': platform.name,
    'accessToken': accessToken,
    'repositoryOwner': repositoryOwner,
    'repositoryName': repositoryName,
    'branch': branch,
    'filePath': filePath,
    'gistId': gistId,
    'gistFileName': gistFileName,
    'autoSync': autoSync,
    'syncIntervalMinutes': syncIntervalMinutes,
  };

  factory SyncConfig.fromJson(Map<String, dynamic> json) => SyncConfig(
    platform: SyncPlatform.values.firstWhere(
      (e) => e.name == json['platform'],
      orElse: () => SyncPlatform.github,
    ),
    accessToken: json['accessToken'],
    repositoryOwner: json['repositoryOwner'],
    repositoryName: json['repositoryName'],
    branch: json['branch'] ?? 'main',
    filePath: json['filePath'],
    gistId: json['gistId'],
    gistFileName: json['gistFileName'],
    autoSync: json['autoSync'] ?? false,
    syncIntervalMinutes:
        json['syncIntervalMinutes'] ?? AppConstants.defaultSyncIntervalMinutes,
  );
}

class AppConfig {
  TerminalConfig terminal;
  DefaultTerminalConfig defaultTerminal;
  SyncConfig? sync;

  AppConfig({
    TerminalConfig? terminal,
    DefaultTerminalConfig? defaultTerminal,
    this.sync,
  }) : terminal = terminal ?? TerminalConfig.defaultConfig,
       defaultTerminal = defaultTerminal ?? DefaultTerminalConfig.defaultConfig;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'terminal': terminal.toJson(),
      'defaultTerminal': defaultTerminal.toJson(),
    };
    if (sync != null) {
      json['sync'] = sync!.toJson();
    }
    return json;
  }

  factory AppConfig.fromJson(Map<String, dynamic> json) => AppConfig(
    terminal: json['terminal'] != null
        ? TerminalConfig.fromJson(json['terminal'] as Map<String, dynamic>)
        : null,
    defaultTerminal: json['defaultTerminal'] != null
        ? DefaultTerminalConfig.fromJson(
            json['defaultTerminal'] as Map<String, dynamic>,
          )
        : null,
    sync: json['sync'] != null
        ? SyncConfig.fromJson(json['sync'] as Map<String, dynamic>)
        : null,
  );
}

class AppConfigService with ChangeNotifier {
  static AppConfigService? _instance;
  final Dio _dio = Dio();
  TerminalConfig _terminal = TerminalConfig.defaultConfig;
  DefaultTerminalConfig _defaultTerminal = DefaultTerminalConfig.defaultConfig;
  SyncConfig? _sync;
  final SyncStatusEnum _status = SyncStatusEnum.idle;
  DateTime? _lastSyncTime;

  AppConfigService._internal() {
    _loadConfig();
  }

  factory AppConfigService.getInstance() {
    _instance ??= AppConfigService._internal();
    return _instance!;
  }

  TerminalConfig get terminal => _terminal;
  DefaultTerminalConfig get defaultTerminal => _defaultTerminal;
  SyncConfig? get sync => _sync;
  SyncStatusEnum get status => _status;
  DateTime? get lastSyncTime => _lastSyncTime;

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final configJson = prefs.getString(AppConstants.appConfigKey);
    if (configJson != null) {
      try {
        final json = jsonDecode(configJson) as Map<String, dynamic>;
        final config = AppConfig.fromJson(json);
        _terminal = config.terminal;
        _defaultTerminal = config.defaultTerminal;
        _sync = config.sync;
      } catch (e) {
        _terminal = TerminalConfig.defaultConfig;
        _defaultTerminal = DefaultTerminalConfig.defaultConfig;
      }
    }
    notifyListeners();
  }

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

  Future<void> saveSyncConfig(SyncConfig config) async {
    _sync = config;
    await _saveToPrefs();
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final config = AppConfig(
      terminal: _terminal,
      defaultTerminal: _defaultTerminal,
      sync: _sync,
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
      sync: _sync,
    );
    return jsonEncode(config.toJson());
  }

  Future<void> importConfig(String jsonString) async {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    final config = AppConfig.fromJson(json);
    _terminal = config.terminal;
    _defaultTerminal = config.defaultTerminal;
    _sync = config.sync;
    await _saveToPrefs();
    notifyListeners();
  }

  Future<void> exportToFile(String filePath) async {
    final jsonString = exportConfig();
    await _writeFile(filePath, jsonString);
  }

  Future<String> importFromFile(String filePath) async {
    final jsonString = await _readFile(filePath);
    await importConfig(jsonString);
    return jsonString;
  }

  Future<void> _writeFile(String path, String content) async {
    final file = File(path);
    await file.writeAsString(content);
  }

  Future<String> _readFile(String path) async {
    final file = File(path);
    return await file.readAsString();
  }

  Future<void> uploadToGiteeGist(String content) async {
    if (_sync == null || _sync!.accessToken == null) {
      throw Exception('同步配置未设置或未授权');
    }

    final fileName = _sync!.gistFileName ?? AppConstants.defaultSyncFileName;

    if (_sync!.gistId == null) {
      final url = 'https://gitee.com/api/v5/gists';
      final data = {
        'access_token': _sync!.accessToken,
        'description': 'SSH Connections Config',
        'public': false,
        'files': {
          fileName: {'content': content},
        },
      };

      final response = await _dio.post(url, data: data);

      final newConfig = SyncConfig(
        platform: _sync!.platform,
        accessToken: _sync!.accessToken,
        gistId: response.data['id'] as String?,
        gistFileName: fileName,
        autoSync: _sync!.autoSync,
        syncIntervalMinutes: _sync!.syncIntervalMinutes,
      );
      await saveSyncConfig(newConfig);
    } else {
      final url =
          'https://gitee.com/api/v5/gists/${_sync!.gistId}?access_token=${_sync!.accessToken}';

      final getResponse = await _dio.get(
        'https://gitee.com/api/v5/gists/${_sync!.gistId}?access_token=${_sync!.accessToken}',
      );

      final files = getResponse.data['files'] as Map<String, dynamic>;
      final existingFile = files[fileName];
      String? fileSha;
      if (existingFile != null) {
        fileSha = existingFile['sha'] as String?;
      }

      final data = {
        'access_token': _sync!.accessToken,
        'description': 'SSH Connections Config',
        'files': {
          fileName: {'content': content, if (fileSha != null) 'sha': fileSha!},
        },
      };

      await _dio.patch(url, data: data);
    }
  }

  Future<String> downloadFromGiteeGist() async {
    if (_sync == null || _sync!.accessToken == null) {
      throw Exception('同步配置未设置或未授权');
    }

    if (_sync!.gistId == null) {
      throw Exception('Gist ID 未设置');
    }

    final fileName = _sync!.gistFileName ?? AppConstants.defaultSyncFileName;
    final url =
        'https://gitee.com/api/v5/gists/${_sync!.gistId}?access_token=${_sync!.accessToken}';

    final response = await _dio.get(url);
    final files = response.data['files'] as Map<String, dynamic>;
    final file = files[fileName];

    if (file == null) {
      throw Exception('Gist 中未找到文件: $fileName');
    }

    return base64Encode(utf8.encode(file['content'] as String));
  }
}
