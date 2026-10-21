import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_strings.dart';

class LanguageSelectorTile extends StatelessWidget {
  final bool isDark;
  final bool isHighContrast;
  final AppStrings strings;
  final String selectedLanguage;
  final ValueChanged<String> onLanguageSelected;

  const LanguageSelectorTile({
    super.key,
    required this.isDark,
    required this.isHighContrast,
    required this.strings,
    required this.selectedLanguage,
    required this.onLanguageSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.translate_rounded,
            color: isDark ? Colors.white : Colors.black,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.languageApp,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.black,
                    fontSize: 17,
                    fontWeight: isHighContrast
                        ? FontWeight.w800
                        : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildPill(
                      label: strings.indonesian,
                      isSelected: selectedLanguage == 'Indonesian',
                      onTap: () => onLanguageSelected('Indonesian'),
                    ),
                    const SizedBox(width: 8),
                    _buildPill(
                      label: strings.english,
                      isSelected: selectedLanguage == 'English',
                      onTap: () => onLanguageSelected('English'),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                Text(
                  label,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  width: 16,
                  height: 16,
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
                            width: 8,
                            height: 8,
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
