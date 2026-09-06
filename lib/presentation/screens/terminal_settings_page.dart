import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/ssh_config.dart';
import '../../data/models/terminal_config.dart';
import '../providers/app_config_provider.dart';
import '../widgets/terminal_preview.dart';

class TerminalSettingsPage extends ConsumerStatefulWidget {
  const TerminalSettingsPage({super.key});

  @override
  ConsumerState<TerminalSettingsPage> createState() =>
      _TerminalSettingsPageState();
}

class _TerminalSettingsPageState extends ConsumerState<TerminalSettingsPage> {
  late TerminalConfig _config;
  late SshConfig _sshConfig;
  final _fontSizeController = TextEditingController();
  final _fontWeightController = TextEditingController();
  final _letterSpacingController = TextEditingController();
  final _lineHeightController = TextEditingController();
  final _paddingController = TextEditingController();
  final _fontFamilyController = TextEditingController();
  final _keepaliveController = TextEditingController();
  final _bgColorController = TextEditingController();
  final _fgColorController = TextEditingController();
  final _cursorColorController = TextEditingController();

  // 预设字体大小
  final List<int> _presetFontSizes = [10, 12, 14, 16, 18, 20, 24, 28, 32];

  // 扩展常用字体列表（跨平台支持）
  final List<String> _popularFonts = [
    // Nerd Fonts（内置，支持 eza --icons 等图标显示）
    'JetBrainsMonoNerdFontMono',
    'JetBrainsMonoNerdFont',
    // 等宽编程字体
    'JetBrains Mono',
    'Fira Code',
    'Source Code Pro',
    'Ubuntu Mono',
    'Hack',
    'Iosevka',
    'Consolas',
    'Monaco',
    'Menlo',
    'DejaVu Sans Mono',
    'Cascadia Code',
    'Cousine',
    'Droid Sans Mono',
    'Inconsolata',
    'Lato Mono',
    'Office Code Pro',
    'Open Sans Mono',
    'Oxygen Mono',
    'PT Mono',
    'Roboto Mono',
    'SF Mono',
    'Terminus',
    'Ubuntu',
    'Victor Mono',
    // 系统通用字体
    'Arial',
    'Helvetica',
    'Verdana',
    'Courier New',
    'Georgia',
    'Times New Roman',
  ];

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  void _loadConfig() {
    _config = ref.read(terminalConfigProvider);
    _sshConfig = ref.read(sshConfigProvider);
    _fontSizeController.text = _config.fontSize.toInt().toString();
    _fontWeightController.text = _config.fontWeight.toString();
    _letterSpacingController.text = _config.letterSpacing.toString();
    _lineHeightController.text = _config.lineHeight.toString();
    _paddingController.text = _config.padding.toString();
    _fontFamilyController.text = _config.fontFamily;
    _keepaliveController.text = (_sshConfig.keepaliveInterval ~/ 1000)
        .toString();
    _bgColorController.text = _config.backgroundColor;
    _fgColorController.text = _config.foregroundColor;
    _cursorColorController.text = _config.cursorColor;
  }

  void _onFontSizeChanged(double value) {
    // 字号必须落在下方 Slider 的 [8, 32] 范围内：预览区的"缩小/放大"按钮以 ±2 步进且无边界，
    // 若不在此钳制，fontSize 会越出 Slider.value 的合法区间，触发 Flutter 断言（min<=value<=max）导致本页面崩溃。
    final clamped = value.clamp(8.0, 32.0).toDouble();
    setState(() {
      _config = _config.copyWith(fontSize: clamped);
      _fontSizeController.text = clamped.toInt().toString();
    });
  }

