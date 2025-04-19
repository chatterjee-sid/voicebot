import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../services/bluetooth_service.dart';

class BluetoothDeviceSelectionScreen extends StatefulWidget {
  const BluetoothDeviceSelectionScreen({Key? key}) : super(key: key);

  @override
  State<BluetoothDeviceSelectionScreen> createState() =>
      _BluetoothDeviceSelectionScreenState();
}

class _BluetoothDeviceSelectionScreenState
    extends State<BluetoothDeviceSelectionScreen> {
  List<BluetoothDiscoveryResult> _devices = [];
  bool _isScanning = false;
  StreamSubscription<BluetoothDiscoveryResult>? _discoveryStreamSubscription;

  @override
  void initState() {
    super.initState();
    _startDiscovery();
  }

  @override
  void dispose() {
    _discoveryStreamSubscription?.cancel();
    super.dispose();
  }

  void _startDiscovery() {
    setState(() {
      _isScanning = true;
      _devices = [];
    });

    BluetoothService.startDiscovery((results) {
      setState(() {
        _devices = results.toList();
      });
    }).then((subscription) {
      _discoveryStreamSubscription = subscription;
    });

    // Stop discovery after 30 seconds automatically
    Future.delayed(const Duration(seconds: 30), () {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Device'),
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
      body: Column(
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
                _devices.isEmpty
                    ? Center(
                      child:
                          _isScanning
                              ? const Text('Scanning for devices...')
                              : const Text('No devices found'),
                    )
                    : ListView.builder(
                      itemCount: _devices.length,
                      itemBuilder: (context, index) {
                        final result = _devices[index];
                        final device = result.device;
                        return ListTile(
                          leading: Icon(
                            Icons.bluetooth,
                            color: Theme.of(context).primaryColor,
                          ),
                          title: Text(device.name ?? 'Unknown device'),
                          subtitle: Text(device.address),
                          trailing: TextButton(
                            child: const Text('CONNECT'),
                            onPressed: () {
                              _stopDiscovery(); // Stop discovery before connecting
                              Navigator.of(
                                context,
                              ).pop(device); // Return the selected device
                            },
                          ),
                          onTap: () {
                            _stopDiscovery(); // Stop discovery before connecting
                            Navigator.of(
                              context,
                            ).pop(device); // Return the selected device
                          },
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
