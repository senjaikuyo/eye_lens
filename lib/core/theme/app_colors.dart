import 'package:flutter/material.dart';

class AppColors {
  // Light Mode (Clean Apple White Dominant)
  static const Color lightBg = Color(0xFFF6F8FA);
  static const Color lightGlassBg = Color(0xE6FFFFFF); // ~90% white opacity
  static const Color lightCardBg = Colors.white;
  static const Color lightBorder = Color(0xFFE5E5EA);
  static const Color lightTextPrimary = Color(0xFF1A1A1A);
  static const Color lightTextSecondary = Color(0xFF636366);

  // Dark Mode (Apple Dark Glass)
  static const Color darkBg = Color(0xFF121212);
  static const Color darkGlassBg = Color(0xCC1E1E1E); // ~80% dark opacity
  static const Color darkCardBg = Color(0xFF1C1C1E);
  static const Color darkBorder = Color(0xFF38383A);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF8E8E93);

  // Accent & Highlight
  static const Color accentYellow = Color(0xFFFFD60A); // High visibility focus yellow
  static const Color highlightYellow = Color(0xFFFFF176); // Soft bright yellow for word highlight
  static const Color accentBlue = Color(0xFF007AFF); // Apple iOS Blue
  static const Color accentGreen = Color(0xFF34C759); // Apple Green
  static const Color accentRed = Color(0xFFFF3B30); // Apple Red
}
