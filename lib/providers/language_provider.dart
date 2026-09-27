import 'package:flutter/material.dart';

class LanguageProvider extends ChangeNotifier {
  String _language = 'English'; // 'Indonesian' or 'English'

  String get language => _language;
  bool get isIndonesian => _language == 'Indonesian';
  bool get isEnglish => _language == 'English';

  Locale get locale => isIndonesian ? const Locale('id') : const Locale('en');

  void setLanguage(String lang) {
    if (_language != lang) {
      _language = lang;
      notifyListeners();
    }
  }
}
