import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme.dart';
import 'providers/app_state.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/robot_control_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/esp32_connection_screen.dart';
import 'screens/esp32_test_screen.dart';

// Global instance of AppState for use throughout the app
final appState = AppState();

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Force portrait orientation
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Listen to changes in the dark mode setting and refresh the UI
    appState.addListener(_refreshUI);
  }

  @override
  void dispose() {
    appState.removeListener(_refreshUI);
    super.dispose();
  }

  void _refreshUI() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice-Controlled Robot',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: appState.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/home': (context) => const HomeScreen(),
        '/robot_control': (context) => const RobotControlScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/esp32_connection': (context) => const ESP32ConnectionScreen(),
        '/esp32_test': (context) => const ESP32TestScreen(),
      },
    );
  }
}
