import 'dart:async';

/// Common model classes for Bluetooth functionality
class BluetoothDevice {
  final String address;
  final String? name;
  final int? type;
  final bool isConnected;

  BluetoothDevice({
    required this.address,
    this.name,
    this.type,
    this.isConnected = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BluetoothDevice &&
          runtimeType == other.runtimeType &&
          address == other.address;

  @override
  int get hashCode => address.hashCode;
}

class BluetoothDiscoveryResult {
  final BluetoothDevice device;
  final int rssi;

  BluetoothDiscoveryResult({required this.device, required this.rssi});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BluetoothDiscoveryResult &&
          runtimeType == other.runtimeType &&
          device == other.device;

  @override
  int get hashCode => device.hashCode;
}

enum BluetoothState {
  UNKNOWN,
  UNAVAILABLE,
  UNAUTHORIZED,
  TURNING_ON,
  ON,
  TURNING_OFF,
  OFF,
}

/// Interface that defines methods any platform-specific Bluetooth implementation must provide
abstract class BluetoothServiceInterface {
  bool get isConnected;
  bool get isDiscovering;
  List<BluetoothDevice> get bondedDevices;
  BluetoothDevice? get connectedDevice;

  /// Stream of data received from the connected device
  Stream<String>? get dataStream;

  Future<bool> initBluetooth();
  Future<List<BluetoothDevice>> getBondedDevices();
  bool isDeviceBonded(BluetoothDevice device);
  Future<StreamSubscription> startDiscovery(
    Function(Set<BluetoothDiscoveryResult>) onResultsUpdated,
  );
  Set<BluetoothDiscoveryResult> getDiscoveredDevices();
  void stopDiscovery();
  Future<bool> pairDevice(BluetoothDevice device);
  Future<bool> connectToDevice(BluetoothDevice device);
  Future<BluetoothState> getBluetoothState();
  Future<bool> sendCommand(String command);

  /// Sends a command and waits for a specific response
  /// Returns the full response if received within timeout, or null if timeout occurs
  Future<String?> sendCommandWithResponse(
    String command, {
    Duration timeout = const Duration(seconds: 5),
  });

  Future<void> disconnect();
  Future<bool> removeBond(BluetoothDevice device);
  void dispose();
}
