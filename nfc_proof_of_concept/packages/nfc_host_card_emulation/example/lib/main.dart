import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nfc_host_card_emulation/nfc_host_card_emulation.dart';
import 'package:nfc_host_card_emulation/nfc_host_card_emulation_platform_interface.dart';

late NfcState _nfcState;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _nfcState = await NfcHce.checkDeviceNfcState();

  if (_nfcState == NfcState.enabled) {
    await NfcHce.init(
      // Standard NDEF application AID (D2760000850101)
      aid: Uint8List.fromList([0xD2, 0x76, 0x00, 0x00, 0x85, 0x01, 0x01]),
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
  bool hasNdefContent = false;
  static const standardNdefFileId = 0xE104;

  String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
  }

  // Sample NDEF record content
  final records = [
    NdefRecordData(
      type: 'text/plain',
      payload: Uint8List.fromList([0x48, 0x65, 0x6C, 0x6C, 0x6F]), // "Hello"
    ),
  ];

  // Track the latest HCE transaction
  HceTransaction? latestTransaction;

  @override
  void initState() {
    super.initState();

    NfcHce.stream.listen((transaction) {
      setState(() => latestTransaction = transaction);
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = _nfcState == NfcState.enabled
        ? Center(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text(
                  'NFC State is ${_nfcState.name}',
                  style: const TextStyle(fontSize: 20),
                ),
                SizedBox(
                  height: 200,
                  width: 300,
                  child: ElevatedButton(
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all(
                        hasNdefContent ? Colors.redAccent : Colors.greenAccent,
                      ),
                    ),
                    onPressed: () async {
                      try {
                        if (!hasNdefContent) {
                          // Add or update NDEF file
                          await NfcHce.addOrUpdateNdefFile(
                            fileId: standardNdefFileId,
                            records: records,
                            maxFileSize: 2048,
                            isWritable: true,
                          );
                        } else {
                          // Remove NDEF file
                          await NfcHce.deleteNdefFile(
                              fileId: standardNdefFileId);
                        }
                        setState(() => hasNdefContent = !hasNdefContent);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    },
                    child: FittedBox(
                      child: Text(
                        hasNdefContent
                            ? 'Remove NDEF Content'
                            : 'Add NDEF Content',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          color: hasNdefContent ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
                if (latestTransaction != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Latest HCE Transaction:\n'
                      'Command: ${latestTransaction!.command}\n'
                      'Response: ${latestTransaction!.response}',
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          )
        : Center(
            child: Text(
              'Oh no...\nNFC is ${_nfcState.name}',
              style: const TextStyle(fontSize: 20),
              textAlign: TextAlign.center,
            ),
          );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('NFC HCE Example'),
        ),
        body: body,
      ),
    );
  }
}
