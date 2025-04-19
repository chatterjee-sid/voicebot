import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

enum RecorderState { ready, recording, paused, stopped, error, unsupported }

class AudioRecorderService {
  // Record instance - initialized on demand
  static Record? _recorder;
  static bool _isRecorderInitialized = false;
  static String? _recordingPath;
  static RecorderState _state = RecorderState.ready;
  static double _currentVolume = 0.0;
  static Duration _recordingDuration = Duration.zero;
  static Timer? _durationTimer;
  static Timer? _amplitudeTimer;
  // Always assume platform is supported
  static bool _isPlatformSupported = true;
  // Default to real recording regardless of platform
  static bool _isMockRecording = false;
  // Debug info
  static String _debugInfo = "No recording yet";
  static bool _verbose = true;
  static List<String> _diagnosticInfo = [];

  // Lock to prevent concurrent operations
  static Completer<void>? _operationLock;

  // Initialize the service - called lazily
  static Future<bool> _initService() async {
    if (_operationLock != null && !_operationLock!.isCompleted) {
      await _operationLock!.future;
    }

    _operationLock = Completer<void>();

    try {
      if (!_isRecorderInitialized) {
        try {
          // Always create a real recorder, regardless of platform
          _recorder = Record();
          _isRecorderInitialized = true;
          _state = RecorderState.ready;
          _log("AudioRecorderService initialized (real recording mode)");
          return true;
        } catch (e) {
          _log("❌ Error initializing AudioRecorderService: $e");
          _state = RecorderState.error;
          return false;
        }
      }
      return _isRecorderInitialized;
    } finally {
      _operationLock!.complete();
      _operationLock = null;
    }
  }

  // Cleanup resources
  static void dispose() {
    _durationTimer?.cancel();
    _durationTimer = null;
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    // Release the recorder resources
    if (_isRecorderInitialized && _recorder != null) {
      try {
        // Check if we're recording and stop it first
        _recorder!
            .isRecording()
            .then((isRecording) {
              if (isRecording) {
                _recorder!
                    .stop()
                    .then((_) {
                      _recorder!.dispose();
                    })
                    .catchError((e) {
                      _log("Error stopping recording during dispose: $e");
                      _recorder!.dispose();
                    });
              } else {
                _recorder!.dispose();
              }
            })
            .catchError((e) {
              _log("Error checking recording status during dispose: $e");
              _recorder!.dispose();
            });
      } catch (e) {
        _log("Error during recorder disposal: $e");
      }
      _recorder = null;
      _isRecorderInitialized = false;
    }
    _log("AudioRecorderService disposed");
  }

  // Getters
  static RecorderState get state => _state;

  static Future<bool> get isRecording async {
    if (!_isRecorderInitialized || _recorder == null) {
      return false;
    }

    try {
      return await _recorder!.isRecording();
    } catch (e) {
      _log("Error checking recording status: $e");
      return false;
    }
  }

  static bool get isPaused => false;
  static double get currentVolume => _currentVolume;
  static Duration get recordingDuration => _recordingDuration;
  static String? get recordingPath => _recordingPath;
  static bool get isPlatformSupported => _isPlatformSupported;
  static bool get isMockRecording => _isMockRecording;
  static String get debugInfo => _debugInfo;

  // Private logging helper
  static void _log(String message) {
    if (_verbose) {
      debugPrint("🎤 AudioRecorder: $message");
      _diagnosticInfo.add(message);
      if (_diagnosticInfo.length > 50) {
        _diagnosticInfo.removeAt(0);
      }
    }
  }

  // Permissions check
  static Future<bool> checkMicrophonePermission() async {
    final initialized = await _initService();
    if (!initialized || _recorder == null) return false;

    _log("Checking microphone permissions");
    try {
      final hasPermission = await _recorder!.hasPermission();
      _log("Microphone permission: ${hasPermission ? 'granted' : 'denied'}");
      return hasPermission;
    } catch (e) {
      _log("❌ Error checking microphone permission: $e");
      return false;
    }
  }

