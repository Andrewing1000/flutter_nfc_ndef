import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_hce/flutter_hce.dart';

void main() => runApp(const MyApp());

// Clave global para el navegador
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
    _listenForNfcIntents(); // Escuchar Intents NFC
  }

  Future<void> _initializeHce() async {
    try {
      // Create standard NDEF AID
      final aid = FlutterHce.createStandardNdefAid();

      // Create NDEF records for HCE
      final records = [
        FlutterHce.createTextRecord('Hello from Flutter HCE!'),
        FlutterHce.createUriRecord('https://flutter.dev'),
      ];

      // Initialize HCE
      final success = await FlutterHce.init(
        aid: aid,
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

  // Escuchar eventos de Intent NFC para navegación automática
  void _listenForNfcIntents() {
    FlutterHce.nfcIntentEvents.listen(
      (intentData) {
        print('🚀 NFC Intent received: $intentData');
        // Navegar a pantalla específica cuando se recibe un Intent NFC
        _navigateToNfcScreen(intentData);
      },
      onError: (error) {
        setState(() {
          _statusText = 'NFC Intent Error: $error';
        });
      },
    );
  }

  // Navegar a la pantalla específica de NFC
  void _navigateToNfcScreen(Map<String, dynamic> intentData) {
    // Solo navegar si la aplicación está en primer plano
    if (navigatorKey.currentContext != null) {
      Navigator.of(navigatorKey.currentContext!).push(
        MaterialPageRoute(
          builder: (context) => NfcActionScreen(intentData: intentData),
        ),
      );
    }
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
      navigatorKey: navigatorKey, // Asignar la clave del navegador
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

// Pantalla específica que se abre cuando se recibe un Intent NFC
class NfcActionScreen extends StatelessWidget {
  final Map<String, dynamic> intentData;

  const NfcActionScreen({super.key, required this.intentData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NFC Intent Detected'),
        backgroundColor: Colors.green,
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
                      '🚀 App Launched by NFC!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Intent Details:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...intentData.entries.map((entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${entry.key}: ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  entry.value.toString(),
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.blue[50],
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Acciones Disponibles:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('• Procesar comando NFC'),
                    Text('• Mostrar información específica'),
                    Text('• Realizar acción automática'),
                    Text('• Continuar con flujo específico'),
                  ],
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
                child: const Text(
                  'Continuar',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
