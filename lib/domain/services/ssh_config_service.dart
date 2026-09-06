import 'dart:io';
import 'package:path/path.dart' as path;
import '../../data/models/ssh_connection.dart';

/// SSH Config 文件服务
class SshConfigService {
  /// 获取默认 SSH config 文件路径
  static String getDefaultConfigPath() {
    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    return path.join(home, '.ssh', 'config');
  }

  /// 读取并解析 SSH config 文件
  static List<SshConfigEntry> readConfigFile({String? filePath}) {
    final configPath = filePath ?? getDefaultConfigPath();
    final configFile = File(configPath);

    if (!configFile.existsSync()) {
      return [];
    }

    try {
      final content = configFile.readAsStringSync();
      return SshConfigEntry.parse(content);
    } catch (e) {
      return [];
    }
  }

  /// 查找匹配的主机配置
  static SshConfigEntry? findHostEntry(String hostPattern, {String? filePath}) {
    final entries = readConfigFile(filePath: filePath);

    // 支持通配符匹配
    final regex = _globToRegex(hostPattern);

    for (final entry in entries) {
      if (regex.hasMatch(entry.hostName)) {
        return entry;
      }
    }

    // 精确匹配
    for (final entry in entries) {
      if (entry.hostName == hostPattern) {
        return entry;
      }
    }

    // 标准 SSH 语义：通配符位于 config 侧（如 `Host *.example.com`），而查找的是字面主机名。
    // 前两遍只把"搜索词"当 glob / 精确匹配，无法命中配置里的通配 Host —— 这里补第三遍：
    // hostName 可能是空格分隔的多个模式（`Host foo bar *.baz`），逐一对字面主机做 glob 匹配。
    for (final entry in entries) {
      for (final pattern in entry.hostName.split(RegExp(r'\s+'))) {
        if (_globToRegex(pattern).hasMatch(hostPattern)) {
          return entry;
        }
      }
    }

    return null;
  }

  /// 将 glob 模式转换为正则表达式
  static RegExp _globToRegex(String pattern) {
    // 仅 `*`（任意串）与 `?`（单字符）是通配符；其余字符按字面匹配。
    // 因此需转义其正则元字符，避免 `.`/`[`/`+` 等被当作正则特殊符号而误匹配
    // （例如模式 `app1.example.com` 中的 `.` 不应匹配任意字符）。
    final buffer = StringBuffer();
    for (final c in pattern.split('')) {
      if (c == '*') {
        buffer.write('.*');
      } else if (c == '?') {
        buffer.write('.');
      } else {
        buffer.write(RegExp.escape(c));
      }
    }
    return RegExp('^$buffer\$');
  }

  /// 检查 SSH config 文件是否存在
  static bool configFileExists({String? filePath}) {
    final configPath = filePath ?? getDefaultConfigPath();
    return File(configPath).existsSync();
  }
}
