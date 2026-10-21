import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../providers/theme_provider.dart';

class AppearanceBoxContainer extends StatelessWidget {
  final Widget child;
  final bool isDark;
  final bool isHighContrast;

  const AppearanceBoxContainer({
    super.key,
    required this.child,
    required this.isDark,
    required this.isHighContrast,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF282828) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHighContrast
              ? (isDark ? Colors.white : Colors.black)
              : (isDark ? const Color(0xFF3E3E3E) : const Color(0xFFE5E7EB)),
          width: isHighContrast ? 1.8 : 1.0,
        ),
      ),
      child: child,
    );
  }
}

class CursorColorTile extends StatelessWidget {
  final bool isDark;
  final bool isHighContrast;
  final String label;
  final Color highlightColor;
  final bool isCursorColorActive;
  final ValueChanged<Color> onColorSelected;

  const CursorColorTile({
    super.key,
    required this.isDark,
    required this.isHighContrast,
    required this.label,
    required this.highlightColor,
    required this.isCursorColorActive,
    required this.onColorSelected,
  });

  String _getColorName(Color color) {
    if (color == ThemeProvider.highlightColors[0]) return 'Orange (Default)';
    if (color == ThemeProvider.highlightColors[1]) return 'Blue';
    if (color == ThemeProvider.highlightColors[2]) return 'Red';
    if (color == ThemeProvider.highlightColors[3]) return 'Green';
    return 'Purple';
  }

  @override
  Widget build(BuildContext context) {
    return AppearanceBoxContainer(
      isDark: isDark,
      isHighContrast: isHighContrast,
      child: Row(
        children: [
          Icon(
            Icons.navigation_outlined,
            color: isDark ? Colors.white : Colors.black,
            size: 26,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.black,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          PopupMenuButton<Color>(
            initialValue: highlightColor,
            onSelected: onColorSelected,
            color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            itemBuilder: (context) =>
                ThemeProvider.highlightColors.map((color) {
                  return PopupMenuItem(
                    value: color,
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 1),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _getColorName(color),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
            child: Container(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: highlightColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isCursorColorActive ? 'Active' : 'Default',
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFFAAAAAA)
                          : const Color(0xFF666666),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.unfold_more_rounded,
                    color: isDark
                        ? const Color(0xFF888888)
                        : const Color(0xFF8E9BAE),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HighContrastTile extends StatelessWidget {
  final bool isDark;
  final bool isHighContrast;
  final String label;
  final VoidCallback onToggle;

  const HighContrastTile({
    super.key,
    required this.isDark,
    required this.isHighContrast,
    required this.label,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AppearanceBoxContainer(
      isDark: isDark,
      isHighContrast: isHighContrast,
      child: Row(
        children: [
          Icon(
            Icons.contrast_rounded,
            color: isDark ? Colors.white : Colors.black,
            size: 26,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.black,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: onToggle,
            child: Container(
              constraints: const BoxConstraints(minWidth: 64, minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isHighContrast
                    ? (isDark ? Colors.white : Colors.black)
                    : (isDark
                          ? const Color(0xFF333333)
                          : const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isHighContrast ? 'On' : 'Off',
                style: TextStyle(
                  color: isHighContrast
                      ? (isDark ? Colors.black : Colors.white)
                      : (isDark
                            ? const Color(0xFFAAAAAA)
                            : const Color(0xFF666666)),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TextSizeSliderTile extends StatefulWidget {
  final bool isDark;
  final bool isHighContrast;
  final String label;
  final double fontSize;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<double>? onFontSizeChangeEnd;

  const TextSizeSliderTile({
    super.key,
    required this.isDark,
    required this.isHighContrast,
    required this.label,
    required this.fontSize,
    required this.onFontSizeChanged,
    this.onFontSizeChangeEnd,
  });

  @override
  State<TextSizeSliderTile> createState() => _TextSizeSliderTileState();
}

class _TextSizeSliderTileState extends State<TextSizeSliderTile> {
  late double _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.fontSize.clamp(18.0, 54.0);
  }

  @override
  void didUpdateWidget(covariant TextSizeSliderTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fontSize != widget.fontSize) {
      _currentValue = widget.fontSize.clamp(18.0, 54.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppearanceBoxContainer(
      isDark: widget.isDark,
      isHighContrast: widget.isHighContrast,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.format_size_rounded,
                    color: widget.isDark ? Colors.white : Colors.black,
                    size: 26,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: widget.isDark ? Colors.white : AppColors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 64, minHeight: 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? const Color(0xFF333333)
                      : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${((_currentValue / 18.0) * 100).round()}%',
                  style: TextStyle(
                    color: widget.isDark ? Colors.white : AppColors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'A',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: widget.isDark
                      ? const Color(0xFFAAAAAA)
                      : const Color(0xFF666666),
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: widget.isDark
                        ? Colors.white
                        : AppColors.black,
                    inactiveTrackColor: widget.isDark
                        ? const Color(0xFF444444)
                        : const Color(0xFFE5E7EB),
                    thumbColor: widget.isDark ? Colors.white : AppColors.black,
                    overlayColor:
                        (widget.isDark ? Colors.white : AppColors.black)
                            .withValues(alpha: 0.12),
                    trackHeight: 6,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 14,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 24,
                    ),
                  ),
                  child: Slider(
                    value: _currentValue.clamp(18.0, 54.0),
                    min: 18.0,
                    max: 54.0,
                    onChanged: (val) {
                      setState(() {
                        _currentValue = val;
                      });
                      widget.onFontSizeChanged(val);
                    },
                    onChangeEnd: (val) {
                      widget.onFontSizeChangeEnd?.call(val);
                    },
                  ),
                ),
              ),
              Text(
                'A',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: widget.isDark ? Colors.white : AppColors.black,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
