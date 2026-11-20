import 'package:flutter/material.dart';

/// Nilai bawaan dan pemetaan pengaturan UI ke kolom `tbl_pengaturan`.
///
/// Warna sorot disimpan sebagai hex di kolom `warna_kursor` agar dapat
/// disinkronkan ke backend. Indeks tidak disimpan terpisah karena dapat
/// diturunkan kembali dari nilai hex.
class SettingsDefaults {
  const SettingsDefaults._();

  static const String themeSystem = 'system';
  static const String themeLight = 'light';
  static const String themeDark = 'dark';

  static const String contrastNormal = 'normal';
  static const String contrastHigh = 'tinggi';

  static const int defaultFontSize = 32;
  static const int minFontSize = 18;
  static const int maxFontSize = 54;

  static const List<Color> highlightColors = [
    Color(0xFFE58E1B), // Orange
    Color(0xFF1678BA), // Blue
    Color(0xFFD42749), // Red
    Color(0xFF1FB16D), // Green
    Color(0xFF7B38D8), // Purple
  ];

  static const List<String> highlightColorHexes = [
    '#E58E1B',
    '#1678BA',
    '#D42749',
    '#1FB16D',
    '#7B38D8',
  ];

  static Color highlightColorFromHex(String? hex) {
    if (hex == null || hex.isEmpty) return highlightColors.first;
    final normalized = hex.startsWith('#') ? hex.substring(1) : hex;
    if (normalized.length != 6) return highlightColors.first;
    final value = int.tryParse(normalized, radix: 16);
    if (value == null) return highlightColors.first;
    return Color(0xFF000000 | value);
  }

  static String hexFromColor(Color color) {
    final argb = color.toARGB32().toRadixString(16).padLeft(8, '0');
    return '#${argb.substring(2).toUpperCase()}';
  }
}
