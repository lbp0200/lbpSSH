import 'dart:io';

/// 解析 TUI 配置文件路径。
///
/// [env] 可注入以便测试；默认使用 [Platform.environment]。
File resolveTuiConfigFile([Map<String, String>? env]) {
  final environment = env ?? Platform.environment;
  final home = environment['HOME'] ?? '.';
  final configDir = environment['LBPSSH_CONFIG_DIR'] ?? '$home/.lbpSSH';
  return File('$configDir/ssh_connections.json');
}
