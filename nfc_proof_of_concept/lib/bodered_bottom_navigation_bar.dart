import 'package:flutter/material.dart';

class BorderedBottomNav extends StatelessWidget {
  final Widget child;
  final int itemCount;
  final Color dividerColor;
  final double thickness;
  final double topInset;
  final double bottomInset;
  final bool drawTopBorder;

  const BorderedBottomNav({
    super.key,
    required this.child,
    required this.itemCount,
    this.dividerColor = Colors.transparent, 
    this.thickness = 1.0,
    this.topInset = 10.0,
    this.bottomInset = 10.0,
    this.drawTopBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _NavDividersPainter(
                itemCount: itemCount,
                color: dividerColor,
                thickness: thickness,
                topInset: topInset,
                bottomInset: bottomInset,
                drawTopBorder: drawTopBorder,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NavDividersPainter extends CustomPainter {
  final int itemCount;
  final Color color;
  final double thickness;
  final double topInset;
  final double bottomInset;
  final bool drawTopBorder;

  _NavDividersPainter({
    required this.itemCount,
    required this.color,
    required this.thickness,
    required this.topInset,
    required this.bottomInset,
    required this.drawTopBorder,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke;

    final halfAdjust = (thickness % 2 == 1) ? 0.5 : 0.0;

    final step = size.width / itemCount;
    for (int i = 1; i < itemCount; i++) {
      final x = step * i + halfAdjust;
      canvas.drawLine(
        Offset(x, topInset),
        Offset(x, size.height - bottomInset),
        paint,
      );
    }

    if (drawTopBorder) {
      canvas.drawLine(
        Offset(0, 0 + halfAdjust),
        Offset(size.width, 0 + halfAdjust),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NavDividersPainter old) {
    return old.itemCount != itemCount ||
           old.color != color ||
           old.thickness != thickness ||
           old.topInset != topInset ||
           old.bottomInset != bottomInset ||
           old.drawTopBorder != drawTopBorder;
  }
}
