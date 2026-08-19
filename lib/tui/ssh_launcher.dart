import 'dart:io';
import '../../data/models/ssh_connection.dart';

/// ssh 启动结果
class SshLaunchResult {
  const SshLaunchResult({required this.succeeded, this.errorMessage});

  /// 是否成功退出（exitCode == 0）
  final bool succeeded;

  /// 失败时的错误信息（stderr 内容或异常消息）
  final String? errorMessage;
}

/// 可注入的进程执行器（测试时可替换以模拟 `Process.run`）
typedef SshProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

/// 启动 ssh 连接。
///
/// 参数数组直接传给 ssh 可执行文件，不经过 shell，避免 username/host
/// 来自配置文件时被 shell 拼接造成命令注入。
/// [run] 可注入以在测试中模拟 `Process.run`。
Future<SshLaunchResult> launchSsh(
  SshConnection conn, {
  SshProcessRunner? run,
}) async {
  final runner = run ?? Process.run;
  try {
    final result = await runner('ssh', [
      '-p',
      conn.port.toString(),
      '${conn.username}@${conn.host}',
    ]);
    if (result.exitCode == 0) {
      return const SshLaunchResult(succeeded: true);
    }
    final stderrText = result.stderr.toString();
    return SshLaunchResult(
      succeeded: false,
      errorMessage: stderrText.isEmpty ? null : stderrText,
    );
  } catch (e) {
    return SshLaunchResult(succeeded: false, errorMessage: 'SSH failed: $e');
  }
}
