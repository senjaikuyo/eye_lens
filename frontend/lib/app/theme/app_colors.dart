import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Core Monochrome
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);

  // Greys & Surfaces
  static const Color greyLight = Color(0xFFF2F2F2);
  static const Color greyBorder = Color(0xFFCCCCCC);
  static const Color greyDarkBorder = Color(0xFF757575);
  static const Color buttonGrey = Color(0xFFD9D9D9);
  static const Color cardBg = Color(0xFFF7F7F7);

  // Accent & Links
  static const Color linkBlue = Color(0xFF3B82F6);
  static const Color accentGreen = Color(0xFF22C55E);

  // Text
  static const Color textPrimary = Color(0xFF000000);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textOnDark = Color(0xFFFFFFFF);
  static const Color textOnDarkSecondary = Color(0xFFCCCCCC);

  // Error & Alerts
  // Merah cerah terkalibrasi (#D8224E) dengan rasio kontras 4.9:1 terhadap teks putih (lulus WCAG AA)
  static const Color alertErrorBg = Color(0xFFD8224E);
  static const Color alertErrorBorder = Color(0xFFB71C40);
  static const Color alertErrorIconX = Color(0xFFD8224E);
}
