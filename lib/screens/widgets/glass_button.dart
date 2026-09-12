import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/haptic_helper.dart';
import '../../providers/settings_provider.dart';

class GlassButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget? icon;
  final String? label;
  final double minSize;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  final bool isPrimary;

  const GlassButton({
    super.key,
    required this.onTap,
    this.icon,
    this.label,
    this.minSize = 56.0,
    this.borderRadius = 20.0,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;
    final fontMultiplier = settings.settings.fontSizeMultiplier;

    Color bg;
    Color border;
    Color textCol;

    if (isPrimary) {
      bg = isDark ? AppColors.accentBlue.withOpacity(0.85) : AppColors.accentBlue;
      border = Colors.white.withOpacity(0.3);
      textCol = Colors.white;
    } else {
      bg = backgroundColor ?? (isDark ? AppColors.darkGlassBg : AppColors.lightGlassBg);
      border = borderColor ?? (isDark ? AppColors.darkBorder : AppColors.lightBorder);
      textCol = textColor ?? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticHelper.lightImpact(enabled: settings.settings.umpanBalikGetar);
          onTap?.call();
        },
        borderRadius: BorderRadius.circular(borderRadius),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
            child: Container(
              constraints: BoxConstraints(
                minWidth: minSize,
                minHeight: minSize,
              ),
              padding: padding,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: border,
                  width: 1.3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ?icon,
                  if (icon != null && label != null) const SizedBox(width: 8),
                  if (label != null)
                    Flexible(
                      child: Text(
                        label!,
                        style: TextStyle(
                          color: textCol,
                          fontSize: 16 * fontMultiplier,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
