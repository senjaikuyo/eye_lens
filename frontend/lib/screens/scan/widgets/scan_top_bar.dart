import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_strings.dart';
import '../../../widgets/feedback_dialog.dart';
import '../../history/history_screen.dart';
import '../../settings/faq_screen.dart';
import '../../settings/settings_screen.dart';

class ScanTopBar extends StatelessWidget {
  final double topPadding;
  final bool isFlashOn;
  final VoidCallback onToggleFlash;
  final bool isDark;
  final AppStrings strings;

  const ScanTopBar({
    super.key,
    required this.topPadding,
    required this.isFlashOn,
    required this.onToggleFlash,
    required this.isDark,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: topPadding + 10,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Flash Toggle Button
          _buildCircleButton(
            onTap: onToggleFlash,
            child: Icon(
              isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: isFlashOn ? const Color(0xFFE58E1B) : Colors.black,
              size: 26,
            ),
          ),

          // Right Actions: History & PopupMenu
          Row(
            children: [
              _buildCircleButton(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const HistoryScreen(),
                    ),
                  );
                },
                child: const Icon(
                  Icons.history_rounded,
                  color: Colors.black,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
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
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        );
                      } else if (value == 'feedback') {
                        FeedbackDialog.show(
                          context,
                          strings: strings,
                          isDark: isDark,
                        );
                      } else if (value == 'faq') {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const FaqScreen(),
                          ),
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'settings',
                        height: 52,
                        child: Text(
                          strings.settings,
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'feedback',
                        height: 52,
                        child: Text(
                          strings.feedback,
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'faq',
                        height: 52,
                        child: Text(
                          strings.faq,
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildCircleButton({Widget? child, VoidCallback? onTap}) {
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
