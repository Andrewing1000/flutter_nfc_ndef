import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_hce/flutter_hce.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _statusText = 'Initializing HCE...';
  String _nfcState = 'Unknown';
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _initializeHce();
    _checkNfcState();
    _startListening();
  }

  Future<void> _initializeHce() async {
    try {
      // Create NDEF records for HCE
      final records = [
        FlutterHce.createTextRecord('Hello from Flutter HCE!'),
        FlutterHce.createUriRecord('https://flutter.dev'),
      ];

      // Initialize HCE
      final success = await FlutterHce.init(
        records: records,
        isWritable: false,
        maxNdefFileSize: 2048,
      );

      setState(() {
        _statusText = success
            ? 'HCE Initialized Successfully!'
            : 'HCE Initialization Failed';
      });
    } catch (e) {
      setState(() {
        _statusText = 'HCE Error: $e';
      });
    }
  }

  Future<void> _checkNfcState() async {
    try {
      final state = await FlutterHce.checkNfcState();
      setState(() {
        _nfcState = state;
      });
    } catch (e) {
      setState(() {
        _nfcState = 'Error: $e';
      });
    }
  }

  void _startListening() {
    if (_isListening) return;

    setState(() {
      _isListening = true;
    });

    FlutterHce.transactionEvents.listen(
      (event) {
        setState(() {
          if (event.type == HceEventType.transaction) {
            _statusText =
                'Transaction: CMD=${_bytesToHex(event.command)} RSP=${_bytesToHex(event.response)}';
          } else if (event.type == HceEventType.deactivated) {
            _statusText = 'HCE Deactivated (reason: ${event.reason})';
          }
        });
      },
      onError: (error) {
        setState(() {
          _statusText = 'Event Stream Error: $error';
        });
      },
    );
  }

  String _bytesToHex(Uint8List? bytes) {
    if (bytes == null) return 'null';
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ')
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Flutter HCE Example'),
          backgroundColor: Colors.blue,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NFC State',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _nfcState,
                        style: TextStyle(
                          fontSize: 16,
                          color: _nfcState == 'enabled'
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'HCE Status',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _statusText,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Instructions',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '1. Ensure NFC is enabled\n'
                        '2. Bring another NFC-enabled device close\n'
                        '3. Watch for transaction events above\n'
                        '4. The emulated card contains a text record and URI record',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            _checkNfcState();
            _initializeHce();
          },
          child: const Icon(Icons.refresh),
        ),
      ),
    );
  }
}
