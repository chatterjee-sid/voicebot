import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as fbs;
import 'bluetooth_service_interface.dart';

/// Real implementation of the Bluetooth service using flutter_bluetooth_serial
class BluetoothServiceReal implements BluetoothServiceInterface {
  // Instance of the flutter_bluetooth_serial plugin
  final fbs.FlutterBluetoothSerial _bluetooth =
      fbs.FlutterBluetoothSerial.instance;

  // Connection state
  bool _isConnected = false;
  bool _isDiscovering = false;
  fbs.BluetoothConnection? _connection;
  // Stores reference to the currently connected device
  BluetoothDevice? _connectedDevice;

  // Discovery state
  final Set<BluetoothDiscoveryResult> _discoveredDevices = {};
  StreamSubscription<fbs.BluetoothDiscoveryResult>?
  _discoveryStreamSubscription;

  // Cache of bonded devices
  final List<BluetoothDevice> _bondedDevices = [];

  @override
  bool get isConnected => _isConnected;

  @override
  bool get isDiscovering => _isDiscovering;

  @override
  List<BluetoothDevice> get bondedDevices => _bondedDevices;

  @override
  BluetoothDevice? get connectedDevice => _connectedDevice;

  @override
  Future<bool> initBluetooth() async {
    debugPrint("Real Bluetooth: Initializing");

    try {
      // Request Bluetooth permission if needed
      bool isBluetoothEnabled = await _bluetooth.isEnabled ?? false;

      if (!isBluetoothEnabled) {
        // Try to request enabling Bluetooth
        isBluetoothEnabled = await _bluetooth.requestEnable() ?? false;
      }

      if (isBluetoothEnabled) {
        // Get already paired devices
        await getBondedDevices();
        return true;
      } else {
        debugPrint("Real Bluetooth: Failed to enable Bluetooth");
        return false;
      }
    } catch (e) {
      debugPrint("Real Bluetooth: Error initializing - $e");
      return false;
    }
  }

  @override
  Future<List<BluetoothDevice>> getBondedDevices() async {
    try {
      // Get the list of paired devices
      final bondedDevicesList = await _bluetooth.getBondedDevices();

      // Convert to our interface's device type
      _bondedDevices.clear();
      for (var device in bondedDevicesList) {
        _bondedDevices.add(_convertToInterfaceDevice(device));
      }

      debugPrint(
        "Real Bluetooth: Found ${_bondedDevices.length} bonded devices",
      );
      return _bondedDevices;
    } catch (e) {
      debugPrint("Real Bluetooth: Error getting bonded devices - $e");
      return [];
    }
  }

  // Convert from plugin BluetoothDevice to our interface BluetoothDevice
  BluetoothDevice _convertToInterfaceDevice(fbs.BluetoothDevice device) {
    // Get the device type as an integer (0 for unknown)
    int deviceTypeInt = 0;
    if (device.type == fbs.BluetoothDeviceType.classic) {
      deviceTypeInt = 0;
    } else if (device.type == fbs.BluetoothDeviceType.le) {
      deviceTypeInt = 1;
    } else if (device.type == fbs.BluetoothDeviceType.dual) {
      deviceTypeInt = 2;
    }

    return BluetoothDevice(
      address: device.address,
      name: device.name ?? "Unknown Device",
      type: deviceTypeInt,
      isConnected: device.isConnected,
    );
  }

  @override
  bool isDeviceBonded(BluetoothDevice device) {
    return _bondedDevices.any((d) => d.address == device.address);
  }

  @override
  Future<StreamSubscription> startDiscovery(
    Function(Set<BluetoothDiscoveryResult>) onResultsUpdated,
  ) async {
    if (_isDiscovering) {
      stopDiscovery();
    }

    debugPrint("Real Bluetooth: Starting device discovery");
    _isDiscovering = true;
    _discoveredDevices.clear();

    try {
      _discoveryStreamSubscription = _bluetooth.startDiscovery().listen(
        (fbs.BluetoothDiscoveryResult result) {
          // Convert to our interface type
          final interfaceResult = BluetoothDiscoveryResult(
            device: _convertToInterfaceDevice(result.device),
            rssi: result.rssi,
          );

          // Add or update the device in our set
          _discoveredDevices.removeWhere(
            (r) => r.device.address == interfaceResult.device.address,
          );
          _discoveredDevices.add(interfaceResult);

          // Notify the listener
          onResultsUpdated(_discoveredDevices);

          debugPrint(
            "Real Bluetooth: Found device: ${result.device.name} - ${result.device.address}",
          );
        },
        onDone: () {
          _isDiscovering = false;
          debugPrint("Real Bluetooth: Discovery finished");
        },
        onError: (error) {
          _isDiscovering = false;
          debugPrint("Real Bluetooth: Error during discovery - $error");
        },
      );

      return _discoveryStreamSubscription!;
    } catch (e) {
      debugPrint("Real Bluetooth: Failed to start discovery - $e");
      _isDiscovering = false;
      // Return a dummy subscription
      final controller =
          StreamController<Set<BluetoothDiscoveryResult>>.broadcast();
      return controller.stream.listen((_) {});
    }
  }

