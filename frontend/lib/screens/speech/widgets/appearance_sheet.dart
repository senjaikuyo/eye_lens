import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_strings.dart';
import '../../../providers/theme_provider.dart';
import 'appearance_controls.dart';

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
                    CursorColorTile(
                      isDark: currentIsDark,
                      isHighContrast: currentHighContrast,
                      label: strings.cursorColor,
                      highlightColor: themeProvider.highlightColor,
                      isCursorColorActive: themeProvider.cursorColor,
                      onColorSelected: (color) {
                        themeProvider.setHighlightColor(color);
                        if (!themeProvider.cursorColor) {
                          themeProvider.toggleCursorColor(true);
                        }
                        setSheetState(() {});
                      },
                    ),

                    const SizedBox(height: 12),

                    // 2. High Contrast Box
                    HighContrastTile(
                      isDark: currentIsDark,
                      isHighContrast: currentHighContrast,
                      label: strings.highContrast,
                      onToggle: () {
                        themeProvider.toggleHighContrast(!currentHighContrast);
                        setSheetState(() {});
                      },
                    ),

                    const SizedBox(height: 12),

                    // 3. Text Size Slider Box
                    TextSizeSliderTile(
                      isDark: currentIsDark,
                      isHighContrast: currentHighContrast,
                      label: strings.textSize,
                      fontSize: currentFontSize,
                      onFontSizeChanged: (newSize) {
                        currentFontSize = newSize;
                        onFontSizeChanged(newSize);
                        setSheetState(() {});
                      },
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
}
