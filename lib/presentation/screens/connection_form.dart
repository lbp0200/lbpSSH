import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/ssh_connection.dart';
import '../providers/connection_provider.dart';

/// 连接配置表单界面
class ConnectionFormScreen extends StatefulWidget {
  final SshConnection? connection;

  const ConnectionFormScreen({
    super.key,
    this.connection,
  });

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
    _notesController.text = connection.notes ?? '';

    if (connection.jumpHost != null) {
      _useJumpHost = true;
      _jumpHostController.text = connection.jumpHost!.host;
      _jumpPortController.text = connection.jumpHost!.port.toString();
      _jumpUsernameController.text = connection.jumpHost!.username;
      _jumpAuthType = connection.jumpHost!.authType;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _keyPathController.dispose();
    _keyPassphraseController.dispose();
    _notesController.dispose();
    _jumpHostController.dispose();
    _jumpPortController.dispose();
    _jumpUsernameController.dispose();
    _jumpPasswordController.dispose();
    super.dispose();
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
        privateKeyPath:
            _keyPathController.text.isNotEmpty ? _keyPathController.text : null,
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

      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.connection != null ? '连接已更新' : '连接已添加',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.connection != null ? '编辑连接' : '添加连接'),
      ),
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
                    decoration: const InputDecoration(
                      labelText: '端口',
                    ),
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
              value: _authType,
              decoration: const InputDecoration(
                labelText: '认证方式',
              ),
              items: const [
                DropdownMenuItem(
                  value: AuthType.password,
                  child: Text('密码认证'),
                ),
                DropdownMenuItem(
                  value: AuthType.key,
                  child: Text('密钥认证'),
                ),
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
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
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

            // 密钥路径（如果是密钥认证）
            if (_authType == AuthType.key || _authType == AuthType.keyWithPassword) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _keyPathController,
                decoration: const InputDecoration(
                  labelText: '私钥路径',
                  hintText: '/path/to/private_key',
                ),
                validator: (value) {
                  if (_authType == AuthType.key ||
                      _authType == AuthType.keyWithPassword) {
                    if (value == null || value.isEmpty) {
                      return '请输入私钥路径';
                    }
                  }
                  return null;
                },
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
                      decoration: const InputDecoration(
                        labelText: '跳板机地址',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _jumpPortController,
                      decoration: const InputDecoration(
                        labelText: '端口',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _jumpUsernameController,
                decoration: const InputDecoration(
                  labelText: '跳板机用户名',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<AuthType>(
                value: _jumpAuthType,
                decoration: const InputDecoration(
                  labelText: '跳板机认证方式',
                ),
                items: const [
                  DropdownMenuItem(
                    value: AuthType.password,
                    child: Text('密码认证'),
                  ),
                  DropdownMenuItem(
                    value: AuthType.key,
                    child: Text('密钥认证'),
                  ),
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
                  decoration: const InputDecoration(
                    labelText: '跳板机密码',
                  ),
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
