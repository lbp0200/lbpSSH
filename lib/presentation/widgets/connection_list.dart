import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/ssh_connection.dart';
import '../providers/connection_provider.dart';
import '../screens/connection_form.dart';

/// 连接列表组件
class ConnectionList extends StatelessWidget {
  final Function(SshConnection)? onConnectionTap;
  final Function(SshConnection)? onSftpTap;
  final bool isCompact;

  const ConnectionList({
    super.key,
    this.onConnectionTap,
    this.onSftpTap,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null) {
          return Center(
            child: Text(
              provider.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          );
        }

        final connections = provider.filteredConnections;

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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _showConnectionForm(context, null),
                  icon: const Icon(Icons.add),
                  label: const Text('添加连接'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: connections.length,
          itemBuilder: (context, index) {
            final connection = connections[index];
            if (isCompact) {
              return _CompactConnectionItem(
                connection: connection,
                onTap: () {
                  onConnectionTap?.call(connection);
                  _onConnectionTap(context, connection);
                },
                onSftpTap: onSftpTap != null ? () => onSftpTap!(connection) : null,
              );
            }
            return _ConnectionListItem(
              connection: connection,
              onTap: () {
                onConnectionTap?.call(connection);
                _onConnectionTap(context, connection);
              },
              onEdit: () => _showConnectionForm(context, connection),
              onDelete: () => _deleteConnection(context, provider, connection),
              onSftpTap: onSftpTap != null ? () => onSftpTap!(connection) : null,
            );
          },
        );
      },
    );
  }

  void _onConnectionTap(BuildContext context, SshConnection connection) {
    // 通知主界面创建终端会话
    // 通过回调或事件总线通知
    // 这里简化处理，实际应该在主界面中处理
  }

  void _showConnectionForm(BuildContext context, SshConnection? connection) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ConnectionFormScreen(connection: connection),
      ),
    );
  }

  Future<void> _deleteConnection(
    BuildContext context,
    ConnectionProvider provider,
    SshConnection connection,
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

/// 连接列表项
class _ConnectionListItem extends StatelessWidget {
  final SshConnection connection;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onSftpTap;

  const _ConnectionListItem({
    required this.connection,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.onSftpTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Icon(
          Icons.computer,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(connection.name),
        subtitle: Text(
          '${connection.username}@${connection.host}:${connection.port}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.folder_copy),
              onPressed: onSftpTap,
              tooltip: 'SFTP',
            ),
            PopupMenuButton(
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
                  onEdit();
                } else if (value == 'delete') {
                  onDelete();
                }
              },
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

/// 紧凑模式连接项（图标模式）
class _CompactConnectionItem extends StatelessWidget {
  final SshConnection connection;
  final VoidCallback onTap;
  final VoidCallback? onSftpTap;

  const _CompactConnectionItem({
    required this.connection,
    required this.onTap,
    this.onSftpTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Icon(
                  Icons.computer,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 4),
                Text(
                  connection.name,
                  style: const TextStyle(fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
        if (onSftpTap != null)
          InkWell(
            onTap: onSftpTap,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Icon(
                Icons.folder_copy,
                size: 16,
              ),
            ),
          ),
      ],
    );
  }
}
