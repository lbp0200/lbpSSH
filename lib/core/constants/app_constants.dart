/// 应用常量
class AppConstants {
  // 存储键名
  static const String syncSettingsKey = 'sync_settings';
  static const String appConfigKey = 'app_config';

  // 默认值
  static const int defaultSyncIntervalMinutes = 5;

  // 默认 Gist 文件名
  static const String defaultGistFilename = 'ssh_connections.json';

  // 文件路径
  static const String configDirName = 'lbpSSH';

  // 应用标识（与 pubspec.yaml 保持一致，避免 ImportExportService 硬编码脱节）
  static const String appName = 'lbpSSH';
  static const String appVersion = '1.9.8';

  // 导入前缀
  static const String importPrefix = '导入_';

  // 导出文件名日期格式
  static const String exportFilePrefix = 'ssh_connections_export_';
}
