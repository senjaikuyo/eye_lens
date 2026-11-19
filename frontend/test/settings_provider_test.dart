import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:eye_lens/core/app_constants.dart';
import 'package:eye_lens/providers/display_preferences_provider.dart';
import 'package:eye_lens/providers/language_provider.dart';
import 'package:eye_lens/providers/settings_provider.dart';
import 'package:eye_lens/services/database_helper.dart';
import 'package:eye_lens/services/pengaturan_service.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    final tempDir = await Directory.systemTemp.createTemp('eyelens_settings');
    await databaseFactoryFfi.setDatabasesPath(tempDir.path);
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final db = await DatabaseHelper.instance.database;
    await db.delete('tbl_pengaturan');
    await DatabaseHelper.instance.setCurrentUserId(1);
  });

  tearDownAll(() async {
    await DatabaseHelper.instance.close();
  });

  group('SettingsProvider SQLite', () {
    test('1. Nilai bawaan autoPlayAudio adalah true', () async {
      final provider = SettingsProvider();
      await provider.initialized;

      expect(provider.autoPlayAudio, isTrue);
    });

    test(
      '2. Perubahan tersimpan ke tbl_pengaturan dan menandai is_synch = 0',
      () async {
        final provider = SettingsProvider();
        await provider.initialized;

        var notified = false;
        provider.addListener(() {
          notified = true;
        });

        await provider.setAutoPlayAudio(false);

        expect(provider.autoPlayAudio, isFalse);
        expect(notified, isTrue);

        final row = await DatabaseHelper.instance.getPengaturan();
        expect(row['otomatis_putar'], 0);
        expect(row['is_synch'], 0);
      },
    );

    test(
      '3. Nilai SQLite terbaca kembali saat provider dibuat ulang',
      () async {
        await DatabaseHelper.instance.updatePengaturanFields({
          'otomatis_putar': 0,
        });

        final provider = SettingsProvider();
        await provider.initialized;

        expect(provider.autoPlayAudio, isFalse);
      },
    );
  });

  group('DisplayPreferencesProvider SQLite', () {
    test(
      '4. Memuat tema, kontras, warna, dan ukuran teks dari SQLite',
      () async {
        await DatabaseHelper.instance.updatePengaturanFields({
          'tema': 'dark',
          'kontras': 'tinggi',
          'warna_kursor': '#1678BA',
          'tampilkan_warna_kursor': 0,
          'ukuran_teks': 40,
        });

        final provider = DisplayPreferencesProvider();
        await provider.initialized;

        expect(provider.themeMode, ThemeMode.dark);
        expect(provider.isHighContrast, isTrue);
        expect(provider.highlightColor, const Color(0xFF1678BA));
        expect(provider.cursorColor, isFalse);
        expect(provider.fontSize, 40);
      },
    );

    test('5. Perubahan tampilan menulis field terkait ke SQLite', () async {
      final provider = DisplayPreferencesProvider();
      await provider.initialized;

      provider.setThemeMode(ThemeMode.system);
      provider.toggleHighContrast(true);
      provider.toggleCursorColor(false);
      provider.setHighlightColor(const Color(0xFFD42749));
      provider.setFontSize(46);

      // recordChange berjalan async; beri kesempatan untuk menyelesaikan I/O.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final row = await DatabaseHelper.instance.getPengaturan();
      expect(row['tema'], 'system');
      expect(row['kontras'], 'tinggi');
      expect(row['tampilkan_warna_kursor'], 0);
      expect(row['warna_kursor'], '#D42749');
      expect(row['ukuran_teks'], 46);
      expect(row['is_synch'], 0);
    });
  });

  group('LanguageProvider SQLite', () {
    test('6. Bahasa aplikasi dimuat dan disimpan', () async {
      await DatabaseHelper.instance.updatePengaturanFields({
        'bahasa_aplikasi': 'en',
      });

      final provider = LanguageProvider();
      await provider.initialized;

      expect(provider.isEnglish, isTrue);

      provider.setLanguage('Indonesian');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final row = await DatabaseHelper.instance.getPengaturan();
      expect(row['bahasa_aplikasi'], 'id');
    });
  });

  group('Migrasi SharedPreferences', () {
    test('7. Pengaturan lama diimpor tanpa menghapus data prefs', () async {
      SharedPreferences.setMockInitialValues({
        AppPreferenceKeys.autoPlayAudio: false,
        'theme_mode': 'dark',
        'high_contrast': true,
        'cursor_color': false,
        'highlight_color_index': 2,
        'speech_font_size': 42.0,
      });

      await PengaturanService.instance.migrateLegacyPreferences();

      final row = await DatabaseHelper.instance.getPengaturan();
      expect(row['otomatis_putar'], 0);
      expect(row['tema'], 'dark');
      expect(row['kontras'], 'tinggi');
      expect(row['tampilkan_warna_kursor'], 0);
      expect(row['warna_kursor'], '#D42749');
      expect(row['ukuran_teks'], 42);
      expect(row['is_synch'], 0);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppPreferenceKeys.autoPlayAudio), isFalse);
      expect(prefs.getBool(PengaturanService.legacyMigrationFlag), isTrue);
    });

    test(
      '8. Migrasi tidak menimpa pengaturan SQLite yang sudah bukan bawaan',
      () async {
        await DatabaseHelper.instance.updatePengaturanFields({
          'tema': 'light',
          'ukuran_teks': 50,
        });

        SharedPreferences.setMockInitialValues({
          'theme_mode': 'dark',
          'speech_font_size': 20.0,
        });

        await PengaturanService.instance.migrateLegacyPreferences();

        final row = await DatabaseHelper.instance.getPengaturan();
        expect(row['tema'], 'light');
        expect(row['ukuran_teks'], 50);
      },
    );
  });

  group('Reassign data legacy', () {
    Map<String, dynamic> row({
      required int userId,
      required String tema,
      required String terakhirDiperbarui,
    }) => {
      'user_id': userId,
      'tema': tema,
      'ukuran_teks': 18,
      'warna_kursor': '#FACC15',
      'tampilkan_warna_kursor': 1,
      'kontras': 'normal',
      'otomatis_putar': 1,
      'kecepatan_suara': 1.0,
      'bahasa_suara': 'id-ID',
      'bahasa_aplikasi': 'id',
      'terakhir_diperbarui': terakhirDiperbarui,
      'is_synch': 1,
    };

    test(
      '9. Legacy yang lebih lama tidak menimpa pengaturan pengguna',
      () async {
        final db = await DatabaseHelper.instance.database;
        await db.delete('tbl_pengaturan');
        DatabaseHelper.instance.clearCurrentUser();

        await db.insert(
          'tbl_pengaturan',
          row(
            userId: DatabaseHelper.legacyUserId,
            tema: 'legacy-lama',
            terakhirDiperbarui: '2026-01-01T00:00:00.000Z',
          ),
        );
        await db.insert(
          'tbl_pengaturan',
          row(
            userId: 5,
            tema: 'pengguna-baru',
            terakhirDiperbarui: '2026-02-01T00:00:00.000Z',
          ),
        );

        await DatabaseHelper.instance.setCurrentUserId(5);

        final settings = await DatabaseHelper.instance.getPengaturan(userId: 5);
        expect(settings['tema'], 'pengguna-baru');

        final legacyRows = await db.query(
          'tbl_pengaturan',
          where: 'user_id = ?',
          whereArgs: [DatabaseHelper.legacyUserId],
        );
        expect(legacyRows, isEmpty);
      },
    );

    test(
      '10. Legacy yang lebih baru menggantikan pengaturan pengguna',
      () async {
        final db = await DatabaseHelper.instance.database;
        await db.delete('tbl_pengaturan');
        DatabaseHelper.instance.clearCurrentUser();

        await db.insert(
          'tbl_pengaturan',
          row(
            userId: DatabaseHelper.legacyUserId,
            tema: 'legacy-baru',
            terakhirDiperbarui: '2026-03-01T00:00:00.000Z',
          ),
        );
        await db.insert(
          'tbl_pengaturan',
          row(
            userId: 6,
            tema: 'pengguna-lama',
            terakhirDiperbarui: '2026-02-01T00:00:00.000Z',
          ),
        );

        await DatabaseHelper.instance.setCurrentUserId(6);

        final settings = await DatabaseHelper.instance.getPengaturan(userId: 6);
        expect(settings['tema'], 'legacy-baru');
        expect(settings['is_synch'], 0);
      },
    );
  });
}
