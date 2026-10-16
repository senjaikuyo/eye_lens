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
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final currentIsDark = themeProvider.isDark(context);
            final currentHighContrast = themeProvider.isHighContrast;

            return Container(
              decoration: BoxDecoration(
                color: currentIsDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                          color: currentIsDark ? Colors.white : AppColors.black,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(bottomSheetContext).pop(),
                        icon: Icon(
                          Icons.close,
                          color: currentIsDark ? Colors.white : AppColors.black,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // 1. Theme Row
                  _buildRow(
                    icon: Icon(
                      currentIsDark ? Icons.nightlight_round_outlined : Icons.wb_sunny_outlined,
                      color: currentIsDark ? Colors.white : Colors.black,
                      size: 24,
                    ),
                    label: strings.theme,
                    currentIsDark: currentIsDark,
                    trailing: PopupMenuButton<ThemeMode>(
                      initialValue: themeProvider.themeMode,
                      onSelected: (mode) {
                        themeProvider.setThemeMode(mode);
                        setSheetState(() {});
                      },
                      color: currentIsDark ? const Color(0xFF2A2A2A) : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      itemBuilder: (context) => [
                        PopupMenuItem(value: ThemeMode.light, child: Text(strings.themeLight)),
                        PopupMenuItem(value: ThemeMode.dark, child: Text(strings.themeDark)),
                        PopupMenuItem(value: ThemeMode.system, child: Text(strings.themeSystem)),
                      ],
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            themeProvider.themeMode == ThemeMode.dark
                                ? strings.themeDark
                                : themeProvider.themeMode == ThemeMode.light
                                    ? strings.themeLight
                                    : strings.themeSystem,
                            style: TextStyle(
                              color: currentIsDark ? const Color(0xFFAAAAAA) : const Color(0xFF666666),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.unfold_more_rounded,
                            color: currentIsDark ? const Color(0xFF888888) : const Color(0xFF8E9BAE),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Divider(height: 24, thickness: 0.8),

                  // 2. Cursor Color Row
                  _buildRow(
                    icon: Icon(
                      Icons.navigation_outlined,
                      color: currentIsDark ? Colors.white : Colors.black,
                      size: 24,
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
                      color: currentIsDark ? const Color(0xFF2A2A2A) : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      itemBuilder: (context) => ThemeProvider.highlightColors.map((color) {
                        return PopupMenuItem(
                          value: color,
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.black, width: 1),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                color == ThemeProvider.highlightColors[0]
                                    ? 'Orange (Default)'
                                    : color == ThemeProvider.highlightColors[1]
                                        ? 'Blue'
                                        : color == ThemeProvider.highlightColors[2]
                                            ? 'Red'
                                            : color == ThemeProvider.highlightColors[3]
                                                ? 'Green'
                                                : 'Purple',
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: themeProvider.highlightColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            themeProvider.cursorColor ? 'Active' : 'Default',
                            style: TextStyle(
                              color: currentIsDark ? const Color(0xFFAAAAAA) : const Color(0xFF666666),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.unfold_more_rounded,
                            color: currentIsDark ? const Color(0xFF888888) : const Color(0xFF8E9BAE),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Divider(height: 24, thickness: 0.8),

                  // 3. High Contrast Row
                  _buildRow(
                    icon: Icon(
                      Icons.contrast_rounded,
                      color: currentIsDark ? Colors.white : Colors.black,
                      size: 24,
                    ),
                    label: strings.highContrast,
                    currentIsDark: currentIsDark,
                    trailing: GestureDetector(
                      onTap: () {
                        themeProvider.toggleHighContrast(!currentHighContrast);
                        setSheetState(() {});
                      },
                      child: Text(
                        currentHighContrast ? 'On' : 'Off',
                        style: TextStyle(
                          color: currentHighContrast
                              ? (currentIsDark ? Colors.white : Colors.black)
                              : const Color(0xFF888888),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const Divider(height: 24, thickness: 0.8),

                  // 4. Text Size Row
                  _buildRow(
                    icon: Icon(
                      Icons.format_size_rounded,
                      color: currentIsDark ? Colors.white : Colors.black,
                      size: 24,
                    ),
                    label: strings.textSize,
                    currentIsDark: currentIsDark,
                    trailing: PopupMenuButton<double>(
                      initialValue: fontSize,
                      onSelected: (size) {
                        onFontSizeChanged(size);
                        setSheetState(() {});
                      },
                      color: currentIsDark ? const Color(0xFF2A2A2A) : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      itemBuilder: (context) => [
                        PopupMenuItem(value: 20.0, child: Text(strings.sizeSmall)),
                        PopupMenuItem(value: 32.0, child: Text(strings.sizeMedium)),
                        PopupMenuItem(value: 42.0, child: Text(strings.sizeLarge)),
                      ],
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            fontSize <= 24
                                ? strings.sizeSmall
                                : fontSize <= 36
                                    ? strings.sizeMedium
                                    : strings.sizeLarge,
                            style: TextStyle(
                              color: currentIsDark ? const Color(0xFFAAAAAA) : const Color(0xFF666666),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.unfold_more_rounded,
                            color: currentIsDark ? const Color(0xFF888888) : const Color(0xFF8E9BAE),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
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
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        trailing,
      ],
    );
  }
}
