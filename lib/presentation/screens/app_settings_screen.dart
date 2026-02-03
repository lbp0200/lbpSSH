import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../data/models/terminal_config.dart';
import '../../data/models/default_terminal_config.dart';
import '../providers/app_config_provider.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  int _selectedIndex = 0;

  final List<String> _tabs = ['终端显示', '默认终端'];

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
              children: [TerminalDisplaySettings(), DefaultTerminalSettings()],
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
            initialValue: _config.execMac,
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
            initialValue: _config.execWindows,
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
            initialValue: _config.execLinux,
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
                    final scaffoldMessenger = ScaffoldMessenger.maybeOf(
                      context,
                    );
                    if (scaffoldMessenger == null) return;

                    try {
                      final provider = Provider.of<AppConfigProvider>(
                        context,
                        listen: false,
                      );
                      await provider.saveDefaultTerminalConfig(_config);

                      scaffoldMessenger.showSnackBar(
                        const SnackBar(content: Text('设置已保存')),
                      );
                    } catch (e) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(content: Text('保存失败: $e')),
                      );
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
