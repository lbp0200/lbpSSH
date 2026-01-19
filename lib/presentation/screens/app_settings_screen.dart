import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../data/models/terminal_config.dart';
import '../../data/models/default_terminal_config.dart';
import '../../domain/services/app_config_service.dart';
import '../providers/app_config_provider.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  int _selectedIndex = 0;

  final List<String> _tabs = ['终端显示', '默认终端', '同步设置', '导入导出'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('应用设置')),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: _tabs.map((tab) {
              return NavigationRailDestination(
                icon: Icon(_getTabIcon(tab)),
                label: Text(tab),
              );
            }).toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                TerminalDisplaySettings(),
                DefaultTerminalSettings(),
                SyncSettings(),
                ImportExportSettings(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTabIcon(String tab) {
    switch (tab) {
      case '终端显示':
        return Icons.text_fields;
      case '默认终端':
        return Icons.terminal;
      case '同步设置':
        return Icons.sync;
      case '导入导出':
        return Icons.import_export;
      default:
        return Icons.settings;
    }
  }
}

class TerminalDisplaySettings extends StatefulWidget {
  const TerminalDisplaySettings({super.key});

  @override
  State<TerminalDisplaySettings> createState() =>
      _TerminalDisplaySettingsState();
}

class _TerminalDisplaySettingsState extends State<TerminalDisplaySettings> {
  late TerminalConfig _config;
  final _fontSizeController = TextEditingController();
  final _fontWeightController = TextEditingController();
  final _letterSpacingController = TextEditingController();
  final _lineHeightController = TextEditingController();
  final _paddingController = TextEditingController();
  final _fontFamilyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  void _loadConfig() {
    final provider = Provider.of<AppConfigProvider>(context, listen: false);
    _config = provider.terminalConfig;
    _fontSizeController.text = _config.fontSize.toInt().toString();
    _fontWeightController.text = _config.fontWeight.toString();
    _letterSpacingController.text = _config.letterSpacing.toString();
    _lineHeightController.text = _config.lineHeight.toString();
    _paddingController.text = _config.padding.toString();
    _fontFamilyController.text = _config.fontFamily;
  }

