import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../data/models/ssh_connection.dart';
import '../../domain/services/import_export_service.dart';

/// 导入导出提供者
class ImportExportProvider with ChangeNotifier {
  final ImportExportService _service;

  ImportExportProvider(this._service);

  /// 获取当前状态
  ImportExportStatus get status => _service.status;

  /// 获取最后错误信息
  String? get lastError => _service.lastError;

  /// 导出到本地文件
  Future<File?> exportToLocalFile() async {
    notifyListeners();
    try {
      final file = await _service.exportToLocalFile();
      notifyListeners();
      return file;
    } catch (e) {
      notifyListeners();
      rethrow;
    }
  }

  /// 从本地文件导入
  Future<List<SshConnection>> importFromLocalFile() async {
    notifyListeners();
    try {
      final connections = await _service.importFromLocalFile();
      notifyListeners();
      return connections;
    } catch (e) {
      notifyListeners();
      rethrow;
    }
  }

  /// 导入并保存连接
  Future<void> importAndSaveConnections(
    List<SshConnection> connections, {
    bool overwrite = false,
    bool addPrefix = true,
  }) async {
    notifyListeners();
    try {
      await _service.importAndSaveConnections(
        connections,
        overwrite: overwrite,
        addPrefix: addPrefix,
      );
      notifyListeners();
    } catch (e) {
      notifyListeners();
      rethrow;
    }
  }

  /// 获取导出统计信息
  Map<String, dynamic> getExportStats() {
    return _service.getExportStats();
  }

  /// 生成导出摘要
  String generateExportSummary() {
    return _service.generateExportSummary();
  }

  /// 重置状态
  void resetStatus() {
    _service.resetStatus();
    notifyListeners();
  }
}
