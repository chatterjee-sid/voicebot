import 'dart:async';
import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../services/audio_recorder.dart';
import '../services/bluetooth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  String _statusMessage = 'Initializing...';
  bool _showError = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _animationController.forward();

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Check microphone permissions
      setState(() {
        _statusMessage = 'Checking microphone access...';
      });

      await AudioRecorderService.checkMicrophonePermission();

      // Initialize Bluetooth (on supported platforms)
      setState(() {
        _statusMessage = 'Initializing Bluetooth...';
      });

      await BluetoothService.initBluetooth();

      // Complete initialization
      setState(() {
        _statusMessage = 'Ready!';
      });

      // Navigate to home screen after a delay
      Timer(const Duration(seconds: 2), () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
        _showError = true;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.primaryContainer,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo animation
            FadeTransition(
              opacity: _animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.5),
                  end: Offset.zero,
                ).animate(_animation),
                child: Icon(
                  Icons.mic,
                  size: 120,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // App name
            FadeTransition(
              opacity: _animation,
              child: Text(
                'Voice-Controlled Robot',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // App description
            FadeTransition(
              opacity: _animation,
              child: Text(
                'Control your robot with voice commands',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onPrimary.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 48),

            // Status and progress indicator
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    _statusMessage,
                    style: TextStyle(
                      color:
                          _showError
                              ? theme.colorScheme.error
                              : theme.colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _showError
                      ? ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _showError = false;
                            _statusMessage = 'Retrying...';
                          });
                          _initializeApp();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.surface,
                        ),
                        child: const Text('Retry'),
                      )
                      : const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
