import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../services/api_service.dart';
import '../services/esp32_wifi_service.dart';
import '../services/audio_recorder.dart';

class RobotControlScreen extends StatefulWidget {
  const RobotControlScreen({super.key});

  @override
  State<RobotControlScreen> createState() => _RobotControlScreenState();
}

class _RobotControlScreenState extends State<RobotControlScreen> {
  bool _isRecording = false;
  String _audioPath = '';
  String _commandResult = '';
  bool _isProcessing = false;
  String _selectedLanguage = 'en'; // Default to English
  bool _isConnected = false;
  String _connectedDeviceName = 'No device connected';
  Timer? _recordingTimer;
  final ESP32WiFiService _wifiService = ESP32WiFiService();
  StreamSubscription? _dataSubscription;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkPermissions();
    _initESP32Connection();
    _setupDataListener();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedLanguage = prefs.getString('language') ?? 'en';
    });
  }

  Future<void> _checkPermissions() async {
    await AudioRecorderService.checkMicrophonePermission();
  }

  void _setupDataListener() {
    _dataSubscription?.cancel();
    _dataSubscription = _wifiService.dataStream.listen((message) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Robot responded: $message'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    });
  }

  Future<void> _initESP32Connection() async {
    try {
      final bool isEnabled = await _wifiService.init();

      if (!isEnabled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Not connected to any ESP32. Please connect to control the robot.',
            ),
          ),
        );
      }

      setState(() {
        _isConnected = _wifiService.isConnected;
        _connectedDeviceName =
            _isConnected
                ? 'Connected to ${_wifiService.espIpAddress}'
                : 'No device connected';
      });
    } catch (e) {
      setState(() {
        _isConnected = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize connection: ${e.toString()}'),
          ),
        );
      }
    }
  }

  Future<void> _connectToESP32() async {
    try {
      // Navigate to ESP32 connection screen
      final result = await Navigator.pushNamed(context, '/esp32_connection');

      // Check if connection was successful
      if (result == true) {
        setState(() {
          _isConnected = _wifiService.isConnected;
          _connectedDeviceName = 'Connected to ${_wifiService.espIpAddress}';
        });

        if (_isConnected && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Connected to ESP32 at ${_wifiService.espIpAddress}',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error connecting to ESP32: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _disconnectFromESP32() async {
    try {
      // Call the disconnect method from ESP32WiFiService
      _wifiService.disconnect();

      setState(() {
        _isConnected = false;
        _connectedDeviceName = 'No device connected';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Disconnected from ESP32'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error disconnecting from ESP32: ${e.toString()}'),
          ),
        );
      }
    }
  }

  Future<void> _startRecording() async {
    try {
      final success = await AudioRecorderService.startRecording();

      if (success) {
        setState(() {
          _isRecording = true;
          _commandResult = '';
        });

        // Start timer to update UI
        _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (
          timer,
        ) {
          // Update UI as needed, no need to track recordingDuration locally
          if (mounted) {
            setState(() {
              // We can update UI directly without storing local variables
            });
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to start recording')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error starting recording: ${e.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start recording: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;

    try {
      setState(() {
        _isRecording = false;
        _isProcessing = true;
      });

      final path = await AudioRecorderService.stopRecording();

      if (path != null) {
        setState(() {
          _audioPath = path;
        });
        await _processAudio();
      } else {
        setState(() {
          _isProcessing = false;
          _commandResult = 'Recording failed';
        });
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
        _isProcessing = false;
      });

      debugPrint('Error stopping recording: ${e.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process recording: ${e.toString()}'),
          ),
        );
      }
    }
  }

  Future<void> _processAudio() async {
    try {
      if (_audioPath.isEmpty) {
        setState(() {
          _isProcessing = false;
          _commandResult = 'No audio recorded';
        });
        return;
      }

      final file = File(_audioPath);
      if (!await file.exists()) {
        setState(() {
          _isProcessing = false;
          _commandResult = 'Audio file not found';
        });
        return;
      }

      final command = await ApiService.processAudioCommand(
        _audioPath,
        _selectedLanguage,
      );

      setState(() {
        _isProcessing = false;
        _commandResult = command;
      });

      if (_isConnected) {
        await _sendCommandToESP32(command);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'No device connected. Connect a device to control the robot.',
            ),
            action: SnackBarAction(
              label: 'CONNECT',
              onPressed: () => _connectToESP32(),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _commandResult = 'Error: ${e.toString()}';
      });
    }
  }

  Future<void> _sendCommandToESP32(String command) async {
    try {
      // Convert full word commands to single character commands
      String formattedCommand = _wifiService.mapCommandToESP32Format(command);

      final bool result = await _wifiService.sendCommand(formattedCommand);

      if (result) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Command sent: $command (as $formattedCommand)'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else {
        setState(() {
          _isConnected = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send command: $command'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isConnected = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending command: ${e.toString()}')),
        );
      }
    }
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _dataSubscription?.cancel();
    AudioRecorderService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Robot Control'),
        centerTitle: true,
        actions: [
          _isConnected
              ? IconButton(
                icon: const Icon(Icons.link_off, color: Colors.orange),
                onPressed: _disconnectFromESP32,
                tooltip: 'Disconnect from ESP32',
              )
              : IconButton(
                icon: const Icon(Icons.wifi_find, color: Colors.green),
                onPressed: _connectToESP32,
                tooltip: 'Connect to ESP32',
              ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Language and device indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Language indicator
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.language, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _selectedLanguage,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Device indicator
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isConnected ? Icons.wifi : Icons.wifi_off,
                          size: 20,
                          color: _isConnected ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isConnected
                              ? _connectedDeviceName.length > 15
                                  ? '${_connectedDeviceName.substring(0, 12)}...'
                                  : _connectedDeviceName
                              : 'Not connected',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: _isConnected ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Voice command section
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Record button
                    GestureDetector(
                      onTapDown: (_) => _startRecording(),
                      onTapUp: (_) => _stopRecording(),
                      onTapCancel: () => _stopRecording(),
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              _isRecording
                                  ? Colors.red
                                  : Theme.of(context).colorScheme.primary,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Center(
                          child:
                              _isRecording
                                  ? const SpinKitPulse(
                                    color: Colors.white,
                                    size: 80.0,
                                  )
                                  : const Icon(
                                    Icons.mic,
                                    size: 48,
                                    color: Colors.white,
                                  ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Instruction text
                    Text(
                      _isRecording
                          ? 'Release to send command'
                          : 'Press and hold to speak',
                      style: TextStyle(
                        fontSize: 18,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Command result section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Command Result:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _isProcessing
                      ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                      : Center(
                        child: Text(
                          _commandResult.isEmpty
                              ? 'Waiting for command...'
                              : _commandResult,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Control pad (for manual control)
            if (_isConnected)
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'Manual Control',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: () => _sendCommandToESP32('Forward'),
                            child: const Icon(Icons.arrow_upward),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: () => _sendCommandToESP32('Left'),
                            child: const Icon(Icons.arrow_back),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: () => _sendCommandToESP32('Stop'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('STOP'),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: () => _sendCommandToESP32('Right'),
                            child: const Icon(Icons.arrow_forward),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: () => _sendCommandToESP32('Backward'),
                            child: const Icon(Icons.arrow_downward),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _disconnectFromESP32,
                        icon: const Icon(Icons.wifi_off),
                        label: const Text('DISCONNECT'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (!_isConnected)
              ElevatedButton.icon(
                onPressed: _connectToESP32,
                icon: const Icon(Icons.wifi_find),
                label: const Text('CONNECT TO ESP32'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
