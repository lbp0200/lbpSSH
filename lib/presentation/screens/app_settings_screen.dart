import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../data/models/ssh_connection.dart';
import '../../data/models/terminal_config.dart';
import '../../data/models/default_terminal_config.dart';
import '../providers/app_config_provider.dart';
import '../providers/connection_provider.dart';
import 'connection_form.dart';
import 'sync_settings.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  int _selectedIndex = 0;

  final List<String> _tabs = ['终端设置', '连接管理', '同步设置'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
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
                const TerminalSettingsPage(),
                const ConnectionManagementPage(),
                const SyncSettingsScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTabIcon(String tab) {
    switch (tab) {
      case '终端设置':
        return Icons.terminal;
      case '连接管理':
        return Icons.settings;
      case '同步设置':
        return Icons.cloud_sync;
      default:
        return Icons.settings;
    }
  }
}

class TerminalSettingsPage extends StatefulWidget {
  const TerminalSettingsPage({super.key});

  @override
  State<TerminalSettingsPage> createState() => _TerminalSettingsPageState();
}

class _TerminalSettingsPageState extends State<TerminalSettingsPage> {
  late TerminalConfig _config;
  late DefaultTerminalConfig _defaultConfig;
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
    _defaultConfig = provider.defaultTerminalConfig;
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
            '终端显示设置',
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
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) {
                    final fontWeight = int.tryParse(value);
                    if (fontWeight != null &&
                        fontWeight >= 100 &&
                        fontWeight <= 900) {
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
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                    final scaffoldMessenger = ScaffoldMessenger.maybeOf(
                      context,
                    );
                    if (scaffoldMessenger == null) return;

                    try {
                      final provider = Provider.of<AppConfigProvider>(
                        context,
                        listen: false,
                      );
                      await provider.saveTerminalConfig(_config);

                      scaffoldMessenger.showSnackBar(
                        const SnackBar(content: Text('设置已保存')),
                      );
                    } catch (e) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(content: Text('保存失败: $e')),
                      );
                    }
                  },
                  child: const Text('保存显示设置'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 24),
          const Text(
            '默认终端应用',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '选择执行 SSH 连接时打开的终端应用',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          _buildDefaultTerminalSettings(),
          const SizedBox(height: 24),
          Row(
            children: [
              OutlinedButton(
                onPressed: () {
                  _defaultConfig = DefaultTerminalConfig.defaultConfig;
                  setState(() {});
                },
                child: const Text('重置'),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final scaffoldMessenger = ScaffoldMessenger.maybeOf(
                      context,
                    );
                    if (scaffoldMessenger == null) return;

                    try {
                      final provider = Provider.of<AppConfigProvider>(
                        context,
                        listen: false,
                      );
                      await provider.saveDefaultTerminalConfig(_defaultConfig);

                      scaffoldMessenger.showSnackBar(
                        const SnackBar(content: Text('默认终端已保存')),
                      );
                    } catch (e) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(content: Text('保存失败: $e')),
                      );
                    }
                  },
                  child: const Text('保存默认终端'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultTerminalSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('macOS 默认终端', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<TerminalType>(
          initialValue: _defaultConfig.execMac,
          decoration: const InputDecoration(labelText: '终端类型'),
          items: const [
            DropdownMenuItem(value: TerminalType.iterm2, child: Text('iTerm2')),
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
              _defaultConfig = _defaultConfig.copyWith(execMac: value);
            });
          },
        ),
        if (_defaultConfig.execMac == TerminalType.custom) ...[
          const SizedBox(height: 16),
          TextFormField(
            initialValue: _defaultConfig.execMacCustom,
            decoration: const InputDecoration(
              labelText: '自定义命令',
              hintText: '例如：open -a /Applications/MyTerminal.app',
            ),
            onChanged: (value) {
              setState(() {
                _defaultConfig = _defaultConfig.copyWith(execMacCustom: value);
              });
            },
          ),
        ],
        const SizedBox(height: 16),
        const Text(
          'Windows 默认终端',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<TerminalType>(
          initialValue: _defaultConfig.execWindows,
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
              _defaultConfig = _defaultConfig.copyWith(execWindows: value);
            });
          },
        ),
        if (_defaultConfig.execWindows == TerminalType.custom) ...[
          const SizedBox(height: 16),
          TextFormField(
            initialValue: _defaultConfig.execWindowsCustom,
            decoration: const InputDecoration(
              labelText: '自定义命令',
              hintText: '例如：C:\\Path\\To\\Terminal.exe',
            ),
            onChanged: (value) {
              setState(() {
                _defaultConfig = _defaultConfig.copyWith(
                  execWindowsCustom: value,
                );
              });
            },
          ),
        ],
        const SizedBox(height: 16),
        const Text('Linux 默认终端', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<TerminalType>(
          initialValue: _defaultConfig.execLinux,
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
              _defaultConfig = _defaultConfig.copyWith(execLinux: value);
            });
          },
        ),
        if (_defaultConfig.execLinux == TerminalType.custom) ...[
          const SizedBox(height: 16),
          TextFormField(
            initialValue: _defaultConfig.execLinuxCustom,
            decoration: const InputDecoration(
              labelText: '自定义命令',
              hintText: '例如：gnome-terminal',
            ),
            onChanged: (value) {
              setState(() {
                _defaultConfig = _defaultConfig.copyWith(
                  execLinuxCustom: value,
                );
              });
            },
          ),
        ],
      ],
    );
  }
}

/// 连接管理页面
class ConnectionManagementPage extends StatelessWidget {
  const ConnectionManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 顶部操作栏
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text(
                '已保存的连接',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          const ConnectionFormScreen(connection: null),
                    ),
                  );
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加连接'),
              ),
            ],
          ),
        ),
        const Divider(),
        // 连接列表
        Expanded(
          child: Consumer<ConnectionProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (provider.error != null) {
                return Center(
                  child: Text(
                    provider.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                );
              }

              final connections = provider.connections;

              if (connections.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_off,
                        size: 64,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '暂无连接配置',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ConnectionFormScreen(connection: null),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('添加第一个连接'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: connections.length,
                itemBuilder: (context, index) {
                  final connection = connections[index];
                  return _ConnectionManagementItem(connection: connection);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ConnectionManagementItem extends StatelessWidget {
  final SshConnection connection;

  const _ConnectionManagementItem({required this.connection});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ConnectionProvider>(context, listen: false);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(
          Icons.vpn_key,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(connection.name),
        subtitle: Text(
          '${connection.username}@${connection.host}:${connection.port}',
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('编辑'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('删除', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'edit') {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      ConnectionFormScreen(connection: connection),
                ),
              );
            } else if (value == 'delete') {
              _showDeleteDialog(context, provider);
            }
          },
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  ConnectionFormScreen(connection: connection),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showDeleteDialog(
    BuildContext context,
    ConnectionProvider provider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除连接 "${connection.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await provider.deleteConnection(connection.id);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('连接已删除')));
      }
    }
  }
}
