import 'package:lbp_ssh/presentation/screens/sftp_browser_screen.dart';

/// 远程文件解析器
/// 解析 ls -la --time-style=long-iso 输出
class FileListParser {
  /// 解析 ls -la 输出
  /// 示例: drwxr-xr-x  2 user user 4096 2024-01-15 10:30 dirname
  static List<FileItem> parse(String output, String currentPath) {
    final lines = output.split('\n');
    final items = <FileItem>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final item = _parseLine(trimmed, currentPath);
      if (item != null) {
        items.add(item);
      }
    }

    return items;
  }

  static FileItem? _parseLine(String line, String currentPath) {
    // 跳过 total 行
    if (line.startsWith('total ')) return null;

    // 解析权限和类型
    // 格式: drwxr-xr-x  2 user user 4096 2024-01-15 10:30 filename
    // 或: -rw-r--r--  1 user user 1234 2024-01-15 09:20 filename

    final parts = line.split(RegExp(r'\s+'));
    if (parts.length < 9) return null;

    final permissions = parts[0];
    final isDirectory = permissions.startsWith('d');

    // 跳过 . 和 ..
    final name = parts.sublist(8).join(' ');
    if (name == '.' || name == '..') return null;

    // 解析大小
    final size = int.tryParse(parts[4]) ?? 0;

    // 解析日期时间
    DateTime? modified;
    if (parts.length >= 10) {
      final dateStr = '${parts[5]} ${parts[6]} ${parts[7]}';
      try {
        modified = DateTime.parse(dateStr);
      } catch (_) {
        // 忽略解析错误
      }
    }

    // 构建完整路径
    final fullPath = currentPath == '/'
        ? '/$name'
        : '$currentPath/$name';

    return FileItem(
      name: name,
      path: fullPath,
      isDirectory: isDirectory,
      size: size,
      modified: modified,
      permissions: permissions,
    );
  }
}
