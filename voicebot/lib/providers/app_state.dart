import 'package:flutter/material.dart';
import '../models/command_model.dart';

/// A simple state management class that uses ValueNotifier instead of provider
/// This class follows the Singleton pattern for global access
class AppState {
  // Singleton instance
  static final AppState _instance = AppState._internal();

  // Factory constructor to return the same instance
  factory AppState() => _instance;

  // Private constructor
  AppState._internal();

  // State variables using ValueNotifier for reactivity
  final selectedLanguage = ValueNotifier<VoiceLanguage>(VoiceLanguage.english);
  final isDarkMode = ValueNotifier<bool>(true);
  final lastCommand = ValueNotifier<String>('');
  final isConnectedToRobot = ValueNotifier<bool>(false);

  // Methods to update state
  void setLanguage(VoiceLanguage language) {
    selectedLanguage.value = language;
  }

  void toggleTheme() {
    isDarkMode.value = !isDarkMode.value;
  }

  void setLastCommand(String command) {
    lastCommand.value = command;
  }

  void setRobotConnection(bool isConnected) {
    isConnectedToRobot.value = isConnected;
  }

  // Dispose method to clean up resources
  void dispose() {
    selectedLanguage.dispose();
    isDarkMode.dispose();
    lastCommand.dispose();
    isConnectedToRobot.dispose();
  }
}
