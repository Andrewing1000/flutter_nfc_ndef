import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Represents a single pulse animation in the NFC bar
class NfcPulse {
  final Offset origin;
  final double baseAlpha;
  final int startMs;
  final int durationMs;

  const NfcPulse({
    required this.origin,
    required this.baseAlpha,
    required this.startMs,
    required this.durationMs,
  });
}

/// Custom painter for rendering NFC pulse animations
class NfcPulsePainter extends CustomPainter {
  final List<NfcPulse> pulses;
  final int currentTimeMs;
  final Color color;

  const NfcPulsePainter({
    required this.pulses,
    required this.currentTimeMs,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || pulses.isEmpty) return;

    for (final pulse in pulses) {
      final t =
          ((currentTimeMs - pulse.startMs) / pulse.durationMs).clamp(0.0, 1.0);
      _drawPulse(canvas, size, pulse.origin, t, pulse.baseAlpha);
    }
  }

  void _drawPulse(
      Canvas canvas, Size size, Offset origin, double t, double baseAlpha) {
    if (t <= 0 || t >= 1) return;

    final farR = _farthestCornerDistance(size, origin);
    final r = _easeOut(t) * farR;

    final opacity = (t < 0.75)
        ? _easeIn((t / 0.4).clamp(0.0, 1.0)) * baseAlpha
        : (1.0 - _easeOut(((t - 0.75) / 0.25).clamp(0.0, 1.0))) * baseAlpha;

    if (opacity <= 0) return;

    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(origin, r, paint);
  }

  double _easeIn(double x) => Curves.easeIn.transform(x.clamp(0.0, 1.0));

  double _easeOut(double x) => Curves.easeOut.transform(x.clamp(0.0, 1.0));

  double _farthestCornerDistance(Size size, Offset origin) {
    final corners = [
      const Offset(0, 0),
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ];

    return corners.map((corner) => (origin - corner).distance).reduce(math.max);
  }

  @override
  bool shouldRepaint(covariant NfcPulsePainter oldDelegate) {
    return pulses != oldDelegate.pulses ||
        currentTimeMs != oldDelegate.currentTimeMs ||
        color != oldDelegate.color;
  }
}
