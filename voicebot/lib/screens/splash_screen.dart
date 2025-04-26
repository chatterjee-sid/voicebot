import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../services/esp32_wifi_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final ESP32WiFiService _wifiService = ESP32WiFiService();
  String _statusMessage = 'Initializing application...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Initialize WiFi service
      setState(() {
        _statusMessage = 'Initializing WiFi service...';
      });

      await _wifiService.init();

      // Artificial delay to display splash screen
      await Future.delayed(const Duration(seconds: 2));

      // Navigate to the home screen
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
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
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App logo or icon
                Icon(
                  Icons.smart_toy,
                  size: 100,
                  color: theme.colorScheme.onPrimary,
                ),

                const SizedBox(height: 40),

                // App title
                Text(
                  'Voice-Controlled Robot',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),

                const SizedBox(height: 10),

                // App subtitle
                Text(
                  'Developed by Group2 SVNIT',
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.colorScheme.onPrimary.withOpacity(0.7),
                  ),
                ),

                const SizedBox(height: 60),

                // Loading indicator
                if (_isLoading)
                  SpinKitDualRing(
                    color: theme.colorScheme.onPrimary,
                    size: 50.0,
                  ),

                const SizedBox(height: 20),

                // Status message
                Text(
                  _statusMessage,
                  style: TextStyle(color: theme.colorScheme.onPrimary),
                  textAlign: TextAlign.center,
                ),

                if (!_isLoading)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _isLoading = true;
                        });
                        _initialize();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.onPrimary,
                        side: BorderSide(color: theme.colorScheme.onPrimary),
                      ),
                      child: const Text('Retry'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
