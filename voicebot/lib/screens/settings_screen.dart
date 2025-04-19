import 'package:flutter/material.dart';
import '../providers/app_state.dart';
import '../models/command_model.dart';
import '../services/api_service.dart';
import '../services/bluetooth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Get the single instance of AppState
  final appState = AppState();

  bool isCheckingServer = false;
  bool isServerReachable = false;
  final serverUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize text controllers with current model URLs
    serverUrlController.text = ApiService.baseUrl;
  }

  @override
  void dispose() {
    serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _checkServerConnection() async {
    setState(() {
      isCheckingServer = true;
    });

    try {
      final isReachable = await ApiService.checkServerStatus();
      setState(() {
        isServerReachable = isReachable;
        isCheckingServer = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SelectableText(
              isReachable
                  ? 'Server is reachable and ready to process commands'
                  : 'Could not reach server. Please check the URL and try again',
            ),
            backgroundColor: isReachable ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isCheckingServer = false;
          isServerReachable = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SelectableText('Error connecting to server: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _disconnectBluetooth() async {
    await BluetoothService.disconnect();

    // Update app state
    appState.setRobotConnection(false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: SelectableText('Bluetooth disconnected')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Settings'),
            Text(
              'Developed by Group2 SVNIT',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: theme.colorScheme.onPrimary.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Language Section
          Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Voice Language', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 16),
                  const SelectableText(
                    'Select the language for voice commands:',
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<VoiceLanguage>(
                    valueListenable: appState.selectedLanguage,
                    builder: (context, selectedLanguage, child) {
                      return Column(
                        children:
                            VoiceLanguage.values
                                .map(
                                  (language) => RadioListTile<VoiceLanguage>(
                                    title: Text(language.displayName),
                                    value: language,
                                    groupValue: selectedLanguage,
                                    onChanged: (VoiceLanguage? value) {
                                      if (value != null) {
                                        appState.setLanguage(value);
                                      }
                                    },
                                  ),
                                )
                                .toList(),
                      );
                    },
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: SelectableText(
                      'Note: Hindi and Gujarati may have higher latency and lower accuracy.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Backend Server Settings
          Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Backend Server', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 16),
                  const SelectableText(
                    'Configure the backend server settings:',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: serverUrlController,
                    decoration: InputDecoration(
                      labelText: 'Server URL',
                      hintText: 'https://your-ngrok-url.ngrok.io',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.save),
                        onPressed: () {
                          // Would normally save this to persistent storage
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: SelectableText('Server URL updated'),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: isCheckingServer ? null : _checkServerConnection,
                    icon:
                        isCheckingServer
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.cloud_done),
                    label: Text(
                      isCheckingServer ? 'Checking...' : 'Test Connection',
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bluetooth Settings
          Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Robot Connection', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<bool>(
                    valueListenable: appState.isConnectedToRobot,
                    builder: (context, isConnected, child) {
                      return ListTile(
                        leading: Icon(
                          isConnected
                              ? Icons.bluetooth_connected
                              : Icons.bluetooth_disabled,
                          color: isConnected ? theme.colorScheme.primary : null,
                        ),
                        title: const Text('Bluetooth Connection'),
                        subtitle: SelectableText(
                          isConnected
                              ? 'Connected to robot'
                              : 'Not connected to any device',
                        ),
                        trailing:
                            isConnected
                                ? ElevatedButton(
                                  onPressed: _disconnectBluetooth,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  child: const Text('Disconnect'),
                                )
                                : null,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // App Theme Settings
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Appearance', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<bool>(
                    valueListenable: appState.isDarkMode,
                    builder: (context, isDarkMode, child) {
                      return SwitchListTile(
                        title: const Text('Dark Mode'),
                        subtitle: const Text('Use dark theme'),
                        value: isDarkMode,
                        onChanged: (_) => appState.toggleTheme(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // App Info
          const SizedBox(height: 20),
          Center(
            child: SelectableText(
              'Voice-Controlled Driving Robot',
              style: theme.textTheme.titleMedium,
            ),
          ),
          Center(
            child: SelectableText('v1.0.0', style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
