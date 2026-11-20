import 'package:flutter/material.dart';

import 'package:eye_lens/app/theme/app_colors.dart';
import 'package:eye_lens/core/services/display_preferences_provider.dart';
import 'package:eye_lens/features/appearance/screen/widgets/appearance_box_container.dart';

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
    if (color == DisplayPreferencesProvider.highlightColors[0]) {
      return 'Orange (Default)';
    }
    if (color == DisplayPreferencesProvider.highlightColors[1]) return 'Blue';
    if (color == DisplayPreferencesProvider.highlightColors[2]) return 'Red';
    if (color == DisplayPreferencesProvider.highlightColors[3]) return 'Green';
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
                DisplayPreferencesProvider.highlightColors.map((color) {
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
