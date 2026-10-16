import 'package:flutter/material.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_strings.dart';

class LanguageBottomSheet {
  static void show(
    BuildContext context, {
    required AppStrings strings,
    required bool isDark,
    required String selectedLanguage,
    required ValueChanged<String> onLanguageSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title & Close Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        strings.speechLanguage,
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.black,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(bottomSheetContext).pop(),
                        icon: Icon(
                          Icons.close,
                          color: isDark ? Colors.white : AppColors.black,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Option 1: Indonesia
                  _buildLanguageOption(
                    title: 'Indonesia',
                    flagAsset: 'assets/images/flag_indonesia.png',
                    isSelected: selectedLanguage == 'Indonesia',
                    isDark: isDark,
                    onTap: () {
                      onLanguageSelected('Indonesia');
                      Navigator.of(bottomSheetContext).pop();
                    },
                  ),
                  const SizedBox(height: 16),

                  // Option 2: English
                  _buildLanguageOption(
                    title: 'English',
                    flagAsset: 'assets/images/flag_usa.png',
                    isSelected: selectedLanguage == 'English',
                    isDark: isDark,
                    onTap: () {
                      onLanguageSelected('English');
                      Navigator.of(bottomSheetContext).pop();
                    },
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static Widget _buildLanguageOption({
    required String title,
    required String flagAsset,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF2A3444) : const Color(0xFFEDF4FC))
                : (isDark ? const Color(0xFF252525) : const Color(0xFFF4F6F9)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? (isDark ? const Color(0xFF3B82F6) : AppColors.black)
                  : (isDark ? const Color(0xFF3A3A3A) : const Color(0xFFD0D7DE)),
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: ClipOval(
                  child: Image.asset(
                    flagAsset,
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.black,
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? (isDark ? const Color(0xFF3B82F6) : AppColors.black)
                        : (isDark ? const Color(0xFF666666) : const Color(0xFF999999)),
                    width: 2.0,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? const Color(0xFF3B82F6) : AppColors.black,
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
