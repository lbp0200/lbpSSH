/// 应用常量
class AppConstants {
  // 应用信息
  static const String appName = 'SSH Manager';
  static const String appVersion = '1.0.2';

  // 存储键名
  static const String syncSettingsKey = 'sync_settings';
  static const String appConfigKey = 'app_config';

  // 同步配置
  static const String defaultSyncFileName = 'ssh_connections.json';
  static const String defaultSyncBranch = 'main';

  // GitHub OAuth
  static const String githubClientId = 'your_github_client_id';
  static const String githubRedirectUri = 'lbpssh://oauth/callback';

  // Gitee OAuth
  static const String giteeClientId = 'your_gitee_client_id';
  static const String giteeRedirectUri = 'lbpssh://oauth/callback';

  // 默认值
  static const int defaultSshPort = 22;
  static const int defaultSyncIntervalMinutes = 5;

  // 文件路径
  static const String configDirName = 'lbpSSH';
}
