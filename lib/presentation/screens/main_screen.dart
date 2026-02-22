import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/terminal_provider.dart';
import '../screens/sftp_browser_screen.dart';
import '../widgets/collapsible_sidebar.dart';
import '../widgets/terminal_view.dart';

/// 主界面
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final terminalProvider = Provider.of<TerminalProvider>(
        context,
        listen: false,
      );
      terminalProvider.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Connection list sidebar
          CollapsibleSidebar(
            onSftpTap: (connection) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SftpBrowserScreen(connection: connection),
                ),
              );
            },
          ),
          const VerticalDivider(width: 1),
          // Terminal view
          const Expanded(
            child: TerminalTabsView(),
          ),
        ],
      ),
    );
  }
}
