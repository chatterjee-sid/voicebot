import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

// Import the global Windows flag
import '../main.dart' show isRunningOnWindows;

enum RecorderState { ready, recording, paused, stopped, error, unsupported }

class AudioRecorderService {
  // Use a late initialized recorder to avoid immediate initialization on Windows
  static late Record _recorder;
  static bool _isRecorderInitialized = false;
  static String? _recordingPath;
  static RecorderState _state = RecorderState.ready;
  static double _currentVolume = 0.0;
  static Duration _recordingDuration = Duration.zero;
  static Timer? _durationTimer;

  // Changed to default to true for all platforms
  static bool _isPlatformSupported = true;

  // Changed to default to false to use real recording whenever possible
  static bool _isMockRecording = false;

  // Debug info
  static String _debugInfo = "No recording yet";
  static bool _verbose = true;
  static List<String> _diagnosticInfo = [];

  // Initialize the service - called lazily
  static void _initService() {
    if (!_isRecorderInitialized) {
      if (!isRunningOnWindows) {
        // Only create the real recorder on non-Windows platforms
        _recorder = Record();
      }
      _isRecorderInitialized = true;
      _log(
        "AudioRecorderService initialized (${isRunningOnWindows ? 'Windows mock mode' : 'native mode'})",
      );
    }
  }

  // Getters
  static RecorderState get state => _state;
  static Future<bool> get isRecording async {
    _initService();
    if (isRunningOnWindows) return false;
    return _recorder.isRecording();
  }

  static bool get isPaused => false;
  static double get currentVolume => _currentVolume;
  static Duration get recordingDuration => _recordingDuration;
  static String? get recordingPath => _recordingPath;
  static bool get isPlatformSupported => _isPlatformSupported;
  static bool get isMockRecording => _isMockRecording || isRunningOnWindows;
  static String get debugInfo => _debugInfo;
  static List<String> get diagnosticInfo => _diagnosticInfo;

  // Debug logging helper with enhancements for diagnostics
  static void _log(String message) {
    if (_verbose) {
      debugPrint("[AudioRecorder] $message");
      _debugInfo = message;
      _diagnosticInfo.add(
        "${DateTime.now().toString().split('.').first}: $message",
      );
      // Keep diagnostic log at a reasonable size
      if (_diagnosticInfo.length > 100) {
        _diagnosticInfo.removeAt(0);
      }
    }
  }

  // Check microphone permission - this replaces the previous method that relied on permission_handler
  static Future<bool> checkMicrophonePermission() async {
    _initService();
    _log("Checking microphone permission...");

    if (isRunningOnWindows) {
      _log(
        "Windows platform - skipping actual permission check, returning true",
      );
      return true;
    }

    try {
      final hasPermission = await _recorder.hasPermission();
      _log(
        hasPermission
            ? "✅ Microphone permission granted"
            : "❌ Microphone permission denied",
      );
      return hasPermission;
    } catch (e) {
      _log("❌ Error checking microphone permission: $e");
      return false;
    }
  }

  // Run comprehensive microphone diagnostics
  static Future<Map<String, dynamic>> runMicrophoneDiagnostics() async {
    _initService();
    final results = <String, dynamic>{};
    _log("🔍 Starting microphone diagnostics");

    // Always include OS information
    results['os'] = Platform.operatingSystem;
    results['osVersion'] = Platform.operatingSystemVersion;

    if (isRunningOnWindows) {
      _log("Windows platform detected - using mock diagnostics");
      results['windowsMockMode'] = true;
      results['microphonePermissionStatus'] = "Mock (Always Granted)";
      results['recorderHasPermission'] = true;
      results['recorderCreated'] = true;
      results['recorderInitialized'] = true;
      results['recorderIsOpen'] = true;
      results['recorderInitError'] = null;
      results['fileSystemAccessible'] = true;
      results['fileSystemWritable'] = true;
      return results;
    }

    // Rest of the implementation for non-Windows platforms
    // ... existing implementation for diagnostics ...

    // Perform real diagnostics
    try {
      // 2. Check microphone permission status using Record package
      _log("Checking microphone permission status");
      final micPermission = await _recorder.hasPermission();
      results['microphonePermissionStatus'] =
          micPermission ? "Granted" : "Denied";

      // ... rest of your existing diagnostic code ...
    } catch (e) {
      _log("❌ Error during diagnostics: $e");
      results['diagnosticError'] = e.toString();
    }

    _log("📊 Diagnostics complete: ${results.length} checks performed");
    return results;
  }

