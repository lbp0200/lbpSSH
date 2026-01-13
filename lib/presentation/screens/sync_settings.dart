import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/services/sync_service.dart' show SyncStatusEnum, SyncPlatform, SyncConfig;
import '../providers/sync_provider.dart';

/// 同步设置界面
class SyncSettingsScreen extends StatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  State<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends State<SyncSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ownerController = TextEditingController();
  final _repoController = TextEditingController();
  final _branchController = TextEditingController();
  final _filePathController = TextEditingController();
  final _tokenController = TextEditingController();
  final _masterPasswordController = TextEditingController();

  SyncPlatform _platform = SyncPlatform.github;
  bool _autoSync = false;
  int _syncInterval = 5;
  bool _obscureToken = true;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  void _loadConfig() {
    final provider = Provider.of<SyncProvider>(context, listen: false);
    final config = provider.config;

    if (config != null) {
      _platform = config.platform;
      _ownerController.text = config.repositoryOwner;
      _repoController.text = config.repositoryName;
      _branchController.text = config.branch;
      _filePathController.text = config.filePath;
      _autoSync = config.autoSync;
      _syncInterval = config.syncIntervalMinutes;
      // 不显示 token，只显示占位符
      _tokenController.text = config.accessToken != null ? '***' : '';
    } else {
      _branchController.text = 'main';
      _filePathController.text = 'ssh_connections.json';
    }
  }

  @override
  void dispose() {
    _ownerController.dispose();
    _repoController.dispose();
    _branchController.dispose();
    _filePathController.dispose();
    _tokenController.dispose();
    _masterPasswordController.dispose();
    super.dispose();
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = Provider.of<SyncProvider>(context, listen: false);

    // 如果 token 是占位符，保持原有 token
    String? accessToken = _tokenController.text;
    if (accessToken == '***') {
      accessToken = provider.config?.accessToken;
    }

    final config = SyncConfig(
      platform: _platform,
      accessToken: accessToken,
      repositoryOwner: _ownerController.text,
      repositoryName: _repoController.text,
      branch: _branchController.text,
      filePath: _filePathController.text,
      autoSync: _autoSync,
      syncIntervalMinutes: _syncInterval,
    );

    try {
      await provider.saveConfig(config);

      // 设置主密码
      if (_masterPasswordController.text.isNotEmpty) {
        provider.setMasterPassword(_masterPasswordController.text);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('配置已保存')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  Future<void> _testConnection() async {
    final provider = Provider.of<SyncProvider>(context, listen: false);
    final config = provider.config;

    if (config == null || config.accessToken == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先配置并保存设置')),
        );
      }
      return;
    }

    try {
      // 尝试下载配置来测试连接
      await provider.downloadConfig();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('连接测试成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('连接测试失败: $e')),
        );
      }
    }
  }

  Future<void> _openOAuthUrl() async {
    final url = _platform == SyncPlatform.github
        ? 'https://github.com/login/oauth/authorize?client_id=YOUR_CLIENT_ID&redirect_uri=sshmanager://oauth/callback&scope=repo'
        : 'https://gitee.com/oauth/authorize?client_id=YOUR_CLIENT_ID&redirect_uri=sshmanager://oauth/callback&response_type=code';

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('同步设置'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 平台选择
            DropdownButtonFormField<SyncPlatform>(
              value: _platform,
              decoration: const InputDecoration(
                labelText: '同步平台',
              ),
              items: const [
                DropdownMenuItem(
                  value: SyncPlatform.github,
                  child: Text('GitHub'),
                ),
                DropdownMenuItem(
                  value: SyncPlatform.gitee,
                  child: Text('Gitee'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _platform = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            // OAuth 认证
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'OAuth 认证',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '点击下方按钮在浏览器中完成 OAuth 认证，然后将返回的 Access Token 粘贴到下方。',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _openOAuthUrl,
                      icon: const Icon(Icons.open_in_browser),
                      label: Text(
                        _platform == SyncPlatform.github
                            ? '在 GitHub 中授权'
                            : '在 Gitee 中授权',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _tokenController,
                      decoration: InputDecoration(
                        labelText: 'Access Token',
                        hintText: '粘贴 OAuth 返回的 Access Token',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureToken ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureToken = !_obscureToken;
                            });
                          },
                        ),
                      ),
                      obscureText: _obscureToken,
                      validator: (value) {
                        if (value == null || value.isEmpty || value == '***') {
                          return '请输入 Access Token';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 仓库配置
            TextFormField(
              controller: _ownerController,
              decoration: InputDecoration(
                labelText: '仓库所有者',
                hintText: _platform == SyncPlatform.github
                    ? '例如：username'
                    : '例如：username',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入仓库所有者';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _repoController,
              decoration: const InputDecoration(
                labelText: '仓库名称',
                hintText: '例如：ssh-configs',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入仓库名称';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _branchController,
                    decoration: const InputDecoration(
                      labelText: '分支',
                      hintText: 'main',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _filePathController,
                    decoration: const InputDecoration(
                      labelText: '文件路径',
                      hintText: 'ssh_connections.json',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 主密码
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '主密码',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '用于加密敏感信息。如果已设置过，留空则保持原密码。',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _masterPasswordController,
                      decoration: InputDecoration(
                        labelText: '主密码',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      obscureText: _obscurePassword,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 自动同步
            SwitchListTile(
              title: const Text('自动同步'),
              subtitle: const Text('定期自动同步配置'),
              value: _autoSync,
              onChanged: (value) {
                setState(() {
                  _autoSync = value;
                });
              },
            ),

            if (_autoSync) ...[
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _syncInterval.toString(),
                decoration: const InputDecoration(
                  labelText: '同步间隔（分钟）',
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  _syncInterval = int.tryParse(value) ?? 5;
                },
              ),
            ],

            const SizedBox(height: 32),

            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _testConnection,
                    child: const Text('测试连接'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveConfig,
                    child: const Text('保存配置'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 同步操作
            Consumer<SyncProvider>(
              builder: (context, provider, child) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      onPressed: provider.status == SyncStatusEnum.syncing
                          ? null
                          : () => _uploadConfig(provider),
                      icon: const Icon(Icons.upload),
                      label: const Text('上传配置'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: provider.status == SyncStatusEnum.syncing
                          ? null
                          : () => _downloadConfig(provider),
                      icon: const Icon(Icons.download),
                      label: const Text('下载配置'),
                    ),
                    if (provider.status == SyncStatusEnum.syncing)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (provider.lastSyncTime != null)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          '最后同步时间: ${provider.lastSyncTime}',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadConfig(SyncProvider provider) async {
    if (provider.config == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先配置同步设置')),
      );
      return;
    }

    if (_masterPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入主密码')),
      );
      return;
    }

    provider.setMasterPassword(_masterPasswordController.text);

    try {
      await provider.uploadConfig();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('配置已上传')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传失败: $e')),
        );
      }
    }
  }

  Future<void> _downloadConfig(SyncProvider provider) async {
    if (provider.config == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先配置同步设置')),
      );
      return;
    }

    if (_masterPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入主密码')),
      );
      return;
    }

    provider.setMasterPassword(_masterPasswordController.text);

    try {
      await provider.downloadConfig();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('配置已下载')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败: $e')),
        );
      }
    }
  }
}
