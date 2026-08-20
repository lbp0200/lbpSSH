import 'terminal_service.dart';

/// Kitty 协议服务基类
///
/// 统一管理终端会话引用、连接状态检查与控制序列发送，
/// 各 Kitty 扩展服务继承本类，避免重复实现相同的样板代码。
abstract class KittyServiceBase {
  KittyServiceBase({TerminalSession? session}) : _session = session;

  /// 底层终端会话，未连接时为 null
  final TerminalSession? _session;

  /// 是否已连接
  bool get isConnected => _session != null;

  /// 获取当前会话，未连接时抛出异常
  TerminalSession get session {
    final s = _session;
    if (s == null) {
      throw Exception('未连接到终端');
    }
    return s;
  }

  /// 获取当前会话，未连接时为 null（供需要空安全访问的子类使用）
  TerminalSession? get sessionOrNull => _session;

  /// 向终端写入原始数据，未连接时抛出异常
  void writeRaw(String data) => session.writeRaw(data);

  /// 若已连接则向终端写入原始数据，否则静默忽略
  void writeRawIfConnected(String data) => sessionOrNull?.writeRaw(data);
}
