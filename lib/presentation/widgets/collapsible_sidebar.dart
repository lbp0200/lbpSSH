import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/core/theme/app_theme.dart';
import 'package:lbp_ssh/presentation/providers/connection_provider.dart';
import '../screens/app_settings_screen.dart';
import 'connection_list.dart';

class CollapsibleSidebar extends StatefulWidget {
  final Function(SshConnection)? onConnectionTap;
  final Function(SshConnection)? onSftpTap;

  const CollapsibleSidebar({super.key, this.onConnectionTap, this.onSftpTap});

  @override
  State<CollapsibleSidebar> createState() => _CollapsibleSidebarState();
}

class _CollapsibleSidebarState extends State<CollapsibleSidebar>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = true;
  final _searchController = TextEditingController();
  bool _showSearch = false;
  late AnimationController _animationController;
  late Animation<double> _widthAnimation;

  static const double _expandedWidth = 280.0;
  static const double _collapsedWidth = 60.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
      value: 1.0, // Start at expanded state
    );
    _widthAnimation = Tween<double>(begin: _collapsedWidth, end: _expandedWidth)
        .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ),
        );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _showSearch = false;
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _toggleSearch() {
    final provider = context.read<ConnectionProvider>();
    setState(() {
      if (_isExpanded) {
        _showSearch = !_showSearch;
        if (!_showSearch) {
          _searchController.clear();
          provider.clearSearch();
        }
      } else {
        _isExpanded = true;
        _animationController.forward();
        _showSearch = true;
      }
    });
  }

  void _openSettings() {
    setState(() {
      _isExpanded = true;
      _showSearch = false;
      _animationController.forward();
    });
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AppSettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _widthAnimation,
      builder: (context, child) {
        final currentWidth = _widthAnimation.value;
        final isCompactMode =
            currentWidth < 200; // Use actual width for layout decision

        return Container(
          width: currentWidth,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.surfaceDark : Colors.white,
            border: Border(
              right: BorderSide(
                color: isDark ? AppTheme.secondaryDark : Colors.grey.shade200,
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              _buildHeader(isDark, isCompactMode),
              Expanded(
                child: ConnectionList(
                  isCompact: isCompactMode,
                  onConnectionTap: widget.onConnectionTap,
                  onSftpTap: widget.onSftpTap,
                ),
              ),
              _buildBottomBar(isDark, isCompactMode),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isDark, bool isCompactMode) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: !isCompactMode
          ? Column(
              children: [
                if (_showSearch)
                  _buildSearchField(isDark)
                else
                  _buildExpandedHeader(isDark),
              ],
            )
          : _buildCollapsedHeader(isDark),
    );
  }

  Widget _buildExpandedHeader(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildIconButton(
          icon: Icons.search,
          onPressed: _toggleSearch,
          tooltip: '搜索',
          isDark: isDark,
        ),
        _buildIconButton(
          icon: Icons.settings,
          onPressed: _openSettings,
          tooltip: '设置',
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildSearchField(bool isDark) {
    return TextField(
      controller: _searchController,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        hintText: '搜索连接...',
        hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
        prefixIcon: Icon(
          Icons.search,
          color: isDark ? Colors.white54 : Colors.black54,
        ),
        suffixIcon: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _toggleSearch,
          color: isDark ? Colors.white54 : Colors.black54,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isDark ? AppTheme.secondaryDark : Colors.grey.shade300,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isDark ? AppTheme.secondaryDark : Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.accentGreen),
        ),
        filled: true,
        fillColor: isDark
            ? AppTheme.secondaryDark.withValues(alpha: 0.5)
            : Colors.grey.shade100,
      ),
      onChanged: (value) {
        context.read<ConnectionProvider>().setSearchQuery(value);
      },
    );
  }

  Widget _buildCollapsedHeader(bool isDark) {
    return _buildIconButton(
      icon: Icons.chevron_right,
      onPressed: _toggleExpanded,
      tooltip: '展开',
      isDark: isDark,
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    required bool isDark,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          hoverColor: isDark
              ? AppTheme.accentGreen.withValues(alpha: 0.1)
              : Colors.grey.shade200,
          child: Container(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              color: isDark ? Colors.white70 : Colors.black87,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(bool isDark, bool isCompactMode) {
    if (!isCompactMode) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: _buildIconButton(
          icon: Icons.chevron_left,
          onPressed: _toggleExpanded,
          tooltip: '折叠',
          isDark: isDark,
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            _buildIconButton(
              icon: Icons.search,
              onPressed: _toggleSearch,
              tooltip: '搜索',
              isDark: isDark,
            ),
            const SizedBox(height: 4),
            _buildIconButton(
              icon: Icons.settings,
              onPressed: _openSettings,
              tooltip: '设置',
              isDark: isDark,
            ),
          ],
        ),
      );
    }
  }
}
