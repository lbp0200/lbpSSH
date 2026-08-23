import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import '../../data/models/ssh_connection.dart';
import '../../data/repositories/connection_repository.dart';

/// 导入导出状态
enum ImportExportStatus { idle, exporting, importing, success, error }

/// 导入导出服务
///
/// 无状态服务：导入/导出的进度状态由 Riverpod Notifier 持有，
/// 本类只负责文件读写与数据合并等纯逻辑。
class ImportExportService {
  final ConnectionRepository _repository;

  ImportExportService(this._repository);

  /// 导出SSH连接配置到本地文件
  Future<File?> exportToLocalFile() async {
    try {
      // 获取所有连接
      final connections = _repository.getAllConnections();

      if (connections.isEmpty) {
        throw Exception('没有SSH连接配置可导出');
      }

      // 准备导出数据
      final exportData = {
        'appName': 'lbpSSH',
        'appVersion': '1.0.0',
        'exportTime': DateTime.now().toIso8601String(),
        'version': 1,
        'totalConnections': connections.length,
        'connections': connections.map((conn) => conn.toJson()).toList(),
      };

      // 准备 JSON 内容
      final jsonContent = const JsonEncoder.withIndent(
        '  ',
      ).convert(exportData);
      final bytes = utf8.encode(jsonContent);

      // 选择保存位置并写入文件
      final outputFile = await FilePicker.saveFile(
        dialogTitle: '保存SSH连接配置',
        fileName:
            'ssh_connections_export_${DateTime.now().toString().substring(0, 10)}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: Uint8List.fromList(bytes),
      );

      if (outputFile == null) {
        return null;
      }

      return File(outputFile.path);
    } catch (e) {
      rethrow;
    }
  }

