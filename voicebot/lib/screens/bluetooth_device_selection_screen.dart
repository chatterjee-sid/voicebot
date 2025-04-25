import 'dart:async';
import 'package:flutter/material.dart';
import '../services/bluetooth_service.dart';
import '../services/bluetooth_service/bluetooth_service_interface.dart';

class BluetoothDeviceSelectionScreen extends StatefulWidget {
  const BluetoothDeviceSelectionScreen({super.key});

  @override
  State<BluetoothDeviceSelectionScreen> createState() =>
      _BluetoothDeviceSelectionScreenState();
}

class _BluetoothDeviceSelectionScreenState
    extends State<BluetoothDeviceSelectionScreen>
    with SingleTickerProviderStateMixin {
  List<BluetoothDiscoveryResult> _discoveredDevices = [];
  List<BluetoothDevice> _pairedDevices = [];
  bool _isScanning = false;
  StreamSubscription? _discoveryStreamSubscription;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initBluetoothState();
  }

  @override
  void dispose() {
    _discoveryStreamSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initBluetoothState() async {
    // Get current Bluetooth state
    final state = await BluetoothService.getBluetoothState();
    if (state != BluetoothState.ON) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bluetooth is not enabled. Please enable Bluetooth.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      await BluetoothService.initBluetooth();
    }

    // Load paired devices
    await _loadPairedDevices();

    // Get any previously discovered devices
    final existingDiscoveredDevices =
        BluetoothService.getDiscoveredDevices().toList();
    if (mounted && existingDiscoveredDevices.isNotEmpty) {
      setState(() {
        _discoveredDevices = existingDiscoveredDevices;
      });
    }

    // Start scanning for new devices
    _startDiscovery();
  }

  Future<void> _loadPairedDevices() async {
    try {
      final devices = await BluetoothService.getBondedDevices();
      if (mounted) {
        setState(() {
          _pairedDevices = devices;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load paired devices: $e')),
        );
      }
    }
  }

  void _startDiscovery() {
    setState(() {
      _isScanning = true;
      // Don't clear existing discovered devices
    });

    BluetoothService.startDiscovery((results) {
      if (mounted) {
        setState(() {
          // Merge with existing devices, avoiding duplicates
          final Map<String, BluetoothDiscoveryResult> deviceMap = {};

          // Add existing devices to map
          for (var device in _discoveredDevices) {
            deviceMap[device.device.address] = device;
          }

          // Add or update with new results
          for (var device in results) {
            deviceMap[device.device.address] = device;
          }

          // Convert back to list
          _discoveredDevices = deviceMap.values.toList();
        });
      }
    }).then((subscription) {
      _discoveryStreamSubscription = subscription;
    });

    // Stop discovery after 120 seconds automatically (increased from 60)
    Future.delayed(const Duration(seconds: 120), () {
      if (mounted) {
        _stopDiscovery();
      }
    });
  }

  void _stopDiscovery() {
    _discoveryStreamSubscription?.cancel();
    BluetoothService.stopDiscovery();

    setState(() {
      _isScanning = false;
    });
  }

  Future<void> _pairDevice(BluetoothDevice device) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pairing with ${device.name ?? "Unknown device"}...'),
          ),
        );
      }

      final success = await BluetoothService.pairDevice(device);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Successfully paired with ${device.name ?? "device"}',
              ),
            ),
          );
          // Refresh paired devices
          await _loadPairedDevices();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to pair with ${device.name ?? "device"}'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error pairing: $e')));
      }
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      // Stop discovery before connecting
      _stopDiscovery();

      // Return the selected device
      Navigator.of(context).pop(device);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Device'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Paired Devices'),
            Tab(text: 'Available Devices'),
          ],
        ),
        actions: [
          if (_isScanning)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _stopDiscovery,
              tooltip: 'Stop scanning',
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _startDiscovery,
              tooltip: 'Scan for devices',
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Paired devices tab
          _buildPairedDevicesList(),

          // Available devices tab
          _buildDiscoveredDevicesList(),
        ],
      ),
    );
  }

  Widget _buildPairedDevicesList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              const Icon(Icons.bluetooth_connected, size: 16),
              const SizedBox(width: 8),
              Text(
                '${_pairedDevices.length} paired ${_pairedDevices.length == 1 ? "device" : "devices"}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
                onPressed: _loadPairedDevices,
              ),
            ],
          ),
        ),
        Expanded(
          child:
              _pairedDevices.isEmpty
                  ? const Center(child: Text('No paired devices'))
                  : ListView.builder(
                    itemCount: _pairedDevices.length,
                    itemBuilder: (context, index) {
                      final device = _pairedDevices[index];
                      return ListTile(
                        leading: const Icon(
                          Icons.bluetooth_connected,
                          color: Colors.green,
                        ),
                        title: Text(device.name ?? 'Unknown device'),
                        subtitle: Text(device.address),
                        trailing: ElevatedButton(
                          child: const Text('CONNECT'),
                          onPressed: () => _connectToDevice(device),
                        ),
                        onTap: () => _connectToDevice(device),
                      );
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildDiscoveredDevicesList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child:
              _isScanning
                  ? const LinearProgressIndicator()
                  : Container(
                    height: 4,
                    alignment: Alignment.centerLeft,
                    child: const Text(
                      'Scan completed',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
        ),
        Expanded(
          child:
              _discoveredDevices.isEmpty
                  ? Center(
                    child:
                        _isScanning
                            ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text('Scanning for devices...'),
                              ],
                            )
                            : const Text('No devices found'),
                  )
                  : ListView.builder(
                    itemCount: _discoveredDevices.length,
                    itemBuilder: (context, index) {
                      final result = _discoveredDevices[index];
                      final device = result.device;
                      final bool isAlreadyPaired =
                          BluetoothService.isDeviceBonded(device);

                      return ListTile(
                        leading: Icon(
                          isAlreadyPaired
                              ? Icons.bluetooth_connected
                              : Icons.bluetooth,
                          color:
                              isAlreadyPaired
                                  ? Colors.green
                                  : Theme.of(context).primaryColor,
                        ),
                        title: Text(device.name ?? 'Unknown device'),
                        subtitle: Text(device.address),
                        trailing:
                            isAlreadyPaired
                                ? ElevatedButton(
                                  child: const Text('CONNECT'),
                                  onPressed: () => _connectToDevice(device),
                                )
                                : OutlinedButton(
                                  child: const Text('PAIR'),
                                  onPressed: () => _pairDevice(device),
                                ),
                        onTap: () {
                          if (isAlreadyPaired) {
                            _connectToDevice(device);
                          } else {
                            _pairDevice(device);
                          }
                        },
                      );
                    },
                  ),
        ),
      ],
    );
  }
}
