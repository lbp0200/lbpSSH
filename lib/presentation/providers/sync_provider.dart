import 'package:flutter/foundation.dart';
import '../../domain/services/sync_service.dart';

/// 同步状态管理
class SyncProvider extends ChangeNotifier {
  final SyncService _syncService;
  String? _masterPassword;

  SyncProvider(this._syncService);

  SyncConfig? get config => _syncService.getConfig();
  SyncStatusEnum get status => _syncService.status;
  DateTime? get lastSyncTime => _syncService.lastSyncTime;

  /// 设置主密码
  void setMasterPassword(String password) {
    _masterPassword = password;
  }

  /// 保存同步配置
  Future<void> saveConfig(SyncConfig config) async {
    await _syncService.saveConfig(config);
    notifyListeners();
  }

  /// 上传配置
  Future<void> uploadConfig() async {
    if (_masterPassword == null) {
      throw Exception('主密码未设置');
    }

    notifyListeners();
    try {
      await _syncService.uploadConfig(_masterPassword!);
    } finally {
      notifyListeners();
    }
  }

  /// 下载配置
  Future<void> downloadConfig() async {
    if (_masterPassword == null) {
      throw Exception('主密码未设置');
    }

    notifyListeners();
    try {
      await _syncService.downloadConfig(_masterPassword!);
    } finally {
      notifyListeners();
    }
  }
}
