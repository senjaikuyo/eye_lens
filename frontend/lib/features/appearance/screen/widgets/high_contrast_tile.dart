import 'package:flutter/material.dart';

import 'package:eye_lens/app/theme/app_colors.dart';
import 'package:eye_lens/features/appearance/screen/widgets/appearance_box_container.dart';

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
