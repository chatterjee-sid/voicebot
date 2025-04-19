import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class BluetoothDeviceSelectionScreen extends StatefulWidget {
  const BluetoothDeviceSelectionScreen({super.key});

  @override
  State<BluetoothDeviceSelectionScreen> createState() =>
      _BluetoothDeviceSelectionScreenState();
}

class _BluetoothDeviceSelectionScreenState
    extends State<BluetoothDeviceSelectionScreen> {
  List<BluetoothDevice> _devices = [];
  bool _isDiscovering = false;

  @override
  void initState() {
    super.initState();

    // Schedule the platform check for after the first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPlatformAndInitialize();
    });
  }

  void _checkPlatformAndInitialize() {
    // For desktop platforms, especially Windows, we'll use simulation mode
    if (Theme.of(context).platform == TargetPlatform.windows ||
        Theme.of(context).platform == TargetPlatform.linux ||
        Theme.of(context).platform == TargetPlatform.macOS) {
      _simulateDevices();
    } else {
      _startDiscovery();
    }
  }

  void _simulateDevices() {
    // Create simulated devices for desktop platforms
    setState(() {
      _devices = [
        BluetoothDevice(
          name: 'Simulated Arduino Robot',
          address: '00:11:22:33:44:55',
        ),
        BluetoothDevice(name: 'HC-05 Module', address: '55:44:33:22:11:00'),
        BluetoothDevice(
          name: 'Robot Car Controller',
          address: 'AA:BB:CC:DD:EE:FF',
        ),
      ];
      _isDiscovering = false;
    });
  }

  void _startDiscovery() async {
    setState(() {
      _isDiscovering = true;
    });

    try {
      // This will only execute on mobile platforms
      bool? isEnabled = await FlutterBluetoothSerial.instance.isEnabled;
      if (isEnabled != true) {
        await FlutterBluetoothSerial.instance.requestEnable();
        isEnabled = await FlutterBluetoothSerial.instance.isEnabled;
        if (isEnabled != true) {
          setState(() {
            _isDiscovering = false;
          });
          return;
        }
      }

      // Get paired devices
      List<BluetoothDevice> bondedDevices =
          await FlutterBluetoothSerial.instance.getBondedDevices();

      setState(() {
        _devices = bondedDevices;
        _isDiscovering = false;
      });
    } catch (e) {
      setState(() {
        _isDiscovering = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to discover devices: ${e.toString()}'),
          ),
        );
      }
    }
  }

  bool isDesktopPlatform() {
    return Theme.of(context).platform == TargetPlatform.windows ||
        Theme.of(context).platform == TargetPlatform.linux ||
        Theme.of(context).platform == TargetPlatform.macOS;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Bluetooth Device'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_isDiscovering ? Icons.stop : Icons.refresh),
            onPressed:
                _isDiscovering
                    ? null
                    : isDesktopPlatform()
                    ? _simulateDevices
                    : _startDiscovery,
          ),
        ],
      ),
      body:
          _isDiscovering
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Discovering devices...'),
                  ],
                ),
              )
              : _devices.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('No devices found'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed:
                          isDesktopPlatform()
                              ? _simulateDevices
                              : _startDiscovery,
                      child: const Text('SCAN AGAIN'),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                itemCount: _devices.length,
                itemBuilder: (context, index) {
                  final device = _devices[index];
                  return ListTile(
                    leading: Icon(
                      device.name?.contains('Arduino') == true ||
                              device.name?.contains('HC-05') == true ||
                              device.name?.contains('Robot') == true
                          ? Icons.memory
                          : Icons.bluetooth,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(device.name ?? 'Unknown device'),
                    subtitle: Text(device.address),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(context, device);
                    },
                  );
                },
              ),
    );
  }
}
