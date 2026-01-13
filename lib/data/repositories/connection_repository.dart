import 'package:hive/hive.dart';
import '../models/ssh_connection.dart';
import 'dart:convert';

/// 连接配置仓库
class ConnectionRepository {
  static const String _boxName = 'ssh_connections';
  late Box _box;

  /// 初始化仓库
  Future<void> init() async {
    // 使用字符串类型存储，手动序列化
    _box = await Hive.openBox(_boxName);
  }

  /// 获取所有连接
  List<SshConnection> getAllConnections() {
    return _box.values
        .map((value) => SshConnection.fromJson(
              jsonDecode(value as String) as Map<String, dynamic>,
            ))
        .toList();
  }

  /// 根据 ID 获取连接
  SshConnection? getConnectionById(String id) {
    final value = _box.get(id);
    if (value == null) return null;
    return SshConnection.fromJson(
      jsonDecode(value as String) as Map<String, dynamic>,
    );
  }

  /// 保存连接
  Future<void> saveConnection(SshConnection connection) async {
    final updated = connection.copyWith(
      updatedAt: DateTime.now(),
      version: connection.version + 1,
    );
    await _box.put(connection.id, jsonEncode(updated.toJson()));
  }

  /// 删除连接
  Future<void> deleteConnection(String id) async {
    await _box.delete(id);
  }

  /// 批量保存连接（用于同步）
  Future<void> saveConnections(List<SshConnection> connections) async {
    for (final connection in connections) {
      await _box.put(connection.id, jsonEncode(connection.toJson()));
    }
  }

  /// 清空所有连接
  Future<void> clearAll() async {
    await _box.clear();
  }

  /// 关闭仓库
  Future<void> close() async {
    await _box.close();
  }
}