  @override
  Set<BluetoothDiscoveryResult> getDiscoveredDevices() {
    return _discoveredDevices;
  }

  @override
  void stopDiscovery() {
    if (_isDiscovering) {
      debugPrint("Real Bluetooth: Stopping discovery");
      _discoveryStreamSubscription?.cancel();
      _discoveryStreamSubscription = null;
      _isDiscovering = false;
    }
  }

  @override
  Future<bool> pairDevice(BluetoothDevice device) async {
    debugPrint(
      "Real Bluetooth: Pairing with device ${device.name} (${device.address})",
    );

    // Not directly supported by flutter_bluetooth_serial
    // For most platforms, you need to start the system pairing dialog

    // For demo purposes, we'll just add the device to bonded devices
    // In a real implementation, you would trigger the system pairing process
    if (!isDeviceBonded(device)) {
      _bondedDevices.add(device);
    }

    return true;
  }

  @override
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      debugPrint(
        "Real Bluetooth: Connecting to device ${device.name} (${device.address})",
      );

      // Disconnect if already connected
      if (_isConnected) {
        await disconnect();
      }

      // Connect to the device
      _connection = await fbs.BluetoothConnection.toAddress(device.address);
      _isConnected = true;
      _connectedDevice = device;

      debugPrint("Real Bluetooth: Connected successfully to ${device.name}");

      // Set up listener for incoming data
      _connection?.input?.listen(
        (List<int> data) {
          // Process incoming data here
          debugPrint(
            "Real Bluetooth: Received data: ${String.fromCharCodes(data)}",
          );
        },
        onDone: () {
          debugPrint("Real Bluetooth: Connection closed");
          _isConnected = false;
          _connectedDevice = null;
          _connection = null;
        },
        onError: (error) {
          debugPrint("Real Bluetooth: Connection error - $error");
          _isConnected = false;
          _connectedDevice = null;
          _connection = null;
        },
      );

      return true;
    } catch (e) {
      debugPrint("Real Bluetooth: Failed to connect - $e");
      _isConnected = false;
      _connectedDevice = null;
      _connection = null;
      return false;
    }
  }

  @override
  Future<BluetoothState> getBluetoothState() async {
    try {
      final state = await _bluetooth.state;

      // Convert to our interface BluetoothState
      switch (state) {
        case fbs.BluetoothState.STATE_ON:
          return BluetoothState.ON;
        case fbs.BluetoothState.STATE_OFF:
          return BluetoothState.OFF;
        case fbs.BluetoothState.STATE_TURNING_ON:
          return BluetoothState.TURNING_ON;
        case fbs.BluetoothState.STATE_TURNING_OFF:
          return BluetoothState.TURNING_OFF;
        default:
          return BluetoothState.UNKNOWN;
      }
    } catch (e) {
      debugPrint("Real Bluetooth: Error getting state - $e");
      return BluetoothState.UNKNOWN;
    }
  }

  @override
  Future<bool> sendCommand(String command) async {
    if (!_isConnected || _connection == null) {
      debugPrint("Real Bluetooth: Cannot send command - not connected");
      return false;
    }

    try {
      debugPrint("Real Bluetooth: Sending command: $command");
      // Convert string to Uint8List for sending
      final data = Uint8List.fromList(command.codeUnits);
      _connection!.output.add(data);
      await _connection!.output.allSent;
      debugPrint("Real Bluetooth: Command sent successfully");
      return true;
    } catch (e) {
      debugPrint("Real Bluetooth: Failed to send command - $e");
      return false;
    }
  }

  @override
  Future<String?> sendCommandWithResponse(
    String command, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    // Basic implementation that just sends command but doesn't wait for response
    await sendCommand(command);
    return null;
  }

  @override
  Future<void> disconnect() async {
    if (_connection != null) {
      try {
        debugPrint("Real Bluetooth: Disconnecting");
        await _connection!.close();
      } catch (e) {
        debugPrint("Real Bluetooth: Error during disconnect - $e");
      } finally {
        _isConnected = false;
        _connectedDevice = null;
        _connection = null;
      }
    }
  }

  @override
  Future<bool> removeBond(BluetoothDevice device) async {
    debugPrint(
      "Real Bluetooth: Removing bond with ${device.name} (${device.address})",
    );

    // Not directly supported by flutter_bluetooth_serial
    // Just remove from our local cache
    final initialCount = _bondedDevices.length;
    _bondedDevices.removeWhere((d) => d.address == device.address);
    final wasRemoved = _bondedDevices.length < initialCount;

    return wasRemoved;
  }

  @override
  Stream<String>? get dataStream => null; // Not implemented in real service

  @override
  void dispose() {
    debugPrint("Real Bluetooth: Disposing resources");
    stopDiscovery();
    disconnect();
  }
}
