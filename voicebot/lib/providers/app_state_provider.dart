import 'package:flutter/material.dart';

// Define the VoiceLanguage enum here if it doesn't exist in command_model.dart
enum VoiceLanguage {
  english(code: 'en', displayName: 'English'),
  hindi(code: 'hi', displayName: 'Hindi'),
  gujarati(code: 'gu', displayName: 'Gujarati');

  const VoiceLanguage({required this.code, required this.displayName});

  final String code;
  final String displayName;
}

class AppStateProvider with ChangeNotifier {
  // Language state
  VoiceLanguage _selectedLanguage = VoiceLanguage.english;
  // Default to true for dark mode
  bool _isDarkMode = true;
  String _lastCommand = '';
  bool _isConnectedToRobot = false;

  // Getters
  VoiceLanguage get selectedLanguage => _selectedLanguage;
  bool get isDarkMode => _isDarkMode;
  String get lastCommand => _lastCommand;
  bool get isConnectedToRobot => _isConnectedToRobot;

  // Setters with notifyListeners
  void setLanguage(VoiceLanguage language) {
    _selectedLanguage = language;
    notifyListeners();
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  void setLastCommand(String command) {
    _lastCommand = command;
    notifyListeners();
  }

  void setRobotConnection(bool isConnected) {
    _isConnectedToRobot = isConnected;
    notifyListeners();
  }
}
