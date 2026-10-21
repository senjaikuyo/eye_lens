import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_strings.dart';
import '../../auth/login_screen.dart';

class LogoutDialog {
  static void show(
    BuildContext context, {
    required AppStrings strings,
    required bool isDark,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          strings.logOutConfirmTitle,
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.black,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          strings.logOutConfirmMessage,
          style: TextStyle(
            color: isDark ? const Color(0xFFCCCCCC) : const Color(0xFF555555),
            fontSize: 16,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              strings.cancel,
              style: TextStyle(
                color: isDark
                    ? const Color(0xFFAAAAAA)
                    : const Color(0xFF777777),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              minimumSize: const Size(80, 48),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            child: Text(
              strings.logOut,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
