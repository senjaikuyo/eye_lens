import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_strings.dart';
import '../../../providers/theme_provider.dart';

class AppearanceBottomSheet {
  static void show(
    BuildContext context, {
    required ThemeProvider themeProvider,
    required AppStrings strings,
    required double fontSize,
    required ValueChanged<double> onFontSizeChanged,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (bottomSheetContext) {
        double currentFontSize = fontSize;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final currentIsDark = themeProvider.isDark(context);
            final currentHighContrast = themeProvider.isHighContrast;

            return SafeArea(
              top: false,
              child: Container(
                decoration: BoxDecoration(
                  color: currentIsDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header: Title & Close Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          strings.appearance,
                          style: TextStyle(
                            color: currentIsDark
                                ? Colors.white
                                : AppColors.black,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          onPressed: () =>
                              Navigator.of(bottomSheetContext).pop(),
                          icon: Icon(
                            Icons.close,
                            color: currentIsDark
                                ? Colors.white
                                : AppColors.black,
                            size: 26,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 1. Cursor Color Box
                    _buildBox(
                      currentIsDark: currentIsDark,
                      isHighContrast: currentHighContrast,
                      child: _buildRow(
                        icon: Icon(
                          Icons.navigation_outlined,
                          color: currentIsDark ? Colors.white : Colors.black,
                          size: 26,
                        ),
                        label: strings.cursorColor,
                        currentIsDark: currentIsDark,
                        trailing: PopupMenuButton<Color>(
                          initialValue: themeProvider.highlightColor,
                          onSelected: (color) {
                            themeProvider.setHighlightColor(color);
                            if (!themeProvider.cursorColor) {
                              themeProvider.toggleCursorColor(true);
                            }
                            setSheetState(() {});
                          },
                          color: currentIsDark
                              ? const Color(0xFF2A2A2A)
                              : Colors.white,
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
                                          border: Border.all(
                                            color: Colors.black,
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        color ==
                                                ThemeProvider.highlightColors[0]
                                            ? 'Orange (Default)'
                                            : color ==
                                                  ThemeProvider
                                                      .highlightColors[1]
                                            ? 'Blue'
                                            : color ==
                                                  ThemeProvider
                                                      .highlightColors[2]
                                            ? 'Red'
                                            : color ==
                                                  ThemeProvider
                                                      .highlightColors[3]
                                            ? 'Green'
                                            : 'Purple',
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
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: themeProvider.highlightColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  themeProvider.cursorColor
                                      ? 'Active'
                                      : 'Default',
                                  style: TextStyle(
                                    color: currentIsDark
                                        ? const Color(0xFFAAAAAA)
                                        : const Color(0xFF666666),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.unfold_more_rounded,
                                  color: currentIsDark
                                      ? const Color(0xFF888888)
                                      : const Color(0xFF8E9BAE),
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 2. High Contrast Box
                    _buildBox(
                      currentIsDark: currentIsDark,
                      isHighContrast: currentHighContrast,
                      child: _buildRow(
                        icon: Icon(
                          Icons.contrast_rounded,
                          color: currentIsDark ? Colors.white : Colors.black,
                          size: 26,
                        ),
                        label: strings.highContrast,
                        currentIsDark: currentIsDark,
                        trailing: GestureDetector(
                          onTap: () {
                            themeProvider.toggleHighContrast(
                              !currentHighContrast,
                            );
                            setSheetState(() {});
                          },
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 64,
                              minHeight: 48,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: currentHighContrast
                                  ? (currentIsDark
                                        ? Colors.white
                                        : Colors.black)
                                  : (currentIsDark
                                        ? const Color(0xFF333333)
                                        : const Color(0xFFE5E7EB)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              currentHighContrast ? 'On' : 'Off',
                              style: TextStyle(
                                color: currentHighContrast
                                    ? (currentIsDark
                                          ? Colors.black
                                          : Colors.white)
                                    : (currentIsDark
                                          ? const Color(0xFFAAAAAA)
                                          : const Color(0xFF666666)),
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 3. Text Size Box (Slider 100% - 300% / 18px - 54px)
                    _buildBox(
                      currentIsDark: currentIsDark,
                      isHighContrast: currentHighContrast,
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
                                    color: currentIsDark
                                        ? Colors.white
                                        : Colors.black,
                                    size: 26,
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    strings.textSize,
                                    style: TextStyle(
                                      color: currentIsDark
                                          ? Colors.white
                                          : AppColors.black,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                constraints: const BoxConstraints(
                                  minWidth: 64,
                                  minHeight: 48,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: currentIsDark
                                      ? const Color(0xFF333333)
                                      : const Color(0xFFE5E7EB),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${((currentFontSize / 18.0) * 100).round()}%',
                                  style: TextStyle(
                                    color: currentIsDark
                                        ? Colors.white
                                        : AppColors.black,
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
                                  color: currentIsDark
                                      ? const Color(0xFFAAAAAA)
                                      : const Color(0xFF666666),
                                ),
                              ),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: currentIsDark
                                        ? Colors.white
                                        : AppColors.black,
                                    inactiveTrackColor: currentIsDark
                                        ? const Color(0xFF444444)
                                        : const Color(0xFFE5E7EB),
                                    thumbColor: currentIsDark
                                        ? Colors.white
                                        : AppColors.black,
                                    overlayColor:
                                        (currentIsDark
                                                ? Colors.white
                                                : AppColors.black)
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
                                    value: currentFontSize.clamp(18.0, 54.0),
                                    min: 18.0,
                                    max: 54.0,
                                    onChanged: (newSize) {
                                      currentFontSize = newSize;
                                      onFontSizeChanged(newSize);
                                      setSheetState(() {});
                                    },
                                  ),
                                ),
                              ),
                              Text(
                                'A',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: currentIsDark
                                      ? Colors.white
                                      : AppColors.black,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Widget _buildBox({
    required Widget child,
    required bool currentIsDark,
    required bool isHighContrast,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: currentIsDark
            ? const Color(0xFF282828)
            : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHighContrast
              ? (currentIsDark ? Colors.white : Colors.black)
              : (currentIsDark
                    ? const Color(0xFF3E3E3E)
                    : const Color(0xFFE5E7EB)),
          width: isHighContrast ? 1.8 : 1.0,
        ),
      ),
      child: child,
    );
  }

  static Widget _buildRow({
    required Widget icon,
    required String label,
    required Widget trailing,
    required bool currentIsDark,
  }) {
    return Row(
      children: [
        icon,
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: currentIsDark ? Colors.white : AppColors.black,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        trailing,
      ],
    );
  }
}
