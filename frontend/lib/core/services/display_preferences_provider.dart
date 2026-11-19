import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DisplayPreferencesProvider extends ChangeNotifier {
  // Default values requested by user:
  // - High contrast OFF by default
  // - Light mode by default
  ThemeMode _themeMode = ThemeMode.light;
  bool _highContrast = false;
  bool _cursorColor = true;
  double _fontSize = 32.0; // Baseline range: 18.0 (100%) to 54.0 (300%)

  // 5 Preset Colors from Figma (Component Color)
  static const List<Color> highlightColors = [
    Color(0xFFE58E1B), // Orange
    Color(0xFF1678BA), // Blue
    Color(0xFFD42749), // Red
    Color(0xFF1FB16D), // Green
    Color(0xFF7B38D8), // Purple
  ];

  Color _highlightColor = const Color(0xFFE58E1B);

  DisplayPreferencesProvider() {
    _loadPreferences();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isHighContrast => _highContrast;
  bool get cursorColor => _cursorColor;
  Color get highlightColor => _highlightColor;
  double get fontSize => _fontSize;

  bool isDark(BuildContext context) {
    if (_themeMode == ThemeMode.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString('theme_mode');
      if (savedTheme != null) {
        if (savedTheme == 'dark') {
          _themeMode = ThemeMode.dark;
        } else if (savedTheme == 'system') {
          _themeMode = ThemeMode.system;
        } else {
          _themeMode = ThemeMode.light;
        }
      }

      final savedContrast = prefs.getBool('high_contrast');
      if (savedContrast != null) {
        _highContrast = savedContrast;
      }

      final savedCursor = prefs.getBool('cursor_color');
      if (savedCursor != null) {
        _cursorColor = savedCursor;
      }

      final savedColorIndex = prefs.getInt('highlight_color_index');
      if (savedColorIndex != null &&
          savedColorIndex >= 0 &&
          savedColorIndex < highlightColors.length) {
        _highlightColor = highlightColors[savedColorIndex];
      }

      final savedFontSize = prefs.getDouble('speech_font_size');
      if (savedFontSize != null &&
          savedFontSize >= 18.0 &&
          savedFontSize <= 54.0) {
        _fontSize = savedFontSize;
      }

      notifyListeners();
    } catch (_) {}
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
    _saveThemeMode(mode);
  }

  Future<void> _saveThemeMode(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String val = 'light';
      if (mode == ThemeMode.dark) val = 'dark';
      if (mode == ThemeMode.system) val = 'system';
      await prefs.setString('theme_mode', val);
    } catch (_) {}
  }

  void toggleHighContrast(bool val) {
    _highContrast = val;
    notifyListeners();
    _saveHighContrast(val);
  }

  Future<void> _saveHighContrast(bool val) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('high_contrast', val);
    } catch (_) {}
  }

  void toggleCursorColor(bool val) {
    _cursorColor = val;
    notifyListeners();
    _saveCursorColor(val);
  }

  Future<void> _saveCursorColor(bool val) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('cursor_color', val);
    } catch (_) {}
  }

  void setHighlightColor(Color color) {
    _highlightColor = color;
    notifyListeners();
    _saveHighlightColor(color);
  }

  Future<void> _saveHighlightColor(Color color) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idx = highlightColors.indexOf(color);
      if (idx != -1) {
        await prefs.setInt('highlight_color_index', idx);
      }
    } catch (_) {}
  }

  void setFontSize(double size) {
    _fontSize = size;
    notifyListeners();
    _saveFontSize(size);
  }

  Future<void> _saveFontSize(double size) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('speech_font_size', size);
    } catch (_) {}
  }
}
