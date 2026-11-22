import 'package:flutter/material.dart';

import 'package:eye_lens/app/theme/app_colors.dart';
import 'package:eye_lens/features/settings/screen/widgets/settings_list_tile.dart';

class SettingsNavTile extends StatelessWidget {
  final IconData iconData;
  final String label;
  final bool isDark;
  final bool isHighContrast;
  final VoidCallback onTap;

  const SettingsNavTile({
    super.key,
    required this.iconData,
    required this.label,
    required this.isDark,
    required this.isHighContrast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsListTile(
      icon: Icon(
        iconData,
        color: isDark ? Colors.white : Colors.black,
        size: 24,
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: isDark ? const Color(0xFF777777) : Colors.black,
        size: 26,
      ),
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          color: isDark ? Colors.white : AppColors.black,
          fontSize: 17,
          fontWeight: isHighContrast ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
    );
  }
}
