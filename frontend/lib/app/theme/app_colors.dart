import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Core Monochrome
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);

  // Greys & Surfaces
  static const Color greyLight = Color(0xFFF2F2F2);
  static const Color greyDarkBorder = Color(0xFF757575);
  static const Color buttonGrey = Color(0xFFD9D9D9);

  // Accent & Links
  static const Color linkBlue = Color(0xFF3B82F6);
  static const Color accentGreen = Color(0xFF22C55E);

  // Text
  static const Color textPrimary = Color(0xFF000000);
  static const Color textOnDark = Color(0xFFFFFFFF);

  // Error & Alerts
  // Merah cerah terkalibrasi (#D8224E) dengan rasio kontras 4.9:1 terhadap teks putih (lulus WCAG AA)
  static const Color alertErrorBg = Color(0xFFD8224E);
  static const Color alertErrorBorder = Color(0xFFB71C40);
}
