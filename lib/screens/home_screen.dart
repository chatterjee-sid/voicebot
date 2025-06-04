import 'dart:async';
import 'package:flutter/material.dart';
import '../services/audio_recorder.dart';
import '../services/api_service.dart';
import '../services/esp32_wifi_service.dart';
import '../providers/app_state.dart';
import '../widgets/audio_visualizer.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // Get the single instance of AppState
  final appState = AppState();

  bool isRecording = false;
  String statusMessage = 'Ready to record';
  String lastRecordedCommand = '';
  bool isProcessing = false;
  bool isScanning = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Recording-related state
  Duration recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  StreamSubscription? _recorderSubscription;
  double currentVolume = 0;
  String _debugInfo = ''; // For showing if recording is real or mock

  // ESP32 WiFi service
  final ESP32WiFiService _wifiService = ESP32WiFiService();
  bool _isConnectedToESP32 = false;
  String _esp32IpAddress = '';
  StreamSubscription? _dataStreamSubscription;

  // Microphone diagnostics state
  bool _showDiagnostics = false;
  Map<String, dynamic> _diagnosticResults = {};

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(_pulseController);

    // Initialize permissions before trying any recording
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    try {
      // Initialize audio recorder in the background
      final hasPermission =
          await AudioRecorderService.checkMicrophonePermission();
      setState(() {
        statusMessage =
            hasPermission
                ? 'Ready to record'
                : 'Microphone permission required';
      });

      // Initialize ESP32 WiFi
      _checkConnectionStatus();
    } catch (e) {
      setState(() {
        statusMessage = 'Error initializing: $e';
      });
    }
  }

  Future<void> _checkConnectionStatus() async {
    await _wifiService.init();
    setState(() {
      _isConnectedToESP32 = _wifiService.isConnected;
      _esp32IpAddress = _wifiService.espIpAddress;
      statusMessage =
          _isConnectedToESP32
              ? 'Connected to ESP32 at $_esp32IpAddress. Ready to record.'
              : 'WiFi enabled. Ready to record.';
    });

    // Setup data listener for ESP32 responses
    _dataStreamSubscription?.cancel();
    _dataStreamSubscription = _wifiService.dataStream.listen((message) {
      setState(() {
        statusMessage = 'ESP32 response: $message';
      });
    });

    // Update app state
    appState.setRobotConnection(_isConnectedToESP32);
  }

  // Run microphone diagnostics
  Future<void> _runMicrophoneDiagnostics() async {
    setState(() {
      isProcessing = true;
      statusMessage = 'Running microphone diagnostics...';
    });

    try {
      final results = await AudioRecorderService.runDiagnostics();

      setState(() {
        _diagnosticResults = results;
        _showDiagnostics = true;
        isProcessing = false;
        statusMessage = 'Diagnostics complete';
      });
    } catch (e) {
      setState(() {
        statusMessage = 'Error running diagnostics: $e';
        isProcessing = false;
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _recorderSubscription?.cancel();
    _recordingTimer?.cancel();
    _dataStreamSubscription?.cancel();
    AudioRecorderService.dispose();
    _wifiService.dispose();
    super.dispose();
  }

  void _scanForESP32Devices() async {
    setState(() {
      isScanning = true;
      statusMessage = 'Scanning for ESP32 devices...';
    });

    try {
      // Navigate to ESP32 connection screen
      final result = await Navigator.pushNamed(context, '/esp32_connection');

      // Check if connection was successful
      if (result == true) {
        setState(() {
          _isConnectedToESP32 = _wifiService.isConnected;
          _esp32IpAddress = _wifiService.espIpAddress;
          statusMessage = 'Connected to ESP32 at $_esp32IpAddress';
        });
        appState.setRobotConnection(_isConnectedToESP32);
      } else {
        setState(() {
          statusMessage = 'ESP32 connection canceled';
        });
      }
    } catch (e) {
      setState(() {
        statusMessage = 'Error scanning for ESP32 devices: $e';
      });
    } finally {
      setState(() {
        isScanning = false;
      });
    }
  }

  // Start the recording timer to update UI - enhanced with debug info
  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      if (mounted) {
        setState(() {
          recordingDuration = AudioRecorderService.recordingDuration;
          currentVolume = AudioRecorderService.currentVolume;

          // Update debug info - let user know if recording is real or mock
          _debugInfo =
              AudioRecorderService.isMockRecording
                  ? "MOCK RECORDING (not using microphone)"
                  : "REAL RECORDING (using microphone)";

          // Get latest debug info from the recorder service
          if (AudioRecorderService.debugInfo.isNotEmpty) {
            statusMessage = AudioRecorderService.debugInfo;
          }
        });
      }
    });
  }

  Future<void> toggleRecording() async {
    try {
      if (!isRecording) {
        // Start recording
        setState(() {
          isProcessing = true;
          statusMessage = 'Starting recorder...';
        });

        final success = await AudioRecorderService.startRecording();

        setState(() {
          isRecording = success;
          isProcessing = false;
          statusMessage =
              success ? 'Recording... Speak now' : 'Failed to start recording';

          // Set debug info immediately
          _debugInfo =
              AudioRecorderService.isMockRecording
                  ? "MOCK RECORDING (not using microphone)"
                  : "REAL RECORDING (using microphone)";
        });

        if (success) {
          _startRecordingTimer();
        }
      } else {
        // Stop recording
        setState(() {
          isProcessing = true;
          isRecording = false;
          statusMessage = 'Processing audio...';
        });

        _recordingTimer?.cancel();

        final filePath = await AudioRecorderService.stopRecording();

        if (filePath == null) {
          setState(() {
            statusMessage = 'Recording failed: No audio file created';
            isProcessing = false;
          });
          return;
        }

        try {
          // Add file info to status
          setState(() {
            statusMessage = 'Processing audio file: $filePath';
          });

          // Process the audio file with the selected language by sending it to backend
          final action = await ApiService.processAudioCommand(
            filePath,
            appState.selectedLanguage.value.code,
          );

          setState(() {
            lastRecordedCommand = action;
            statusMessage = 'Command recognized: $action';
            isProcessing = false;
          });

          appState.setLastCommand(action);

          // Send command to the ESP32 if connected
          if (_isConnectedToESP32) {
            final sent = await _wifiService.sendCommand(action);
            if (sent) {
              setState(() {
                statusMessage = 'Command sent to ESP32: $action';
              });
            } else {
              setState(() {
                statusMessage = 'Failed to send command to ESP32';
              });
            }
          }
        } catch (e) {
          setState(() {
            statusMessage = 'Error: $e';
            isProcessing = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        statusMessage = 'Error: $e';
        isProcessing = false;
        isRecording = false;
      });
    }
  }

  Future<void> _cancelRecording() async {
    if (isRecording) {
      _recordingTimer?.cancel();
      try {
        await AudioRecorderService.stopRecording();
        await AudioRecorderService.deleteRecording();

        setState(() {
          isRecording = false;
          statusMessage = 'Recording cancelled';
          recordingDuration = Duration.zero;
        });
      } catch (e) {
        setState(() {
          isRecording = false;
          statusMessage = 'Error cancelling recording: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // If diagnostics view is shown, create a completely separate UI for it
    if (_showDiagnostics) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Microphone Diagnostics'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              setState(() {
                _showDiagnostics = false;
              });
            },
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Display diagnostic results
            Expanded(
              child:
                  _diagnosticResults.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // System info
                          _buildDiagnosticSection('System Information', {
                            'Operating System':
                                _diagnosticResults['os'] ?? 'Unknown',
                            'OS Version':
                                _diagnosticResults['osVersion'] ?? 'Unknown',
                          }),
                          const Divider(),

                          // Microphone access
                          _buildDiagnosticSection('Microphone Permissions', {
                            'Permission Status':
                                _diagnosticResults['microphonePermissionStatus'] ??
                                'Unknown',
                            'Permission Request Result':
                                _diagnosticResults['microphonePermissionRequest'] ??
                                'Not requested',
                          }),
                          const Divider(),

                          // Recorder state
                          _buildDiagnosticSection('Audio Recorder', {
                            'Recorder Created': _boolToString(
                              _diagnosticResults['recorderCreated'],
                            ),
                            'Recorder Initialized': _boolToString(
                              _diagnosticResults['recorderInitialized'],
                            ),
                            'Recorder Open': _boolToString(
                              _diagnosticResults['recorderIsOpen'],
                            ),
                            'Initialization Error':
                                _diagnosticResults['recorderInitError'] ??
                                'None',
                          }),
                          const Divider(),

                          // File system
                          _buildDiagnosticSection('File System', {
                            'File System Accessible': _boolToString(
                              _diagnosticResults['fileSystemAccessible'],
                            ),
                            'File System Writable': _boolToString(
                              _diagnosticResults['fileSystemWritable'],
                            ),
                            'Documents Directory':
                                _diagnosticResults['appDocsPath'] ?? 'Unknown',
                          }),
                          const Divider(),

                          // Solution suggestions
                          _buildSolutionSuggestions(),
                        ],
                      ),
            ),
          ],
        ),
        // Add a floating action button as a secondary option
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            setState(() {
              _showDiagnostics = false;
            });
          },
          tooltip: 'Return to main screen',
          child: const Icon(Icons.home),
        ),
      );
    }

    // Regular home screen UI when diagnostics are not shown
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('Voice-Controlled Robot'),
            const Text(
              'Developed by Group2 SVNIT',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          // Add diagnostic button
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'Microphone Diagnostics',
            onPressed: _runMicrophoneDiagnostics,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Status and language section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: appState.isConnectedToRobot,
                  builder: (context, isConnected, child) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isConnected ? Icons.wifi : Icons.wifi_off,
                              color:
                                  isConnected
                                      ? theme.colorScheme.primary
                                      : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isConnected
                                  ? 'ESP32 Connected'
                                  : 'ESP32 Disconnected',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                        ValueListenableBuilder<VoiceLanguage>(
                          valueListenable: appState.selectedLanguage,
                          builder: (context, selectedLanguage, child) {
                            return DropdownButton<VoiceLanguage>(
                              value: selectedLanguage,
                              onChanged: (VoiceLanguage? newLanguage) {
                                if (newLanguage != null) {
                                  appState.setLanguage(newLanguage);
                                }
                              },
                              items:
                                  VoiceLanguage.values
                                      .map<DropdownMenuItem<VoiceLanguage>>(
                                        (language) =>
                                            DropdownMenuItem<VoiceLanguage>(
                                              value: language,
                                              child: Text(language.displayName),
                                            ),
                                      )
                                      .toList(),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isProcessing
                            ? Icons.sync
                            : (isRecording ? Icons.mic : Icons.info_outline),
                        color:
                            isRecording
                                ? Colors.red
                                : theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SelectableText(
                          statusMessage,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                // Debug banner - show when recording
                if (isRecording && _debugInfo.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      color:
                          AudioRecorderService.isMockRecording
                              ? Colors.orange.withOpacity(0.8)
                              : Colors.green.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _debugInfo,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Main content area (shown when diagnostics are not visible)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Audio visualizer when recording
                    if (isRecording)
                      AudioVisualizer(
                        isRecording: isRecording,
                        recordingDuration: recordingDuration,
                      ),

                    // Robot command visualization
                    if (lastRecordedCommand.isNotEmpty && !isRecording)
                      Container(
                        margin: const EdgeInsets.only(bottom: 40),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Last Command:',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 10),
                            SelectableText(
                              lastRecordedCommand.toUpperCase(),
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Icon(
                              _getCommandIcon(lastRecordedCommand),
                              color: theme.colorScheme.primary,
                              size: 50,
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 20),

                    // Recording controls - simplified to only voice controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Cancel button (when recording)
                        if (isRecording)
                          Padding(
                            padding: const EdgeInsets.only(right: 32.0),
                            child: IconButton.filled(
                              onPressed: _cancelRecording,
                              icon: const Icon(Icons.cancel),
                              color: Colors.white,
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.red,
                                minimumSize: const Size(60, 60),
                              ),
                            ),
                          ),

                        // Record/Stop button
                        ScaleTransition(
                          scale: _pulseAnimation,
                          child: InkWell(
                            onTap: isProcessing ? null : toggleRecording,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color:
                                    isRecording
                                        ? Colors.red
                                        : theme.colorScheme.primary,
                                boxShadow: [
                                  BoxShadow(
                                    color: (isRecording
                                            ? Colors.red
                                            : theme.colorScheme.primary)
                                        .withOpacity(0.5),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Icon(
                                isRecording ? Icons.stop : Icons.mic,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    Text(
                      isRecording
                          ? 'Tap to stop recording'
                          : 'Tap to record voice command',
                      style: theme.textTheme.bodyLarge,
                    ),

                    if (!isRecording && AudioRecorderService.isMockRecording)
                      Container(
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.warning_amber,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Using mock recordings - tap "Microphone Diagnostics" icon to troubleshoot',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.orange[800],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Add ESP32 test option for development
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0, top: 16.0),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.developer_board),
                        label: const Text('ESP32 WiFi Test'),
                        onPressed:
                            () => Navigator.pushNamed(context, '/esp32_test'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton:
          isRecording
              ? null
              : FloatingActionButton(
                onPressed: isScanning ? null : _scanForESP32Devices,
                tooltip: 'Connect to ESP32',
                child: Icon(isScanning ? Icons.wifi_find : Icons.wifi),
              ),
    );
  }

  // Helper to format boolean values for the diagnostic display
  String _boolToString(dynamic value) {
    if (value == null) return 'Unknown';
    return value == true ? 'Yes ✅' : 'No ❌';
  }

  // Build a section of the diagnostic results
  Widget _buildDiagnosticSection(String title, Map<String, String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        ...items.entries
            .map(
              (entry) => Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${entry.key}: ',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Expanded(
                      child: SelectableText(
                        entry.value,
                        style: TextStyle(
                          color: entry.value.contains('❌') ? Colors.red : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ],
    );
  }

  // Build solution suggestions based on diagnostic results
  Widget _buildSolutionSuggestions() {
    final List<String> suggestions = [];

    // Check permission issues
    if (_diagnosticResults['microphonePermissionStatus'] !=
        'PermissionStatus.granted') {
      suggestions.add(
        '• Check Windows Privacy Settings to allow microphone access for this app',
      );
      suggestions.add('• Try running the app with administrator privileges');
    }

    // Check recorder initialization issues
    if (_diagnosticResults['recorderInitialized'] != true) {
      suggestions.add(
        '• Make sure a microphone is properly connected to your computer',
      );
      suggestions.add(
        '• Check if the microphone is set as the default recording device in Windows Sound settings',
      );
      suggestions.add('• Try updating your audio drivers');
    }

    // Check filesystem issues
    if (_diagnosticResults['fileSystemAccessible'] != true ||
        _diagnosticResults['fileSystemWritable'] != true) {
      suggestions.add('• The app may not have proper file system access');
      suggestions.add('• Try running the app from a different location');
    }

    // If no specific issues found, provide general suggestions
    if (suggestions.isEmpty) {
      suggestions.add('• Restart the application and try again');
      suggestions.add(
        '• Check if your microphone is muted or disabled in Windows',
      );
      suggestions.add('• Try using a different microphone if available');
      suggestions.add('• Restart your computer to reset audio services');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Suggested Solutions',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        ...suggestions
            .map(
              (suggestion) => Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 8),
                child: SelectableText(suggestion),
              ),
            )
            .toList(),
      ],
    );
  }

  IconData _getCommandIcon(String command) {
    switch (command.toLowerCase()) {
      case 'forward':
        return Icons.arrow_upward;
      case 'backward':
        return Icons.arrow_downward;
      case 'left':
        return Icons.arrow_back;
      case 'right':
        return Icons.arrow_forward;
      case 'stop':
        return Icons.stop;
      default:
        return Icons.device_unknown;
    }
  }
}
