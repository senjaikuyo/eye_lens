import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';

class SettingsEmailTile extends StatelessWidget {
  final String emailLabel;
  final String email;
  final bool isDark;
  final bool isHighContrast;

  const SettingsEmailTile({
    super.key,
    required this.emailLabel,
    required this.email,
    required this.isDark,
    required this.isHighContrast,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            emailLabel,
            style: const TextStyle(
              color: Color(0xFF888888),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.black,
              fontSize: 17,
              fontWeight: isHighContrast ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
