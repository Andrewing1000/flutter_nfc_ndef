import 'package:flutter/material.dart';
import 'package:flutter_hce/flutter_hce.dart';

/// Ejemplo completo de NFC Intent Launching
///
/// Esta app demuestra cómo:
/// 1. Configurar HCE para responder a comandos NFC
/// 2. Detectar si la app se abrió por un comando NFC
/// 3. Manejar diferentes tipos de eventos NFC
class NfcLaunchingExample extends StatefulWidget {
  @override
  _NfcLaunchingExampleState createState() => _NfcLaunchingExampleState();
}

class _NfcLaunchingExampleState extends State<NfcLaunchingExample> {
  bool _isHceActive = false;
  bool _launchedViaHce = false;
  String _statusMessage = 'Inicializando...';
  Map<String, dynamic>? _nfcIntentData;
  List<String> _eventLog = [];

  @override
  void initState() {
    super.initState();
    _setupHceAndCheckIntent();
    _listenToTransactionEvents();
  }

  Future<void> _setupHceAndCheckIntent() async {
    try {
      // 1. Verificar si la app se abrió por NFC
      await _checkNfcLaunch();

      // 2. Configurar HCE
      await _initializeHce();
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: ${e.toString()}';
      });
    }
  }

  Future<void> _checkNfcLaunch() async {
    try {
      // Verificar si hay datos de NFC intent
      final nfcIntent = await FlutterHce.getNfcIntent();

      if (nfcIntent != null) {
        setState(() {
          _launchedViaHce = true;
          _nfcIntentData = nfcIntent;
          _statusMessage = '🚀 ¡App abierta por NFC!';
        });

        _addToEventLog('App launched via NFC: ${nfcIntent['action']}');

        // Log detailed NFC data
        if (nfcIntent['data'] != null) {
          final nfcData = nfcIntent['data'] as Map<String, dynamic>;
          _addToEventLog('NFC Tag ID: ${nfcData['tagId']}');
          _addToEventLog('Tech List: ${nfcData['techList']}');
        }
      } else {
        setState(() {
          _statusMessage = 'App abierta normalmente (no por NFC)';
        });
      }
    } catch (e) {
      print('Error checking NFC launch: $e');
      setState(() {
        _statusMessage = 'Error verificando lanzamiento NFC: $e';
      });
    }
  }

  Future<void> _initializeHce() async {
    try {
      // Crear AID estándar NDEF
      final aid = FlutterHce.createStandardNdefAid();

      // Crear records NDEF
      final records = [
        FlutterHce.createTextRecord(
          _launchedViaHce
              ? '¡Hola! Esta app se abrió automáticamente por NFC 🎉'
              : 'Hola desde Flutter HCE! Toca para abrir la app.',
        ),
        FlutterHce.createUriRecord('https://flutter.dev'),
      ];

      // Inicializar HCE
      final success = await FlutterHce.init(aid: aid, records: records);

      if (success) {
        setState(() {
          _isHceActive = true;
          if (!_launchedViaHce) {
            _statusMessage =
                'HCE activo. Acerca un lector NFC para abrir la app automáticamente.';
          } else {
            _statusMessage += '\nHCE activo y listo para más interacciones.';
          }
        });
        _addToEventLog('HCE initialized successfully');
      } else {
        setState(() {
          _statusMessage = 'Error: No se pudo inicializar HCE';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error inicializando HCE: $e';
      });
    }
  }

  void _listenToTransactionEvents() {
    FlutterHce.transactionEvents.listen((event) {
      _addToEventLog(
          'Transaction: ${event.type} - Command: ${event.command?.length ?? 0} bytes');

      // Si hay una transacción mientras la app está abierta
      if (event.type == HceEventType.transaction) {
        setState(() {
          _statusMessage = '💳 Transacción NFC detectada!';
        });

        // Opcional: mostrar notificación
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Transacción NFC realizada!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void _addToEventLog(String message) {
    setState(() {
      _eventLog.insert(
          0, '${DateTime.now().toString().substring(11, 19)}: $message');
      if (_eventLog.length > 10) _eventLog.removeLast();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('NFC App Launching'),
        backgroundColor: _launchedViaHce ? Colors.green : Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              elevation: 4,
              color: _launchedViaHce ? Colors.green[50] : Colors.blue[50],
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      _launchedViaHce ? Icons.rocket_launch : Icons.nfc,
                      size: 64,
                      color: _launchedViaHce
                          ? Colors.green
                          : _isHceActive
                              ? Colors.blue
                              : Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      _statusMessage,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_launchedViaHce) ...[
                      SizedBox(height: 12),
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '✅ App Launched via HCE',
                          style: TextStyle(
                            color: Colors.green[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // NFC Intent Data
            if (_nfcIntentData != null) ...[
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📱 Datos del Intent NFC',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text('Action: ${_nfcIntentData!['action']}'),
                      if (_nfcIntentData!['data'] != null) ...[
                        SizedBox(height: 8),
                        Text('Tag Data:',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        ..._formatNfcData(
                            _nfcIntentData!['data'] as Map<String, dynamic>),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
            ],

            // Instructions
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📋 Instrucciones de Uso',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text('1. Asegúrate de que NFC esté habilitado'),
                    Text('2. Acerca un lector NFC al dispositivo'),
                    Text('3. La app se abrirá automáticamente si está cerrada'),
                    Text(
                        '4. Si ya está abierta, verás una notificación de transacción'),
                    SizedBox(height: 8),
                    Text(
                      '💡 Tip: Cierra la app y usa un lector NFC para probar el lanzamiento automático',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Event Log
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📝 Log de Eventos',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Container(
                      height: 200,
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: _eventLog.isEmpty
                          ? Center(child: Text('No hay eventos aún...'))
                          : ListView.builder(
                              itemCount: _eventLog.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: EdgeInsets.symmetric(vertical: 2),
                                  child: Text(
                                    _eventLog[index],
                                    style: TextStyle(
                                      fontSize: 12,
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
            ),

            SizedBox(height: 20),

            // Test buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _testNfcState,
                    child: Text('Verificar Estado NFC'),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _clearLog,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange),
                    child: Text('Limpiar Log'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _formatNfcData(Map<String, dynamic> data) {
    final widgets = <Widget>[];

    data.forEach((key, value) {
      if (value != null) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(left: 16, top: 4),
            child: Text(
              '$key: ${value.toString()}',
              style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
        );
      }
    });

    return widgets;
  }

  Future<void> _testNfcState() async {
    try {
      final nfcState = await FlutterHce.checkNfcState();
      _addToEventLog('NFC State: $nfcState');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Estado NFC: $nfcState'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      _addToEventLog('Error checking NFC state: $e');
    }
  }

  void _clearLog() {
    setState(() {
      _eventLog.clear();
    });
  }
}
