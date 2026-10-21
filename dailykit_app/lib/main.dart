import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/notification_service.dart';
import 'core/database/local_database_service.dart';
import 'providers/auth_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/habit_provider.dart';
import 'providers/expense_provider.dart';
import 'providers/item_provider.dart';
import 'providers/renewal_provider.dart';
import 'screens/home/root_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize local notifications service
  await NotificationService().init();

  // Initialize Phone Storage (SQLite Database)
  await LocalDatabaseService().database;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..checkAuthStatus()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => HabitProvider()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => ItemProvider()),
        ChangeNotifierProvider(create: (_) => RenewalProvider()),
      ],
      child: const DailyKitApp(),
    ),
  );
}

class DailyKitApp extends StatelessWidget {
  const DailyKitApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();

    return MaterialApp(
      title: 'HEW',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settingsProvider.themeMode,
      home: const RootNavigationScreen(),
    );
  }
}
