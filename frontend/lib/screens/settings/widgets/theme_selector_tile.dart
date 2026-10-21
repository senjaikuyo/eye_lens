import 'package:flutter/material.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_strings.dart';

class ThemeSelectorTile extends StatelessWidget {
  final bool isDark;
  final bool isHighContrast;
  final AppStrings strings;
  final ThemeMode selectedThemeMode;
  final ValueChanged<ThemeMode> onThemeSelected;

  const ThemeSelectorTile({
    super.key,
    required this.isDark,
    required this.isHighContrast,
    required this.strings,
    required this.selectedThemeMode,
    required this.onThemeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
            color: isDark ? Colors.white : Colors.black,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.theme,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.black,
                    fontSize: 15,
                    fontWeight: isHighContrast ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildPill(
                      label: strings.themeLight,
                      isSelected: selectedThemeMode == ThemeMode.light,
                      onTap: () => onThemeSelected(ThemeMode.light),
                    ),
                    const SizedBox(width: 8),
                    _buildPill(
                      label: strings.themeDark,
                      isSelected: selectedThemeMode == ThemeMode.dark,
                      onTap: () => onThemeSelected(ThemeMode.dark),
                    ),
                    const SizedBox(width: 8),
                    _buildPill(
                      label: strings.themeSystem,
                      isSelected: selectedThemeMode == ThemeMode.system,
                      onTap: () => onThemeSelected(ThemeMode.system),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isHighContrast
                    ? (isDark ? Colors.white : Colors.black)
                    : (isDark ? const Color(0xFF555555) : Colors.black),
                width: isHighContrast ? 1.8 : 1.0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? Colors.white : Colors.black,
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white : Colors.black,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
