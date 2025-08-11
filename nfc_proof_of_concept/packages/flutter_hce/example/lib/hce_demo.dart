import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_hce/flutter_hce.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter HCE Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HceDemo(),
    );
  }
}

class HceDemo extends StatefulWidget {
  const HceDemo({super.key});

  @override
  State<HceDemo> createState() => _HceDemoState();
}

class _HceDemoState extends State<HceDemo> {
  String _status = 'Inicializando...';
  String _nfcState = 'Desconocido';
  String _lastTransaction = 'Ninguna';
  bool _isListening = false;
  StreamSubscription<HceTransactionEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    _initializeHce();
    _checkNfcState();
    _startListening();
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }

  Future<void> _initializeHce() async {
    try {
      // Verificar estado NFC primero
      final nfcState = await FlutterHce.checkNfcState();
      if (nfcState != 'enabled') {
        setState(() {
          _status = 'NFC no está disponible o habilitado';
        });
        return;
      }

      // Crear AID estándar
      final aid = FlutterHce.createStandardNdefAid();

      // Crear registros NDEF
      final records = [
        FlutterHce.createTextRecord('¡Hola desde Flutter HCE!', language: 'es'),
        FlutterHce.createTextRecord('Hello from Flutter HCE!', language: 'en'),
        FlutterHce.createUriRecord('https://flutter.dev'),
        FlutterHce.createRawRecord(
          type: 'application/json',
          payload: Uint8List.fromList(
              '{"app": "flutter_hce", "version": "1.0.0"}'.codeUnits),
        ),
      ];

      // Inicializar HCE
      final success = await FlutterHce.init(
        aid: aid,
        records: records,
        isWritable: false,
        maxNdefFileSize: 4096, // 4KB
      );

      setState(() {
        _status = success
            ? '✅ HCE Activo - Acerca tu dispositivo a un lector NFC'
            : '❌ Error al inicializar HCE';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
      });
    }
  }

  Future<void> _checkNfcState() async {
    try {
      final state = await FlutterHce.checkNfcState();
      final isInitialized = await FlutterHce.isStateMachineInitialized();

      setState(() {
        _nfcState = state;
        if (state == 'enabled' && isInitialized) {
          _nfcState += ' (HCE Ready)';
        }
      });
    } catch (e) {
      setState(() {
        _nfcState = 'Error: $e';
      });
    }
  }

  void _startListening() {
    if (_isListening) return;

    _subscription = FlutterHce.transactionEvents.listen(
      (event) {
        setState(() {
          switch (event.type) {
            case HceEventType.transaction:
              final command = event.command
                      ?.map((b) => b.toRadixString(16).padLeft(2, '0'))
                      .join(' ') ??
                  'N/A';
              final response = event.response
                      ?.map((b) => b.toRadixString(16).padLeft(2, '0'))
                      .join(' ') ??
                  'N/A';
              _lastTransaction = 'CMD: $command\nRSP: $response';
              break;

            case HceEventType.deactivated:
              _lastTransaction = 'NFC desactivado (razón: ${event.reason})';
              break;
          }
        });

        // Mostrar notificación
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transacción NFC detectada!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      },
      onError: (error) {
        setState(() {
          _lastTransaction = 'Error: $error';
        });
      },
    );

    setState(() {
      _isListening = true;
    });
  }

  void _stopListening() {
    _subscription?.cancel();
    _subscription = null;
    setState(() {
      _isListening = false;
    });
  }

  Future<void> _updateRecords() async {
    try {
      final aid = FlutterHce.createStandardNdefAid();
      final newRecords = [
        FlutterHce.createTextRecord('Actualizado: ${DateTime.now()}'),
        FlutterHce.createUriRecord('https://pub.dev/packages/flutter_hce'),
      ];

      final success = await FlutterHce.init(
        aid: aid,
        records: newRecords,
      );

      setState(() {
        _status =
            success ? '✅ Registros actualizados' : '❌ Error al actualizar';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter HCE Demo'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Estado del sistema
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estado del Sistema',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text('HCE: $_status'),
                    const SizedBox(height: 4),
                    Text('NFC: $_nfcState'),
                    const SizedBox(height: 4),
                    Text('Escuchando: ${_isListening ? "✅" : "❌"}'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Última transacción
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Última Transacción',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _lastTransaction,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Instrucciones
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instrucciones',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Asegúrate de que el NFC esté habilitado\n'
                      '2. Acerca el dispositivo a un lector NFC\n'
                      '3. El lector debería detectar los registros NDEF\n'
                      '4. Las transacciones aparecerán arriba',
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Botones de control
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _checkNfcState,
                    child: const Text('Verificar NFC'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isListening ? _stopListening : _startListening,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isListening ? Colors.red : Colors.green,
                    ),
                    child: Text(_isListening ? 'Parar' : 'Escuchar'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _updateRecords,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                ),
                child: const Text('Actualizar Registros'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
