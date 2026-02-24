import 'dart:async';

/// 终端输入服务抽象接口
/// 用于统一 SSH 和本地终端服务
abstract class TerminalInputService {
  /// 输出流
  Stream<String> get outputStream;

  /// 状态流（用于通知连接/断开状态）
  Stream<bool> get stateStream;

  /// 发送输入
  void sendInput(String input);

  /// 执行命令
  Future<String> executeCommand(String command, {bool silent = false});

  /// 清理资源
  void dispose();
}
