import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/ocr_service.dart';

class GoogleLensOverlayPainter extends CustomPainter {
  final List<DetectedWord> words;
  final Size originalImageSize;
  final String activeWord;

  GoogleLensOverlayPainter({
    required this.words,
    required this.originalImageSize,
    required this.activeWord,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (words.isEmpty || originalImageSize.width == 0 || originalImageSize.height == 0) return;

    final double scaleX = size.width / originalImageSize.width;
    final double scaleY = size.height / originalImageSize.height;

    final boxPaint = Paint()
      ..color = Colors.white.withOpacity(0.28)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final activePaint = Paint()
      ..color = AppColors.accentYellow.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final activeBorderPaint = Paint()
      ..color = AppColors.accentYellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;

    for (final word in words) {
      final rect = Rect.fromLTRB(
        word.boundingBox.left * scaleX,
        word.boundingBox.top * scaleY,
        word.boundingBox.right * scaleX,
        word.boundingBox.bottom * scaleY,
      );

      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(5));
      final bool isActive = activeWord.isNotEmpty &&
          word.text.toLowerCase().contains(activeWord.toLowerCase());

      if (isActive) {
        canvas.drawRRect(rrect, activePaint);
        canvas.drawRRect(rrect, activeBorderPaint);
      } else {
        canvas.drawRRect(rrect, boxPaint);
        canvas.drawRRect(rrect, borderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant GoogleLensOverlayPainter oldDelegate) {
    return oldDelegate.words != words ||
        oldDelegate.activeWord != activeWord ||
        oldDelegate.originalImageSize != originalImageSize;
  }
}