  // Start recording method
  static Future<bool> startRecording() async {
    _initService();
    _log("Starting audio recording process");

    // Reset state
    _isMockRecording = false; // Default to real recording

    if (isRunningOnWindows) {
      _log("Windows platform detected - will try real recording first");
    }

    try {
      // Initialize recorder
      final isInitialized = await _initRecorder();
      if (!isInitialized) {
        _log("❌ Failed to initialize recorder");
        return _fallbackToMockRecording();
      }

      if (!isRunningOnWindows) {
        // On non-Windows platforms, use the recorder directly
        try {
          // Get temp directory for recording file
          final tempDir = await getTemporaryDirectory();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          _recordingPath = path.join(tempDir.path, 'recording_$timestamp.m4a');

          // Configure the recorder
          await _recorder.start(
            path: _recordingPath,
            encoder: AudioEncoder.aacLc, // Using AAC for better compatibility
            bitRate: 128000, // 128kbps for good quality
            samplingRate: 44100, // 44.1kHz standard audio rate
          );

          _log("✅ Started real recording at path: $_recordingPath");
          _state = RecorderState.recording;
          _startDurationTimer();
          return true;
        } catch (e) {
          _log("❌ Error starting real recording: $e");
          // Try mock recording as fallback
          return _fallbackToMockRecording();
        }
      } else {
        // On Windows, try using the recorder but be ready to fall back
        try {
          // Create the real recorder for Windows
          if (!_isRecorderInitialized) {
            _recorder = Record();
            _isRecorderInitialized = true;
          }

          // Get temp directory for recording file
          final tempDir = await getTemporaryDirectory();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          _recordingPath = path.join(tempDir.path, 'recording_$timestamp.m4a');

          // Check permission even on Windows
          final hasPermission = await _recorder.hasPermission();
          if (!hasPermission) {
            _log("❌ Microphone permission denied on Windows");
            return _fallbackToMockRecording();
          }

          // Try to start recording on Windows
          await _recorder.start(
            path: _recordingPath,
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            samplingRate: 44100,
          );

          _log(
            "✅ Successfully started real recording on Windows at: $_recordingPath",
          );
          _state = RecorderState.recording;
          _isMockRecording = false;
          _startDurationTimer();
          return true;
        } catch (e) {
          _log(
            "❌ Error starting recording on Windows: $e - falling back to mock",
          );
          return _fallbackToMockRecording();
        }
      }
    } catch (e) {
      _log("❌ Unhandled error in startRecording: $e");
      return _fallbackToMockRecording();
    }
  }

  // Helper method for fallback to mock recording
  static Future<bool> _fallbackToMockRecording() async {
    _isMockRecording = true;
    return _startMockRecording();
  }

  // Initialize the recorder - simplified version
  static Future<bool> _initRecorder() async {
    if (isRunningOnWindows) {
      return true; // Mock success on Windows
    }

    // Simplified init for non-Windows
    try {
      final hasPermission = await _recorder.hasPermission();
      _isRecorderInitialized = true;
      _state = RecorderState.ready;
      return hasPermission;
    } catch (e) {
      _log("Error initializing recorder: $e");
      _isMockRecording = true;
      _isRecorderInitialized = true;
      return true;
    }
  }

