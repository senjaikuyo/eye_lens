import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  bool _highContrast = true;
  bool _cursorColor = true;

  // 5 Preset Colors from Figma (Component Color)
  static const List<Color> highlightColors = [
    Color(0xFFE58E1B), // Orange
    Color(0xFF1678BA), // Blue
    Color(0xFFD42749), // Red
    Color(0xFF1FB16D), // Green
    Color(0xFF7B38D8), // Purple
  ];

  Color _highlightColor = const Color(0xFFE58E1B);

  ThemeMode get themeMode => _themeMode;
  bool get isHighContrast => _highContrast;
  bool get cursorColor => _cursorColor;
  Color get highlightColor => _highlightColor;

  bool isDark(BuildContext context) {
    if (_themeMode == ThemeMode.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  void toggleHighContrast(bool val) {
    _highContrast = val;
    notifyListeners();
  }

  void toggleCursorColor(bool val) {
    _cursorColor = val;
    notifyListeners();
  }

  void setHighlightColor(Color color) {
    _highlightColor = color;
    notifyListeners();
  }
}
