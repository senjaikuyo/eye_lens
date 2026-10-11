import 'package:flutter/material.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_strings.dart';

class HistoryDeleteDialog {
  static Future<bool?> showDeleteSingle(
    BuildContext context, {
    required AppStrings strings,
    required bool isDark,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          strings.deleteConfirmTitle,
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          strings.deleteConfirmMessage,
          style: TextStyle(
            color: isDark ? const Color(0xFFCCCCCC) : const Color(0xFF555555),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              strings.cancel,
              style: TextStyle(
                color: isDark ? const Color(0xFFAAAAAA) : const Color(0xFF777777),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              strings.delete,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  static Future<bool?> showClearAll(
    BuildContext context, {
    required AppStrings strings,
    required bool isDark,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          strings.clearAll,
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          strings.clearAllConfirmMessage,
          style: TextStyle(
            color: isDark ? const Color(0xFFCCCCCC) : const Color(0xFF555555),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              strings.cancel,
              style: TextStyle(
                color: isDark ? const Color(0xFFAAAAAA) : const Color(0xFF777777),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              strings.clearAll,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
