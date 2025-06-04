import 'package:flutter/material.dart';
import 'dart:async';
import '../services/esp32_wifi_service.dart';

class ESP32ConnectionScreen extends StatefulWidget {
  const ESP32ConnectionScreen({super.key});

  @override
  State<ESP32ConnectionScreen> createState() => _ESP32ConnectionScreenState();
}

class _ESP32ConnectionScreenState extends State<ESP32ConnectionScreen> {
  final ESP32WiFiService _esp32Service = ESP32WiFiService();
  final TextEditingController _ipAddressController = TextEditingController();
  bool _isScanning = false;
  bool _isConnecting = false;
  List<String> _discoveredDevices = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _ipAddressController.text = _esp32Service.espIpAddress;
    _startScan();
  }

  @override
  void dispose() {
    _ipAddressController.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _errorMessage = null;
    });

    try {
      // Check if WiFi is available first
      final isEnabled = await _esp32Service.init();
      if (!isEnabled) {
        setState(() {
          _errorMessage =
              'WiFi is not enabled. Please enable WiFi to continue.';
          _isScanning = false;
        });
        return;
      }

      // Scan for ESP32 devices
      final devices = await _esp32Service.scanForESP32Devices();

      if (mounted) {
        setState(() {
          _discoveredDevices = devices;
          _isScanning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error scanning: $e';
          _isScanning = false;
        });
      }
    }
  }

  Future<void> _connectToDevice(String ipAddress) async {
    if (_isConnecting) return;

    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    try {
      final success = await _esp32Service.connectToESP(ipAddress);

      if (mounted) {
        if (success) {
          // Return success to previous screen
          Navigator.pop(context, true);
        } else {
          setState(() {
            _errorMessage = 'Failed to connect to ESP32 at $ipAddress';
            _isConnecting = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Connection error: $e';
          _isConnecting = false;
        });
      }
    }
  }

  Future<void> _connectToManualIP() async {
    final ipAddress = _ipAddressController.text.trim();
    if (ipAddress.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter an IP address';
      });
      return;
    }

    await _connectToDevice(ipAddress);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to ESP32'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isScanning ? null : _startScan,
            tooltip: 'Rescan',
          ),
        ],
      ),
      body: Column(
        children: [
          // Manual IP entry
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _ipAddressController,
                  decoration: InputDecoration(
                    labelText: 'ESP32 IP Address',
                    hintText: '192.168.1.100',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.wifi),
                    suffixIcon: IconButton(
                      icon:
                          _isConnecting
                              ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : Icon(Icons.send),
                      onPressed: _isConnecting ? null : _connectToManualIP,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the IP address of your ESP32 device or select from discovered devices below.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          // Error message
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[300]!),
              ),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red[800]),
              ),
            ),

          // Discovered devices list
          Expanded(
            child:
                _isScanning
                    ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Scanning for ESP32 devices...'),
                        ],
                      ),
                    )
                    : _discoveredDevices.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.devices,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          const Text('No ESP32 devices found on the network'),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: _startScan,
                            child: const Text('Scan Again'),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      itemCount: _discoveredDevices.length,
                      itemBuilder: (context, index) {
                        final device = _discoveredDevices[index];
                        return ListTile(
                          leading: const Icon(
                            Icons.devices,
                            color: Colors.blue,
                          ),
                          title: Text('ESP32 Device'),
                          subtitle: Text(device),
                          trailing: ElevatedButton(
                            onPressed: () => _connectToDevice(device),
                            child: const Text('CONNECT'),
                          ),
                          onTap: () => _connectToDevice(device),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