  @override
  void dispose() {
    _fontSizeController.dispose();
    _fontWeightController.dispose();
    _letterSpacingController.dispose();
    _lineHeightController.dispose();
    _paddingController.dispose();
    _fontFamilyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '终端字体设置',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _fontFamilyController,
            decoration: const InputDecoration(
              labelText: '字体家族',
              hintText: 'JetBrainsMono',
            ),
            onChanged: (value) {
              _config = _config.copyWith(fontFamily: value);
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _fontSizeController,
                  decoration: const InputDecoration(
                    labelText: '字体大小',
                    suffixText: 'px',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  onChanged: (value) {
                    final fontSize = int.tryParse(value);
                    if (fontSize != null && fontSize > 0) {
                      _config = _config.copyWith(fontSize: fontSize.toDouble());
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _fontWeightController,
                  decoration: const InputDecoration(
                    labelText: '字重',
                    suffixText: '100-900',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  onChanged: (value) {
                    final fontWeight = int.tryParse(value);
                    if (fontWeight != null && fontWeight >= 100 && fontWeight <= 900) {
                      _config = _config.copyWith(fontWeight: fontWeight);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _letterSpacingController,
                  decoration: const InputDecoration(
                    labelText: '字母间距',
                    suffixText: 'em',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final letterSpacing = double.tryParse(value);
                    if (letterSpacing != null) {
                      _config = _config.copyWith(letterSpacing: letterSpacing);
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _lineHeightController,
                  decoration: const InputDecoration(
                    labelText: '行高',
                    suffixText: '倍',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final lineHeight = double.tryParse(value);
                    if (lineHeight != null) {
                      _config = _config.copyWith(lineHeight: lineHeight);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _paddingController,
            decoration: const InputDecoration(
              labelText: '内边距',
              suffixText: 'px',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            onChanged: (value) {
              final padding = int.tryParse(value);
              if (padding != null && padding >= 0) {
                _config = _config.copyWith(padding: padding);
              }
            },
          ),
          const SizedBox(height: 24),
          const Text(
            '颜色设置',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: _config.backgroundColor,
                  decoration: const InputDecoration(labelText: '背景颜色'),
                  onChanged: (value) {
                    _config = _config.copyWith(backgroundColor: value);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  initialValue: _config.foregroundColor,
                  decoration: const InputDecoration(labelText: '前景颜色'),
                  onChanged: (value) {
                    _config = _config.copyWith(foregroundColor: value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: _config.cursorColor,
            decoration: const InputDecoration(labelText: '光标颜色'),
            onChanged: (value) {
              _config = _config.copyWith(cursorColor: value);
            },
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              OutlinedButton(
                onPressed: () {
                  _loadConfig();
                  setState(() {});
                },
                child: const Text('重置'),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final provider = Provider.of<AppConfigProvider>(
                      context,
                      listen: false,
                    );
                    await provider.saveTerminalConfig(_config);
                    if (mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('设置已保存')));
                    }
                  },
                  child: const Text('保存设置'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DefaultTerminalSettings extends StatefulWidget {
  const DefaultTerminalSettings({super.key});

  @override
  State<DefaultTerminalSettings> createState() =>
      _DefaultTerminalSettingsState();
}

class _DefaultTerminalSettingsState extends State<DefaultTerminalSettings> {
  late DefaultTerminalConfig _config;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<AppConfigProvider>(context, listen: false);
    _config = provider.defaultTerminalConfig;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'macOS 默认终端',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '选择执行 SSH 连接时打开的终端应用',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<TerminalType>(
            value: _config.execMac,
            decoration: const InputDecoration(labelText: '终端类型'),
            items: const [
              DropdownMenuItem(
                value: TerminalType.iterm2,
                child: Text('iTerm2'),
              ),
              DropdownMenuItem(
                value: TerminalType.terminal,
                child: Text('Terminal (系统终端)'),
              ),
              DropdownMenuItem(
                value: TerminalType.alacritty,
                child: Text('Alacritty'),
              ),
              DropdownMenuItem(value: TerminalType.kitty, child: Text('Kitty')),
              DropdownMenuItem(
                value: TerminalType.wezterm,
                child: Text('WezTerm'),
              ),
              DropdownMenuItem(value: TerminalType.custom, child: Text('自定义')),
            ],
            onChanged: (value) {
              setState(() {
                _config = _config.copyWith(execMac: value);
              });
            },
          ),
          if (_config.execMac == TerminalType.custom) ...[
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _config.execMacCustom,
              decoration: const InputDecoration(
                labelText: '自定义命令',
                hintText: '例如：open -a /Applications/MyTerminal.app',
              ),
              onChanged: (value) {
                setState(() {
                  _config = _config.copyWith(execMacCustom: value);
                });
              },
            ),
          ],
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          const Text(
            'Windows 默认终端',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '选择执行 SSH 连接时打开的终端应用',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<TerminalType>(
            value: _config.execWindows,
            decoration: const InputDecoration(labelText: '终端类型'),
            items: const [
              DropdownMenuItem(
                value: TerminalType.windowsTerminal,
                child: Text('Windows Terminal'),
              ),
              DropdownMenuItem(
                value: TerminalType.powershell,
                child: Text('PowerShell'),
              ),
              DropdownMenuItem(value: TerminalType.cmd, child: Text('CMD')),
              DropdownMenuItem(value: TerminalType.custom, child: Text('自定义')),
            ],
            onChanged: (value) {
              setState(() {
                _config = _config.copyWith(execWindows: value);
              });
            },
          ),
          if (_config.execWindows == TerminalType.custom) ...[
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _config.execWindowsCustom,
              decoration: const InputDecoration(
                labelText: '自定义命令',
                hintText: '例如：C:\\Path\\To\\Terminal.exe',
              ),
              onChanged: (value) {
                setState(() {
                  _config = _config.copyWith(execWindowsCustom: value);
                });
              },
            ),
          ],
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          const Text(
            'Linux 默认终端',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '选择执行 SSH 连接时打开的终端应用',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<TerminalType>(
            value: _config.execLinux,
            decoration: const InputDecoration(labelText: '终端类型'),
            items: const [
              DropdownMenuItem(
                value: TerminalType.terminal,
                child: Text('系统默认终端'),
              ),
              DropdownMenuItem(
                value: TerminalType.alacritty,
                child: Text('Alacritty'),
              ),
              DropdownMenuItem(value: TerminalType.kitty, child: Text('Kitty')),
              DropdownMenuItem(
                value: TerminalType.wezterm,
                child: Text('WezTerm'),
              ),
              DropdownMenuItem(value: TerminalType.custom, child: Text('自定义')),
            ],
            onChanged: (value) {
              setState(() {
                _config = _config.copyWith(execLinux: value);
              });
            },
          ),
          if (_config.execLinux == TerminalType.custom) ...[
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _config.execLinuxCustom,
              decoration: const InputDecoration(
                labelText: '自定义命令',
                hintText: '例如：gnome-terminal',
              ),
              onChanged: (value) {
                setState(() {
                  _config = _config.copyWith(execLinuxCustom: value);
                });
              },
            ),
          ],
          const SizedBox(height: 32),
          Row(
            children: [
              OutlinedButton(
                onPressed: () {
                  _config = DefaultTerminalConfig.defaultConfig;
                  setState(() {});
                },
                child: const Text('重置'),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final provider = Provider.of<AppConfigProvider>(
                      context,
                      listen: false,
                    );
                    await provider.saveDefaultTerminalConfig(_config);
                    if (mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('设置已保存')));
                    }
                  },
                  child: const Text('保存设置'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SyncSettings extends StatefulWidget {
  const SyncSettings({super.key});

  @override
  State<SyncSettings> createState() => _SyncSettingsState();
}

class _SyncSettingsState extends State<SyncSettings> {
  final _formKey = GlobalKey<FormState>();
  final _ownerController = TextEditingController();
  final _repoController = TextEditingController();
  final _branchController = TextEditingController();
  final _filePathController = TextEditingController();
  final _gistIdController = TextEditingController();
  final _gistFileNameController = TextEditingController();
  final _tokenController = TextEditingController();
  final _giteeGistIdController = TextEditingController();

  SyncPlatform _platform = SyncPlatform.github;
  bool _autoSync = false;
  int _syncInterval = 5;
  bool _obscureToken = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  void _loadConfig() {
    final provider = Provider.of<AppConfigProvider>(context, listen: false);
    final config = provider.syncConfig;

    if (config != null) {
      _platform = config.platform;
      _ownerController.text = config.repositoryOwner ?? '';
      _repoController.text = config.repositoryName ?? '';
      _branchController.text = config.branch ?? 'main';
      _filePathController.text = config.filePath ?? 'ssh_connections.json';
      _gistIdController.text = config.gistId ?? '';
      _gistFileNameController.text =
          config.gistFileName ?? 'ssh_connections.json';
      _giteeGistIdController.text = config.gistId ?? '';
      _autoSync = config.autoSync;
      _syncInterval = config.syncIntervalMinutes;
      _tokenController.text = config.accessToken != null ? '***' : '';
    } else {
      _branchController.text = 'main';
      _filePathController.text = 'ssh_connections.json';
      _gistFileNameController.text = 'ssh_connections.json';
    }
  }

  @override
  void dispose() {
    _ownerController.dispose();
    _repoController.dispose();
    _branchController.dispose();
    _filePathController.dispose();
    _gistIdController.dispose();
    _gistFileNameController.dispose();
    _tokenController.dispose();
    _giteeGistIdController.dispose();
    super.dispose();
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = Provider.of<AppConfigProvider>(context, listen: false);

    String? accessToken = _tokenController.text;
    if (accessToken == '***') {
      accessToken = provider.syncConfig?.accessToken;
    }

    String? gistId;
    if (_platform == SyncPlatform.gist) {
      gistId = _gistIdController.text;
    } else if (_platform == SyncPlatform.giteeGist) {
      gistId = _giteeGistIdController.text;
    }

    final config = SyncConfig(
      platform: _platform,
      accessToken: accessToken,
      repositoryOwner:
          _platform != SyncPlatform.gist && _platform != SyncPlatform.giteeGist
          ? _ownerController.text
          : null,
      repositoryName:
          _platform != SyncPlatform.gist && _platform != SyncPlatform.giteeGist
          ? _repoController.text
          : null,
      branch:
          _platform != SyncPlatform.gist && _platform != SyncPlatform.giteeGist
          ? _branchController.text
          : null,
      filePath:
          _platform != SyncPlatform.gist && _platform != SyncPlatform.giteeGist
          ? _filePathController.text
          : null,
      gistId: gistId,
      gistFileName: _platform == SyncPlatform.gist
          ? _gistFileNameController.text
          : null,
      autoSync: _autoSync,
      syncIntervalMinutes: _syncInterval,
    );

    try {
      await provider.saveSyncConfig(config);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('配置已保存')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<SyncPlatform>(
              value: _platform,
              decoration: const InputDecoration(labelText: '同步平台'),
              items: const [
                DropdownMenuItem(
                  value: SyncPlatform.github,
                  child: Text('GitHub Repository'),
                ),
                DropdownMenuItem(
                  value: SyncPlatform.gitee,
                  child: Text('Gitee Repository'),
                ),
                DropdownMenuItem(
                  value: SyncPlatform.gist,
                  child: Text('GitHub Gist'),
                ),
                DropdownMenuItem(
                  value: SyncPlatform.giteeGist,
                  child: Text('Gitee Gist'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _platform = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '认证令牌',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _tokenController,
                      decoration: InputDecoration(
                        labelText: 'Access Token',
                        hintText: _platform == SyncPlatform.giteeGist
                            ? '输入 Gitee Access Token'
                            : '输入 GitHub Access Token',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureToken
                                ? Icons.visibility
                                : Icons.visibility_off,
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
            if (_platform == SyncPlatform.gist) ...[
              TextFormField(
                controller: _gistIdController,
                decoration: const InputDecoration(
                  labelText: 'Gist ID（可选）',
                  hintText: '留空将创建新 Gist',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _gistFileNameController,
                decoration: const InputDecoration(
                  labelText: '文件名',
                  hintText: 'ssh_connections.json',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入文件名';
                  }
                  return null;
                },
              ),
            ] else if (_platform == SyncPlatform.giteeGist) ...[
              TextFormField(
                controller: _giteeGistIdController,
                decoration: const InputDecoration(
                  labelText: 'Gist ID（可选）',
                  hintText: '留空将创建新 Gist',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _gistFileNameController,
                decoration: const InputDecoration(
                  labelText: '文件名',
                  hintText: 'ssh_connections.json',
                ),
              ),
            ] else ...[
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
            ],
            const SizedBox(height: 24),
            SwitchListTile(
              title: const Text('自动同步'),
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
                decoration: const InputDecoration(labelText: '同步间隔（分钟）'),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  _syncInterval = int.tryParse(value) ?? 5;
                },
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton(onPressed: _saveConfig, child: const Text('保存配置')),
          ],
        ),
      ),
    );
  }
}

class ImportExportSettings extends StatefulWidget {
  const ImportExportSettings({super.key});

  @override
  State<ImportExportSettings> createState() => _ImportExportSettingsState();
}

class _ImportExportSettingsState extends State<ImportExportSettings> {
  bool _isExporting = false;
  bool _isImporting = false;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppConfigProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '本地导入导出',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '通过剪贴板导入导出配置',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isExporting
                  ? null
                  : () async {
                      setState(() {
                        _isExporting = true;
                      });
                      try {
                        final jsonString = provider.exportConfig();
                        await Clipboard.setData(
                          ClipboardData(text: jsonString),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('配置已复制到剪贴板'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('导出失败: $e')),
                          );
                        }
                      }
                      if (mounted) {
                        setState(() {
                          _isExporting = false;
                        });
                      }
                    },
              icon: _isExporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.copy),
              label: const Text('复制配置到剪贴板'),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isImporting
                  ? null
                  : () async {
                      setState(() {
                        _isImporting = true;
                      });
                      try {
                        final data =
                            await Clipboard.getData(Clipboard.kTextPlain);
                        if (data != null && data.text != null) {
                          await provider.importConfig(data.text!);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('配置已导入'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('剪贴板为空')),
                            );
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('导入失败: $e')),
                          );
                        }
                      }
                      if (mounted) {
                        setState(() {
                          _isImporting = false;
                        });
                      }
                    },
              icon: _isImporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.paste),
              label: const Text('从剪贴板导入配置'),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          const Text(
            '重置设置',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('将所有设置恢复为默认值', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('确认重置'),
                  content: const Text('确定要将所有设置恢复为默认值吗？此操作不可撤销。'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('确定'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await provider.resetToDefaults();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('设置已重置')),
                  );
                }
              }
            },
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('重置为默认值'),
          ),
        ],
      ),
    );
  }
}
