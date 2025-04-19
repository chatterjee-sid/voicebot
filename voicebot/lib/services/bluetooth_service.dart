import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

// Import Windows platform flag
import '../main.dart' show isRunningOnWindows;

class BluetoothService {
  static BluetoothConnection? connection;
  static StreamSubscription<BluetoothDiscoveryResult>? _streamSubscription;
  static List<BluetoothDiscoveryResult> devices = [];
  static bool isConnected = false;
  static bool _isPlatformSupported = !isRunningOnWindows;

  // Check if this platform supports Bluetooth
  static bool get isPlatformSupported => _isPlatformSupported;

  // Initialize Bluetooth
  static Future<bool> initBluetooth() async {
    try {
      // Always return mock success on Windows
      if (isRunningOnWindows) {
        debugPrint('Running on Windows - using mock Bluetooth');
        _isPlatformSupported = false;
        return true;
      }

      // Check for platform support
      if (!Platform.isAndroid && !Platform.isIOS) {
        debugPrint(
          'Bluetooth functionality not supported on ${Platform.operatingSystem}',
        );
        _isPlatformSupported = false;
        return false;
      }

      _isPlatformSupported = true;
      bool isEnabled = await FlutterBluetoothSerial.instance.isEnabled ?? false;
      if (!isEnabled) {
        await FlutterBluetoothSerial.instance.requestEnable();
      }
      return await FlutterBluetoothSerial.instance.isEnabled ?? false;
    } catch (e) {
      debugPrint('Error initializing Bluetooth: $e');
      _isPlatformSupported = false;
      return false;
    }
  }

  // Start device discovery
  static void startDiscovery(
    Function(List<BluetoothDiscoveryResult>) onDevicesFound,
  ) {
    // Always provide mock devices on Windows or unsupported platforms
    if (isRunningOnWindows || !_isPlatformSupported) {
      debugPrint(
        'Using mock Bluetooth discovery on ${Platform.operatingSystem}',
      );
      _provideMockDevices(onDevicesFound);
      return;
    }

    devices.clear();
    _streamSubscription?.cancel();

    _streamSubscription = FlutterBluetoothSerial.instance
        .startDiscovery()
        .listen((result) {
          final deviceIndex = devices.indexWhere(
            (device) => device.device.address == result.device.address,
          );
          if (deviceIndex < 0) {
            devices.add(result);
            onDevicesFound(devices);
          }
        });

    _streamSubscription?.onDone(() {
      _streamSubscription = null;
    });
  }

  // Provide mock Bluetooth devices for testing on Windows or platforms without Bluetooth support
  static void _provideMockDevices(
    Function(List<BluetoothDiscoveryResult>) onDevicesFound,
  ) {
    // Create mock devices with a delay to simulate discovery
    Future.delayed(const Duration(seconds: 2), () {
      final mockDevices = [
        BluetoothDiscoveryResult(
          device: BluetoothDevice(
            name: 'Mock Robot 1',
            address: '00:11:22:33:44:55',
          ),
          rssi: -60,
        ),
        BluetoothDiscoveryResult(
          device: BluetoothDevice(
            name: 'Mock Arduino Bot',
            address: 'AA:BB:CC:DD:EE:FF',
          ),
          rssi: -70,
        ),
        BluetoothDiscoveryResult(
          device: BluetoothDevice(
            name: 'Windows Test Device',
            address: 'WW:II:NN:DD:OO:WS',
          ),
          rssi: -50,
        ),
      ];

      devices.addAll(mockDevices);
      onDevicesFound(devices);
    });
  }

  // Stop discovery process
  static void stopDiscovery() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
  }

  // Connect to a bluetooth device
  static Future<bool> connectToDevice(BluetoothDevice device) async {
    if (isRunningOnWindows || !_isPlatformSupported) {
      // Simulate connection on Windows
      debugPrint('Simulating connection to device: ${device.name}');
      isConnected = true;
      return true;
    }

    if (connection != null) {
      await connection?.close();
      connection = null;
      isConnected = false;
    }

    try {
      connection = await BluetoothConnection.toAddress(device.address);
      isConnected = true;

      // Listen for incoming data (useful for status updates)
      connection?.input?.listen((data) {
        final message = ascii.decode(data);
        debugPrint('Data received from Arduino: $message');
      });

      return true;
    } catch (e) {
      debugPrint('Connection error: $e');
      isConnected = false;
      return false;
    }
  }

  // Send command to Arduino
  static Future<bool> sendCommand(String command) async {
    if (isRunningOnWindows || !_isPlatformSupported) {
      // Simulate sending command on Windows
      debugPrint('Simulating sending command: $command');
      return true;
    }

    if (connection?.isConnected ?? false) {
      try {
        connection!.output.add(utf8.encode('$command\r\n'));
        await connection!.output.allSent;
        return true;
      } catch (e) {
        debugPrint('Failed to send command: $e');
        return false;
      }
    } else {
      debugPrint('Bluetooth not connected');
      return false;
    }
  }

  // Disconnect from device
  static Future<void> disconnect() async {
    if (isRunningOnWindows || !_isPlatformSupported) {
      isConnected = false;
      return;
    }

    await connection?.close();
    connection = null;
    isConnected = false;
  }
}
