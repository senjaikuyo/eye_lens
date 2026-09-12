import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/settings_provider.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double blurSigma;
  final Color? customBgColor;
  final Color? customBorderColor;
  final double borderWidth;
  final BoxShadow? shadow;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 22.0,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.blurSigma = 18.0,
    this.customBgColor,
    this.customBorderColor,
    this.borderWidth = 1.2,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    final bgColor = customBgColor ?? (isDark ? AppColors.darkGlassBg : AppColors.lightGlassBg);
    final borderColor = customBorderColor ?? (isDark ? AppColors.darkBorder : AppColors.lightBorder);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadow != null
            ? [shadow!]
            : [
                BoxShadow(
                  color: isDark ? Colors.black.withOpacity(0.4) : Colors.black.withOpacity(0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: borderColor,
                width: borderWidth,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
