import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'bluetooth_service/bluetooth_service_interface.dart';
import 'bluetooth_service/bluetooth_service_windows.dart';
import 'bluetooth_service/bluetooth_service_android.dart';

/// A Bluetooth service that can use platform-specific implementations
class BluetoothService {
  // Flag to control whether to use mock implementation or real Bluetooth hardware
  static bool useMockImplementation = false;

  // Lazy initialize the appropriate implementation
  static BluetoothServiceInterface get _implementation {
    if (_instance == null) {
      if (useMockImplementation) {
        // Use mock implementation for testing
        debugPrint('💡 Bluetooth Service: Using MOCK implementation');
        _instance = _getMockImplementation();
      } else {
        // Use real implementation based on platform
        _instance = _getRealImplementation();
        debugPrint(
          '💡 Bluetooth Service: Using REAL ${Platform.operatingSystem} implementation',
        );
      }
    }
    return _instance!;
  }

  // Create the appropriate mock implementation
  static BluetoothServiceInterface _getMockImplementation() {
    // Always return a mock that simulates successful operations
    return BluetoothServiceWindows(); // Using Windows implementation as a mock
  }

  // Create the appropriate real implementation based on platform
  static BluetoothServiceInterface _getRealImplementation() {
    if (Platform.isAndroid) {
      return BluetoothServiceAndroid();
    } else if (Platform.isWindows) {
      // Use our Windows Bluetooth implementation that attempts to work with real devices
      // through PowerShell, but can fall back to simulation if needed
      debugPrint(
        '💡 Bluetooth Service: Using Windows Bluetooth implementation with real device support',
      );
      return BluetoothServiceWindows();
    } else {
      // For other platforms, fallback to mock implementation
      debugPrint(
        '⚠️ Warning: No Bluetooth implementation for ${Platform.operatingSystem}',
      );
      debugPrint('⚠️ Using Windows implementation as fallback');
      return BluetoothServiceWindows();
    }
  }

  // Singleton instance
  static BluetoothServiceInterface? _instance;

  // Public API - delegates to the appropriate implementation

  /// Returns whether Bluetooth is currently connected
  static bool get isConnected => _implementation.isConnected;

  /// Returns whether device discovery is currently in progress
  static bool get isDiscovering => _implementation.isDiscovering;

  /// Returns list of currently bonded/paired devices
  static List<BluetoothDevice> get bondedDevices =>
      _implementation.bondedDevices;

  /// Returns the currently connected device or null if not connected
  static BluetoothDevice? get connectedDevice =>
      _implementation.connectedDevice;

  /// Returns a stream of data received from the connected device
  static Stream<String>? get dataStream => _implementation.dataStream;

  /// Initialize Bluetooth functionality
  static Future<bool> initBluetooth() async {
    try {
      debugPrint(
        '💡 Bluetooth Service: Initializing for ${Platform.operatingSystem}',
      );
      return await _implementation.initBluetooth();
    } catch (e) {
      debugPrint('❌ Error initializing Bluetooth: $e');
      return false;
    }
  }

  /// Get list of bonded/paired devices
  static Future<List<BluetoothDevice>> getBondedDevices() async {
    return _implementation.getBondedDevices();
  }

  /// Check if a device is bonded/paired
  static bool isDeviceBonded(BluetoothDevice device) {
    return _implementation.isDeviceBonded(device);
  }

  /// Start scanning for Bluetooth devices
  static Future<StreamSubscription> startDiscovery(
    Function(Set<BluetoothDiscoveryResult>) onResultsUpdated,
  ) async {
    debugPrint('🔍 Starting Bluetooth discovery...');
    try {
      final subscription = await _implementation.startDiscovery(
        onResultsUpdated,
      );
      debugPrint('✅ Bluetooth discovery started successfully');
      return subscription;
    } catch (e) {
      debugPrint('❌ Error starting Bluetooth discovery: $e');
      rethrow;
    }
  }

  /// Get current discovered devices
  static Set<BluetoothDiscoveryResult> getDiscoveredDevices() {
    final devices = _implementation.getDiscoveredDevices();
    debugPrint(
      '📱 Found ${devices.length} Bluetooth devices: ${devices.map((d) => d.device.name ?? 'Unknown').join(', ')}',
    );
    return devices;
  }

  /// Stop scanning for Bluetooth devices
  static void stopDiscovery() {
    _implementation.stopDiscovery();
  }

  /// Pair with a Bluetooth device
  static Future<bool> pairDevice(BluetoothDevice device) async {
    return _implementation.pairDevice(device);
  }

  /// Connect to a Bluetooth device
  static Future<bool> connectToDevice(BluetoothDevice device) async {
    return _implementation.connectToDevice(device);
  }

  /// Get current Bluetooth state
  static Future<BluetoothState> getBluetoothState() async {
    return _implementation.getBluetoothState();
  }

  /// Send command to connected device
  static Future<bool> sendCommand(String command) async {
    return _implementation.sendCommand(command);
  }

  /// Disconnect from device
  static Future<void> disconnect() async {
    await _implementation.disconnect();
  }

  /// Remove bond (unpair) with device
  static Future<bool> removeBond(BluetoothDevice device) async {
    return _implementation.removeBond(device);
  }

  /// Dispose of resources
  static void dispose() {
    _implementation.dispose();
  }
}