  @override
  void dispose() {
    _fontSizeController.dispose();
    _fontWeightController.dispose();
    _letterSpacingController.dispose();
    _lineHeightController.dispose();
    _paddingController.dispose();
    _fontFamilyController.dispose();
    _keepaliveController.dispose();
    _bgColorController.dispose();
    _fgColorController.dispose();
    _cursorColorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: LinearColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(LinearSpacing.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '终端显示设置',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: LinearColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: LinearSpacing.spacing16),
            _buildFontFamilySelector(),
            const SizedBox(height: LinearSpacing.spacing16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '字体大小',
                            style: TextStyle(color: LinearColors.textPrimary),
                          ),
                          Text(
                            '${_config.fontSize.toInt()}px',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _config.fontSize,
                        min: 8,
                        max: 32,
                        divisions: 24,
                        onChanged: _onFontSizeChanged,
                      ),
                      // 预设按钮
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _presetFontSizes.map((size) {
                            final isSelected = _config.fontSize.toInt() == size;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                selected: isSelected,
                                label: Text('${size}px'),
                                onSelected: (_) =>
                                    _onFontSizeChanged(size.toDouble()),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: LinearSpacing.spacing16),
                Expanded(
                  child: TextFormField(
                    controller: _fontWeightController,
                    style: const TextStyle(color: LinearColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: '字重',
                      labelStyle: TextStyle(color: LinearColors.textSecondary),
                      suffixText: '100-900',
                      suffixStyle: TextStyle(color: LinearColors.textTertiary),
                      filled: true,
                      fillColor: LinearColors.fillSurface,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) {
                      final fontWeight = int.tryParse(value);
                      if (fontWeight != null &&
                          fontWeight >= 100 &&
                          fontWeight <= 900) {
                        setState(() {
                          _config = _config.copyWith(fontWeight: fontWeight);
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: LinearSpacing.spacing16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _letterSpacingController,
                    style: const TextStyle(color: LinearColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: '字母间距',
                      labelStyle: TextStyle(color: LinearColors.textSecondary),
                      suffixText: 'em',
                      suffixStyle: TextStyle(color: LinearColors.textTertiary),
                      filled: true,
                      fillColor: LinearColors.fillSurface,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      final letterSpacing = double.tryParse(value);
                      if (letterSpacing != null) {
                        setState(() {
                          _config = _config.copyWith(
                            letterSpacing: letterSpacing,
                          );
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: LinearSpacing.spacing16),
                Expanded(
                  child: TextFormField(
                    controller: _lineHeightController,
                    style: const TextStyle(color: LinearColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: '行高',
                      labelStyle: TextStyle(color: LinearColors.textSecondary),
                      suffixText: '倍',
                      suffixStyle: TextStyle(color: LinearColors.textTertiary),
                      filled: true,
                      fillColor: LinearColors.fillSurface,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      final lineHeight = double.tryParse(value);
                      // 行高必须为正数：0/负数会使 TextStyle.height 为 0，终端文字高度塌缩、不可见。
                      if (lineHeight != null && lineHeight > 0) {
                        setState(() {
                          _config = _config.copyWith(lineHeight: lineHeight);
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: LinearSpacing.spacing16),
            TextFormField(
              controller: _paddingController,
              style: const TextStyle(color: LinearColors.textPrimary),
              decoration: const InputDecoration(
                labelText: '内边距',
                labelStyle: TextStyle(color: LinearColors.textSecondary),
                suffixText: 'px',
                suffixStyle: TextStyle(color: LinearColors.textTertiary),
                filled: true,
                fillColor: LinearColors.fillSurface,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (value) {
                final padding = int.tryParse(value);
                if (padding != null && padding >= 0) {
                  setState(() {
                    _config = _config.copyWith(padding: padding);
                  });
                }
              },
            ),
            const SizedBox(height: LinearSpacing.spacing24),
            // 实时预览区域
            TerminalPreview(
              config: _config,
              onFontSizeChanged: _onFontSizeChanged,
            ),
            const SizedBox(height: LinearSpacing.spacing24),
            Text(
              '颜色设置',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: LinearColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: LinearSpacing.spacing16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _bgColorController,
                    style: const TextStyle(color: LinearColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: '背景颜色',
                      labelStyle: TextStyle(color: LinearColors.textSecondary),
                      filled: true,
                      fillColor: LinearColors.fillSurface,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _config = _config.copyWith(backgroundColor: value);
                      });
                    },
                  ),
                ),
                const SizedBox(width: LinearSpacing.spacing16),
                Expanded(
                  child: TextFormField(
                    controller: _fgColorController,
                    style: const TextStyle(color: LinearColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: '前景颜色',
                      labelStyle: TextStyle(color: LinearColors.textSecondary),
                      filled: true,
                      fillColor: LinearColors.fillSurface,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _config = _config.copyWith(foregroundColor: value);
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: LinearSpacing.spacing16),
            TextFormField(
              controller: _cursorColorController,
              style: const TextStyle(color: LinearColors.textPrimary),
              decoration: const InputDecoration(
                labelText: '光标颜色',
                labelStyle: TextStyle(color: LinearColors.textSecondary),
                filled: true,
                fillColor: LinearColors.fillSurface,
              ),
              onChanged: (value) {
                setState(() {
                  _config = _config.copyWith(cursorColor: value);
                });
              },
            ),
            const SizedBox(height: LinearSpacing.spacing32),
            Text(
              '终端兼容性设置',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: LinearColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: LinearSpacing.spacing16),
            Material(
              type: MaterialType.transparency,
              child: SwitchListTile(
                title: const Text(
                  '启用 Kitty 协议',
                  style: TextStyle(color: LinearColors.textPrimary),
                ),
                subtitle: const Text(
                  '发送终端设备属性查询 (\\x1b[>1u)，让支持 Kitty 协议的应用（如 Neovim）自动启用高级特性。关闭此选项可兼容老旧终端设备。',
                  style: TextStyle(color: LinearColors.textTertiary),
                ),
                value: _config.enableKittyProtocol,
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(enableKittyProtocol: value);
                  });
                },
              ),
            ),
            const SizedBox(height: LinearSpacing.spacing32),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () {
                    _loadConfig();
                    setState(() {});
                  },
                  child: const Text('重置'),
                ),
                const SizedBox(width: LinearSpacing.spacing16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final scaffoldMessenger = ScaffoldMessenger.maybeOf(
                        context,
                      );
                      if (scaffoldMessenger == null) return;

                      try {
                        await ref
                            .read(terminalConfigProvider.notifier)
                            .updateConfig(_config);

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
            const SizedBox(height: LinearSpacing.spacing32),
            const Divider(),
            const SizedBox(height: LinearSpacing.spacing24),
            Text(
              '默认终端应用',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: LinearColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: LinearSpacing.spacing8),
            const Text(
              '选择执行 SSH 连接时打开的终端应用',
              style: TextStyle(color: LinearColors.textTertiary),
            ),
            const SizedBox(height: LinearSpacing.spacing16),
            _buildDefaultTerminalSettings(),
            const SizedBox(height: LinearSpacing.spacing32),
            const Divider(),
            const SizedBox(height: LinearSpacing.spacing24),
            Text(
              'SSH 连接设置',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: LinearColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: LinearSpacing.spacing16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _keepaliveController,
                    style: const TextStyle(color: LinearColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Keepalive 间隔',
                      labelStyle: TextStyle(color: LinearColors.textSecondary),
                      suffixText: '秒',
                      suffixStyle: TextStyle(color: LinearColors.textTertiary),
                      helperText: '定期发送保活数据包，防止连接因空闲断开',
                      helperStyle: TextStyle(color: LinearColors.textTertiary),
                      filled: true,
                      fillColor: LinearColors.fillSurface,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) {
                      final seconds = int.tryParse(value);
                      if (seconds != null && seconds > 0) {
                        _sshConfig = _sshConfig.copyWith(
                          keepaliveInterval: seconds * 1000,
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: LinearSpacing.spacing16),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () {
                    _loadConfig();
                    setState(() {});
                  },
                  child: const Text('重置'),
                ),
                const SizedBox(width: LinearSpacing.spacing16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final scaffoldMessenger = ScaffoldMessenger.maybeOf(
                        context,
                      );
                      if (scaffoldMessenger == null) return;

                      try {
                        await ref
                            .read(sshConfigProvider.notifier)
                            .updateConfig(_sshConfig);

                        scaffoldMessenger.showSnackBar(
                          const SnackBar(content: Text('SSH 设置已保存')),
                        );
                      } catch (e) {
                        scaffoldMessenger.showSnackBar(
                          SnackBar(content: Text('保存失败: $e')),
                        );
                      }
                    },
                    child: const Text('保存 SSH 设置'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultTerminalSettings() {
    // 常用 Shell 列表
    final commonShells = [
      {'name': 'zsh', 'path': '/bin/zsh'},
      {'name': 'bash', 'path': '/bin/bash'},
      {'name': 'fish', 'path': '/usr/local/bin/fish'},
      {'name': 'PowerShell', 'path': '/usr/local/bin/pwsh'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '本地终端 Shell',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: LinearColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: LinearSpacing.spacing8),
        const Text(
          '选择或输入本地终端使用的 Shell 路径',
          style: TextStyle(color: LinearColors.textTertiary),
        ),
        const SizedBox(height: LinearSpacing.spacing16),
        DropdownButtonFormField<String>(
          initialValue: commonShells.any((s) => s['path'] == _config.shellPath)
              ? _config.shellPath
              : null,
          style: const TextStyle(color: LinearColors.textPrimary),
          dropdownColor: LinearColors.surface,
          iconEnabledColor: LinearColors.textPrimary,
          decoration: const InputDecoration(
            labelText: 'Shell',
            hintText: '选择常用 Shell 或输入自定义路径',
            filled: true,
            fillColor: LinearColors.fillSurface,
          ),
          items: [
            // 自动检测选项
            DropdownMenuItem(
              value: '',
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: LinearSpacing.spacing12),
                  const Text(
                    '自动检测 (系统默认)',
                    style: TextStyle(color: LinearColors.textPrimary),
                  ),
                ],
              ),
            ),
            const DropdownMenuItem(
              value: '__divider__',
              enabled: false,
              child: Divider(color: LinearColors.borderStandard),
            ),
            // 常用 Shell
            ...commonShells.map((shell) {
              return DropdownMenuItem(
                value: shell['path'],
                child: Text(
                  '${shell['name']} (${shell['path']})',
                  style: const TextStyle(color: LinearColors.textPrimary),
                ),
              );
            }),
          ],
          onChanged: (value) {
            if (value != null && value != '__divider__') {
              setState(() {
                _config = _config.copyWith(shellPath: value);
              });
            }
          },
        ),
        const SizedBox(height: LinearSpacing.spacing16),
        TextFormField(
          initialValue: _config.shellPath,
          style: const TextStyle(color: LinearColors.textPrimary),
          decoration: const InputDecoration(
            labelText: '自定义 Shell 路径',
            labelStyle: TextStyle(color: LinearColors.textSecondary),
            hintText: '例如：/usr/bin/zsh',
            hintStyle: TextStyle(color: LinearColors.textQuaternary),
            filled: true,
            fillColor: LinearColors.fillSurface,
          ),
          onChanged: (value) {
            setState(() {
              _config = _config.copyWith(shellPath: value);
            });
          },
        ),
        const SizedBox(height: LinearSpacing.spacing8),
        Text(
          '提示：空值将自动使用系统默认 Shell (从 \$SHELL 环境变量获取)',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  static FontWeight _mapFontWeight(int weight) {
    final Map<int, FontWeight> mapping = {
      100: FontWeight.w100,
      200: FontWeight.w200,
      300: FontWeight.w300,
      400: FontWeight.w400,
      500: FontWeight.w500,
      600: FontWeight.w600,
      700: FontWeight.w700,
      800: FontWeight.w800,
      900: FontWeight.w900,
    };
    return mapping[weight] ?? FontWeight.w400;
  }

  Widget _buildFontFamilySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _popularFonts.contains(_config.fontFamily)
              ? _config.fontFamily
              : null,
          isDense: false,
          itemHeight: 50,
          style: const TextStyle(color: LinearColors.textPrimary),
          dropdownColor: LinearColors.surface,
          iconEnabledColor: LinearColors.textPrimary,
          decoration: const InputDecoration(
            labelText: '字体家族',
            hintText: '选择或输入字体',
            filled: true,
            fillColor: LinearColors.fillSurface,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 22),
          ),
          items: [
            // 编程字体分类
            const DropdownMenuItem(
              value: 'programming_header',
              enabled: false,
              child: Text(
                ' - 编程等宽字体 -',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                  color: LinearColors.textTertiary,
                ),
              ),
            ),
            ..._popularFonts.take(10).map((font) {
              return DropdownMenuItem(
                value: font,
                child: Text(
                  font,
                  style: TextStyle(
                    fontFamily: font,
                    color: LinearColors.textPrimary,
                  ),
                ),
              );
            }),
            const DropdownMenuItem(
              value: 'divider_item',
              enabled: false,
              child: Divider(color: LinearColors.borderStandard),
            ),
            // 系统字体
            const DropdownMenuItem(
              value: 'system_header',
              enabled: false,
              child: Text(
                ' - 系统字体 -',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                  color: LinearColors.textTertiary,
                ),
              ),
            ),
            ..._popularFonts.skip(10).map((font) {
              return DropdownMenuItem(
                value: font,
                child: Text(
                  font,
                  style: const TextStyle(color: LinearColors.textPrimary),
                ),
              );
            }),
          ],
          onChanged: (value) {
            if (value != null &&
                value != 'programming_header' &&
                value != 'system_header' &&
                value != 'divider_item') {
              setState(() {
                _fontFamilyController.text = value;
                _config = _config.copyWith(fontFamily: value);
              });
            }
          },
        ),
        const SizedBox(height: LinearSpacing.spacing8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _fontFamilyController,
                style: const TextStyle(color: LinearColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: '输入自定义字体名称',
                  hintStyle: TextStyle(color: LinearColors.textQuaternary),
                  filled: true,
                  fillColor: LinearColors.fillSurface,
                ),
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(fontFamily: value);
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: LinearSpacing.spacing12),
        // 字体预览
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '字体预览',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: LinearSpacing.spacing8),
              Text(
                'The quick brown fox jumps over the lazy dog.',
                style: TextStyle(
                  fontFamily: _config.fontFamily.isNotEmpty
                      ? _config.fontFamily
                      : null,
                  fontSize: _config.fontSize,
                  fontWeight: _mapFontWeight(_config.fontWeight),
                  color: LinearColors.textPrimary,
                ),
              ),
              const SizedBox(height: LinearSpacing.spacing8),
              Text(
                '1234567890 !@#\$%^&*()',
                style: TextStyle(
                  fontFamily: _config.fontFamily.isNotEmpty
                      ? _config.fontFamily
                      : null,
                  fontSize: _config.fontSize,
                  fontWeight: _mapFontWeight(_config.fontWeight),
                  color: LinearColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: LinearSpacing.spacing8),
        const Text(
          '提示：确保系统已安装所选字体。推荐使用等宽编程字体以获得最佳终端体验。',
          style: TextStyle(fontSize: 11, color: LinearColors.textTertiary),
        ),
      ],
    );
  }
}
