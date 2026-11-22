import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:eye_lens/core/constants/app_constants.dart';
import 'package:eye_lens/core/settings_defaults.dart';
import 'package:eye_lens/core/services/database_helper.dart';
import 'package:eye_lens/core/services/sync_service.dart';

/// Sumber tunggal pengaturan lokal di `tbl_pengaturan`.
///
/// Provider UI membaca dan menulis lewat service ini. Setiap perubahan
/// menandai baris `is_synch = 0` lalu mencoba sinkronisasi; kegagalan
/// (mis. offline) tidak menghapus data dan akan dicoba lagi oleh
/// [SyncCoordinator].
class PengaturanService {
  static final PengaturanService instance = PengaturanService._internal();

  static const String legacyMigrationFlag = 'settings_sqlite_migrated_v1';

  final DatabaseHelper _dbHelper;
  final SyncService _syncService;

  PengaturanService._internal({
    DatabaseHelper? dbHelper,
    SyncService? syncService,
  }) : _dbHelper = dbHelper ?? DatabaseHelper.instance,
       _syncService = syncService ?? SyncService.instance;

  Future<Map<String, dynamic>> load() => _dbHelper.getPengaturan();

  /// Memindahkan pengaturan lama dari SharedPreferences ke SQLite satu kali.
  ///
  /// Impor hanya dilakukan bila baris SQLite masih seluruhnya bernilai
  /// bawaan. Jika pengguna sudah pernah mengubah pengaturan di versi baru
  /// (baris tidak lagi bawaan), nilai prefs tidak boleh menimpanya. Kunci
  /// SharedPreferences lama juga tidak dihapus agar tidak ada data yang hilang.
  Future<void> migrateLegacyPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(legacyMigrationFlag) ?? false) return;

    final current = await _dbHelper.getPengaturan();
    if (!_dbHelper.isBaselinePengaturan(current)) {
      await prefs.setBool(legacyMigrationFlag, true);
      return;
    }

    final fields = <String, dynamic>{};

    final savedAutoPlay = prefs.getBool(AppPreferenceKeys.autoPlayAudio);
    if (savedAutoPlay != null) {
      fields['otomatis_putar'] = savedAutoPlay ? 1 : 0;
    }

    final savedTheme = prefs.getString('theme_mode');
    if (savedTheme != null) {
      fields['tema'] = savedTheme;
    }

    final savedContrast = prefs.getBool('high_contrast');
    if (savedContrast != null) {
      fields['kontras'] = savedContrast
          ? SettingsDefaults.contrastHigh
          : SettingsDefaults.contrastNormal;
    }

    final savedCursor = prefs.getBool('cursor_color');
    if (savedCursor != null) {
      fields['tampilkan_warna_kursor'] = savedCursor ? 1 : 0;
    }

    final savedColorIndex = prefs.getInt('highlight_color_index');
    if (savedColorIndex != null &&
        savedColorIndex >= 0 &&
        savedColorIndex < SettingsDefaults.highlightColorHexes.length) {
      fields['warna_kursor'] =
          SettingsDefaults.highlightColorHexes[savedColorIndex];
    }

    final savedFontSize = prefs.getDouble('speech_font_size');
    if (savedFontSize != null) {
      final rounded = savedFontSize.round().clamp(
        SettingsDefaults.minFontSize,
        SettingsDefaults.maxFontSize,
      );
      fields['ukuran_teks'] = rounded;
    }

    if (fields.isNotEmpty) {
      await _dbHelper.updatePengaturanFields(fields);
    } else if ((current['is_synch'] as num?)?.toInt() == 0) {
      // Baris bawaan dari versi lama jangan ikut dikirim sebagai perubahan.
      await _dbHelper.resetPengaturanBaseline();
    }

    await prefs.setBool(legacyMigrationFlag, true);
  }

  /// Catat perubahan pengaturan, tandai `is_synch = 0`, lalu coba sinkron.
  Future<void> recordChange({
    String? tema,
    int? ukuranTeks,
    String? warnaKursor,
    int? tampilkanWarnaKursor,
    String? kontras,
    int? otomatisPutar,
    double? kecepatanSuara,
    String? bahasaSuara,
    String? bahasaAplikasi,
  }) async {
    final fields = <String, dynamic>{};
    void put(String key, dynamic value) {
      if (value != null) fields[key] = value;
    }

    put('tema', tema);
    put('ukuran_teks', ukuranTeks);
    put('warna_kursor', warnaKursor);
    put('tampilkan_warna_kursor', tampilkanWarnaKursor);
    put('kontras', kontras);
    put('otomatis_putar', otomatisPutar);
    put('kecepatan_suara', kecepatanSuara);
    put('bahasa_suara', bahasaSuara);
    put('bahasa_aplikasi', bahasaAplikasi);
    if (fields.isEmpty) return;

    try {
      await _dbHelper.updatePengaturanFields(fields);
      unawaited(_syncService.syncPending());
    } catch (_) {
      // Data lokal tetap bertahan; siklus sinkronisasi berikutnya mencoba lagi.
    }
  }
}
