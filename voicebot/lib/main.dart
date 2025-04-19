import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';
import 'core/theme.dart';
import 'providers/app_state.dart';

// Global flag to quickly identify if we're running on Windows
// This helps conditionally disable problematic native features
final bool isRunningOnWindows = Platform.isWindows;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations (not needed for Windows, but kept for mobile)
  if (!isRunningOnWindows) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Set system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  // Show a platform-specific warning if running on Windows
  if (isRunningOnWindows) {
    debugPrint('Running on Windows - some features will be limited');
  }

  runApp(const VoiceControlApp());
}

class VoiceControlApp extends StatefulWidget {
  const VoiceControlApp({super.key});

  @override
  State<VoiceControlApp> createState() => _VoiceControlAppState();
}

class _VoiceControlAppState extends State<VoiceControlApp> {
  // Get the single instance of AppState
  final appState = AppState();

  @override
  Widget build(BuildContext context) {
    // Use ValueListenableBuilder to rebuild when isDarkMode changes
    return ValueListenableBuilder<bool>(
      valueListenable: appState.isDarkMode,
      builder: (context, isDarkMode, child) {
        return MaterialApp(
          title: 'Voice-Controlled Robot',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const SplashScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
