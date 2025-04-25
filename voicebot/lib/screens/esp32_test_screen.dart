import 'dart:async';
import 'package:flutter/material.dart';
import '../services/bluetooth_service.dart';
import '../services/bluetooth_service/bluetooth_service_interface.dart';

class ESP32TestScreen extends StatefulWidget {
  const ESP32TestScreen({super.key});

  @override
  State<ESP32TestScreen> createState() => _ESP32TestScreenState();
}

class _ESP32TestScreenState extends State<ESP32TestScreen> {
  bool _isConnected = false;
  bool _isScanning = false;
  List<BluetoothDiscoveryResult> _devices = [];
  BluetoothDevice? _connectedDevice;
  final TextEditingController _commandController = TextEditingController();
  final List<String> _commandHistory = [];
  final List<String> _responseMessages = [];
  StreamSubscription? _dataStreamSubscription;
  String _connectionMethod = "None";

  @override
  void initState() {
    super.initState();
    _initializeBluetooth();
  }

  Future<void> _initializeBluetooth() async {
    try {
      final initialized = await BluetoothService.initBluetooth();
      if (!initialized) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Failed to initialize Bluetooth. Please make sure Bluetooth is enabled.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Check if already connected
      final device = BluetoothService.connectedDevice;
      if (device != null) {
        setState(() {
          _isConnected = true;
          _connectedDevice = device;
          _setupDataListener();
          _addToHistory("Connected to ${device.name ?? 'Unknown Device'}");
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing Bluetooth: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startScan() {
    setState(() {
      _isScanning = true;
      _devices = [];
    });

    _addToHistory("Scanning for devices...");

    BluetoothService.startDiscovery((devices) {
          if (mounted) {
            setState(() {
              _devices = devices.toList();
            });
          }
        })
        .then((subscription) {
          // Cancel the subscription after 30 seconds if still active
          Future.delayed(const Duration(seconds: 30), () {
            subscription.cancel();
            if (mounted && _isScanning) {
              setState(() {
                _isScanning = false;
              });
              _addToHistory("Scan completed, found ${_devices.length} devices");
            }
          });
        })
        .catchError((error) {
          if (mounted) {
            setState(() {
              _isScanning = false;
            });
            _addToHistory("Scan error: $error");
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error scanning: $error'),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
  }

  void _stopScan() {
    BluetoothService.stopDiscovery();
    setState(() {
      _isScanning = false;
    });
    _addToHistory("Scan stopped manually");
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      setState(() {
        _connectionMethod = "Connecting...";
      });
      _addToHistory("Connecting to ${device.name ?? 'Unknown Device'}...");

      final connected = await BluetoothService.connectToDevice(device);

      if (connected) {
        setState(() {
          _isConnected = true;
          _connectedDevice = device;
          _setupDataListener();

          // Determine connection method (BLE or Serial)
          if (BluetoothService.dataStream != null) {
            // Send a test command to see if we can identify the connection type
            BluetoothService.sendCommand("AT");

            // For now, just set it to "Bluetooth"
            _connectionMethod = "Bluetooth";
          }
        });
        _addToHistory("✅ Connected to ${device.name ?? 'Unknown Device'}");
      } else {
        _addToHistory(
          "❌ Failed to connect to ${device.name ?? 'Unknown Device'}",
        );
        setState(() {
          _connectionMethod = "None";
        });
      }
    } catch (e) {
      _addToHistory("❌ Connection error: $e");
      setState(() {
        _connectionMethod = "None";
      });
    }
  }

  void _setupDataListener() {
    // Cancel any existing subscription
    _dataStreamSubscription?.cancel();

    // Only set up a new listener if we have a data stream
    if (BluetoothService.dataStream != null) {
      _dataStreamSubscription = BluetoothService.dataStream!.listen(
        (data) {
          if (mounted) {
            setState(() {
              _responseMessages.add("← $data");
            });
            _addToHistory("Received: $data");
          }
        },
        onError: (error) {
          _addToHistory("Data stream error: $error");
        },
        onDone: () {
          if (mounted) {
            setState(() {
              _isConnected = false;
              _connectedDevice = null;
              _connectionMethod = "None";
            });
            _addToHistory("Device disconnected");
          }
        },
      );
    }
  }

  Future<void> _disconnect() async {
    try {
      await BluetoothService.disconnect();
      _dataStreamSubscription?.cancel();
      _dataStreamSubscription = null;

      setState(() {
        _isConnected = false;
        _connectedDevice = null;
        _connectionMethod = "None";
      });
      _addToHistory("Disconnected from device");
    } catch (e) {
      _addToHistory("Error disconnecting: $e");
    }
  }

  Future<void> _sendCommand() async {
    final command = _commandController.text.trim();
    if (command.isEmpty) return;

    try {
      _addToHistory("Sending: $command");
      setState(() {
        _responseMessages.add("→ $command");
      });

      final sent = await BluetoothService.sendCommand(command);
      if (!sent) {
        _addToHistory("❌ Failed to send command");
      }

      if (mounted) {
        setState(() {
          _commandController.clear();
        });
      }
    } catch (e) {
      _addToHistory("❌ Error sending command: $e");
    }
  }

  void _addToHistory(String message) {
    if (mounted) {
      setState(() {
        _commandHistory.add("[${DateTime.now().toIso8601String()}] $message");
      });
    }
  }

  @override
  void dispose() {
    _dataStreamSubscription?.cancel();
    _commandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ESP32 Bluetooth Test'),
        actions: [
          if (_isConnected)
            IconButton(
              icon: const Icon(Icons.bluetooth_disabled),
              onPressed: _disconnect,
              tooltip: 'Disconnect',
            ),
        ],
      ),
      body: Column(
        children: [
          // Status Bar
          Container(
            color: Theme.of(context).colorScheme.primaryContainer,
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _isConnected
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth_disabled,
                      color: _isConnected ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isConnected
                          ? 'Connected to ${_connectedDevice?.name ?? 'Unknown Device'}'
                          : 'Not Connected',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isConnected ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
                if (_connectionMethod != "None")
                  Chip(
                    label: Text('Method: $_connectionMethod'),
                    backgroundColor: Colors.blue.shade100,
                  ),
              ],
            ),
          ),

          Expanded(
            child: _isConnected ? _buildConnectedView() : _buildDevicesList(),
          ),
        ],
      ),
      floatingActionButton:
          _isConnected
              ? FloatingActionButton(
                onPressed: _sendPredefinedCommands,
                child: const Icon(Icons.list),
                tooltip: 'Quick Commands',
              )
              : _isScanning
              ? FloatingActionButton(
                onPressed: _stopScan,
                backgroundColor: Colors.red,
                child: const Icon(Icons.stop),
                tooltip: 'Stop Scanning',
              )
              : FloatingActionButton(
                onPressed: _startScan,
                child: const Icon(Icons.bluetooth_searching),
                tooltip: 'Scan for Devices',
              ),
    );
  }

  Widget _buildDevicesList() {
    return Column(
      children: [
        // Status header
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(
                _isScanning ? Icons.search : Icons.devices,
                size: 24,
                color: _isScanning ? Colors.blue : Colors.grey,
              ),
              const SizedBox(width: 16),
              Text(
                _isScanning ? 'Scanning for devices...' : 'Available devices',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_isScanning)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),

        // Devices list
        Expanded(
          child:
              _devices.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bluetooth_disabled,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isScanning
                              ? 'Searching for devices...'
                              : 'No devices found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (!_isScanning)
                          Padding(
                            padding: const EdgeInsets.only(top: 24.0),
                            child: ElevatedButton.icon(
                              onPressed: _startScan,
                              icon: const Icon(Icons.search),
                              label: const Text('START SCAN'),
                            ),
                          ),
                      ],
                    ),
                  )
                  : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final result = _devices[index];
                      final device = result.device;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: const Icon(
                            Icons.bluetooth,
                            color: Colors.blue,
                          ),
                        ),
                        title: Text(device.name ?? 'Unknown Device'),
                        subtitle: Text(device.address),
                        trailing: Text('RSSI: ${result.rssi} dBm'),
                        onTap: () => _connectToDevice(device),
                      );
                    },
                  ),
        ),

        // Command history
        if (_commandHistory.isNotEmpty)
          Container(
            height: 150,
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(
                top: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Text(
                    'Activity Log',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _commandHistory.length,
                    reverse: true,
                    itemBuilder: (context, index) {
                      final item =
                          _commandHistory[_commandHistory.length - 1 - index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 2.0,
                          horizontal: 8.0,
                        ),
                        child: Text(
                          item,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade800,
                            fontFamily: 'monospace',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildConnectedView() {
    return Column(
      children: [
        // Communication panel
        Expanded(
          child: Column(
            children: [
              // Messages area
              Expanded(
                child: Container(
                  color: Colors.grey.shade50,
                  padding: const EdgeInsets.all(8.0),
                  child:
                      _responseMessages.isEmpty
                          ? Center(
                            child: Text(
                              'No messages yet',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          )
                          : ListView.builder(
                            itemCount: _responseMessages.length,
                            itemBuilder: (context, index) {
                              final message = _responseMessages[index];
                              final bool isIncoming = message.startsWith('←');

                              return Align(
                                alignment:
                                    isIncoming
                                        ? Alignment.centerLeft
                                        : Alignment.centerRight,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 4.0,
                                  ),
                                  padding: const EdgeInsets.all(8.0),
                                  decoration: BoxDecoration(
                                    color:
                                        isIncoming
                                            ? Colors.blue.shade100
                                            : Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  child: Text(message),
                                ),
                              );
                            },
                          ),
                ),
              ),

              // Command input
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commandController,
                        decoration: InputDecoration(
                          hintText: 'Enter command...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24.0),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                        ),
                        onSubmitted: (_) => _sendCommand(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: _sendCommand,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Command history
        Container(
          height: 150,
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(
              top: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Text(
                  'Activity Log',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _commandHistory.length,
                  reverse: true,
                  itemBuilder: (context, index) {
                    final item =
                        _commandHistory[_commandHistory.length - 1 - index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 2.0,
                        horizontal: 8.0,
                      ),
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade800,
                          fontFamily: 'monospace',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _sendPredefinedCommands() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.arrow_upward),
                title: const Text('Forward'),
                onTap: () {
                  Navigator.of(context).pop();
                  _commandController.text = 'Forward';
                  _sendCommand();
                },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_downward),
                title: const Text('Backward'),
                onTap: () {
                  Navigator.of(context).pop();
                  _commandController.text = 'Backward';
                  _sendCommand();
                },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_back),
                title: const Text('Left'),
                onTap: () {
                  Navigator.of(context).pop();
                  _commandController.text = 'Left';
                  _sendCommand();
                },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_forward),
                title: const Text('Right'),
                onTap: () {
                  Navigator.of(context).pop();
                  _commandController.text = 'Right';
                  _sendCommand();
                },
              ),
              ListTile(
                leading: const Icon(Icons.stop, color: Colors.red),
                title: const Text('Stop'),
                onTap: () {
                  Navigator.of(context).pop();
                  _commandController.text = 'Stop';
                  _sendCommand();
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('AT'),
                subtitle: const Text('Test command'),
                onTap: () {
                  Navigator.of(context).pop();
                  _commandController.text = 'AT';
                  _sendCommand();
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('AT+VERSION'),
                subtitle: const Text('Get version info'),
                onTap: () {
                  Navigator.of(context).pop();
                  _commandController.text = 'AT+VERSION';
                  _sendCommand();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
