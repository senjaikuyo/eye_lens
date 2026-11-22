import 'package:flutter/material.dart';

import 'package:eye_lens/app/theme/app_colors.dart';
import 'package:eye_lens/features/settings/screen/widgets/settings_list_tile.dart';

class SettingsAutoPlayTile extends StatelessWidget {
  final bool value;
  final bool isDark;
  final bool isHighContrast;
  final String title;
  final String subtitle;
  final String semanticsLabel;
  final ValueChanged<bool> onChanged;

  const SettingsAutoPlayTile({
    super.key,
    required this.value,
    required this.isDark,
    required this.isHighContrast,
    required this.title,
    required this.subtitle,
    required this.semanticsLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: semanticsLabel,
      child: SettingsListTile(
        icon: Icon(
          Icons.graphic_eq_rounded,
          color: isDark ? Colors.white : Colors.black,
          size: 24,
        ),
        trailing: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Switch(
              value: value,
              activeThumbColor: isDark ? Colors.white : Colors.black,
              onChanged: onChanged,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.black,
                fontSize: 17,
                fontWeight: isHighContrast ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(
                color: isDark
                    ? const Color(0xFF9E9E9E)
                    : const Color(0xFF6E6E6E),
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
