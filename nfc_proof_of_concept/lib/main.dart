import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:nfc_host_card_emulation/nfc_host_card_emulation.dart';
import './app_layer/ndef_format/ndef_message_serializer.dart';
import './app_layer/ndef_format/ndef_record_fields.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Query initial NFC state
  final NfcState initialState = await NfcHce.checkDeviceNfcState();

  // 2. If supported, initialize HCE with your AID
  if (initialState == NfcState.enabled) {
    await NfcHce.init(
      aid: Uint8List.fromList([0xA0, 0x00, 0xDA, 0xDA, 0xDA, 0xDA, 0xDA]),
      permanentApduResponses: true,
      listenOnlyConfiguredPorts: false,
    );
  }

  runApp(BankingAppUI(initialNfcState: initialState));
}

class BankingAppUI extends StatelessWidget {
  final NfcState initialNfcState;
  const BankingAppUI({required this.initialNfcState, super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cobro Digital',
      theme: ThemeData(
        fontFamily: 'IBMPlexSans',
        scaffoldBackgroundColor: const Color(0xFFF9F9F9),
      ),
      home: CoDiScreen(initialNfcState: initialNfcState),
    );
  }
}

class CoDiScreen extends StatefulWidget {
  final NfcState initialNfcState;
  const CoDiScreen({required this.initialNfcState, super.key});

  @override
  State<StatefulWidget> createState() => _QRState();
}

class _QRState extends State<CoDiScreen> {
  late TextEditingController control;
  late NfcState _nfcState;
  bool _messageConfigured = false;

  @override
  void initState() {
    super.initState();
    control = TextEditingController(text: '0.0');
    _nfcState = widget.initialNfcState;
    _configureNdef(); // push the same URL into HCE
  }

  Future<void> _configureNdef() async {
    if (_nfcState == NfcState.enabled) {
      final uriPayload =
          createUriPayload('https://codi.org.mx/charge/123456789');
      final record = (type: NdefTypeField.uri, payload: uriPayload, id: null);
      final ndefMessage =
          NdefMessageSerializer.fromRecords(recordData: [record]);
      await NfcHce.addApduResponse(0, ndefMessage.buffer.toList());
      setState(() => _messageConfigured = true);
    }
  }

  static NdefPayload createUriPayload(String uri) {
    final identifierCode = 0x02;
    final uriBytes = ascii.encode(uri.replaceFirst('https://www.', ''));
    return NdefPayload(Uint8List.fromList([identifierCode, ...uriBytes]));
  }

  @override
  void dispose() {
    control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color santanderRed = Color(0xFFEC0000);
    const Color successGreenBg = Color.fromARGB(255, 248, 246, 216);
    const Color successGreenText = Color.fromARGB(255, 125, 110, 46);
    const Color inactiveGreyBg = Color(0xFFEEEEEE);
    const Color inactiveGreyText = Color(0xFF757575);

    // determine if NFC is “ready” (enabled + payload registered)
    final bool nfcReady = _nfcState == NfcState.enabled && _messageConfigured;
    final Color nfcBg = nfcReady
        ? const Color(0xFF00E5FF) // vibrant blu-cyan
        : inactiveGreyBg;
    final Color nfcTextColor = nfcReady ? Colors.white : inactiveGreyText;
    final IconData nfcIcon = Icons.nfc;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: santanderRed,
        foregroundColor: Colors.white,
        elevation: 2,
        leading: const Icon(Icons.qr_code),
        titleSpacing: 0,
        title: const Text("Pago QR"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // QR CODE
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.13),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: 'https://codi.org.mx/charge/123456789',
                  version: QrVersions.auto,
                  size: MediaQuery.of(context).size.width * 0.6,
                ),
              ),

              const Spacer(flex: 1),

              // NFC status with animated background
              AnimatedContainer(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(
                    vertical: 10.0, horizontal: 20.0),
                decoration: BoxDecoration(
                  color: nfcBg,
                  borderRadius: BorderRadius.circular(3.0),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(nfcIcon, color: nfcTextColor),
                    const SizedBox(width: 12),
                    Text(
                      nfcReady ? 'NFC activo' : 'NFC inactivo',
                      style: TextStyle(
                        fontFamily: 'SpaceMono',
                        color: nfcTextColor,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Amount input
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: control,
                      style: const TextStyle(
                        fontFamily: 'IBMPlexSans',
                        fontWeight: FontWeight.w200,
                        fontSize: 52,
                        color: Colors.black87,
                      ),
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
                    child: Text(
                      'BOB',
                      style: TextStyle(
                        fontFamily: 'SpaceMono',
                        fontSize: 20,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Success message
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                decoration: BoxDecoration(
                  color: successGreenBg,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: successGreenText),
                ),
                child: const Text(
                  'Código QR generado exitosamente',
                  style: TextStyle(
                    fontFamily: 'SpaceMono',
                    color: successGreenText,
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.4,
                  ),
                ),
              ),

              const Spacer(flex: 3),

              const Padding(
                padding: EdgeInsets.only(bottom: 20.0),
                child: Icon(Icons.more_horiz, color: Colors.grey, size: 40),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
