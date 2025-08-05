import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import './app_layer/ndef_format/ndef_message_serializer.dart';
import './app_layer/ndef_format/ndef_record_fields.dart';
import 'package:nfc_host_card_emulation/nfc_host_card_emulation.dart';

late NfcState _nfcState;

NdefPayload createTextPayload(String text, {String langCode = "en"}) {
  final langBytes = ascii.encode(langCode);
  final textBytes = utf8.encode(text);
  final statusByte = langBytes.length;

  final payloadBytes =
      Uint8List.fromList([statusByte, ...langBytes, ...textBytes]);
  return NdefPayload(payloadBytes);
}

NdefPayload createUriPayload(String uri) {
  final identifierCode = 0x02;
  final uriBytes = ascii.encode(uri.replaceFirst("https://www.", ""));

  final payloadBytes = Uint8List.fromList([identifierCode, ...uriBytes]);
  return NdefPayload(payloadBytes);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _nfcState = await NfcHce.checkDeviceNfcState();
  print('*'*80);
  print('Estado NFC inicial: ${_nfcState.name}');

  if (_nfcState == NfcState.enabled) {
    await NfcHce.init(
      aid: Uint8List.fromList([0xA0, 0x00, 0xDA, 0xDA, 0xDA, 0xDA, 0xDA]),
      permanentApduResponses: true,
      listenOnlyConfiguredPorts: false,
    );
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool messageConfigured = false;
  NfcApduCommand? lastCommand;

  @override
  void initState() {
    super.initState();

    // Escuchar comandos APDU entrantes
    NfcHce.stream.listen((command) {
      setState(() => lastCommand = command);
    });
  }

  Future<void> _configureNdefMessage() async {
    final recordData = [
      (
        type: NdefTypeField.uri,
        payload: createUriPayload("flutter.dev"),
        id: NdefIdField.fromAscii("main-link"),
      ),
      (
        type: NdefTypeField.text,
        payload: createTextPayload("¡Visita Flutter!", langCode: "es"),
        id: null,
      ),
    ];

    final ndefMessage =
        NdefMessageSerializer.fromRecords(recordData: recordData);
    final serializedBytes = ndefMessage.buffer;

    await NfcHce.addApduResponse(0, serializedBytes.toList());
    setState(() => messageConfigured = true);
  }

  Future<void> _removeNdefMessage() async {
    await NfcHce.removeApduResponse(0);
    setState(() => messageConfigured = false);
  }

  @override
  Widget build(BuildContext context) {
    final body = _nfcState == NfcState.enabled
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _nfcState == NfcState.enabled
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _nfcState == NfcState.enabled
                            ? Icons.nfc
                            : Icons.not_interested,
                        color: _nfcState == NfcState.enabled
                            ? Colors.green
                            : Colors.red,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Estado NFC: ${_nfcState.name}',
                        style: TextStyle(
                          fontSize: 20,
                          color: _nfcState == NfcState.enabled
                              ? Colors.green
                              : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 200,
                  width: 300,
                  child: ElevatedButton(
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(
                        messageConfigured
                            ? Colors.redAccent
                            : Colors.greenAccent,
                      ),
                    ),
                    onPressed: () async {
                      if (!messageConfigured) {
                        await _configureNdefMessage();
                      } else {
                        await _removeNdefMessage();
                      }
                    },
                    child: FittedBox(
                      child: Text(
                        messageConfigured
                            ? 'Remover\nMensaje NDEF'
                            : 'Configurar\nMensaje NDEF',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          color:
                              messageConfigured ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
                if (lastCommand != null)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Último comando recibido:\n'
                      'Puerto: ${lastCommand!.port}\n'
                      'Comando: ${lastCommand!.command}\n'
                      'Datos: ${lastCommand!.data}',
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          )
        : Center(
            child: Text(
              'NFC está ${_nfcState.name}',
              style: const TextStyle(fontSize: 20),
              textAlign: TextAlign.center,
            ),
          );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('NDEF Host Card Emulation'),
        ),
        body: body,
      ),
    );
  }
}
