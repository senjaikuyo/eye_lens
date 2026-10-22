import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_constants.dart';

/// Provider untuk mengelola preferensi umum aplikasi seperti putar otomatis suara.
class SettingsProvider extends ChangeNotifier {
  bool _autoPlayAudio = true;
  bool _isLoaded = false;

  SettingsProvider({SharedPreferences? preferences}) {
    if (preferences != null) {
      _initFromPrefs(preferences);
    } else {
      _loadPreferences();
    }
  }

  /// Status pengaturan putar otomatis suara saat berpindah kelompok teks (default: true).
  bool get autoPlayAudio => _autoPlayAudio;

  /// Menandakan apakah pengaturan telah selesai dimuat dari penyimpanan lokal.
  bool get isLoaded => _isLoaded;

  void _initFromPrefs(SharedPreferences prefs) {
    _autoPlayAudio = prefs.getBool(AppPreferenceKeys.autoPlayAudio) ?? true;
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _initFromPrefs(prefs);
    } catch (_) {
      _isLoaded = true;
      notifyListeners();
    }
  }

  /// Mengubah status sakelar putar otomatis suara dan menyimpannya ke SharedPreferences.
  Future<void> setAutoPlayAudio(bool val) async {
    if (_autoPlayAudio == val) return;
    _autoPlayAudio = val;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppPreferenceKeys.autoPlayAudio, val);
    } catch (_) {}
  }
}
