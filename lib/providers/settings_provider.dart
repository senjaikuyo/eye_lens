import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/settings_model.dart';

class SettingsProvider with ChangeNotifier {
  SettingsModel _settings = SettingsModel();
  bool _isLoading = true;

  SettingsModel get settings => _settings;
  bool get isLoading => _isLoading;
  bool get isDarkMode => _settings.modeTema == 'dark';

  SettingsProvider() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();
    _settings = await DatabaseHelper.instance.getSettings();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    final nextTheme = _settings.modeTema == 'light' ? 'dark' : 'light';
    _settings = _settings.copyWith(modeTema: nextTheme);
    notifyListeners();
    await DatabaseHelper.instance.updateSettings(_settings);
  }

  Future<void> setFontSize(String size) async {
    _settings = _settings.copyWith(skalaFont: size);
    notifyListeners();
    await DatabaseHelper.instance.updateSettings(_settings);
  }

  Future<void> setSpeechRate(double rate) async {
    _settings = _settings.copyWith(kecepatanSuara: rate);
    notifyListeners();
    await DatabaseHelper.instance.updateSettings(_settings);
  }

  Future<void> setLanguage(String lang) async {
    _settings = _settings.copyWith(bahasaSuara: lang);
    notifyListeners();
    await DatabaseHelper.instance.updateSettings(_settings);
  }

  Future<void> toggleGuideLine() async {
    _settings = _settings.copyWith(garisPanduanAktif: !_settings.garisPanduanAktif);
    notifyListeners();
    await DatabaseHelper.instance.updateSettings(_settings);
  }

  Future<void> toggleHaptics() async {
    _settings = _settings.copyWith(umpanBalikGetar: !_settings.umpanBalikGetar);
    notifyListeners();
    await DatabaseHelper.instance.updateSettings(_settings);
  }
}
