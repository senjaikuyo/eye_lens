import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData lightTheme(double fontMultiplier) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBg,
      colorScheme: ColorScheme.light(
        primary: AppColors.accentBlue,
        secondary: AppColors.accentYellow,
        surface: AppColors.lightCardBg,
        onSurface: AppColors.lightTextPrimary,
        error: AppColors.accentRed,
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28 * fontMultiplier,
          fontWeight: FontWeight.bold,
          color: AppColors.lightTextPrimary,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 22 * fontMultiplier,
          fontWeight: FontWeight.bold,
          color: AppColors.lightTextPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 19 * fontMultiplier,
          fontWeight: FontWeight.w600,
          color: AppColors.lightTextPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 17 * fontMultiplier,
          fontWeight: FontWeight.w500,
          color: AppColors.lightTextPrimary,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 15 * fontMultiplier,
          color: AppColors.lightTextSecondary,
          height: 1.4,
        ),
      ),
    );
  }

  static ThemeData darkTheme(double fontMultiplier) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBg,
      colorScheme: ColorScheme.dark(
        primary: AppColors.accentBlue,
        secondary: AppColors.accentYellow,
        surface: AppColors.darkCardBg,
        onSurface: AppColors.darkTextPrimary,
        error: AppColors.accentRed,
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28 * fontMultiplier,
          fontWeight: FontWeight.bold,
          color: AppColors.darkTextPrimary,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 22 * fontMultiplier,
          fontWeight: FontWeight.bold,
          color: AppColors.darkTextPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 19 * fontMultiplier,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 17 * fontMultiplier,
          fontWeight: FontWeight.w500,
          color: AppColors.darkTextPrimary,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 15 * fontMultiplier,
          color: AppColors.darkTextSecondary,
          height: 1.4,
        ),
      ),
    );
  }
}
