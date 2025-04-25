import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as fbs;

import 'bluetooth_service_interface.dart';

/// Android implementation of the Bluetooth service using flutter_bluetooth_serial
class BluetoothServiceAndroid implements BluetoothServiceInterface {
  final fbs.FlutterBluetoothSerial _bluetooth =
      fbs.FlutterBluetoothSerial.instance;
  fbs.BluetoothConnection? _connection;
  bool _isConnected = false;
  final Set<fbs.BluetoothDiscoveryResult> _devicesList = {};
  StreamSubscription<fbs.BluetoothDiscoveryResult>? _discoveryStream;
  List<fbs.BluetoothDevice> _bondedDevices = [];
  bool _isDiscovering = false;
  StreamController<String>? _dataStreamController;
  Stream<String>? _dataStream;

  @override
  bool get isConnected => _isConnected;

  @override
  bool get isDiscovering => _isDiscovering;

  @override
  List<BluetoothDevice> get bondedDevices =>
      _bondedDevices.map((device) => _convertDevice(device)).toList();

  @override
  BluetoothDevice? get connectedDevice {
    if (_connection == null) return null;

    try {
      final device = _bondedDevices.firstWhere(
        (device) => device.address == _connection!.address,
      );
      return _convertDevice(device);
    } catch (e) {
      return null;
    }
  }

  @override
  Stream<String>? get dataStream => _dataStream;

