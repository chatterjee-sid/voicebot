import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import '../services/audio_recorder.dart';

class AudioVisualizer extends StatefulWidget {
  final bool isRecording;
  final Stream<double>? volumeStream;
  final Duration recordingDuration;

  const AudioVisualizer({
    Key? key,
    required this.isRecording,
    this.volumeStream,
    required this.recordingDuration,
  }) : super(key: key);

  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final List<double> _volumeLevels = List.filled(30, 0.05);
  final Random _random = Random();
  StreamSubscription? _volumeSubscription;
  Timer? _volumeUpdateTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..repeat();

    // Start volume monitoring immediately if recording
    if (widget.isRecording) {
      _startVolumeMonitoring();
    }
  }

  @override
  void didUpdateWidget(AudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle changes in recording state
    if (widget.isRecording != oldWidget.isRecording) {
      if (widget.isRecording) {
        _startVolumeMonitoring();
      } else {
        _stopVolumeMonitoring();
      }
    }
  }

  void _startVolumeMonitoring() {
    // Clean up any existing subscriptions first
    _stopVolumeMonitoring();

    // Try to get real volume data from the recorder
    final amplitudeStream = AudioRecorderService.getRecordingStream();

    if (amplitudeStream != null) {
      // Use real volume data from recorder
      _volumeSubscription = amplitudeStream.listen(
        (amplitude) {
          // The Record package's Amplitude class uses 'current' instead of 'decibels'
          final double volume = amplitude.current ?? 0;
          _updateVolumeLevels(volume);
        },
        onError: (e) {
          debugPrint('Error from volume stream: $e');
          // Fall back to simulated volume on error
          _startSimulatedVolumeUpdates();
        },
      );
    } else {
      // Use the recorder's current volume property directly
      _startSimulatedVolumeUpdates();
    }
  }

  void _stopVolumeMonitoring() {
    _volumeSubscription?.cancel();
    _volumeSubscription = null;
    _volumeUpdateTimer?.cancel();
    _volumeUpdateTimer = null;
  }

  void _startSimulatedVolumeUpdates() {
    // Cancel any existing timer
    _volumeUpdateTimer?.cancel();

    // Create a new timer that updates every 100ms
    _volumeUpdateTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      if (!mounted || !widget.isRecording) {
        timer.cancel();
        return;
      }

      // Get current volume from the AudioRecorderService
      final currentVolume = AudioRecorderService.currentVolume;

      // Add some randomness to make it look more natural
      final randomFactor = 0.3 * _random.nextDouble();
      final adjustedVolume = (currentVolume * (0.7 + randomFactor)).clamp(
        0.05,
        1.0,
      );

      _updateVolumeLevels(adjustedVolume * 60); // Scale for visual effect
    });
  }

  // Update the volume levels for visualization
  void _updateVolumeLevels(double volume) {
    if (!mounted) return;

    // Scale volume to make visualization more dynamic
    double scaledVolume = volume <= 0 ? 0.05 : min(1.0, (volume / 60) + 0.2);

    setState(() {
      // Shift all levels left and add new volume at end
      for (int i = 0; i < _volumeLevels.length - 1; i++) {
        _volumeLevels[i] = _volumeLevels[i + 1];
      }
      _volumeLevels[_volumeLevels.length - 1] = scaledVolume;
    });
  }

  @override
  void dispose() {
    _stopVolumeMonitoring();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If we're not recording, reset visualization
    if (!widget.isRecording) {
      if (_volumeLevels.any((level) => level > 0.05)) {
        // Only reset if there's something to reset (avoid unnecessary rebuilds)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              for (int i = 0; i < _volumeLevels.length; i++) {
                _volumeLevels[i] = 0.05;
              }
            });
          }
        });
      }
    }

    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Audio visualization bars
        SizedBox(
          height: 80,
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(_volumeLevels.length, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 50),
                    width:
                        MediaQuery.of(context).size.width /
                            _volumeLevels.length -
                        2,
                    height: widget.isRecording ? _volumeLevels[index] * 70 : 5,
                    decoration: BoxDecoration(
                      color:
                          widget.isRecording
                              ? theme.colorScheme.primary.withOpacity(
                                0.7 + _volumeLevels[index] * 0.3,
                              )
                              : theme.colorScheme.primary.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              );
            },
          ),
        ),

        // Recording time display
        if (widget.isRecording)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.5),
                        blurRadius: 5,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDuration(widget.recordingDuration),
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}
