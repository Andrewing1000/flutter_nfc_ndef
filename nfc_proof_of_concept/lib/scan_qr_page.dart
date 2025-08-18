// lib/scan_qr_page.dart

import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:nfc_proof_of_concept/nfc_aid_helper.dart';
import 'package:nfc_proof_of_concept/widgets/scan_overlay_widgets.dart';
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
      // For testing purposes, always navigate to confirmation with complete data
      debugPrint("NFC data received: $ndefData");
      _navigateToDataDisplay(ndefData);
    } catch (e) {
      debugPrint("Error processing NDEF data: $e");
      appLayoutKey.currentState?.showNotification(
        text: "Error al procesar datos NFC",
        icon: Icons.error,
      );
    }
  }

  void _navigateToDataDisplay(Map<String, dynamic> ndefData) {
    appLayoutKey.currentState?.showNotification(
      text: "Datos NFC recibidos correctamente",
      icon: Icons.check,
    );

    debugPrint("Complete NDEF data: $ndefData");
    appLayoutKey.currentState?.navigateToDataDisplay(ndefData);
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
          ScanMaskOverlay(
            holeSize: cutoutSize,
            cornerRadius: _cornerRadius,
          ),
          ScanFrameBorder(
            size: cutoutSize,
            cornerRadius: _cornerRadius,
          ),
          ScanUiHints(
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
