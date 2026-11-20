import 'package:flutter/material.dart';

import 'package:eye_lens/app/theme/app_colors.dart';
import 'package:eye_lens/features/appearance/screen/widgets/appearance_box_container.dart';

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
