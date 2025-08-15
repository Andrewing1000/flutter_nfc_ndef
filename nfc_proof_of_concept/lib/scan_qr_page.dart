// lib/scan_qr_page.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:nfc_proof_of_concept/nfc_active_bar.dart';
import 'package:nfc_proof_of_concept/services/nfc_service.dart';
import 'package:nfc_proof_of_concept/nfc_aid_helper.dart';
import './main.dart';

class ScanQrPage extends StatefulWidget {
  const ScanQrPage({super.key});

  @override
  State<ScanQrPage> createState() => _ScanQrPageState();
}

class _ScanQrPageState extends State<ScanQrPage> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  Uint8List? aid;
  bool isLoadingAid = true;

  static const double _cornerRadius = 16;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadAid();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        debugPrint("No cameras found");
        return;
      }
      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() => _isCameraInitialized = true);
    } on CameraException catch (e) {
      debugPrint("Camera Error: ${e.code}\nError Message: ${e.description}");
    }
  }

  Future<void> _loadAid() async {
    try {
      final retrievedAid = await NfcAidHelper.getAidFromXml();
      if (mounted) {
        setState(() {
          aid = retrievedAid;
          isLoadingAid = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingAid = false;
        });
        appLayoutKey.currentState?.showNotification(
            text: "Error al cargar AID: $e", icon: Icons.error);
      }
    }
  }

  void _onError(String error) {
    appLayoutKey.currentState?.showNotification(
      text: "Error al leer NFC: $error",
      icon: Icons.error,
    );
  }

  void _onDiscovered() {
    appLayoutKey.currentState?.showNotification(
      text: "Dispositivo NFC detectado",
      icon: Icons.nfc,
    );
  }

  void _onMessageRead(Map<String, dynamic> ndefData) {
    try {
      // The new NdefReaderService returns merged JSON data directly
      // No need to extract from nested records structure
      if (_isPaymentData(ndefData)) {
        final paymentData = _formatPaymentData(ndefData);
        _navigateToPaymentConfirmation(paymentData);
        return;
      }

      // No valid payment data found
      appLayoutKey.currentState?.showNotification(
        text: "No se encontraron datos de pago válidos",
        icon: Icons.error,
      );
    } catch (e) {
      debugPrint("Error processing NDEF data: $e");
      appLayoutKey.currentState?.showNotification(
        text: "Error al procesar datos NFC",
        icon: Icons.error,
      );
    }
  }

  bool _isPaymentData(Map<String, dynamic> data) {
    // Check for common payment fields
    const paymentFields = [
      'amount',
      'currency',
      'recipient',
      'payment',
      'transaction',
      'transfer',
      'money'
    ];

    return paymentFields.any((field) =>
        data.keys.any((key) => key.toString().toLowerCase().contains(field)));
  }

  bool _isSimplePaymentString(String data) {
    // Check if string looks like payment data (contains currency symbols or payment keywords)
    final lowerData = data.toLowerCase();
    const indicators = [
      '\$',
      '€',
      '£',
      '¥',
      'usd',
      'eur',
      'pay',
      'amount',
      'transfer'
    ];

    return indicators.any((indicator) => lowerData.contains(indicator));
  }

  String _formatPaymentData(Map<String, dynamic> paymentData) {
    // Create a clean, readable format for payment confirmation
    final buffer = StringBuffer();

    // Add amount if present
    final amount =
        paymentData['amount'] ?? paymentData['value'] ?? paymentData['money'];
    final currency = paymentData['currency'] ?? paymentData['curr'] ?? '\$';

    if (amount != null) {
      buffer.write('Monto: $currency$amount\n');
    }

    // Add recipient if present
    final recipient =
        paymentData['recipient'] ?? paymentData['to'] ?? paymentData['payee'];
    if (recipient != null) {
      buffer.write('Para: $recipient\n');
    }

    // Add concept/description if present
    final concept = paymentData['concept'] ??
        paymentData['description'] ??
        paymentData['memo'];
    if (concept != null) {
      buffer.write('Concepto: $concept\n');
    }

    // If no structured data, return JSON string
    if (buffer.isEmpty) {
      return json.encode(paymentData);
    }

    return buffer.toString().trim();
  }

  void _navigateToPaymentConfirmation(String paymentData) {
    appLayoutKey.currentState?.showNotification(
      text: "Datos de pago recibidos correctamente",
      icon: Icons.check,
    );

    debugPrint("Payment data extracted: $paymentData");
    appLayoutKey.currentState?.navigateToPaymentConfirmation(paymentData);
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cutoutSize = size.width * 0.7;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        alignment: const Alignment(0, 0.5),
        clipBehavior: Clip.none,
        children: [
          if (_isCameraInitialized)
            _buildCameraPreview()
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          _ScanMaskOverlay(
            holeSize: cutoutSize,
            cornerRadius: _cornerRadius,
          ),
          Align(
            alignment: Alignment.center,
            child: IgnorePointer(
              ignoring: true,
              child: Container(
                width: cutoutSize,
                height: cutoutSize,
                decoration: BoxDecoration(
                  border: Border.all(
                      color: Colors.white.withOpacity(0.85), width: 2),
                  borderRadius: BorderRadius.circular(_cornerRadius),
                ),
              ),
            ),
          ),
          _UiHintsBelowCutout(
            cutoutSize: cutoutSize,
            aid: aid,
            isLoadingAid: isLoadingAid,
            onDiscovered: _onDiscovered,
            onReadError: _onError,
            onRead: _onMessageRead,
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const SizedBox.shrink();
    }
    final screen = MediaQuery.of(context).size;

    var scale = screen.aspectRatio * _cameraController!.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;

    return Transform.scale(
      scale: scale,
      child: Center(child: CameraPreview(_cameraController!)),
    );
  }
}

