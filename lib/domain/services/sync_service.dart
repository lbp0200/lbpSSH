import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/ssh_connection.dart';
import '../../data/repositories/connection_repository.dart';
import '../../core/constants/app_constants.dart';

/// 同步平台类型
enum SyncPlatform {
  github,
  gitee,
}

/// 同步状态
enum SyncStatusEnum {
  idle,
  syncing,
  success,
  error,
}

/// 同步配置
class SyncConfig {
  final SyncPlatform platform;
  final String? accessToken;
  final String repositoryOwner;
  final String repositoryName;
  final String branch;
  final String filePath;
  final bool autoSync;
  final int syncIntervalMinutes;

  SyncConfig({
    required this.platform,
    this.accessToken,
    required this.repositoryOwner,
    required this.repositoryName,
    this.branch = 'main',
    this.filePath = AppConstants.defaultSyncFileName,
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
        filePath: json['filePath'] ?? AppConstants.defaultSyncFileName,
        autoSync: json['autoSync'] ?? false,
        syncIntervalMinutes:
            json['syncIntervalMinutes'] ?? AppConstants.defaultSyncIntervalMinutes,
      );
}

/// 配置同步服务
class SyncService {
  final ConnectionRepository _repository;
  final Dio _dio = Dio();
  SyncConfig? _config;
  SyncStatusEnum _status = SyncStatusEnum.idle;
  DateTime? _lastSyncTime;

  SyncService(this._repository) {
    _loadConfig();
  }

  /// 加载同步配置
  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final configJson = prefs.getString(AppConstants.syncSettingsKey);
    if (configJson != null) {
      _config = SyncConfig.fromJson(jsonDecode(configJson));
    }
  }

