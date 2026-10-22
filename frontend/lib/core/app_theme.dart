import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static TextTheme _buildTextTheme({required Color textColor}) {
    return TextTheme(
      headlineLarge: TextStyle(
        fontFamily: 'sans-serif',
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.4,
        color: textColor,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'sans-serif',
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.4,
        color: textColor,
      ),
      titleLarge: TextStyle(
        fontFamily: 'sans-serif',
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: textColor,
      ),
      titleMedium: TextStyle(
        fontFamily: 'sans-serif',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: textColor,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'sans-serif',
        fontSize: 18,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: textColor,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'sans-serif',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: textColor,
      ),
      labelLarge: TextStyle(
        fontFamily: 'sans-serif',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.4,
        color: textColor,
      ),
      labelMedium: TextStyle(
        fontFamily: 'sans-serif',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: textColor,
      ),
      labelSmall: TextStyle(
        fontFamily: 'sans-serif',
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: textColor,
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.white,
      colorScheme: const ColorScheme.light(
        primary: AppColors.black,
        secondary: AppColors.buttonGrey,
        surface: AppColors.white,
        onSurface: AppColors.textPrimary,
      ),
      fontFamily: 'sans-serif',
      textTheme: _buildTextTheme(textColor: AppColors.textPrimary),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.black,
        elevation: 0,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.black,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.white,
        secondary: AppColors.buttonGrey,
        surface: Color(0xFF1E1E1E),
        onSurface: AppColors.white,
      ),
      fontFamily: 'sans-serif',
      textTheme: _buildTextTheme(textColor: AppColors.textOnDark),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
    );
  }
}
