// lib/scan_qr_page.dart

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:nfc_proof_of_concept/nfc_active_bar.dart';

class ScanQrPage extends StatefulWidget {
  const ScanQrPage({super.key});

  @override
  State<ScanQrPage> createState() => _ScanQrPageState();
}

class _ScanQrPageState extends State<ScanQrPage> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;

  static const double _cornerRadius = 16;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
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
          _UiHintsBelowCutout(cutoutSize: cutoutSize),
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

  const _UiHintsBelowCutout({required this.cutoutSize});

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
              constraints: const BoxConstraints(maxWidth: 320), // pick your cap
              child: const NfcActiveBar(toggle: true),
            ),
          ),
        ),
      ],
    );
  }
}