  @override
  Future<bool> initBluetooth() async {
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

      // Load bonded devices on initialization
      await getBondedDevices();

      return isEnabled ?? false;
    } catch (e) {
      debugPrint('Error initializing Bluetooth: $e');
      return false;
    }
  }

  @override
  Future<List<BluetoothDevice>> getBondedDevices() async {
    try {
      _bondedDevices = await _bluetooth.getBondedDevices();
      return _bondedDevices.map((device) => _convertDevice(device)).toList();
    } catch (e) {
      debugPrint('Error getting bonded devices: $e');
      return [];
    }
  }

  @override
  bool isDeviceBonded(BluetoothDevice device) {
    return _bondedDevices.any((d) => d.address == device.address);
  }

  @override
  Future<StreamSubscription> startDiscovery(
    Function(Set<BluetoothDiscoveryResult>) onResultsUpdated,
  ) async {
    _devicesList.clear();
    _isDiscovering = true;

    // Cancel any existing discovery stream
    await _discoveryStream?.cancel();

    // Start discovery and listen for results
    _discoveryStream = _bluetooth.startDiscovery().listen(
      (result) {
        final existingIndex = _devicesList.lookup(result);
        if (existingIndex == null) {
          _devicesList.add(result);
          onResultsUpdated(_convertDiscoveryResults(_devicesList));
        }
      },
      onDone: () {
        _isDiscovering = false;
      },
      onError: (error) {
        debugPrint('Error during discovery: $error');
        _isDiscovering = false;
      },
    );

    return _discoveryStream!;
  }

  @override
  Set<BluetoothDiscoveryResult> getDiscoveredDevices() {
    return _convertDiscoveryResults(_devicesList);
  }

  @override
  void stopDiscovery() {
    _discoveryStream?.cancel();
    _discoveryStream = null;
    _isDiscovering = false;
  }

  @override
  Future<bool> pairDevice(BluetoothDevice device) async {
    try {
      debugPrint('Pairing with device: ${device.name}');
      bool? bondResult = await _bluetooth.bondDeviceAtAddress(device.address);
      if (bondResult == true) {
        // Refresh bonded devices list
        await getBondedDevices();
      }
      return bondResult ?? false;
    } catch (e) {
      debugPrint('Error pairing with device: $e');
      return false;
    }
  }

  @override
  Future<bool> connectToDevice(BluetoothDevice device) async {
    if (_connection != null) {
      await _connection!.close();
      _connection = null;
      _isConnected = false;
    }

    try {
      _connection = await fbs.BluetoothConnection.toAddress(device.address);
      _isConnected = true;
      debugPrint('Connected to ${device.name}');

      // Initialize data stream
      _dataStreamController = StreamController<String>.broadcast();
      _dataStream = _dataStreamController?.stream;

      // Listen for incoming data
      _connection!.input!.listen(
        (Uint8List data) {
          String message = utf8.decode(data);
          _dataStreamController?.add(message);
          debugPrint('Received data: $message');
        },
        onDone: () {
          _isConnected = false;
          _connection = null;
          _dataStreamController?.close();
          _dataStreamController = null;
          _dataStream = null;
          debugPrint('Disconnected from ${device.name}');
        },
        onError: (error) {
          debugPrint('Connection error: $error');
          _isConnected = false;
          _connection = null;
          _dataStreamController?.close();
          _dataStreamController = null;
          _dataStream = null;
        },
      );

      return true;
    } catch (e) {
      debugPrint('Error connecting to device: $e');
      _isConnected = false;
      _connection = null;
      return false;
    }
  }

  @override
  Future<BluetoothState> getBluetoothState() async {
    try {
      fbs.BluetoothState state = await _bluetooth.state;
      return _convertBluetoothState(state);
    } catch (e) {
      debugPrint('Error getting Bluetooth state: $e');
      return BluetoothState.UNKNOWN;
    }
  }

  @override
  Future<bool> sendCommand(String command) async {
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

  @override
  Future<void> disconnect() async {
    if (_connection != null) {
      await _connection!.close();
      _connection = null;
      _isConnected = false;
      _dataStreamController?.close();
      _dataStreamController = null;
      _dataStream = null;
      debugPrint('Bluetooth disconnected');
    }
  }

  @override
  Future<bool> removeBond(BluetoothDevice device) async {
    try {
      bool? unbondResult = await _bluetooth.removeDeviceBondWithAddress(
        device.address,
      );
      if (unbondResult == true) {
        // Refresh bonded devices list
        await getBondedDevices();
      }
      return unbondResult ?? false;
    } catch (e) {
      debugPrint('Error removing bond: $e');
      return false;
    }
  }

  @override
  void dispose() {
    stopDiscovery();
    disconnect();
    _dataStreamController?.close();
    _dataStreamController = null;
    _dataStream = null;
  }

  // Helper methods to convert between package-specific models and our interface models

  BluetoothDevice _convertDevice(fbs.BluetoothDevice device) {
    return BluetoothDevice(
      address: device.address,
      name: device.name,
      type: device.type != null ? _convertDeviceTypeToInt(device.type) : null,
      isConnected: device.isConnected,
    );
  }

  int _convertDeviceTypeToInt(fbs.BluetoothDeviceType type) {
    switch (type) {
      case fbs.BluetoothDeviceType.classic:
        return 1;
      case fbs.BluetoothDeviceType.le:
        return 2;
      case fbs.BluetoothDeviceType.dual:
        return 3;
      case fbs.BluetoothDeviceType.unknown:
      default:
        return 0;
    }
  }

  Set<BluetoothDiscoveryResult> _convertDiscoveryResults(
    Set<fbs.BluetoothDiscoveryResult> results,
  ) {
    return results
        .map(
          (result) => BluetoothDiscoveryResult(
            device: _convertDevice(result.device),
            rssi: result.rssi,
          ),
        )
        .toSet();
  }

  BluetoothState _convertBluetoothState(fbs.BluetoothState state) {
    switch (state) {
      case fbs.BluetoothState.STATE_ON:
        return BluetoothState.ON;
      case fbs.BluetoothState.STATE_OFF:
        return BluetoothState.OFF;
      case fbs.BluetoothState.STATE_TURNING_ON:
        return BluetoothState.TURNING_ON;
      case fbs.BluetoothState.STATE_TURNING_OFF:
        return BluetoothState.TURNING_OFF;
      case fbs.BluetoothState.ERROR:
      case fbs.BluetoothState.UNKNOWN:
      default:
        return BluetoothState.UNKNOWN;
    }
  }
}
