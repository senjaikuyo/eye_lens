import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/lens_selection_helper.dart';

/// Painter bersama untuk menggambar 4 sudut berbentuk huruf L melengkung putih khas Google Lens.
/// Digunakan secara identik pada viewfinder kamera pemindai (ScanningScreen) dan overlay citra (SpeechScreen).
class ScannerCornerPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double cornerLength;
  final double cornerRadius;

  const ScannerCornerPainter({
    this.color = Colors.white,
    this.strokeWidth = LensSelectionHelper.lensStrokeWidth,
    this.cornerLength = LensSelectionHelper.lensCornerLength,
    this.cornerRadius = LensSelectionHelper.lensCornerRadius,
  });

  /// Menggambar 4 sudut L melengkung Google Lens pada sembarang [rect].
  static void drawGoogleLensCorners({
    required Canvas canvas,
    required Rect rect,
    required Paint paint,
    double cornerLength = LensSelectionHelper.lensCornerLength,
    double cornerRadius = LensSelectionHelper.lensCornerRadius,
  }) {
    if (rect.width <= 0 || rect.height <= 0) return;

    final effectiveCornerLength = math.min(
      cornerLength,
      math.min(rect.width, rect.height) * 0.45,
    );
    final effectiveRadius = math.min(
      cornerRadius,
      effectiveCornerLength * 0.8,
    );

    // 1. Sudut Kiri Atas (Top-Left)
    final tlPath = Path()
      ..moveTo(rect.left, rect.top + effectiveCornerLength)
      ..lineTo(rect.left, rect.top + effectiveRadius)
      ..arcToPoint(
        Offset(rect.left + effectiveRadius, rect.top),
        radius: Radius.circular(effectiveRadius),
        clockwise: true,
      )
      ..lineTo(rect.left + effectiveCornerLength, rect.top);
    canvas.drawPath(tlPath, paint);

    // 2. Sudut Kanan Atas (Top-Right)
    final trPath = Path()
      ..moveTo(rect.right - effectiveCornerLength, rect.top)
      ..lineTo(rect.right - effectiveRadius, rect.top)
      ..arcToPoint(
        Offset(rect.right, rect.top + effectiveRadius),
        radius: Radius.circular(effectiveRadius),
        clockwise: true,
      )
      ..lineTo(rect.right, rect.top + effectiveCornerLength);
    canvas.drawPath(trPath, paint);

    // 3. Sudut Kanan Bawah (Bottom-Right)
    final brPath = Path()
      ..moveTo(rect.right, rect.bottom - effectiveCornerLength)
      ..lineTo(rect.right, rect.bottom - effectiveRadius)
      ..arcToPoint(
        Offset(rect.right - effectiveRadius, rect.bottom),
        radius: Radius.circular(effectiveRadius),
        clockwise: true,
      )
      ..lineTo(rect.right - effectiveCornerLength, rect.bottom);
    canvas.drawPath(brPath, paint);

    // 4. Sudut Kiri Bawah (Bottom-Left)
    final blPath = Path()
      ..moveTo(rect.left + effectiveCornerLength, rect.bottom)
      ..lineTo(rect.left + effectiveRadius, rect.bottom)
      ..arcToPoint(
        Offset(rect.left, rect.bottom - effectiveRadius),
        radius: Radius.circular(effectiveRadius),
        clockwise: true,
      )
      ..lineTo(rect.left, rect.bottom - effectiveCornerLength);
    canvas.drawPath(blPath, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final halfStroke = strokeWidth / 2.0;
    final rect = Rect.fromLTRB(
      halfStroke,
      halfStroke,
      size.width - halfStroke,
      size.height - halfStroke,
    );

    drawGoogleLensCorners(
      canvas: canvas,
      rect: rect,
      paint: paint,
      cornerLength: cornerLength,
      cornerRadius: cornerRadius,
    );
  }

  @override
  bool shouldRepaint(covariant ScannerCornerPainter oldDelegate) =>
      color != oldDelegate.color ||
      strokeWidth != oldDelegate.strokeWidth ||
      cornerLength != oldDelegate.cornerLength ||
      cornerRadius != oldDelegate.cornerRadius;
}