class _ScanMaskOverlay extends StatelessWidget {
  final double holeSize;
  final double cornerRadius;

  const _ScanMaskOverlay({
    required this.holeSize,
    required this.cornerRadius,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: ClipPath(
        clipper: _QrScannerOverlayClipper(
          overlayHoleSize: holeSize,
          cornerRadius: cornerRadius,
        ),
        child: Container(color: Colors.black.withOpacity(0.6)),
      ),
    );
  }
}

class _QrScannerOverlayClipper extends CustomClipper<Path> {
  final double overlayHoleSize;
  final double cornerRadius;

  _QrScannerOverlayClipper({
    required this.overlayHoleSize,
    required this.cornerRadius,
  });

  @override
  Path getClip(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outer = Path()..addRect(Offset.zero & size);
    final innerRRect = RRect.fromRectAndCorners(
      Rect.fromCenter(
          center: center, width: overlayHoleSize, height: overlayHoleSize),
      topLeft: Radius.circular(cornerRadius),
      topRight: Radius.circular(cornerRadius),
      bottomLeft: Radius.circular(cornerRadius),
      bottomRight: Radius.circular(cornerRadius),
    );
    final inner = Path()..addRRect(innerRRect);

    return Path.combine(PathOperation.difference, outer, inner);
  }

  @override
  bool shouldReclip(covariant _QrScannerOverlayClipper oldClipper) {
    return oldClipper.overlayHoleSize != overlayHoleSize ||
        oldClipper.cornerRadius != cornerRadius;
  }
}

class _UiHintsBelowCutout extends StatelessWidget {
  final double cutoutSize;
  final Uint8List? aid;
  final bool isLoadingAid;
  final void Function()? onDiscovered;
  final void Function(String error)? onReadError;
  final void Function(Map<String, dynamic> data)? onRead;

  const _UiHintsBelowCutout({
    required this.cutoutSize,
    required this.aid,
    required this.isLoadingAid,
    this.onDiscovered,
    this.onReadError,
    this.onRead,
  });

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: (screen.height / 2) + (cutoutSize / 2) - 40,
          child: const Center(
            child: Text(
              'Apunta al código QR',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'SpaceMono',
                fontSize: 16,
                shadows: [Shadow(blurRadius: 10, color: Colors.black54)],
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(bottom: padding.bottom + 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: aid != null
                  ? NfcActiveBar(
                      whiteText: true,
                      mode: NfcBarMode.readOnly,
                      onDiscovered: onDiscovered,
                      onReadError: onReadError,
                      onRead: onRead,
                      aid: aid!,
                    )
                  : Container(
                      height: 38,
                      alignment: Alignment.center,
                      child: isLoadingAid
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Error cargando AID',
                              style: TextStyle(
                                color: Colors.red,
                                fontFamily: 'SpaceMono',
                                fontSize: 14,
                              ),
                            ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
