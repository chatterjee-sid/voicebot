import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Singleton pattern for global app state
class AppState extends ChangeNotifier {
  // Singleton instance
  static final AppState _instance = AppState._internal();

  factory AppState() {
    return _instance;
  }

  AppState._internal() {
    _loadSavedSettings();
  }

  // Language settings
  final ValueNotifier<VoiceLanguage> selectedLanguage = ValueNotifier(
    VoiceLanguage.english,
  );

  // Dark mode setting - default to true for dark theme
  bool _isDarkMode = true;
  bool get isDarkMode => _isDarkMode;

  // Debug mode setting
  final ValueNotifier<bool> showDebugInfo = ValueNotifier(false);

  // Robot connection state
  final ValueNotifier<bool> isConnectedToRobot = ValueNotifier(false);

  // Last recognized command
  final ValueNotifier<String> lastCommand = ValueNotifier("");

  // Load settings from shared preferences
  Future<void> _loadSavedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load language setting
      final String? langCode = prefs.getString('language');
      if (langCode != null) {
        selectedLanguage.value = VoiceLanguage.values.firstWhere(
          (l) => l.code == langCode,
          orElse: () => VoiceLanguage.english,
        );
      }

      // Load dark mode setting, default to true if not set
      _isDarkMode = prefs.getBool('darkMode') ?? true;

      // Load debug info setting
      showDebugInfo.value = prefs.getBool('showDebugInfo') ?? false;

      // Notify listeners after loading settings
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  // Set language and save to shared preferences
  Future<void> setLanguage(VoiceLanguage language) async {
    selectedLanguage.value = language;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language', language.code);
    } catch (e) {
      debugPrint('Error saving language setting: $e');
    }
  }

  // Set dark mode and save to shared preferences
  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('darkMode', value);
    } catch (e) {
      debugPrint('Error saving dark mode setting: $e');
    }
  }

  // Set debug info and save to shared preferences
  Future<void> setDebugInfoVisibility(bool value) async {
    showDebugInfo.value = value;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('showDebugInfo', value);
    } catch (e) {
      debugPrint('Error saving debug info setting: $e');
    }
  }

  // Update robot connection state
  void setRobotConnection(bool isConnected) {
    isConnectedToRobot.value = isConnected;
  }

  // Update last command
  void setLastCommand(String command) {
    lastCommand.value = command;
  }
}

// Voice language enum
enum VoiceLanguage {
  english(code: 'en', displayName: 'English'),
  hindi(code: 'hi', displayName: 'Hindi'),
  gujarati(code: 'gu', displayName: 'Gujarati');

  const VoiceLanguage({required this.code, required this.displayName});

  final String code;
  final String displayName;
}