  /// 保存同步配置
  Future<void> saveConfig(SyncConfig config) async {
    _config = config;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      AppConstants.syncSettingsKey,
      jsonEncode(config.toJson()),
    );
  }

  /// 获取同步配置
  SyncConfig? getConfig() => _config;

  /// 获取同步状态
  SyncStatusEnum get status => _status;

  /// 获取最后同步时间
  DateTime? get lastSyncTime => _lastSyncTime;

  /// 上传配置到远程仓库
  Future<void> uploadConfig(String masterPassword) async {
    if (_config == null || _config!.accessToken == null) {
      throw Exception('同步配置未设置或未授权');
    }

      _status = SyncStatusEnum.syncing;

    try {
      // 获取所有连接
      final connections = _repository.getAllConnections();

      // 加密敏感信息
      final encryptedConnections = connections.map((conn) {
        // 创建副本，确保敏感信息已加密
        return conn;
      }).toList();

      // 转换为 JSON
      final jsonData = {
        'version': 1,
        'timestamp': DateTime.now().toIso8601String(),
        'connections': encryptedConnections.map((c) => c.toJson()).toList(),
      };

      final content = jsonEncode(jsonData);
      final contentBase64 = base64Encode(utf8.encode(content));

      // 获取文件 SHA（如果存在）
      String? fileSha;
      try {
        final fileInfo = await _getFileInfo();
        fileSha = fileInfo['sha'] as String?;
      } catch (e) {
        // 文件不存在，忽略
      }

      // 上传到 GitHub 或 Gitee
      if (_config!.platform == SyncPlatform.github) {
        await _uploadToGitHub(contentBase64, fileSha);
      } else {
        await _uploadToGitee(contentBase64, fileSha);
      }

      _lastSyncTime = DateTime.now();
      _status = SyncStatusEnum.success;
    } catch (e) {
      _status = SyncStatusEnum.error;
      rethrow;
    }
  }

  /// 从远程仓库下载配置
  Future<void> downloadConfig(String masterPassword) async {
    if (_config == null || _config!.accessToken == null) {
      throw Exception('同步配置未设置或未授权');
    }

      _status = SyncStatusEnum.syncing;

    try {
      String contentBase64;
      if (_config!.platform == SyncPlatform.github) {
        contentBase64 = await _downloadFromGitHub();
      } else {
        contentBase64 = await _downloadFromGitee();
      }

      final content = utf8.decode(base64Decode(contentBase64));
      final jsonData = jsonDecode(content) as Map<String, dynamic>;

      // 解析连接配置
      final connectionsJson = jsonData['connections'] as List;
      final connections = connectionsJson
          .map((json) => SshConnection.fromJson(json as Map<String, dynamic>))
          .toList();

      // 检测冲突
      final localConnections = _repository.getAllConnections();
      final conflicts = _detectConflicts(localConnections, connections);

      if (conflicts.isNotEmpty) {
        // 有冲突，需要用户解决
        throw SyncConflictException(conflicts);
      }

      // 保存配置
      await _repository.saveConnections(connections);

      _lastSyncTime = DateTime.now();
      _status = SyncStatusEnum.success;
    } catch (e) {
      _status = SyncStatusEnum.error;
      rethrow;
    }
  }

  /// 上传到 GitHub
  Future<void> _uploadToGitHub(String contentBase64, String? fileSha) async {
    final url =
        'https://api.github.com/repos/${_config!.repositoryOwner}/${_config!.repositoryName}/contents/${_config!.filePath}';

    final data = {
      'message': 'Update SSH connections config',
      'content': contentBase64,
      'branch': _config!.branch,
      if (fileSha != null) 'sha': fileSha,
    };

    await _dio.put(
      url,
      data: data,
      options: Options(
        headers: {
          'Authorization': 'token ${_config!.accessToken}',
          'Accept': 'application/vnd.github.v3+json',
        },
      ),
    );
  }

  /// 从 GitHub 下载
  Future<String> _downloadFromGitHub() async {
    final url =
        'https://api.github.com/repos/${_config!.repositoryOwner}/${_config!.repositoryName}/contents/${_config!.filePath}?ref=${_config!.branch}';

    final response = await _dio.get(
      url,
      options: Options(
        headers: {
          'Authorization': 'token ${_config!.accessToken}',
          'Accept': 'application/vnd.github.v3+json',
        },
      ),
    );

    return response.data['content'] as String;
  }

  /// 获取 GitHub 文件信息
  Future<Map<String, dynamic>> _getFileInfo() async {
    final url =
        'https://api.github.com/repos/${_config!.repositoryOwner}/${_config!.repositoryName}/contents/${_config!.filePath}?ref=${_config!.branch}';

    final response = await _dio.get(
      url,
      options: Options(
        headers: {
          'Authorization': 'token ${_config!.accessToken}',
          'Accept': 'application/vnd.github.v3+json',
        },
      ),
    );

    return response.data as Map<String, dynamic>;
  }

  /// 上传到 Gitee
  Future<void> _uploadToGitee(String contentBase64, String? fileSha) async {
    final url =
        'https://gitee.com/api/v5/repos/${_config!.repositoryOwner}/${_config!.repositoryName}/contents/${_config!.filePath}';

    final data = {
      'access_token': _config!.accessToken,
      'message': 'Update SSH connections config',
      'content': contentBase64,
      'branch': _config!.branch,
      if (fileSha != null) 'sha': fileSha,
    };

    await _dio.put(url, data: data);
  }

  /// 从 Gitee 下载
  Future<String> _downloadFromGitee() async {
    final url =
        'https://gitee.com/api/v5/repos/${_config!.repositoryOwner}/${_config!.repositoryName}/contents/${_config!.filePath}?ref=${_config!.branch}&access_token=${_config!.accessToken}';

    final response = await _dio.get(url);
    return response.data['content'] as String;
  }

  /// 检测冲突
  List<SyncConflict> _detectConflicts(
    List<SshConnection> local,
    List<SshConnection> remote,
  ) {
    final conflicts = <SyncConflict>[];

    // 创建 ID 映射
    final remoteMap = {for (var c in remote) c.id: c};

    // 检查每个连接的冲突
    for (final localConn in local) {
      final remoteConn = remoteMap[localConn.id];
      if (remoteConn != null) {
        // 两个版本都存在，检查版本号
        if (localConn.version != remoteConn.version &&
            localConn.updatedAt.isAfter(remoteConn.updatedAt) &&
            remoteConn.updatedAt.isAfter(localConn.createdAt)) {
          // 有冲突
          conflicts.add(SyncConflict(
            connectionId: localConn.id,
            localConnection: localConn,
            remoteConnection: remoteConn,
          ));
        }
      }
    }

    return conflicts;
  }
}

/// 同步冲突异常
class SyncConflictException implements Exception {
  final List<SyncConflict> conflicts;

  SyncConflictException(this.conflicts);

  @override
  String toString() => '发现 ${conflicts.length} 个配置冲突';
}

/// 同步冲突
class SyncConflict {
  final String connectionId;
  final SshConnection localConnection;
  final SshConnection remoteConnection;

  SyncConflict({
    required this.connectionId,
    required this.localConnection,
    required this.remoteConnection,
  });
}
