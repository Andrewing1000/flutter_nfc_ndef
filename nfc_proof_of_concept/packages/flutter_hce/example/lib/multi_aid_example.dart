import 'package:flutter/material.dart';
import 'package:flutter_hce/flutter_hce.dart';

/// Ejemplo completo de cómo usar diferentes AIDs en Flutter HCE
class MultiAidExample extends StatefulWidget {
  @override
  _MultiAidExampleState createState() => _MultiAidExampleState();
}

class _MultiAidExampleState extends State<MultiAidExample> {
  bool _isHceActive = false;
  String _currentAid = 'Ninguno';
  String _statusMessage = 'Selecciona un AID para empezar';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Flutter HCE - Múltiples AIDs'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status card
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      _isHceActive ? Icons.nfc : Icons.nfc_outlined,
                      size: 64,
                      color: _isHceActive ? Colors.green : Colors.grey,
                    ),
                    SizedBox(height: 8),
                    Text(
                      _statusMessage,
                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    if (_isHceActive) ...[
                      SizedBox(height: 8),
                      Text(
                        'AID Activo: $_currentAid',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            // Configuración XML
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚠️ Configuración XML Requerida',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Para usar estos AIDs, debes declararlos en:\n'
                      'android/app/src/main/res/xml/hce_aid_list.xml',
                      style: TextStyle(fontSize: 14),
                    ),
                    SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => _showXmlConfiguration(context),
                      child: Text('Ver Configuración XML'),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            // Botones de AIDs
            Text(
              'Selecciona un AID:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),

            _buildAidButton(
              'NDEF Estándar',
              'D2760000850101',
              () => _initWithAid(
                  AidUtils.createStandardNdefAid(), 'NDEF Estándar'),
            ),

            _buildAidButton(
              'Personalizado 1',
              'F0394148148100',
              () => _initWithAid(
                AidUtils.createCustomAid(pix: [0x81, 0x00]),
                'Personalizado 1',
              ),
            ),

            _buildAidButton(
              'Personalizado 2',
              'F0394148148200',
              () => _initWithAid(
                AidUtils.createCustomAid(pix: [0x82, 0x00]),
                'Personalizado 2',
              ),
            ),

            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _showAidUtils,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: Text('Utilidades de AID'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAidButton(String name, String hexAid, VoidCallback onPressed) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: ElevatedButton(
        onPressed: onPressed,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(name, style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              'AID: $hexAid',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _initWithAid(aid, String aidName) async {
    try {
      setState(() {
        _isHceActive = false;
        _statusMessage = 'Inicializando HCE...';
      });

      // Crear records NDEF de ejemplo
      final records = [
        FlutterHce.createTextRecord('Hola desde $aidName!'),
        FlutterHce.createUriRecord('https://flutter.dev'),
      ];

      // Inicializar HCE
      final success = await FlutterHce.init(aid: aid, records: records);

      if (success) {
        setState(() {
          _isHceActive = true;
          _currentAid = aidName;
          _statusMessage = 'HCE activo. Acerca un lector NFC.';
        });
      } else {
        setState(() {
          _statusMessage = 'Error: No se pudo inicializar HCE';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: ${e.toString()}';
      });

      // Mostrar dialog con el error
      _showErrorDialog(e.toString());
    }
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error de HCE'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('No se pudo inicializar HCE:'),
            SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            SizedBox(height: 16),
            Text('Posibles causas:'),
            Text('• AID no declarado en hce_aid_list.xml'),
            Text('• NFC deshabilitado'),
            Text('• Dispositivo no soporta HCE'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showXmlConfiguration(context);
            },
            child: Text('Ver Configuración'),
          ),
        ],
      ),
    );
  }

  void _showXmlConfiguration(BuildContext context) {
    final xmlConfig = '''<?xml version="1.0" encoding="utf-8"?>
<host-apdu-service xmlns:android="http://schemas.android.com/apk/res/android"
    android:description="@string/hce_service_description"
    android:requireDeviceUnlock="false">
    
    <aid-group android:description="@string/hce_aid_group"
        android:category="other">
        
        <!-- NDEF Estándar -->
        <aid-filter android:name="D2760000850101" />
        
        <!-- Personalizado 1 -->
        <aid-filter android:name="F0394148148100" />
        
        <!-- Personalizado 2 -->
        <aid-filter android:name="F0394148148200" />
        
    </aid-group>
</host-apdu-service>''';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Configuración XML Necesaria'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Crear archivo:'),
              Text(
                'android/app/src/main/res/xml/hce_aid_list.xml',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('Contenido:'),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(8),
                color: Colors.grey[100],
                child: Text(
                  xmlConfig,
                  style: TextStyle(fontFamily: 'monospace', fontSize: 10),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showAidUtils() {
    // Imprimir ejemplos en consola
    print('\n=== AID Utils Examples ===');
    AidUtils.printXmlExamples();

    // Mostrar en UI
    final examples = AidUtils.commonAids;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Utilidades de AID'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AIDs Disponibles:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              ...examples.entries.map((entry) {
                final hexString = AidUtils.aidToHexString(entry.value);
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.key,
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('HEX: $hexString',
                          style: TextStyle(fontFamily: 'monospace')),
                      Text('Bytes: ${entry.value.length}',
                          style: TextStyle(fontSize: 12)),
                    ],
                  ),
                );
              }),
              SizedBox(height: 16),
              Text('Crear AID personalizado:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text('final aid = AidUtils.createCustomAid(pix: [0x01, 0x02]);'),
              SizedBox(height: 8),
              Text('Para XML:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('AidUtils.aidToHexString(aid)'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
