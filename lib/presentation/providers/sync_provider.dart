import 'package:flutter/foundation.dart';
import '../../domain/services/sync_service.dart';

/// 同步状态管理
class SyncProvider extends ChangeNotifier {
  final SyncService _syncService;

  SyncProvider(this._syncService);

  SyncConfig? get config => _syncService.getConfig();
  SyncStatusEnum get status => _syncService.status;
  DateTime? get lastSyncTime => _syncService.lastSyncTime;

  /// 保存同步配置
  Future<void> saveConfig(SyncConfig config) async {
    await _syncService.saveConfig(config);
  }

  /// 上传配置
  Future<void> uploadConfig() async {
    notifyListeners();
    try {
      await _syncService.uploadConfig();
    } finally {
      notifyListeners();
    }
  }

  /// 下载配置
  Future<void> downloadConfig() async {
    notifyListeners();
    try {
      await _syncService.downloadConfig();
    } finally {
      notifyListeners();
    }
  }

  /// 测试连接（跳过冲突检测）
  Future<void> testConnection() async {
    notifyListeners();
    try {
      await _syncService.downloadConfig(skipConflictCheck: true);
    } finally {
      notifyListeners();
    }
  }
}
