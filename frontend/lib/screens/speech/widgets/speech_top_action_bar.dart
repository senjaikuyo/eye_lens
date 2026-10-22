import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_strings.dart';

class SpeechTopActionBar extends StatelessWidget {
  final bool isDark;
  final AppStrings strings;
  final VoidCallback onBackPressed;
  final VoidCallback onAppearancePressed;
  final VoidCallback onSettingsTap;
  final VoidCallback onFeedbackTap;
  final VoidCallback onFaqTap;
  final bool showAppearanceButton;

  const SpeechTopActionBar({
    super.key,
    required this.isDark,
    required this.strings,
    required this.onBackPressed,
    required this.onAppearancePressed,
    required this.onSettingsTap,
    required this.onFeedbackTap,
    required this.onFaqTap,
    this.showAppearanceButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        // Back Button
        _buildCircleButton(
          onTap: onBackPressed,
          child: const Icon(
            Icons.arrow_back_rounded,
            color: Colors.black,
            size: 26,
          ),
        ),

        const Spacer(),

        // "Aa" Appearance Button (hanya tampil di mode teks)
        if (showAppearanceButton) ...[
          _buildCircleButton(
            onTap: onAppearancePressed,
            child: Text(
              'Aa',
              style: textTheme.labelLarge?.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],

        // Three Dots Overflow Menu
        _buildCircleButton(
          child: Theme(
            data: Theme.of(context).copyWith(
              popupMenuTheme: PopupMenuThemeData(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            child: PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert_rounded,
                color: Colors.black,
                size: 26,
              ),
              padding: EdgeInsets.zero,
              onSelected: (value) {
                if (value == 'settings') {
                  onSettingsTap();
                } else if (value == 'feedback') {
                  onFeedbackTap();
                } else if (value == 'faq') {
                  onFaqTap();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'settings',
                  height: 52,
                  child: Text(
                    strings.settings,
                    style: textTheme.bodyLarge?.copyWith(
                      color: isDark ? Colors.white : AppColors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                PopupMenuItem(
                  value: 'feedback',
                  height: 52,
                  child: Text(
                    strings.feedback,
                    style: textTheme.bodyLarge?.copyWith(
                      color: isDark ? Colors.white : AppColors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                PopupMenuItem(
                  value: 'faq',
                  height: 52,
                  child: Text(
                    strings.faq,
                    style: textTheme.bodyLarge?.copyWith(
                      color: isDark ? Colors.white : AppColors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCircleButton({VoidCallback? onTap, required Widget child}) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFD0D7DE), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Center(child: child),
        ),
      ),
    );
  }
}
