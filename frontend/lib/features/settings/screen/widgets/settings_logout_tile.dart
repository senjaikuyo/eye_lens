import 'package:flutter/material.dart';

import 'package:eye_lens/features/settings/screen/widgets/settings_list_tile.dart';

class SettingsLogoutTile extends StatelessWidget {
  final bool isDark;
  final String label;
  final VoidCallback onTap;

  const SettingsLogoutTile({
    super.key,
    required this.isDark,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsListTile(
      color: isDark ? const Color(0xFF2A1517) : const Color(0xFFFFF1F2),
      onTap: onTap,
      icon: const Icon(
        Icons.logout_rounded,
        color: Color(0xFFEF4444),
        size: 24,
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFEF4444),
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
