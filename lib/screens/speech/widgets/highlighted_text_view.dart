import 'package:flutter/material.dart';
import '../../../core/app_colors.dart';

class HighlightedTextView extends StatelessWidget {
  final String text;
  final double fontSize;
  final bool cursorColorEnabled;
  final Color highlightColor;
  final bool isDark;
  final bool isHighContrast;
  final double progress;
  final ValueChanged<double> onProgressChanged;

  const HighlightedTextView({
    super.key,
    required this.text,
    required this.fontSize,
    required this.cursorColorEnabled,
    required this.highlightColor,
    required this.isDark,
    required this.isHighContrast,
    required this.progress,
    required this.onProgressChanged,
  });

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    if (!cursorColorEnabled) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines.map((line) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              line,
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.black,
                fontSize: fontSize,
                height: 1.35,
                fontWeight: isHighContrast ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          );
        }).toList(),
      );
    }

    final activeIndex =
        (progress * lines.length).clamp(0, lines.length - 1).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(lines.length, (index) {
        final line = lines[index];
        final isActive = index == activeIndex;

        return GestureDetector(
          onTap: () {
            onProgressChanged(index / lines.length);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: EdgeInsets.symmetric(
              horizontal: isActive ? 12 : 0,
              vertical: isActive ? 6 : 4,
            ),
            decoration: BoxDecoration(
              color: isActive ? highlightColor : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isActive && isHighContrast
                  ? Border.all(
                      color: isDark ? Colors.white : Colors.black,
                      width: 2.0,
                    )
                  : null,
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: highlightColor.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              line,
              style: TextStyle(
                color: isActive
                    ? Colors.white
                    : (isDark ? Colors.white : AppColors.black),
                fontSize: fontSize,
                height: 1.35,
                fontWeight: isHighContrast
                    ? FontWeight.w900
                    : (isActive ? FontWeight.w700 : FontWeight.w600),
              ),
            ),
          ),
        );
      }),
    );
  }
}
