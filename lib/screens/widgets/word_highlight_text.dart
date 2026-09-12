import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class WordHighlightText extends StatelessWidget {
  final String fullText;
  final int highlightStart;
  final int highlightEnd;
  final double fontSize;
  final Color textColor;
  final Color highlightColor;

  const WordHighlightText({
    super.key,
    required this.fullText,
    required this.highlightStart,
    required this.highlightEnd,
    this.fontSize = 22.0,
    required this.textColor,
    this.highlightColor = AppColors.highlightYellow,
  });

  @override
  Widget build(BuildContext context) {
    if (fullText.isEmpty) {
      return Text(
        'Tidak ada teks terdeteksi.',
        style: TextStyle(
          fontSize: fontSize,
          color: textColor.withOpacity(0.6),
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final hasHighlight = highlightStart >= 0 &&
        highlightEnd > highlightStart &&
        highlightEnd <= fullText.length;

    if (!hasHighlight) {
      return SelectableText(
        fullText,
        style: TextStyle(
          fontSize: fontSize,
          color: textColor,
          fontWeight: FontWeight.w600,
          height: 1.6,
          letterSpacing: 0.2,
        ),
      );
    }

    final before = fullText.substring(0, highlightStart);
    final active = fullText.substring(highlightStart, highlightEnd);
    final after = fullText.substring(highlightEnd);

    return SelectableText.rich(
      TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          color: textColor,
          fontWeight: FontWeight.w600,
          height: 1.6,
          letterSpacing: 0.2,
        ),
        children: [
          TextSpan(text: before),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: highlightColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                active,
                style: TextStyle(
                  fontSize: fontSize,
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  height: 1.6,
                ),
              ),
            ),
          ),
          TextSpan(text: after),
        ],
      ),
    );
  }
}
