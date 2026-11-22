import 'package:flutter/material.dart';

import 'package:eye_lens/core/services/database_helper.dart';
import 'package:eye_lens/features/settings/logic/pengaturan_service.dart';

class LanguageProvider extends ChangeNotifier {
  final PengaturanService _pengaturanService;

  String _language = 'Indonesian'; // 'Indonesian' or 'English'
  bool _disposed = false;
  late final Future<void> _initialization;

  LanguageProvider({PengaturanService? pengaturanService})
    : _pengaturanService = pengaturanService ?? PengaturanService.instance {
    DatabaseHelper.instance.addListener(_load);
    _initialization = _load();
  }

  /// Selesai setelah nilai awal dibaca dari SQLite.
  Future<void> get initialized => _initialization;

  String get language => _language;
  bool get isIndonesian => _language == 'Indonesian';
  bool get isEnglish => _language == 'English';

  Locale get locale => isIndonesian ? const Locale('id') : const Locale('en');

  Future<void> _load() async {
    try {
      final row = await _pengaturanService.load();
      _language = row['bahasa_aplikasi'] == 'en' ? 'English' : 'Indonesian';
    } catch (e) {
      debugPrint('[LanguageProvider] _load failed: ${e.runtimeType}');
      // Tetap gunakan bahasa bawaan bila database belum siap.
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  void setLanguage(String lang) {
    if (_language == lang) return;
    _language = lang;
    notifyListeners();
    _pengaturanService.recordChange(
      bahasaAplikasi: lang == 'English' ? 'en' : 'id',
    );
  }

  @override
  void dispose() {
    _disposed = true;
    DatabaseHelper.instance.removeListener(_load);
    super.dispose();
  }
}
