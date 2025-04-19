import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/audio_recorder.dart';
import '../services/api_service.dart';
import '../widgets/audio_visualizer.dart';
import '../widgets/custom_button.dart';

class RobotControlScreen extends StatefulWidget {
  const RobotControlScreen({super.key});

  @override
  State<RobotControlScreen> createState() => _RobotControlScreenState();
}

class _RobotControlScreenState extends State<RobotControlScreen> with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  bool _isProcessing = false;
  String _lastCommand = '';
  String _response = '';
  bool _isPressing = false;
  double _volumeLevel = 0.0;
  Timer? _volumeTimer;
  final ApiService _apiService = ApiService();
  
  // Animation controller for recording feedback
  late AnimationController _animationController;
  
  // Fixed position for record button to prevent it from moving
  final recordButtonPosition = const Offset(0, 0);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _volumeTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  // Start recording with better state management
  Future<void> _startRecording() async {
    if (_isRecording || _isProcessing) return;

    // Check microphone permission
    final hasPermission = await AudioRecorderService.checkMicrophonePermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required to record audio')),
        );
      }
      return;
    }

    // Set recording state before attempting to start
    setState(() {
      _isPressing = true;
      _response = '';
    });

    try {
      // Start recording
      final success = await AudioRecorderService.startRecording();
      
      if (success) {
        if (mounted) {
          setState(() {
            _isRecording = true;
            _lastCommand = '';
          });
        }
        
        // Start monitoring volume for visualization
        _startVolumeMonitoring();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to start recording')),
          );
          setState(() {
            _isPressing = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting recording: $e')),
        );
        setState(() {
          _isPressing = false;
        });
      }
    }
  }

  // Stop recording with better error handling
  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    try {
      setState(() {
        _isProcessing = true;
      });
      
      // Stop volume monitoring
      _volumeTimer?.cancel();
      _volumeTimer = null;

      // Stop recording
      final recordingPath = await AudioRecorderService.stopRecording();
      
      if (recordingPath != null) {
        final file = File(recordingPath);
        if (await file.exists()) {
          await _processRecording(file);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Recording file not found')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to stop recording')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error stopping recording: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isPressing = false;
          _isProcessing = false;
          _volumeLevel = 0.0;
        });
      }
    }
  }

  void _startVolumeMonitoring() {
    // Cancel any existing timer
    _volumeTimer?.cancel();
    
    // Start a new timer to update the volume level
    _volumeTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted && _isRecording) {
        setState(() {
          _volumeLevel = AudioRecorderService.currentVolume;
        });
      }
    });
  }

  Future<void> _processRecording(File recordingFile) async {
    try {
      // Process the recording
      final result = await _apiService.processAudioCommand(recordingFile);
      
      if (mounted) {
        setState(() {
          _lastCommand = result['command'] ?? 'No command detected';
          _response = result['response'] ?? 'No response received';
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastCommand = 'Error processing command';
          _response = 'Error: $e';
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Robot Control'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status Section
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: appState.isConnected ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    appState.isConnected
                        ? 'Connected to ${appState.connectedDeviceName}'
                        : 'Not connected',
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            
            // Main Content Area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Last Command Section
                    if (_lastCommand.isNotEmpty)
                      Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Last Command:',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(_lastCommand),
                            ],
                          ),
                        ),
                      ),
                    
                    // Response Section
                    if (_response.isNotEmpty)
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Response:',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(_response),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Bottom Controls Section - fixed height to prevent jumping
            Container(
              height: 200, // Fixed height for the bottom controls
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Audio Visualizer (only shown when recording)
                    if (_isRecording)
                      SizedBox(
                        height: 60,
                        child: AudioVisualizer(
                          volume: _volumeLevel,
                          color: theme.colorScheme.primary,
                          animationController: _animationController,
                        ),
                      ),
                    
                    const SizedBox(height: 16),
                    
                    // Recording Status Text
                    Text(
                      _isRecording 
                          ? 'Listening...' 
                          : _isProcessing 
                              ? 'Processing...' 
                              : 'Press and hold to speak',
                      style: theme.textTheme.bodyLarge,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Record Button (or Stop Button when recording)
                    if (_isRecording) 
                      // Stop Recording Button
                      CustomButton(
                        onPressed: _stopRecording,
                        icon: Icons.stop,
                        text: 'Stop',
                        color: Colors.red,
                        isLoading: _isProcessing,
                      )
                    else
                      // Start Recording Button with better gesture handling
                      GestureDetector(
                        onLongPress: _startRecording,
                        onLongPressEnd: (_) {
                          if (_isRecording) {
                            _stopRecording();
                          }
                          setState(() {
                            _isPressing = false;
                          });
                        },
                        onLongPressCancel: () {
                          setState(() {
                            _isPressing = false;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          width: _isPressing ? 100 : 80,
                          height: _isPressing ? 100 : 80,
                          decoration: BoxDecoration(
                            color: _isPressing
                                ? theme.colorScheme.primary.withOpacity(0.7)
                                : theme.colorScheme.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.mic,
                            color: Colors.white,
                            size: _isPressing ? 50 : 40,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
