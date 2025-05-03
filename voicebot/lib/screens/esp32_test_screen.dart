import 'dart:async';
import 'package:flutter/material.dart';
import '../services/esp32_wifi_service.dart';
import '../widgets/custom_button.dart';

class ESP32TestScreen extends StatefulWidget {
  const ESP32TestScreen({super.key});

  @override
  State<ESP32TestScreen> createState() => _ESP32TestScreenState();
}

class _ESP32TestScreenState extends State<ESP32TestScreen> {
  final ESP32WiFiService _esp32Service = ESP32WiFiService();
  final List<String> _receivedMessages = [];
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _dataSubscription;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _setupDataListener();
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _setupDataListener() {
    _dataSubscription = _esp32Service.dataStream.listen((message) {
      setState(() {
        _receivedMessages.add('← Received: $message');
        _scrollToBottom();
      });
    });
  }

  void _scrollToBottom() {
    // Wait for the list to update, then scroll
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendCommand(String command) async {
    if (!_esp32Service.isConnected) {
      _showErrorSnackBar('Not connected to ESP32');
      return;
    }

    setState(() {
      _isSending = true;
      _receivedMessages.add('→ Sending: $command');
    });

    try {
      final success = await _esp32Service.sendCommand(command);
      if (mounted) {
        if (!success) {
          _showErrorSnackBar('Failed to send command');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
          _scrollToBottom();
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _disconnect() {
    _esp32Service.disconnect();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('ESP32 Test'),
            Text(
              _esp32Service.espIpAddress,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _disconnect,
            tooltip: 'Disconnect',
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection status
          Container(
            color: _esp32Service.isConnected ? Colors.green : Colors.red,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            width: double.infinity,
            child: Text(
              _esp32Service.isConnected
                  ? 'Connected to ${_esp32Service.espIpAddress}'
                  : 'Disconnected',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),

          // Message log
          Expanded(
            child:
                _receivedMessages.isEmpty
                    ? const Center(
                      child: Text(
                        'No messages yet.\nUse the buttons below to send commands.',
                        textAlign: TextAlign.center,
                      ),
                    )
                    : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _receivedMessages.length,
                      itemBuilder: (context, index) {
                        final message = _receivedMessages[index];
                        final isSent = message.startsWith('→');

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSent ? Colors.blue[50] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  isSent
                                      ? Colors.blue[200]!
                                      : Colors.grey[300]!,
                            ),
                          ),
                          child: Text(message),
                        );
                      },
                    ),
          ),

          // Command buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: CustomButton(
                        text: 'Forward',
                        onPressed:
                            _isSending ? null : () => _sendCommand('Forward'),
                        icon: Icons.arrow_upward,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CustomButton(
                        text: 'Backward',
                        onPressed:
                            _isSending ? null : () => _sendCommand('Backward'),
                        icon: Icons.arrow_downward,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: CustomButton(
                        text: 'Left',
                        onPressed:
                            _isSending ? null : () => _sendCommand('Left'),
                        icon: Icons.arrow_back,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CustomButton(
                        text: 'Right',
                        onPressed:
                            _isSending ? null : () => _sendCommand('Right'),
                        icon: Icons.arrow_forward,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                CustomButton(
                  text: 'STOP',
                  onPressed: _isSending ? null : () => _sendCommand('Stop'),
                  icon: Icons.stop_circle,
                  backgroundColor: Colors.red,
                  textColor: Colors.white,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: CustomButton(
                        text: 'Status',
                        onPressed:
                            _isSending ? null : () => _sendCommand('Status'),
                        icon: Icons.info_outline,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CustomButton(
                        text: 'Clear',
                        onPressed: () {
                          setState(() {
                            _receivedMessages.clear();
                          });
                        },
                        icon: Icons.clear_all,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
