import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/connection_repository.dart';
import 'domain/services/terminal_service.dart';
import 'domain/services/sync_service.dart';
import 'domain/services/app_config_service.dart';
import 'presentation/providers/connection_provider.dart';
import 'presentation/providers/terminal_provider.dart';
import 'presentation/providers/sync_provider.dart';
import 'presentation/providers/app_config_provider.dart';
import 'presentation/screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final connectionRepository = ConnectionRepository();
  await connectionRepository.init();

  final terminalService = TerminalService();
  final syncService = SyncService(connectionRepository);
  final appConfigService = AppConfigService.getInstance();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) =>
              ConnectionProvider(connectionRepository)..loadConnections(),
        ),
        ChangeNotifierProvider(
          create: (_) => TerminalProvider(terminalService, appConfigService),
        ),
        ChangeNotifierProvider(create: (_) => SyncProvider(syncService)),
        ChangeNotifierProvider(
          create: (_) => AppConfigProvider(appConfigService),
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
