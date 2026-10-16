import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../providers/theme_provider.dart';

class CustomAuthField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType keyboardType;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final String? errorText;

  const CustomAuthField({
    super.key,
    required this.label,
    this.controller,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.suffixIcon,
    this.onChanged,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark(context);
    final isHighContrast = themeProvider.isHighContrast;
    final hasError = errorText != null && errorText!.isNotEmpty;

    final borderColor = hasError
        ? const Color(0xFFEF4444)
        : (isHighContrast
            ? (isDark ? Colors.white : Colors.black)
            : (isDark ? const Color(0xFF383838) : AppColors.greyDarkBorder));

    final borderWidth = hasError
        ? (isHighContrast ? 2.2 : 1.4)
        : (isHighContrast ? 2.0 : 0.9);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? AppColors.white : AppColors.textPrimary,
            fontSize: 14,
            fontWeight: isHighContrast ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : AppColors.greyLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: borderColor,
              width: borderWidth,
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            onChanged: onChanged,
            cursorColor: isDark ? Colors.white : Colors.black,
            style: TextStyle(
              color: isDark ? AppColors.white : AppColors.textPrimary,
              fontSize: 15,
              fontWeight: isHighContrast ? FontWeight.w600 : FontWeight.w400,
            ),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: InputBorder.none,
              isDense: true,
              suffixIcon: suffixIcon != null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [suffixIcon!],
                    )
                  : null,
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFEF4444),
                  size: 14,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    errorText!,
                    style: TextStyle(
                      color: const Color(0xFFEF4444),
                      fontSize: 12,
                      fontWeight: isHighContrast ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
