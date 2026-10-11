import 'package:flutter/material.dart';

/// Painter untuk garis siku-siku (sudut 90 derajat) tipis di 4 sudut jendela bidik kamera.
class ScannerCornerPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double cornerLength;

  const ScannerCornerPainter({
    this.color = Colors.white,
    this.strokeWidth = 2.0,
    this.cornerLength = 32.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter;

    final w = size.width;
    final h = size.height;
    final l = cornerLength;

    // Top-Left Corner ┌
    final pathTL = Path()
      ..moveTo(0, l)
      ..lineTo(0, 0)
      ..lineTo(l, 0);
    canvas.drawPath(pathTL, paint);

    // Top-Right Corner ┐
    final pathTR = Path()
      ..moveTo(w - l, 0)
      ..lineTo(w, 0)
      ..lineTo(w, l);
    canvas.drawPath(pathTR, paint);

    // Bottom-Left Corner └
    final pathBL = Path()
      ..moveTo(0, h - l)
      ..lineTo(0, h)
      ..lineTo(l, h);
    canvas.drawPath(pathBL, paint);

    // Bottom-Right Corner ┘
    final pathBR = Path()
      ..moveTo(w - l, h)
      ..lineTo(w, h)
      ..lineTo(w, h - l);
    canvas.drawPath(pathBR, paint);
  }

  @override
  bool shouldRepaint(covariant ScannerCornerPainter oldDelegate) =>
      color != oldDelegate.color ||
      strokeWidth != oldDelegate.strokeWidth ||
      cornerLength != oldDelegate.cornerLength;
}
