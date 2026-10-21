import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Painter untuk 4 busur sudut melengkung halus (quarter-circle arcs)
/// Persis seperti tampilan viewfinder focus frame / scanner reticle pada referensi:
/// Tidak ada garis lurus berlebih, murni 4 busur 90 derajat di keempat sudut.
class ScannerCornerPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double arcRadius;

  const ScannerCornerPainter({
    this.color = Colors.white,
    this.strokeWidth = 2.0,
    this.arcRadius = 38.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final d = arcRadius * 2;

    // 1. Top-Left Arc (90 derajat busur sudut kiri atas)
    canvas.drawArc(
      Rect.fromLTWH(0, 0, d, d),
      math.pi,
      math.pi / 2,
      false,
      paint,
    );

    // 2. Top-Right Arc (90 derajat busur sudut kanan atas)
    canvas.drawArc(
      Rect.fromLTWH(w - d, 0, d, d),
      -math.pi / 2,
      math.pi / 2,
      false,
      paint,
    );

    // 3. Bottom-Right Arc (90 derajat busur sudut kanan bawah)
    canvas.drawArc(
      Rect.fromLTWH(w - d, h - d, d, d),
      0,
      math.pi / 2,
      false,
      paint,
    );

    // 4. Bottom-Left Arc (90 derajat busur sudut kiri bawah)
    canvas.drawArc(
      Rect.fromLTWH(0, h - d, d, d),
      math.pi / 2,
      math.pi / 2,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant ScannerCornerPainter oldDelegate) =>
      color != oldDelegate.color ||
      strokeWidth != oldDelegate.strokeWidth ||
      arcRadius != oldDelegate.arcRadius;
}
