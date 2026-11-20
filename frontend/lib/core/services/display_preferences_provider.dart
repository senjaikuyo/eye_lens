import 'package:flutter/material.dart';

import 'package:eye_lens/core/settings_defaults.dart';
import 'package:eye_lens/core/services/database_helper.dart';
import 'package:eye_lens/features/settings/logic/pengaturan_service.dart';

/// Preferensi tampilan yang bersumber dari `tbl_pengaturan` (SQLite).
///
/// Pemetaan kolom:
/// - `tema` -> ThemeMode
/// - `kontras` -> mode kontras tinggi
/// - `warna_kursor` -> warna sorot (hex)
/// - `tampilkan_warna_kursor` -> sakelar warna kursor (lokal, tidak disinkron)
/// - `ukuran_teks` -> ukuran font tampilan teks
class DisplayPreferencesProvider extends ChangeNotifier {
  static const List<Color> highlightColors = SettingsDefaults.highlightColors;

  final PengaturanService _pengaturanService;

  ThemeMode _themeMode = ThemeMode.light;
  bool _highContrast = false;
  bool _cursorColor = true;
  double _fontSize = SettingsDefaults.defaultFontSize.toDouble();
  Color _highlightColor = SettingsDefaults.highlightColors.first;

  bool _disposed = false;
  late final Future<void> _initialization;

  DisplayPreferencesProvider({PengaturanService? pengaturanService})
    : _pengaturanService = pengaturanService ?? PengaturanService.instance {
    DatabaseHelper.instance.addListener(_load);
    _initialization = _load();
  }

  /// Selesai setelah nilai awal dibaca dari SQLite.
  Future<void> get initialized => _initialization;

  @override
  void dispose() {
    _disposed = true;
    DatabaseHelper.instance.removeListener(_load);
    super.dispose();
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

  Future<void> _load() async {
    try {
      final row = await _pengaturanService.load();

      _themeMode = _themeModeFromValue(row['tema'] as String?);
      _highContrast =
          row['kontras'] == SettingsDefaults.contrastHigh ||
          row['kontras'] == 'high';
      _cursorColor =
          ((row['tampilkan_warna_kursor'] as num?)?.toInt() ?? 1) != 0;
      _highlightColor = SettingsDefaults.highlightColorFromHex(
        row['warna_kursor'] as String?,
      );

      final size = (row['ukuran_teks'] as num?)?.toDouble();
      if (size != null) {
        _fontSize = size.clamp(
          SettingsDefaults.minFontSize.toDouble(),
          SettingsDefaults.maxFontSize.toDouble(),
        );
      }
    } catch (_) {
      // Tetap gunakan nilai bawaan bila database belum siap.
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  ThemeMode _themeModeFromValue(String? value) {
    switch (value) {
      case 'dark':
      case 'gelap':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      case 'sistem':
        // Nilai bawaan skema v2; tampilan lama selalu dimulai dari mode terang.
        return ThemeMode.light;
      default:
        return ThemeMode.light;
    }
  }

  String _themeValue(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return SettingsDefaults.themeDark;
      case ThemeMode.system:
        return SettingsDefaults.themeSystem;
      case ThemeMode.light:
        return SettingsDefaults.themeLight;
    }
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
    _pengaturanService.recordChange(tema: _themeValue(mode));
  }

  void toggleHighContrast(bool val) {
    _highContrast = val;
    notifyListeners();
    _pengaturanService.recordChange(
      kontras: val
          ? SettingsDefaults.contrastHigh
          : SettingsDefaults.contrastNormal,
    );
  }

  void toggleCursorColor(bool val) {
    _cursorColor = val;
    notifyListeners();
    _pengaturanService.recordChange(tampilkanWarnaKursor: val ? 1 : 0);
  }

  void setHighlightColor(Color color) {
    _highlightColor = color;
    notifyListeners();
    _pengaturanService.recordChange(
      warnaKursor: SettingsDefaults.hexFromColor(color),
    );
  }

  void setFontSize(double size) {
    _fontSize = size.clamp(
      SettingsDefaults.minFontSize.toDouble(),
      SettingsDefaults.maxFontSize.toDouble(),
    );
    notifyListeners();
    _pengaturanService.recordChange(ukuranTeks: _fontSize.round());
  }
}
