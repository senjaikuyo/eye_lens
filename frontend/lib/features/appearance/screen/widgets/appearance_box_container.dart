import 'package:flutter/material.dart';

class AppearanceBoxContainer extends StatelessWidget {
  final Widget child;
  final bool isDark;
  final bool isHighContrast;

  const AppearanceBoxContainer({
    super.key,
    required this.child,
    required this.isDark,
    required this.isHighContrast,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF282828) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHighContrast
              ? (isDark ? Colors.white : Colors.black)
              : (isDark ? const Color(0xFF3E3E3E) : const Color(0xFFE5E7EB)),
          width: isHighContrast ? 1.8 : 1.0,
        ),
      ),
      child: child,
    );
  }
}