  /// 从本地文件导入SSH连接配置
  Future<List<SshConnection>> importFromLocalFile() async {
    try {
      // 选择要导入的文件
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: '选择SSH连接配置文件',
      );

      if (file == null || file.path == null) {
        throw Exception('未选择文件');
      }

      final filePath = file.path!;
      final selectedFile = File(filePath);

      if (!await selectedFile.exists()) {
        throw Exception('文件不存在');
      }

      // 读取文件内容
      final content = await selectedFile.readAsString();
      final Map<String, dynamic> jsonData;

      try {
        jsonData = jsonDecode(content) as Map<String, dynamic>;
      } catch (e) {
        throw Exception('无效的JSON文件格式');
      }

      // 验证文件结构
      if (!_validateExportFile(jsonData)) {
        throw Exception('不是有效的SSH连接配置文件');
      }

      // 解析连接配置
      final connectionsJson = jsonData['connections'] as List;
      final List<SshConnection> importedConnections = [];

      for (final json in connectionsJson) {
        try {
          final connection = SshConnection.fromJson(
            json as Map<String, dynamic>,
          );
          importedConnections.add(connection);
        } catch (e) {
          // 跳过无效的连接配置
          continue;
        }
      }

      if (importedConnections.isEmpty) {
        throw Exception('文件中没有有效的连接配置');
      }

      return importedConnections;
    } catch (e) {
      rethrow;
    }
  }

  /// 验证导出文件格式
  bool _validateExportFile(Map<String, dynamic> data) {
    // 检查必要字段
    if (!data.containsKey('connections') ||
        !data.containsKey('version') ||
        !data.containsKey('exportTime')) {
      return false;
    }

    // 检查connections是否为数组
    if (data['connections'] is! List) {
      return false;
    }

    // 检查是否有至少一个连接配置
    if ((data['connections'] as List).isEmpty) {
      return false;
    }

    // 检查appName（可选）
    if (data.containsKey('appName') && data['appName'] is! String) {
      return false;
    }

    return true;
  }

  /// 合并导入的连接配置
  Future<List<SshConnection>> mergeImportedConnections(
    List<SshConnection> importedConnections, {
    bool overwrite = false,
    bool addPrefix = true,
  }) async {
    final currentConnections = _repository.getAllConnections();
    final Map<String, SshConnection> existingConnections = {
      for (var conn in currentConnections) conn.id: conn,
    };

    final List<SshConnection> mergedConnections = [];
    final Set<String> addedConnectionIds = {};

    // 添加现有连接
    mergedConnections.addAll(currentConnections);

    for (final imported in importedConnections) {
      String finalId = imported.id;
      String finalName = imported.name;

      if (existingConnections.containsKey(imported.id)) {
        if (overwrite) {
          // 覆盖现有连接
          mergedConnections.removeWhere((conn) => conn.id == imported.id);
          // 生成新的ID避免冲突
          finalId =
              '${imported.id}_imported_${DateTime.now().millisecondsSinceEpoch}';
          finalName = addPrefix ? '导入_${imported.name}' : imported.name;
        } else {
          // 跳过重复的连接
          continue;
        }
      }

      final newConnection = imported.copyWith(
        id: finalId,
        name: finalName,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      mergedConnections.add(newConnection);
      addedConnectionIds.add(finalId);
    }

    // 保存合并后的连接
    await _repository.clearAll();
    await _repository.saveConnections(mergedConnections);

    return mergedConnections
        .where(
          (conn) =>
              addedConnectionIds.contains(conn.id) ||
              existingConnections.containsKey(conn.id),
        )
        .toList();
  }

  /// 导入并保存连接配置
  Future<void> importAndSaveConnections(
    List<SshConnection> connections, {
    bool overwrite = false,
    bool addPrefix = true,
  }) async {
    await mergeImportedConnections(
      connections,
      overwrite: overwrite,
      addPrefix: addPrefix,
    );
  }

  /// 获取导出统计信息
  Map<String, dynamic> getExportStats() {
    final connections = _repository.getAllConnections();

    int passwordCount = 0;
    int keyCount = 0;
    int keyWithPasswordCount = 0;
    int jumpHostCount = 0;

    for (final conn in connections) {
      switch (conn.authType) {
        case AuthType.password:
          passwordCount++;
          break;
        case AuthType.key:
          keyCount++;
          break;
        case AuthType.keyWithPassword:
          keyWithPasswordCount++;
          break;
        case AuthType.sshConfig:
          // SSH Config 认证不计入密码或密钥统计
          break;
      }

      if (conn.jumpHost != null) {
        jumpHostCount++;
      }
    }

    return {
      'totalConnections': connections.length,
      'passwordAuth': passwordCount,
      'keyAuth': keyCount,
      'keyWithPasswordAuth': keyWithPasswordCount,
      'jumpHostConnections': jumpHostCount,
      'lastUpdated': connections.isNotEmpty
          ? connections
                .map((conn) => conn.updatedAt)
                .reduce((a, b) => a.isAfter(b) ? a : b)
          : null,
    };
  }

  /// 重置状态
  void resetStatus() {}

  /// 导出配置摘要
  String generateExportSummary() {
    final stats = getExportStats();
    final buffer = StringBuffer();

    buffer.writeln('SSH连接配置导出摘要');
    buffer.writeln('=' * 30);
    buffer.writeln('总连接数: ${stats['totalConnections']}');
    buffer.writeln('密码认证: ${stats['passwordAuth']}');
    buffer.writeln('密钥认证: ${stats['keyAuth']}');
    buffer.writeln('密钥+密码: ${stats['keyWithPasswordAuth']}');
    buffer.writeln('跳板机连接: ${stats['jumpHostConnections']}');

    if (stats['lastUpdated'] != null) {
      buffer.writeln('最后更新: ${stats['lastUpdated']}');
    }

    buffer.writeln('导出时间: ${DateTime.now()}');
    buffer.writeln();
    buffer.writeln('注意: 此配置文件包含敏感信息(密码、私钥等)');
    buffer.writeln('请妥善保管，不要在不安全的网络环境中传输');

    return buffer.toString();
  }
}