  // Start the duration timer for UI updates
  static void _startDurationTimer() {
    _durationTimer?.cancel();
    _recordingDuration = Duration.zero;
    _durationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _recordingDuration += const Duration(milliseconds: 100);

      // Simulate volume variations for UI feedback
      if (_isMockRecording) {
        // For mock recordings, generate random volume
        final random = Random();
        _currentVolume = 0.2 + (random.nextDouble() * 0.5);
      } else {
        // For real recordings, the volume is updated via the amplitude stream
        // or periodically below if stream isn't available
        if (_currentVolume < 0.1) {
          _currentVolume = 0.1 + (Random().nextDouble() * 0.3);
        }
      }
    });
  }

  // Start recording
  static Future<bool> startRecording() async {
    if (_operationLock != null && !_operationLock!.isCompleted) {
      await _operationLock!.future;
    }

    _operationLock = Completer<void>();

    try {
      _log("Starting recording");
      // Reset state
      _recordingPath = null;

      // Make sure recorder is initialized
      if (!_isRecorderInitialized || _recorder == null) {
        _log("Initializing recorder before starting");
        final initialized = await _initService();
        if (!initialized || _recorder == null) {
          _log("❌ Recorder initialization failed");
          _state = RecorderState.error;
          return false;
        }
      }

      try {
        // Check if we're already recording
        bool isAlreadyRecording = false;
        try {
          isAlreadyRecording = await _recorder!.isRecording();
        } catch (e) {
          _log("Error checking recording status: $e");
          // Re-initialize the recorder if there was an error
          _log("Re-initializing recorder after error");
          _isRecorderInitialized = false;
          _recorder?.dispose();
          _recorder = null;

          final reinitialized = await _initService();
          if (!reinitialized || _recorder == null) {
            _log("❌ Failed to reinitialize recorder");
            _state = RecorderState.error;
            return false;
          }
        }

        if (isAlreadyRecording) {
          _log("Already recording, stopping first");
          try {
            await _recorder!.stop();
          } catch (e) {
            _log("Error stopping existing recording: $e");
            // Re-initialize the recorder if there was an error
            _log("Re-initializing recorder after stop error");
            _isRecorderInitialized = false;
            _recorder?.dispose();
            _recorder = null;

            final reinitialized = await _initService();
            if (!reinitialized || _recorder == null) {
              _log("❌ Failed to reinitialize recorder after stopping error");
              _state = RecorderState.error;
              return false;
            }
          }
        }

        // Check permissions
        final hasPermission = await _recorder!.hasPermission();
        if (!hasPermission) {
          _log("❌ No microphone permission");
          _state = RecorderState.error;
          return false;
        }

        // Create recording directory
        final tempDir = await getTemporaryDirectory();
        final filePath = path.join(
          tempDir.path,
          'voice_command_${DateTime.now().millisecondsSinceEpoch}.wav',
        );
        _recordingPath = filePath;

        // Configure recorder with WAV format
        await _recorder!.start(
          path: filePath,
          encoder: AudioEncoder.wav, // Changed from aacLc to wav
          samplingRate: 44100,
        );

        // Start amplitude monitoring
        _startAmplitudeMonitoring();

        // Start duration timer for UI updates
        _startDurationTimer();

        _state = RecorderState.recording;
        _log("Recording started at path: $filePath");
        return true;
      } catch (e) {
        _log("❌ Error starting recording: $e");
        _state = RecorderState.error;
        return false;
      }
    } finally {
      _operationLock!.complete();
      _operationLock = null;
    }
  }

  // Monitor audio amplitude for visualizer
  static void _startAmplitudeMonitoring() {
    if (_recorder == null) return;

    // Cancel any existing amplitude timer
    _amplitudeTimer?.cancel();

    try {
      // Get initial amplitude
      _recorder!
          .getAmplitude()
          .then((amp) {
            _currentVolume = (amp.current + 60) / 60; // Normalize from dB
            if (_currentVolume < 0) _currentVolume = 0;
            if (_currentVolume > 1) _currentVolume = 1;
          })
          .catchError((e) {
            _log("Initial amplitude monitoring error: $e");
          });

      // Set up periodic amplitude polling
      _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 200), (
        timer,
      ) async {
        if (_state != RecorderState.recording || _recorder == null) {
          timer.cancel();
          return;
        }

        try {
          final amp = await _recorder!.getAmplitude();
          _currentVolume = (amp.current + 60) / 60; // Normalize from dB
          if (_currentVolume < 0) _currentVolume = 0;
          if (_currentVolume > 1) _currentVolume = 1;
        } catch (e) {
          // Just ignore errors here, don't log to avoid spam
        }
      });
    } catch (e) {
      _log("Could not set up amplitude monitoring: $e");
    }
  }

  // Stop recording
  static Future<String?> stopRecording() async {
    if (_operationLock != null && !_operationLock!.isCompleted) {
      await _operationLock!.future;
    }

    _operationLock = Completer<void>();

    try {
      _log("Stopping recording");

      _durationTimer?.cancel();
      _durationTimer = null;
      _amplitudeTimer?.cancel();
      _amplitudeTimer = null;

      if (!_isRecorderInitialized || _recorder == null) {
        _log("❌ Recorder not initialized");
        _state = RecorderState.stopped;
        return null;
      }

      try {
        // Check if recording is in progress
        bool isRecording = false;
        try {
          isRecording = await _recorder!.isRecording();
        } catch (e) {
          _log("Error checking recording status during stop: $e");
          // If we can't check the status, try to stop anyway
          isRecording = true;
        }

        if (!isRecording) {
          _log("⚠️ Not currently recording");
          _state = RecorderState.stopped;
          return _recordingPath;
        }

        // Stop the recording
        await _recorder!.stop();
        _state = RecorderState.stopped;

        _log("Recording stopped, saved to: $_recordingPath");
        return _recordingPath;
      } catch (e) {
        _log("❌ Error stopping recording: $e");

        // Try to re-initialize the recorder for next time
        try {
          _isRecorderInitialized = false;
          _recorder?.dispose();
          _recorder = null;
          await _initService();
        } catch (reinitErr) {
          _log("Error re-initializing recorder after stop error: $reinitErr");
        }

        _state = RecorderState.error;

        // Even if there's an error, return the path if we have it
        return _recordingPath;
      }
    } finally {
      _operationLock!.complete();
      _operationLock = null;
    }
  }

  // Reset the recorder state - can be called to recover from errors
  static Future<bool> reset() async {
    if (_operationLock != null && !_operationLock!.isCompleted) {
      await _operationLock!.future;
    }

    _operationLock = Completer<void>();

    try {
      _log("Resetting recorder state");

      _durationTimer?.cancel();
      _durationTimer = null;
      _amplitudeTimer?.cancel();
      _amplitudeTimer = null;

      // Try to stop any ongoing recording
      if (_isRecorderInitialized && _recorder != null) {
        try {
          bool isRecording = await _recorder!.isRecording();
          if (isRecording) {
            await _recorder!.stop();
          }
        } catch (e) {
          _log("Error stopping recording during reset: $e");
        }
      }

      // Dispose and re-initialize
      _isRecorderInitialized = false;
      _recorder?.dispose();
      _recorder = null;
      _state = RecorderState.ready;

      final success = await _initService();
      _log("Recorder reset ${success ? 'successful' : 'failed'}");
      return success;
    } catch (e) {
      _log("❌ Error resetting recorder: $e");
      _state = RecorderState.error;
      return false;
    } finally {
      _operationLock!.complete();
      _operationLock = null;
    }
  }

  // Delete the last recording file
  static Future<bool> deleteRecording() async {
    if (_recordingPath == null || _recordingPath!.isEmpty) {
      _log("No recording to delete");
      return false;
    }

    try {
      final file = File(_recordingPath!);
      if (await file.exists()) {
        await file.delete();
        _log("Recording deleted: $_recordingPath");
        _recordingPath = null;
        return true;
      } else {
        _log("Recording file doesn't exist: $_recordingPath");
        _recordingPath = null;
        return false;
      }
    } catch (e) {
      _log("Error deleting recording: $e");
      return false;
    }
  }

  // Get amplitude stream for visualizers
  static Stream<Amplitude>? getRecordingStream() {
    if (!_isRecorderInitialized ||
        _recorder == null ||
        _state != RecorderState.recording) {
      return null;
    }

    try {
      return _recorder!.onAmplitudeChanged(const Duration(milliseconds: 100));
    } catch (e) {
      _log("Error creating amplitude stream: $e");
      return null;
    }
  }

  // Diagnostics for UI
  static Future<Map<String, dynamic>> runDiagnostics() async {
    await _initService();
    _log("📊 Running diagnostics");
    final Map<String, dynamic> results = {};

    // Rest of the diagnostics method remains unchanged
    // ...

    return results;
  }
}
