import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/presentation/providers/connection_provider.dart';
import '../screens/app_settings_screen.dart';
import 'connection_list.dart';

class CollapsibleSidebar extends StatefulWidget {
  final Function(SshConnection)? onConnectionTap;
  final Function(SshConnection)? onSftpTap;

  const CollapsibleSidebar({
    super.key,
    this.onConnectionTap,
    this.onSftpTap,
  });

  @override
  State<CollapsibleSidebar> createState() => _CollapsibleSidebarState();
}

class _CollapsibleSidebarState extends State<CollapsibleSidebar> {
  bool _isExpanded = true;
  final _searchController = TextEditingController();
  bool _showSearch = false;

  static const double _expandedWidth = 280.0;
  static const double _collapsedWidth = 60.0;

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _showSearch = false;
      }
    });
  }

  void _toggleSearch() {
    setState(() {
      if (_isExpanded) {
        _showSearch = !_showSearch;
        if (!_showSearch) {
          _searchController.clear();
        }
      } else {
        _isExpanded = true;
        _showSearch = true;
      }
    });
  }

  void _openSettings() {
    setState(() {
      _isExpanded = true;
      _showSearch = false;
    });
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AppSettingsScreen()),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: _isExpanded ? _expandedWidth : _collapsedWidth,
      child: Column(
        children: [
          // Top buttons row
          Padding(
            padding: const EdgeInsets.all(8),
            child: _isExpanded
                ? Column(
                    children: [
                      if (_showSearch)
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: '搜索连接...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: _toggleSearch,
                            ),
                            border: const OutlineInputBorder(),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          onChanged: (value) {
                            context.read<ConnectionProvider>().setSearchQuery(value);
                          },
                        )
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.search),
                              onPressed: _toggleSearch,
                              tooltip: '搜索',
                            ),
                            IconButton(
                              icon: const Icon(Icons.settings),
                              onPressed: _openSettings,
                              tooltip: '设置',
                            ),
                          ],
                        ),
                    ],
                  )
                : Column(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: _toggleExpanded,
                        tooltip: '展开',
                      ),
                    ],
                  ),
          ),
          // Connection list
          Expanded(
            child: ConnectionList(
              isCompact: !_isExpanded,
              onConnectionTap: widget.onConnectionTap,
              onSftpTap: widget.onSftpTap,
            ),
          ),
          // Bottom toggle button
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.all(8),
              child: IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _toggleExpanded,
                tooltip: '折叠',
              ),
            ),
          if (!_isExpanded)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _toggleSearch,
                    tooltip: '搜索',
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: _openSettings,
                    tooltip: '设置',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