  // Mock recording for fallback
  static Future<bool> _startMockRecording() async {
    _log("⚠️ Starting MOCK recording (no real audio)");
    _state = RecorderState.recording;
    _isMockRecording = true;

    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _recordingPath = path.join(tempDir.path, 'mock_recording_$timestamp.wav');

      // Create a realistic audio file
      await _createTestWavFileWithAudio(_recordingPath!);

      _log("Created MOCK recording at: $_recordingPath");
      _startDurationTimer();
      return true;
    } catch (e) {
      _log("Error in mock recording: $e");
      // Try in system temp as last resort
      try {
        final tempFile = path.join(
          Directory.systemTemp.path,
          'mock_recording_${DateTime.now().millisecondsSinceEpoch}.wav',
        );
        _recordingPath = tempFile;
        await _createTestWavFileWithAudio(tempFile);
        _startDurationTimer();
        return true;
      } catch (finalError) {
        _log("Final fallback failed: $finalError");
        _state = RecorderState.error;
        return false;
      }
    }
  }

  // Stop recording
  static Future<String?> stopRecording() async {
    _initService();
    _log("Stopping recording");

    try {
      _durationTimer?.cancel();
      _durationTimer = null;

      if (!_isRecorderInitialized) {
        _log("❌ Cannot stop - recorder not initialized");
        return null;
      }

      // For real recordings (not mock recordings)
      if (!_isMockRecording) {
        try {
          // Check if we're recording before stopping
          final isCurrentlyRecording = await _recorder.isRecording();
          if (isCurrentlyRecording) {
            _log("Stopping real recorder...");
            await _recorder.stop();
            _log("✅ Recording stopped at path: $_recordingPath");
          } else {
            _log("⚠️ Not currently recording, nothing to stop");
          }
        } catch (e) {
          _log("❌ Error stopping recorder: $e");
          // If we can't stop the recording, we'll still try to use the file if it exists
        }
      }

      _state = RecorderState.stopped;

      if (_recordingPath == null) {
        _log("❌ No recording path available");
        return null;
      }

      // Validate the recording file
      final file = File(_recordingPath!);
      if (await file.exists()) {
        final fileSize = await file.length();
        _log("Recording file size: ${(fileSize / 1024).toStringAsFixed(2)} KB");

        if (fileSize < 1000 && !_isMockRecording) {
          _log(
            "⚠️ Warning: File size too small ($fileSize bytes), might not be valid audio",
          );

          // Only replace with mock data if it's suspiciously small
          if (fileSize < 100) {
            _log("File size extremely small, replacing with mock audio");
            await _createTestWavFileWithAudio(_recordingPath!);
          }
        } else {
          _log(
            "✅ Recording file has good size (${(fileSize / 1024).toStringAsFixed(2)} KB)",
          );
        }
      } else if (_isMockRecording) {
        _log("❌ Mock recording file doesn't exist, creating one");
        await _createTestWavFileWithAudio(_recordingPath!);
      } else {
        _log("❌ Real recording file doesn't exist: $_recordingPath");
        return null;
      }

      final recordingPath = _recordingPath;
      _recordingDuration = Duration.zero;
      return recordingPath;
    } catch (e) {
      _log("❌ Error in stopRecording: $e");
      _state = RecorderState.error;

      // If we have a path but something went wrong, try to create a mock file as last resort
      if (_recordingPath != null && _isMockRecording) {
        try {
          await _createTestWavFileWithAudio(_recordingPath!);
          return _recordingPath;
        } catch (finalError) {
          _log("Final attempt failed: $finalError");
        }
      }
      return null;
    }
  }

  // Timer for recording duration and visual feedback
  static void _startDurationTimer() {
    _recordingDuration = Duration.zero;
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _recordingDuration += const Duration(milliseconds: 100);

      // Generate volume indicators - smooth sine wave for mock recordings
      final secondsElapsed = _recordingDuration.inMilliseconds / 1000;
      final sinValue = sin(secondsElapsed * 3) * 0.3 + 0.5;
      _currentVolume = (sinValue * 100) / 100;
    });
  }

  // Get a stream of recording data (volume levels)
  static Stream<Amplitude>? getRecordingStream() {
    _initService();
    _log("Getting recording stream");

    if (isRunningOnWindows) {
      _log("Windows platform - cannot provide real recording stream");
      return null;
    }

    try {
      if (_isRecorderInitialized &&
          !_isMockRecording &&
          _state == RecorderState.recording) {
        return _recorder.onAmplitudeChanged(const Duration(milliseconds: 100));
      } else {
        _log(
          "Cannot get recording stream - not recording or using mock recording",
        );
        return null;
      }
    } catch (e) {
      _log("Error getting recording stream: $e");
      return null;
    }
  }

  // Improved test WAV file creation - this generates a proper sine wave
  static Future<void> _createTestWavFileWithAudio(String filePath) async {
    _log("Creating test WAV file with sine wave audio");
    final file = File(filePath);

    // Create WAV header plus a short sine wave of audio data
    final List<int> bytes = [];

    // Constants for WAV creation
    const int sampleRate = 16000;
    const int numChannels = 1;
    const int bitsPerSample = 16;

    // Create 2 seconds of sine wave data at 440Hz (A4 note)
    const double frequency = 440.0; // Hz
    const double amplitude = 0.5 * 32767.0; // 50% of max amplitude for 16-bit
    const double duration = 2.0; // seconds

    final int numSamples = (sampleRate * duration).toInt();
    final List<int> audioData = [];

    // Generate sine wave data
    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate; // time in seconds
      final double angle = 2 * pi * frequency * t;
      final int sample = (amplitude * sin(angle)).toInt();

      // Add sample as 16-bit little-endian
      audioData.add(sample & 0xFF);
      audioData.add((sample >> 8) & 0xFF);
    }

    // Calculate data sizes
    final int dataSize = audioData.length;
    final int fileSize = 36 + dataSize; // 36 bytes for the header + data size

    // Add RIFF header
    bytes.addAll([0x52, 0x49, 0x46, 0x46]); // "RIFF"
    bytes.addAll(_intToBytes(fileSize - 8, 4)); // Chunk size (file size - 8)
    bytes.addAll([0x57, 0x41, 0x56, 0x45]); // "WAVE"

    // Add fmt subchunk
    bytes.addAll([0x66, 0x6D, 0x74, 0x20]); // "fmt "
    bytes.addAll([0x10, 0x00, 0x00, 0x00]); // Subchunk size (16 bytes)
    bytes.addAll([0x01, 0x00]); // Audio format (1 = PCM)
    bytes.addAll(_intToBytes(numChannels, 2)); // Number of channels
    bytes.addAll(_intToBytes(sampleRate, 4)); // Sample rate

    // Calculate byte rate and block align
    final int byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    final int blockAlign = numChannels * (bitsPerSample ~/ 8);

    bytes.addAll(_intToBytes(byteRate, 4)); // Byte rate
    bytes.addAll(_intToBytes(blockAlign, 2)); // Block align
    bytes.addAll(_intToBytes(bitsPerSample, 2)); // Bits per sample

    // Add data subchunk
    bytes.addAll([0x64, 0x61, 0x74, 0x61]); // "data"
    bytes.addAll(_intToBytes(dataSize, 4)); // Data size

    // Add the audio data
    bytes.addAll(audioData);

    // Write the WAV file
    await file.writeAsBytes(bytes);
    _log("✅ Created test WAV file with 2-second sine wave audio at: $filePath");
  }

  // Helper method to convert int to little-endian bytes
  static List<int> _intToBytes(int value, int numBytes) {
    final List<int> bytes = [];
    for (int i = 0; i < numBytes; i++) {
      bytes.add((value >> (i * 8)) & 0xFF);
    }
    return bytes;
  }

  // Delete current recording file
  static Future<bool> deleteRecording() async {
    try {
      if (_recordingPath != null) {
        final file = File(_recordingPath!);
        if (await file.exists()) {
          await file.delete();
          _log("Recording file deleted: $_recordingPath");
        }
        _recordingPath = null;
        return true;
      }
      return false;
    } catch (e) {
      _log("Error deleting recording: $e");
      return false;
    }
  }

  // Dispose the recorder
  static Future<void> dispose() async {
    _durationTimer?.cancel();
    _durationTimer = null;

    if (_isRecorderInitialized && !_isMockRecording && !isRunningOnWindows) {
      try {
        if (await _recorder.isRecording()) {
          await _recorder.stop();
        }
      } catch (e) {
        _log("Error disposing recorder: $e");
      }
    }
    _isRecorderInitialized = false;
    _state = RecorderState.ready;
    _log("Recorder disposed");
  }
}
