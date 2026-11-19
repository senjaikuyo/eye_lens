import 'package:flutter/material.dart';

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
    return Material(
      color: isDark ? const Color(0xFF2A1517) : const Color(0xFFFFF1F2),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              const Icon(
                Icons.logout_rounded,
                color: Color(0xFFEF4444),
                size: 24,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
