import 'package:flutter/foundation.dart';
import '../../data/models/ssh_connection.dart';
import '../../data/repositories/connection_repository.dart';

/// 连接列表状态管理
class ConnectionProvider extends ChangeNotifier {
  final ConnectionRepository _repository;
  List<SshConnection> _connections = [];
  bool _isLoading = false;
  String? _error;

  ConnectionProvider(this._repository);

  List<SshConnection> get connections => _connections;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// 加载所有连接
  Future<void> loadConnections() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _connections = _repository.getAllConnections();
      _error = null;
    } catch (e) {
      _error = '加载连接失败: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 添加连接
  Future<void> addConnection(SshConnection connection) async {
    try {
      await _repository.saveConnection(connection);
      await loadConnections();
    } catch (e) {
      _error = '添加连接失败: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// 更新连接
  Future<void> updateConnection(SshConnection connection) async {
    try {
      await _repository.saveConnection(connection);
      await loadConnections();
    } catch (e) {
      _error = '更新连接失败: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// 删除连接
  Future<void> deleteConnection(String id) async {
    try {
      await _repository.deleteConnection(id);
      await loadConnections();
    } catch (e) {
      _error = '删除连接失败: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// 根据 ID 获取连接
  SshConnection? getConnectionById(String id) {
    return _repository.getConnectionById(id);
  }
}
