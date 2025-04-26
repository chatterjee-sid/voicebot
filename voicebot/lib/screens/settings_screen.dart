import 'package:flutter/material.dart';
import '../providers/app_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Using the global instance from main.dart
  final appState = AppState();

  @override
  void initState() {
    super.initState();
    // Listen to AppState changes to refresh UI when needed
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Language settings
          Card(
            elevation: 2.0,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Language Settings', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 16.0),
                  ValueListenableBuilder<VoiceLanguage>(
                    valueListenable: appState.selectedLanguage,
                    builder: (context, selectedLanguage, child) {
                      return Column(
                        children:
                            VoiceLanguage.values.map((language) {
                              return RadioListTile<VoiceLanguage>(
                                title: Text(language.displayName),
                                subtitle: Text('Code: ${language.code}'),
                                value: language,
                                groupValue: selectedLanguage,
                                onChanged: (VoiceLanguage? newLanguage) {
                                  if (newLanguage != null) {
                                    appState.setLanguage(newLanguage);
                                  }
                                },
                              );
                            }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16.0),

          // Appearance settings
          Card(
            elevation: 2.0,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Appearance', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 16.0),
                  SwitchListTile(
                    title: const Text('Dark Mode'),
                    subtitle: const Text('Use dark theme throughout the app'),
                    value: appState.isDarkMode,
                    onChanged: (value) {
                      appState.setDarkMode(value);
                    },
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: appState.showDebugInfo,
                    builder: (context, showDebug, child) {
                      return SwitchListTile(
                        title: const Text('Show Debug Info'),
                        subtitle: const Text('Display technical information'),
                        value: showDebug,
                        onChanged: (value) {
                          appState.setDebugInfoVisibility(value);
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16.0),

          // About section
          Card(
            elevation: 2.0,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('About', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 16.0),
                  const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Version'),
                    subtitle: Text('1.0.0'),
                  ),
                  const Divider(),
                  const ListTile(
                    leading: Icon(Icons.people_outline),
                    title: Text('Developed by'),
                    subtitle: Text('Group2 SVNIT'),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: const Text('Help'),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder:
                            (context) => AlertDialog(
                              title: const Text('Help'),
                              content: const SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Voice Commands:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text('• Say "Forward" to move forward'),
                                    Text('• Say "Backward" to move backward'),
                                    Text('• Say "Left" to turn left'),
                                    Text('• Say "Right" to turn right'),
                                    Text('• Say "Stop" to stop the robot'),

                                    SizedBox(height: 16),
                                    Text(
                                      'Connection Issues:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text('• Make sure Bluetooth is enabled'),
                                    Text('• Try restarting the robot'),
                                    Text('• Check if the robot is powered on'),
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                      );
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.policy_outlined),
                    title: const Text('Privacy Policy'),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder:
                            (context) => AlertDialog(
                              title: const Text('Privacy Policy'),
                              content: const SingleChildScrollView(
                                child: Text(
                                  'This application uses your microphone to capture voice commands. '
                                  'The audio data is processed locally and on our servers to recognize commands. '
                                  'We do not store your voice recordings after processing. '
                                  'Bluetooth permissions are used to connect to and control the robot.',
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
