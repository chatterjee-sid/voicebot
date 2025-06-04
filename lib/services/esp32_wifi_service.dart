import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Service to handle WiFi communication with an ESP32 device
class ESP32WiFiService with ChangeNotifier {
  // Static instance for singleton pattern
  static final ESP32WiFiService _instance = ESP32WiFiService._internal();
  factory ESP32WiFiService() => _instance;
  ESP32WiFiService._internal();

  // Connection state
  bool _isConnected = false;
  bool _isInitialized = false;
  String _espIpAddress = '';
  int _espPort = 80;

  // Data stream for received messages from ESP32
  final StreamController<String> _dataStreamController =
      StreamController<String>.broadcast();
  Stream<String> get dataStream => _dataStreamController.stream;

  // Getters
  bool get isConnected => _isConnected;
  bool get isInitialized => _isInitialized;
  String get espIpAddress => _espIpAddress;
  int get espPort => _espPort;

  /// Initialize the WiFi service
  Future<bool> init() async {
    if (_isInitialized) return true;

    debugPrint('ESP32 WiFi: Initializing service');
    _isInitialized = true;

    // Add initialization message to stream
    _dataStreamController.add('WiFi service initialized');

    return true;
  }

  /// Initialize connection to ESP32 with the provided IP address and port
  Future<bool> connect(String ipAddress, {int port = 80}) async {
    try {
      debugPrint('ESP32 WiFi: Connecting to $ipAddress:$port...');

      // Test connection by sending a ping command
      final response = await http
          .get(Uri.parse('http://$ipAddress:$port/command?move=S'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _espIpAddress = ipAddress;
        _espPort = port;
        _isConnected = true;

        // Send connection established message to stream
        _dataStreamController.add(
          'Connected to ESP32 at $_espIpAddress:$_espPort',
        );

        debugPrint('ESP32 WiFi: Connected successfully');
        notifyListeners();
        return true;
      } else {
        debugPrint(
          'ESP32 WiFi: Connection failed - HTTP ${response.statusCode}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('ESP32 WiFi: Connection error - $e');
      return false;
    }
  }

  /// Connect to ESP32 with the provided IP address and port
  Future<bool> connectToESP(String ipAddress, {int port = 80}) async {
    return await connect(ipAddress, port: port);
  }

  /// Scan for ESP32 devices on the local network
  /// This is a simplified implementation that searches common ESP32 IP addresses
  Future<List<String>> scanForDevices() async {
    debugPrint('ESP32 WiFi: Scanning for devices...');

    List<String> foundDevices = [];
    List<Future<bool>> scanFutures = [];

    // Common IP ranges for ESP32 devices
    // Usually, ESP32 devices might be in the 192.168.4.x range when in AP mode
    // or in the local network range when in Station mode

    // Try AP mode (ESP32 creates its own network)
    scanFutures.add(
      _checkDevice('192.168.4.1').then((found) {
        if (found) foundDevices.add('192.168.4.1');
        return found;
      }),
    );

    // Windows hotspot typically uses 192.168.137.x range
    for (int i = 2; i < 254; i++) {
      final ip = '192.168.137.$i';
      scanFutures.add(
        _checkDevice(ip).then((found) {
          if (found) foundDevices.add(ip);
          return found;
        }),
      );
    }

    // Try common local network IP ranges
    for (int i = 2; i < 254; i++) {
      final ip = '192.168.0.$i';
      scanFutures.add(
        _checkDevice(ip).then((found) {
          if (found) foundDevices.add(ip);
          return found;
        }),
      );
    }

    for (int i = 2; i < 20; i++) {
      final ip = '192.168.1.$i';
      scanFutures.add(
        _checkDevice(ip).then((found) {
          if (found) foundDevices.add(ip);
          return found;
        }),
      );
    }

    // Wait for all scan futures to complete
    await Future.wait(scanFutures);

    debugPrint('ESP32 WiFi: Found ${foundDevices.length} devices');
    return foundDevices;
  }

  /// Scan for ESP32 devices on the local network (alias for scanForDevices)
  Future<List<String>> scanForESP32Devices() async {
    return await scanForDevices();
  }

  /// Check if an ESP32 is at the given IP address
  Future<bool> _checkDevice(String ipAddress) async {
    try {
      // Use a harmless test command like "S" or "STOP"
      final testUrl = Uri.parse('http://$ipAddress/command?move=S');
      final response = await http
          .get(testUrl)
          .timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        debugPrint('ESP32 found at $ipAddress');
        return true;
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  /// Send a command to the ESP32
  Future<bool> sendCommand(String command) async {
    if (!_isConnected) {
      debugPrint('ESP32 WiFi: Cannot send command - not connected');
      return false;
    }

    // Ensure we're only sending a single character command
    // This is a failsafe in case the command wasn't already mapped
    String singleCharCommand = command.length > 1 ? command[0] : command;

    debugPrint('ESP32 WiFi: Sending command: $command (as $singleCharCommand)');

    try {
      // Send GET request with move query param
      final uri = Uri.parse(
        'http://$_espIpAddress:$_espPort/command?move=$singleCharCommand',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        debugPrint('ESP32 WiFi: Command sent successfully');
        debugPrint('ESP32 WiFi: Response: ${response.body}');
        _dataStreamController.add(response.body);
        return true;
      } else {
        debugPrint('ESP32 WiFi: Command failed - HTTP ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('ESP32 WiFi: Error sending command - $e');
      return false;
    }
  }

  /// Send a command and wait for a response
  Future<String?> sendCommandWithResponse(String command) async {
    if (!_isConnected) {
      debugPrint('ESP32 WiFi: Cannot send command - not connected');
      return null;
    }

    debugPrint('ESP32 WiFi: Sending command with response: $command');

    try {
      final response = await http
          .post(
            Uri.parse('http://$_espIpAddress:$_espPort/command'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'command': command}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        debugPrint('ESP32 WiFi: Command sent successfully');

        // Return response as string
        return response.body;
      } else {
        debugPrint('ESP32 WiFi: Command failed - HTTP ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('ESP32 WiFi: Error sending command - $e');
      return null;
    }
  }

  /// Get the status of the ESP32
  Future<Map<String, dynamic>?> getStatus() async {
    if (!_isConnected) {
      debugPrint('ESP32 WiFi: Cannot get status - not connected');
      return null;
    }

    try {
      final response = await http
          .get(Uri.parse('http://$_espIpAddress:$_espPort/status'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        try {
          return jsonDecode(response.body);
        } catch (e) {
          debugPrint('ESP32 WiFi: Error parsing status response - $e');
          return {'status': 'unknown', 'message': response.body};
        }
      } else {
        debugPrint(
          'ESP32 WiFi: Failed to get status - HTTP ${response.statusCode}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('ESP32 WiFi: Error getting status - $e');
      return null;
    }
  }

  /// Disconnect from the ESP32
  void disconnect() {
    debugPrint('ESP32 WiFi: Disconnecting');
    _isConnected = false;
    _espIpAddress = '';
    _espPort = 80;
    notifyListeners();
  }

  /// Convert natural language commands to ESP32 single-character format
  String mapCommandToESP32Format(String command) {
    final String lowercaseCommand = command.toLowerCase().trim();

    // Map common movement commands to ESP32 format (F, L, R, B, S)
    if (lowercaseCommand.contains('forward') ||
        lowercaseCommand.contains('ahead') ||
        lowercaseCommand.contains('go')) {
      return 'F';
    } else if (lowercaseCommand.contains('left') ||
        lowercaseCommand.contains('turn left')) {
      return 'L';
    } else if (lowercaseCommand.contains('right') ||
        lowercaseCommand.contains('turn right')) {
      return 'R';
    } else if (lowercaseCommand.contains('back') ||
        lowercaseCommand.contains('backward') ||
        lowercaseCommand.contains('reverse')) {
      return 'B';
    } else if (lowercaseCommand.contains('stop') ||
        lowercaseCommand.contains('halt') ||
        lowercaseCommand.contains('pause')) {
      return 'S';
    }

    // If no match found, default to Stop command
    return 'S';
  }

  /// Dispose of resources
  @override
  void dispose() {
    _dataStreamController.close();
    super.dispose();
  }
}
