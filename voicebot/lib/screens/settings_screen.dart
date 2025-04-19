import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_state.dart';
import '../models/command_model.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Reference to global app state
  final appState = AppState();

  // Local settings
  late VoiceLanguage _selectedLanguage;
  bool _isDarkMode = false;
  bool _showDebugInfo = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      // Load language from app state
      _selectedLanguage = appState.selectedLanguage.value;

      // Load dark mode setting
      _isDarkMode = appState.isDarkMode.value;

      // Load debug info setting
      _showDebugInfo = appState.showDebugInfo.value;
    });
  }

  Future<void> _saveSettings() async {
    // Save settings to app state
    appState.setLanguage(_selectedLanguage);
    appState.setDarkMode(_isDarkMode);
    appState.setDebugInfoVisibility(_showDebugInfo);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Settings saved')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: 'Save Settings',
          ),
        ],
      ),
      body: ListView(
        children: [
          // Language Settings
          ListTile(
            title: const Text('Language'),
            subtitle: const Text('Select voice command language'),
            trailing: DropdownButton<VoiceLanguage>(
              value: _selectedLanguage,
              onChanged: (newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedLanguage = newValue;
                  });
                }
              },
              items:
                  VoiceLanguage.values.map((language) {
                    return DropdownMenuItem<VoiceLanguage>(
                      value: language,
                      child: Text(language.displayName),
                    );
                  }).toList(),
            ),
          ),

          const Divider(),

          // Theme Setting - change the label to reflect dark mode is primary
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Enable dark theme (recommended)'),
            value: _isDarkMode,
            onChanged: (value) {
              setState(() {
                _isDarkMode = value;
              });
              // This would normally also update the app theme
            },
          ),

          // Debug Info Setting
          SwitchListTile(
            title: const Text('Show Debug Information'),
            subtitle: const Text(
              'Display technical details for troubleshooting',
            ),
            value: _showDebugInfo,
            onChanged: (value) {
              setState(() {
                _showDebugInfo = value;
              });
            },
          ),

          const Divider(),

          // About section
          const ListTile(
            title: Text('About'),
            subtitle: Text('Voice-Controlled Robot v1.0.0'),
          ),

          ListTile(
            title: const Text('Developed by'),
            subtitle: const Text('Group2 SVNIT'),
            trailing: IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'Voice-Controlled Robot',
                  applicationVersion: '1.0.0',
                  applicationIcon: const FlutterLogo(size: 50),
                  children: const [
                    Text(
                      'A voice-controlled robot application that uses speech recognition to convert voice commands into robot movements.',
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Developed by Group2 of SVNIT as part of the App Development project.',
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
