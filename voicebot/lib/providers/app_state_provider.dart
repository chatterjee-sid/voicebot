import 'package:flutter/material.dart';
import '../models/command_model.dart';

class AppStateProvider with ChangeNotifier {
  // Language state
  VoiceLanguage _selectedLanguage = VoiceLanguage.english;
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
