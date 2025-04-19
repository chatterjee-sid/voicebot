import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class BluetoothService {
  static final FlutterBluetoothSerial _bluetooth =
      FlutterBluetoothSerial.instance;
  static BluetoothConnection? _connection;
  static bool _isConnected = false;
  static final Set<BluetoothDiscoveryResult> _devicesList = {};
  static StreamSubscription<BluetoothDiscoveryResult>? _discoveryStream;

  static bool get isConnected => _isConnected;

  // Initialize Bluetooth
  static Future<bool> initBluetooth() async {
    try {
      // Check if Bluetooth is available
      bool? isAvailable = await _bluetooth.isAvailable;
      if (isAvailable != true) {
        return false;
      }

      // Check if Bluetooth is enabled
      bool? isEnabled = await _bluetooth.isEnabled;
      if (isEnabled != true) {
        // Request user to enable Bluetooth
        await _bluetooth.requestEnable();
        // Check again if it was enabled
        isEnabled = await _bluetooth.isEnabled;
      }

      return isEnabled ?? false;
    } catch (e) {
      debugPrint('Error initializing Bluetooth: $e');
      return false;
    }
  }

  // Start device discovery
  static Future<StreamSubscription<BluetoothDiscoveryResult>> startDiscovery(
    Function(Set<BluetoothDiscoveryResult>) onResultsUpdated,
  ) async {
    _devicesList.clear();

    // Cancel any existing discovery stream
    await _discoveryStream?.cancel();

    // Start discovery and listen for results
    _discoveryStream = _bluetooth.startDiscovery().listen((result) {
      final existingIndex = _devicesList.lookup(result);
      if (existingIndex == null) {
        _devicesList.add(result);
        onResultsUpdated(_devicesList);
      }
    });

    return _discoveryStream!;
  }

  // Stop discovery
  static void stopDiscovery() {
    _discoveryStream?.cancel();
    _discoveryStream = null;
  }

  // Connect to a device
  static Future<bool> connectToDevice(BluetoothDevice device) async {
    if (_connection != null) {
      await _connection!.close();
      _connection = null;
      _isConnected = false;
    }

    try {
      _connection = await BluetoothConnection.toAddress(device.address);
      _isConnected = true;
      debugPrint('Connected to ${device.name}');

      // Listen for disconnection
      _connection!.input!.listen(null).onDone(() {
        _isConnected = false;
        _connection = null;
        debugPrint('Disconnected from ${device.name}');
      });

      return true;
    } catch (e) {
      debugPrint('Error connecting to device: $e');
      _isConnected = false;
      _connection = null;
      return false;
    }
  }

  // Send command to connected device
  static Future<bool> sendCommand(String command) async {
    if (!_isConnected || _connection == null) {
      return false;
    }

    try {
      // Add a newline character to end the command
      command = "$command\n";
      _connection!.output.add(Uint8List.fromList(utf8.encode(command)));
      await _connection!.output.allSent;
      debugPrint('Command sent: $command');
      return true;
    } catch (e) {
      debugPrint('Error sending command: $e');
      _isConnected = false;
      return false;
    }
  }

  // Disconnect from device
  static Future<void> disconnect() async {
    if (_connection != null) {
      await _connection!.close();
      _connection = null;
      _isConnected = false;
      debugPrint('Bluetooth disconnected');
    }
  }

  // Dispose of resources
  static void dispose() {
    stopDiscovery();
    disconnect();
  }
}
