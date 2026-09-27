import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_strings.dart';
import '../../providers/theme_provider.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark(context);
    final isHighContrast = themeProvider.isHighContrast;
    final strings = AppStrings.of(context);

    final cardBorderColor = isHighContrast
        ? (isDark ? Colors.white : Colors.black)
        : (isDark ? const Color(0xFF333333) : const Color(0xFFDDE3EA));
    final cardBorderWidth = isHighContrast ? 2.0 : 1.0;

    return Scaffold(
      backgroundColor: isDark ? AppColors.black : AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              // Header: Back Button + "Appearance"
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2A2A2A)
                          : const Color(0xFFD9D9D9),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: isDark ? Colors.white : Colors.black,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    strings.appearance,
                    style: TextStyle(
                      color: isDark ? AppColors.white : AppColors.black,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // 1. Theme Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E1E1E)
                      : const Color(0xFFF2F4F7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: cardBorderColor,
                    width: cardBorderWidth,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isDark
                          ? Icons.nightlight_round_outlined
                          : Icons.wb_sunny_outlined,
                      color: isDark ? Colors.white : Colors.black,
                      size: 24,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        strings.theme,
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    PopupMenuButton<ThemeMode>(
                      initialValue: themeProvider.themeMode,
                      onSelected: (mode) {
                        context.read<ThemeProvider>().setThemeMode(mode);
                      },
                      color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: ThemeMode.light,
                          child: Text(strings.themeLight),
                        ),
                        PopupMenuItem(
                          value: ThemeMode.dark,
                          child: Text(strings.themeDark),
                        ),
                        PopupMenuItem(
                          value: ThemeMode.system,
                          child: Text(strings.themeSystem),
                        ),
                      ],
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            themeProvider.themeMode == ThemeMode.dark
                                ? strings.themeDark
                                : themeProvider.themeMode == ThemeMode.light
                                    ? strings.themeLight
                                    : '${strings.themeSystem} (${isDark ? strings.themeDark : strings.themeLight})',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.unfold_more_rounded,
                            color: isDark
                                ? const Color(0xFF888888)
                                : const Color(0xFF8E9BAE),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 2. High Contrast Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E1E1E)
                      : const Color(0xFFF2F4F7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: cardBorderColor,
                    width: cardBorderWidth,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.contrast_rounded,
                      color: isDark ? Colors.white : Colors.black,
                      size: 24,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        strings.highContrast,
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Switch(
                      value: themeProvider.isHighContrast,
                      activeThumbColor: isDark ? Colors.white : Colors.black,
                      onChanged: (val) {
                        context.read<ThemeProvider>().toggleHighContrast(val);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 3. Cursor Color Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E1E1E)
                      : const Color(0xFFF2F4F7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: cardBorderColor,
                    width: cardBorderWidth,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.bookmark_outline_rounded,
                      color: isDark ? Colors.white : Colors.black,
                      size: 24,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        strings.cursorColor,
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Switch(
                      value: themeProvider.cursorColor,
                      activeThumbColor: isDark ? Colors.white : Colors.black,
                      onChanged: (val) {
                        context.read<ThemeProvider>().toggleCursorColor(val);
                      },
                    ),
                  ],
                ),
              ),

              // 4. Color Palette (Component Color) when Cursor Color is ON
              if (themeProvider.cursorColor) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E1E1E)
                        : const Color(0xFFF2F4F7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: cardBorderColor,
                      width: cardBorderWidth,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ThemeProvider.highlightColors.map((color) {
                      final isSelected = themeProvider.highlightColor == color;
                      return GestureDetector(
                        onTap: () {
                          context.read<ThemeProvider>().setHighlightColor(color);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 52,
                          height: 26,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: isSelected && isDark ? Colors.white : Colors.black,
                              width: isSelected ? 2.5 : 1.2,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.5),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? const Center(
                                  child: Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
