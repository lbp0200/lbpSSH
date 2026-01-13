import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/connection_repository.dart';
import 'domain/services/terminal_service.dart';
import 'domain/services/sync_service.dart';
import 'presentation/providers/connection_provider.dart';
import 'presentation/providers/terminal_provider.dart';
import 'presentation/providers/sync_provider.dart';
import 'presentation/screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化仓库
  final connectionRepository = ConnectionRepository();
  await connectionRepository.init();

  // 初始化服务
  final terminalService = TerminalService();
  final syncService = SyncService(connectionRepository);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ConnectionProvider(connectionRepository)
            ..loadConnections(),
        ),
        ChangeNotifierProvider(
          create: (_) => TerminalProvider(terminalService),
        ),
        ChangeNotifierProvider(
          create: (_) => SyncProvider(syncService),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SSH Manager',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
