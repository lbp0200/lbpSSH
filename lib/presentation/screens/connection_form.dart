import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/models/ssh_connection.dart';
import '../providers/connection_provider.dart';

/// 连接配置表单界面
class ConnectionFormScreen extends StatefulWidget {
  final SshConnection? connection;

  const ConnectionFormScreen({super.key, this.connection});

  @override
  State<ConnectionFormScreen> createState() => _ConnectionFormScreenState();
}

class _ConnectionFormScreenState extends State<ConnectionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _keyPathController = TextEditingController();
  final _keyPassphraseController = TextEditingController();
  final _notesController = TextEditingController();

  // 私钥内容存储
  String? _privateKeyContent;

  AuthType _authType = AuthType.password;
  bool _obscurePassword = true;
  bool _obscureKeyPassphrase = true;

  // 跳板机配置
  bool _useJumpHost = false;
  final _jumpHostController = TextEditingController();
  final _jumpPortController = TextEditingController();
  final _jumpUsernameController = TextEditingController();
  final _jumpPasswordController = TextEditingController();
  AuthType _jumpAuthType = AuthType.password;

  @override
  void initState() {
    super.initState();
    if (widget.connection != null) {
      _loadConnection(widget.connection!);
    } else {
      _portController.text = '22';
      _jumpPortController.text = '22';
    }
  }

  void _loadConnection(SshConnection connection) {
    _nameController.text = connection.name;
    _hostController.text = connection.host;
    _portController.text = connection.port.toString();
    _usernameController.text = connection.username;
    _authType = connection.authType;
    _keyPathController.text = connection.privateKeyPath ?? '';
    _privateKeyContent = connection.privateKeyContent;
    _notesController.text = connection.notes ?? '';

    if (connection.jumpHost != null) {
      _useJumpHost = true;
      _jumpHostController.text = connection.jumpHost!.host;
      _jumpPortController.text = connection.jumpHost!.port.toString();
      _jumpUsernameController.text = connection.jumpHost!.username;
      _jumpAuthType = connection.jumpHost!.authType;
    }
  }

  // 选择私钥文件
  Future<void> _pickPrivateKeyFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pem',
          'key',
          'ppk',
          'txt',
          'rsa',
          'ed25519',
          'dsa',
          'ecdsa',
        ],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;

        // 检查文件是否存在且可读
        final file = File(filePath);
        if (!await file.exists()) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('文件不存在或无法访问')));
          return;
        }

        // 读取文件内容
        String fileContent;
        try {
          fileContent = await file.readAsString();
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('读取文件失败: $e')));
          return;
        }

        // 验证私钥格式
        if (!_isValidPrivateKey(fileContent)) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '选择的文件不是有效的私钥格式。\n'
                '请确保选择的是标准的SSH私钥文件，\n'
                '例如 ~/.ssh/id_rsa、~/.ssh/id_ed25519 等',
              ),
            ),
          );
          return;
        }

        setState(() {
          _keyPathController.text = filePath;
          _privateKeyContent = fileContent;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('私钥文件已加载: ${filePath.split('/').last}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('选择文件失败: $e')));
    }
  }

  // 验证私钥格式
  bool _isValidPrivateKey(String content) {
    final trimmed = content.trim();

    // 支持多种私钥格式
    // 1. PEM格式 (-----BEGIN/END PRIVATE KEY-----)
    if (trimmed.startsWith('-----BEGIN') &&
        trimmed.contains('PRIVATE KEY-----') &&
        trimmed.endsWith('-----END PRIVATE KEY-----')) {
      return true;
    }

    // 2. OpenSSH格式 (-----BEGIN/END OPENSSH PRIVATE KEY-----)
    if (trimmed.startsWith('-----BEGIN') &&
        trimmed.contains('OPENSSH PRIVATE KEY-----') &&
        trimmed.endsWith('-----END OPENSSH PRIVATE KEY-----')) {
      return true;
    }

    // 3. RSA格式 (-----BEGIN/END RSA PRIVATE KEY-----)
    if (trimmed.startsWith('-----BEGIN') &&
        trimmed.contains('RSA PRIVATE KEY-----') &&
        trimmed.endsWith('-----END RSA PRIVATE KEY-----')) {
      return true;
    }

    // 4. DSA格式 (-----BEGIN/END DSA PRIVATE KEY-----)
    if (trimmed.startsWith('-----BEGIN') &&
        trimmed.contains('DSA PRIVATE KEY-----') &&
        trimmed.endsWith('-----END DSA PRIVATE KEY-----')) {
      return true;
    }

    // 5. EC格式 (-----BEGIN/END EC PRIVATE KEY-----)
    if (trimmed.startsWith('-----BEGIN') &&
        trimmed.contains('EC PRIVATE KEY-----') &&
        trimmed.endsWith('-----END EC PRIVATE KEY-----')) {
      return true;
    }

    return false;
  }

  Future<void> _saveConnection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = Provider.of<ConnectionProvider>(context, listen: false);

    try {
      // 创建跳板机配置
      JumpHostConfig? jumpHost;
      if (_useJumpHost) {
        jumpHost = JumpHostConfig(
          host: _jumpHostController.text,
          port: int.tryParse(_jumpPortController.text) ?? 22,
          username: _jumpUsernameController.text,
          authType: _jumpAuthType,
          password: _jumpPasswordController.text.isNotEmpty
              ? _jumpPasswordController.text
              : null,
        );
      }

      // 创建连接配置
      final connection = SshConnection(
        id: widget.connection?.id ?? const Uuid().v4(),
        name: _nameController.text,
        host: _hostController.text,
        port: int.tryParse(_portController.text) ?? 22,
        username: _usernameController.text,
        authType: _authType,
        password: _passwordController.text.isNotEmpty
            ? _passwordController.text
            : null,
        privateKeyPath: _keyPathController.text.isNotEmpty
            ? _keyPathController.text
            : null,
        privateKeyContent: _privateKeyContent,
        keyPassphrase: _keyPassphraseController.text.isNotEmpty
            ? _keyPassphraseController.text
            : null,
        jumpHost: jumpHost,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        createdAt: widget.connection?.createdAt,
        updatedAt: DateTime.now(),
        version: widget.connection?.version ?? 1,
      );

      if (widget.connection != null) {
        await provider.updateConnection(connection);
      } else {
        await provider.addConnection(connection);
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.connection != null ? '连接已更新' : '连接已添加')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.connection != null ? '编辑连接' : '添加连接')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 基本信息
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '连接名称',
                hintText: '例如：生产服务器',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入连接名称';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _hostController,
                    decoration: const InputDecoration(
                      labelText: '主机地址',
                      hintText: '例如：192.168.1.100',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入主机地址';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _portController,
                    decoration: const InputDecoration(labelText: '端口'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入端口';
                      }
                      final port = int.tryParse(value);
                      if (port == null || port < 1 || port > 65535) {
                        return '端口号无效';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: '用户名',
                hintText: '例如：root',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入用户名';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 认证方式
            DropdownButtonFormField<AuthType>(
              initialValue: _authType,
              decoration: const InputDecoration(labelText: '认证方式'),
              items: const [
                DropdownMenuItem(value: AuthType.password, child: Text('密码认证')),
                DropdownMenuItem(value: AuthType.key, child: Text('密钥认证')),
                DropdownMenuItem(
                  value: AuthType.keyWithPassword,
                  child: Text('密钥+密码认证'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _authType = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            // 密码输入（如果是密码认证）
            if (_authType == AuthType.password)
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: '密码',
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

            // 私钥文件（如果是密钥认证）
            if (_authType == AuthType.key ||
                _authType == AuthType.keyWithPassword) ...[
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('私钥文件'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _keyPathController,
                          readOnly: true,
                          decoration: InputDecoration(
                            hintText: _privateKeyContent != null
                                ? '已选择私钥文件'
                                : '点击右侧按钮选择私钥文件',
                            suffixIcon: _privateKeyContent != null
                                ? const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  )
                                : null,
                          ),
                          validator: (value) {
                            if (_authType == AuthType.key ||
                                _authType == AuthType.keyWithPassword) {
                              if (_privateKeyContent == null) {
                                return '请选择私钥文件';
                              }
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _pickPrivateKeyFile,
                        icon: const Icon(Icons.folder_open),
                        label: const Text('选择文件'),
                      ),
                    ],
                  ),
                  if (_privateKeyContent != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '私钥已加载: ${_keyPathController.text.isNotEmpty ? _keyPathController.text.split('/').last : "未知文件"}',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ],

            // 密钥密码（如果是密钥+密码认证）
            if (_authType == AuthType.keyWithPassword) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _keyPassphraseController,
                decoration: InputDecoration(
                  labelText: '密钥密码',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureKeyPassphrase
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureKeyPassphrase = !_obscureKeyPassphrase;
                      });
                    },
                  ),
                ),
                obscureText: _obscureKeyPassphrase,
              ),
            ],

            const SizedBox(height: 24),

            // 跳板机配置
            CheckboxListTile(
              title: const Text('使用跳板机'),
              value: _useJumpHost,
              onChanged: (value) {
                setState(() {
                  _useJumpHost = value ?? false;
                });
              },
            ),

            if (_useJumpHost) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _jumpHostController,
                      decoration: const InputDecoration(labelText: '跳板机地址'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _jumpPortController,
                      decoration: const InputDecoration(labelText: '端口'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _jumpUsernameController,
                decoration: const InputDecoration(labelText: '跳板机用户名'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<AuthType>(
                initialValue: _jumpAuthType,
                decoration: const InputDecoration(labelText: '跳板机认证方式'),
                items: const [
                  DropdownMenuItem(
                    value: AuthType.password,
                    child: Text('密码认证'),
                  ),
                  DropdownMenuItem(value: AuthType.key, child: Text('密钥认证')),
                ],
                onChanged: (value) {
                  setState(() {
                    _jumpAuthType = value!;
                  });
                },
              ),
              if (_jumpAuthType == AuthType.password) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _jumpPasswordController,
                  decoration: const InputDecoration(labelText: '跳板机密码'),
                  obscureText: true,
                ),
              ],
            ],

            const SizedBox(height: 24),

            // 备注
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: '备注',
                hintText: '可选',
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 32),

            // 保存按钮
            ElevatedButton(
              onPressed: _saveConnection,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}
