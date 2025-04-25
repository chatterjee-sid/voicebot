import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../services/api_service.dart';
import '../services/bluetooth_service.dart';
import '../services/bluetooth_service/bluetooth_service_interface.dart';
import '../services/audio_recorder.dart';
import 'bluetooth_device_selection_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkPermissions();
    _initBluetooth();
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

  Future<void> _initBluetooth() async {
    try {
      final bool isEnabled = await BluetoothService.initBluetooth();

      if (!isEnabled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bluetooth is not enabled. Please enable Bluetooth.'),
          ),
        );
      }

      setState(() {
        _isConnected = BluetoothService.isConnected;
        _connectedDeviceName =
            _isConnected ? 'Connected Device' : 'No device connected';
      });
    } catch (e) {
      setState(() {
        _isConnected = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize Bluetooth: ${e.toString()}'),
          ),
        );
      }
    }
  }

  Future<void> _selectBluetoothDevice() async {
    try {
      // Navigate to Bluetooth device selection screen using a direct route
      // instead of a named route that might not be defined
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const BluetoothDeviceSelectionScreen(),
        ),
      );

      // Check if result is a BluetoothDevice before processing
      if (result != null && result is BluetoothDevice) {
        // Connect to the selected device
        final BluetoothDevice device = result;
        final isConnected = await BluetoothService.connectToDevice(device);

        setState(() {
          _isConnected = isConnected;
          _connectedDeviceName =
              isConnected
                  ? device.name ?? 'Connected Device'
                  : 'No device connected';
        });

        if (_isConnected && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Connected to $_connectedDeviceName')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting device: ${e.toString()}')),
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
        await _sendCommandToRobot(command);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'No device connected. Connect a device to control the robot.',
            ),
            action: SnackBarAction(
              label: 'CONNECT',
              onPressed: () => _selectBluetoothDevice(),
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

  Future<void> _sendCommandToRobot(String command) async {
    try {
      final bool result = await BluetoothService.sendCommand(command);

      if (result) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Command sent: $command'),
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

      // Listen for any response from the ESP32
      if (BluetoothService.dataStream != null && mounted) {
        BluetoothService.dataStream!
            .listen((response) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Robot responded: $response'),
                    backgroundColor: Colors.blue,
                  ),
                );
              }
            })
            .onDone(() {
              debugPrint('Response stream closed');
            });
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
          IconButton(
            icon: Icon(
              _isConnected
                  ? Icons.bluetooth_connected
                  : Icons.bluetooth_disabled,
              color: _isConnected ? Colors.green : Colors.red,
            ),
            onPressed: _selectBluetoothDevice,
            tooltip:
                _isConnected
                    ? 'Connected to $_connectedDeviceName'
                    : 'Connect to robot',
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
                          _isConnected
                              ? Icons.bluetooth_connected
                              : Icons.bluetooth_disabled,
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
                            onPressed: () => _sendCommandToRobot('Forward'),
                            child: const Icon(Icons.arrow_upward),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: () => _sendCommandToRobot('Left'),
                            child: const Icon(Icons.arrow_back),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: () => _sendCommandToRobot('Stop'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('STOP'),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: () => _sendCommandToRobot('Right'),
                            child: const Icon(Icons.arrow_forward),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: () => _sendCommandToRobot('Backward'),
                            child: const Icon(Icons.arrow_downward),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            if (!_isConnected)
              ElevatedButton.icon(
                onPressed: _selectBluetoothDevice,
                icon: const Icon(Icons.bluetooth_searching),
                label: const Text('CONNECT TO ROBOT'),
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
