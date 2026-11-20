import 'dart:math';

import 'package:flutter/material.dart';

import 'package:eye_lens/features/camera/screen/widgets/scanner_corner_painter.dart';
import 'package:eye_lens/features/image_area/logic/lens_selection_helper.dart';

/// Painter untuk menggambar scrim gelap tipis di luar bingkai serta empat sudut putih
/// melengkung halus khas Google Lens, tanpa garis sisi penuh dan tanpa glow/bayangan tebal.
class GoogleLensFramePainter extends CustomPainter {
  final Rect frameRect;

  const GoogleLensFramePainter({required this.frameRect});

  @override
  void paint(Canvas canvas, Size size) {
    if (frameRect.width <= 0 || frameRect.height <= 0) return;

    final scrimPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.38)
      ..style = PaintingStyle.fill;

    final fullPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final framePath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          frameRect,
          const Radius.circular(LensSelectionHelper.lensCornerRadius),
        ),
      );

    final cutOutPath = Path.combine(
      PathOperation.difference,
      fullPath,
      framePath,
    );
    canvas.drawPath(cutOutPath, scrimPaint);

    // Inset setengah stroke agar tidak pernah terpotong di tepi layar maupun tepi citra.
    final halfStroke = LensSelectionHelper.lensStrokeWidth / 2.0;
    final insetRect = Rect.fromLTRB(
      max(halfStroke, frameRect.left + halfStroke),
      max(halfStroke, frameRect.top + halfStroke),
      min(size.width - halfStroke, frameRect.right - halfStroke),
      min(size.height - halfStroke, frameRect.bottom - halfStroke),
    );

    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = LensSelectionHelper.lensStrokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    ScannerCornerPainter.drawGoogleLensCorners(
      canvas: canvas,
      rect: insetRect,
      paint: cornerPaint,
      cornerLength: LensSelectionHelper.lensCornerLength,
      cornerRadius: LensSelectionHelper.lensCornerRadius,
    );
  }

  @override
  bool shouldRepaint(covariant GoogleLensFramePainter oldDelegate) {
    return oldDelegate.frameRect != frameRect;
  }
}
