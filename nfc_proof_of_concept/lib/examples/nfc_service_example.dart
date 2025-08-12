import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/nfc_service.dart';
import '../nfc_active_bar.dart';

class NfcServiceExample extends StatelessWidget {
  static final Uint8List ndefAppAid =
      Uint8List.fromList([0xD2, 0x76, 0x00, 0x00, 0x85, 0x01, 0x01]);
  static final Uint8List customAid =
      Uint8List.fromList([0xA0, 0x00, 0x00, 0x04, 0x76, 0x20, 0x10]);

  const NfcServiceExample({super.key});

  @override
  Widget build(BuildContext context) {
    final sampleJsonData = json.encode({
      'tipo': 'pago',
      'monto': 25.50,
      'moneda': 'USD',
      'comerciante': 'Tienda Demo',
      'timestamp': DateTime.now().toIso8601String(),
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('NFC Service Examples'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'NFC HCE Mode (Broadcast)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // HCE Mode with NDEF AID
            NfcActiveBar(
              mode: NfcBarMode.broadcastOnly,
              aid: ndefAppAid,
              broadcastData: sampleJsonData,
              clearText: false,
            ),

            const SizedBox(height: 16),

            Text(
              'Broadcasting JSON:\n${_formatJson(sampleJsonData)}',
              style: const TextStyle(fontSize: 12, fontFamily: 'SpaceMono'),
            ),

            const SizedBox(height: 32),

            const Text(
              'NFC Reader Mode',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Reader Mode
            const NfcActiveBar(
              mode: NfcBarMode.readOnly,
              clearText: false,
            ),

            const SizedBox(height: 16),

            const Text(
              'Ready to read NFC tags and process APDU commands',
              style: TextStyle(fontSize: 12, fontFamily: 'SpaceMono'),
            ),

            const SizedBox(height: 32),

            const Text(
              'Custom HCE with Custom AID',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Custom HCE
            NfcActiveBar(
              mode: NfcBarMode.broadcastOnly,
              aid: customAid,
              broadcastData: json.encode({
                'app': 'CustomApp',
                'version': '1.0.0',
                'data': 'Custom payload'
              }),
              clearText: false,
              toggle: true,
            ),

            const SizedBox(height: 16),

            Text(
              'Custom AID: ${_formatAid(customAid)}',
              style: const TextStyle(fontSize: 12, fontFamily: 'SpaceMono'),
            ),

            const Spacer(),

            const Card(
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: Text(
                  'Notas:\n'
                  '• Los pulses se activan automáticamente en transacciones NFC\n'
                  '• En modo HCE, los datos JSON se serializan como NDEF\n'
                  '• El servicio notifica cambios de estado a la UI\n'
                  '• Tap para reconectar en caso de error',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatJson(String jsonString) {
    try {
      final parsed = json.decode(jsonString);
      return json
          .encode(parsed)
          .replaceAll(',', ',\n')
          .replaceAll('{', '{\n  ')
          .replaceAll('}', '\n}');
    } catch (e) {
      return jsonString;
    }
  }

  String _formatAid(Uint8List aid) {
    return aid
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
  }
}
