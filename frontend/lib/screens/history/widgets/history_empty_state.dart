import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_strings.dart';

class HistoryEmptyState extends StatelessWidget {
  final AppStrings strings;
  final bool isDark;

  const HistoryEmptyState({
    super.key,
    required this.strings,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E1E1E)
                    : const Color(0xFFF2F4F7),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history_rounded,
                color: isDark
                    ? const Color(0xFF666666)
                    : const Color(0xFFA0AEC0),
                size: 46,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              strings.noHistoryTitle,
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.black,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              strings.noHistorySubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark
                    ? const Color(0xFF888888)
                    : const Color(0xFF718096),
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
