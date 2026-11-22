import 'package:flutter/foundation.dart';

import 'package:eye_lens/core/services/database_helper.dart';
import 'package:eye_lens/features/settings/logic/pengaturan_service.dart';

/// Provider preferensi umum yang bersumber dari `tbl_pengaturan` (SQLite).
class SettingsProvider extends ChangeNotifier {
  final PengaturanService _pengaturanService;

  bool _autoPlayAudio = true;
  bool _isLoaded = false;
  bool _disposed = false;
  late final Future<void> _initialization;

  SettingsProvider({PengaturanService? pengaturanService})
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

  /// Status pengaturan putar otomatis suara saat berpindah kelompok teks (default: true).
  bool get autoPlayAudio => _autoPlayAudio;

  /// Menandakan apakah pengaturan telah selesai dimuat dari penyimpanan lokal.
  bool get isLoaded => _isLoaded;

  Future<void> _load() async {
    try {
      final row = await _pengaturanService.load();
      _autoPlayAudio = ((row['otomatis_putar'] as num?)?.toInt() ?? 1) != 0;
    } catch (e) {
      debugPrint('[SettingsProvider] _load failed: ${e.runtimeType}');
      // Tetap gunakan nilai bawaan bila database belum siap.
    } finally {
      _isLoaded = true;
      if (!_disposed) notifyListeners();
    }
  }

  /// Mengubah status sakelar dan menyimpannya ke `tbl_pengaturan`.
  Future<void> setAutoPlayAudio(bool val) async {
    if (_autoPlayAudio == val) return;
    _autoPlayAudio = val;
    notifyListeners();

    await _pengaturanService.recordChange(otomatisPutar: val ? 1 : 0);
  }
}
