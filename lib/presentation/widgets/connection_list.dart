import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/ssh_connection.dart';
import '../../core/theme/app_theme.dart';
import '../providers/connection_provider.dart';
import '../screens/connection_form.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                  Icons.dns_outlined,
                  size: 56,
                  color: isDark ? Colors.white24 : Colors.black12,
                ),
                const SizedBox(height: 16),
                Text(
                  '暂无连接配置',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _showConnectionForm(context, null),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加连接'),
                  style: FilledButton.styleFrom(
                    backgroundColor: isDark ? AppTheme.accentGreen : null,
                  ),
                ),
              ],
            ),
          );
        }

        final bottomPadding = isCompact ? 8.0 : 60.0;
        return Stack(
          children: [
            ListView.builder(
              padding: EdgeInsets.only(top: 8, bottom: bottomPadding),
              itemCount: connections.length,
              itemBuilder: (context, index) {
                final connection = connections[index];
                if (isCompact) {
                  return _CompactConnectionItem(
                    connection: connection,
                    onTap: () {
                      onConnectionTap?.call(connection);
                    },
                    onSftpTap: onSftpTap != null
                        ? () => onSftpTap!(connection)
                        : null,
                  );
                }
                return _ConnectionListItem(
                  connection: connection,
                  onTap: () {
                    onConnectionTap?.call(connection);
                  },
                  onEdit: () => _showConnectionForm(context, connection),
                  onDelete: () =>
                      _deleteConnection(context, provider, connection),
                  onSftpTap: onSftpTap != null
                      ? () => onSftpTap!(connection)
                      : null,
                );
              },
            ),
            if (!isCompact)
              Positioned(
                bottom: 8,
                right: 8,
                child: FloatingActionButton.small(
                  heroTag: 'add_connection',
                  onPressed: () => _showConnectionForm(context, null),
                  tooltip: '添加连接',
                  backgroundColor: isDark ? AppTheme.accentGreen : null,
                  child: const Icon(Icons.add),
                ),
              ),
          ],
        );
      },
    );
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          hoverColor: isDark
              ? AppTheme.accentGreen.withValues(alpha: 0.08)
              : Colors.grey.shade100,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppTheme.secondaryDark : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.accentGreen.withValues(alpha: 0.15)
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.terminal,
                    color: isDark
                        ? AppTheme.accentGreen
                        : Colors.green.shade600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        connection.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${connection.username}@${connection.host}:${connection.port}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black45,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (onSftpTap != null)
                  IconButton(
                    icon: Icon(
                      Icons.folder_copy_outlined,
                      size: 20,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                    onPressed: onSftpTap,
                    tooltip: 'SFTP',
                    visualDensity: VisualDensity.compact,
                  ),
                PopupMenuButton(
                  icon: Icon(
                    Icons.more_vert,
                    size: 20,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit,
                            size: 18,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '编辑',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 10),
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
          ),
        ),
      ),
    );
  }
}

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: '${connection.name}\n${connection.host}',
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            hoverColor: isDark
                ? AppTheme.accentGreen.withValues(alpha: 0.1)
                : Colors.grey.shade200,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              child: Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.accentGreen.withValues(alpha: 0.15)
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.terminal,
                      color: isDark
                          ? AppTheme.accentGreen
                          : Colors.green.shade600,
                      size: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    connection.name,
                    style: TextStyle(
                      fontSize: 9,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (onSftpTap != null)
          Tooltip(
            message: 'SFTP',
            child: InkWell(
              onTap: onSftpTap,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Icon(
                  Icons.folder_copy_outlined,
                  size: 14,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
