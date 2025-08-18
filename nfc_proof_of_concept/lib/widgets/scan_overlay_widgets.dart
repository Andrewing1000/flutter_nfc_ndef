// lib/widgets/scan_overlay_widgets.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nfc_proof_of_concept/nfc_active_bar.dart';
import 'package:nfc_proof_of_concept/services/nfc_service.dart';

/// Overlay mask that creates the scanning window with rounded corners
class ScanMaskOverlay extends StatelessWidget {
  final double holeSize;
  final double cornerRadius;

  const ScanMaskOverlay({
    super.key,
    required this.holeSize,
    required this.cornerRadius,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: ClipPath(
        clipper: QrScannerOverlayClipper(
          overlayHoleSize: holeSize,
          cornerRadius: cornerRadius,
        ),
        child: Container(color: Colors.black.withOpacity(0.6)),
      ),
    );
  }
}

/// Custom clipper that creates the scanning window cutout
class QrScannerOverlayClipper extends CustomClipper<Path> {
  final double overlayHoleSize;
  final double cornerRadius;

  QrScannerOverlayClipper({
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
  bool shouldReclip(covariant QrScannerOverlayClipper oldClipper) {
    return oldClipper.overlayHoleSize != overlayHoleSize ||
        oldClipper.cornerRadius != cornerRadius;
  }
}

/// Scanning window border frame
class ScanFrameBorder extends StatelessWidget {
  final double size;
  final double cornerRadius;
  final Color color;
  final double strokeWidth;

  const ScanFrameBorder({
    super.key,
    required this.size,
    required this.cornerRadius,
    this.color = Colors.white,
    this.strokeWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: IgnorePointer(
        ignoring: true,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            border: Border.all(
              color: color.withOpacity(0.85),
              width: strokeWidth,
            ),
            borderRadius: BorderRadius.circular(cornerRadius),
          ),
        ),
      ),
    );
  }
}

/// UI hints and NFC bar positioned below the scanning window
class ScanUiHints extends StatelessWidget {
  final double cutoutSize;
  final Uint8List? aid;
  final bool isLoadingAid;
  final void Function()? onDiscovered;
  final void Function(String error)? onReadError;
  final void Function(Map<String, dynamic> data)? onRead;

  const ScanUiHints({
    super.key,
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
        // Scanning instruction text
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
        // NFC Bar or loading/error state
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(bottom: padding.bottom + 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: _buildNfcSection(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNfcSection() {
    if (aid != null) {
      return NfcActiveBar(
        whiteText: true,
        mode: NfcBarMode.readOnly,
        onDiscovered: onDiscovered,
        onReadError: onReadError,
        onRead: onRead,
        aid: aid!,
      );
    }

    return Container(
      height: 38,
      alignment: Alignment.center,
      child: isLoadingAid
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
    );
  }
}
