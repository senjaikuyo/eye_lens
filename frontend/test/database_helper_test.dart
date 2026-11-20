import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:eye_lens/core/services/database_helper.dart';
import 'package:eye_lens/features/history/logic/history_provider.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final dbHelper = DatabaseHelper.instance;
    await dbHelper.clearAllRiwayat();
    await dbHelper.getPengaturan(); // pastikan baris pengaturan user aktif ada
    final db = await dbHelper.database;
    await db.update(
      'tbl_pengaturan',
      {
        'tema': 'sistem',
        'ukuran_teks': 18,
        'warna_kursor': '#FACC15',
        'kontras': 'normal',
        'otomatis_putar': 1,
        'kecepatan_suara': 1.0,
        'bahasa_suara': 'id-ID',
        'bahasa_aplikasi': 'id',
        'terakhir_diperbarui': DateTime.now().toIso8601String(),
        'is_synch': 0,
      },
      where: 'user_id = ?',
      whereArgs: [DatabaseHelper.legacyUserId],
    );
  });

  tearDownAll(() async {
    await DatabaseHelper.instance.close();
  });

  group('DatabaseHelper SQLite Unit Tests', () {
    test(
      '1. Insert dan get riwayat bekerja sesuai urutan waktu terbaru',
      () async {
        final dbHelper = DatabaseHelper.instance;

        final id1 = await dbHelper.insertRiwayat(
          judul: 'Pindai Pertama',
          isiTeks: 'Ini adalah isi dokumen kesatu.',
          jumlahKata: 5,
          sumber: 'kamera',
          waktu: DateTime(2026, 1, 1, 10, 0),
        );

        final id2 = await dbHelper.insertRiwayat(
          judul: 'Pindai Kedua',
          isiTeks: 'Ini adalah isi dokumen kedua lebih baru.',
          jumlahKata: 7,
          sumber: 'galeri',
          waktu: DateTime(2026, 1, 1, 12, 0),
        );

        final list = await dbHelper.getRiwayatModelList();
        expect(list.length, 2);
        expect(list.first.idRiwayat, id2);
        expect(list.first.judul, 'Pindai Kedua');
        expect(list.last.idRiwayat, id1);
        expect(list.last.sumber, 'kamera');
      },
    );
    test(
      '2. Retensi hanya memangkas data tersinkron (maksimal 50 per pengguna)',
      () async {
        final dbHelper = DatabaseHelper.instance;
        final ids = <int>[];

        for (int i = 1; i <= 55; i++) {
          ids.add(
            await dbHelper.insertRiwayat(
              judul: 'Dokumen $i',
              isiTeks: 'Teks dokumen ke-$i',
              jumlahKata: 3,
              sumber: 'kamera',
              waktu: DateTime(2026, 1, 1, 0, i),
            ),
          );
        }

        // Semua masih belum tersinkron: tidak boleh ada yang dihapus.
        expect(await dbHelper.getRiwayatCount(), 55);
        expect(await dbHelper.getRiwayatById(ids.first), isNotNull);

        // Setelah ditandai tersinkron, retensi 50 berlaku.
        await dbHelper.markRiwayatSynced(ids);

        final count = await dbHelper.getRiwayatCount();
        expect(count, 50);

        final list = await dbHelper.getRiwayatModelList();
        expect(list.length, 50);
        expect(list.first.judul, 'Dokumen 55');
        expect(list.last.judul, 'Dokumen 6');
      },
    );

    test('3. Hapus riwayat tunggal dan bersihkan seluruh riwayat', () async {
      final dbHelper = DatabaseHelper.instance;

      final id = await dbHelper.insertRiwayat(
        judul: 'Dokumen Hapus',
        isiTeks: 'Teks akan dihapus',
        jumlahKata: 3,
        sumber: 'kamera',
      );

      final deletedRows = await dbHelper.deleteRiwayatById(id);
      expect(deletedRows, 1);

      final item = await dbHelper.getRiwayatById(id);
      expect(item, isNull);

      await dbHelper.insertRiwayat(
        judul: 'Dokumen A',
        isiTeks: 'Teks A',
        jumlahKata: 2,
        sumber: 'kamera',
      );
      await dbHelper.insertRiwayat(
        judul: 'Dokumen B',
        isiTeks: 'Teks B',
        jumlahKata: 2,
        sumber: 'kamera',
      );

      await dbHelper.clearAllRiwayat();
      final finalCount = await dbHelper.getRiwayatCount();
      expect(finalCount, 0);
    });

    test('4. Sinkronisasi status riwayat markRiwayatSynced', () async {
      final dbHelper = DatabaseHelper.instance;

      final id1 = await dbHelper.insertRiwayat(
        judul: 'Unsynced 1',
        isiTeks: 'Teks 1',
        jumlahKata: 2,
        sumber: 'kamera',
      );
      final id2 = await dbHelper.insertRiwayat(
        judul: 'Unsynced 2',
        isiTeks: 'Teks 2',
        jumlahKata: 2,
        sumber: 'kamera',
      );

      final unsynced = await dbHelper.getUnsyncedRiwayat();
      expect(unsynced.length, 2);

      final updated = await dbHelper.markRiwayatSynced([id1, id2]);
      expect(updated, 2);

      final unsyncedAfter = await dbHelper.getUnsyncedRiwayat();
      expect(unsyncedAfter.isEmpty, isTrue);
    });

    test('5. Pengaturan default dan update pengaturan', () async {
      final dbHelper = DatabaseHelper.instance;

      final initial = await dbHelper.getPengaturan();
      expect(initial['user_id'], DatabaseHelper.legacyUserId);
      expect(initial['tema'], 'sistem');

      await dbHelper.updatePengaturan({'tema': 'gelap', 'ukuran_teks': 24});

      final updated = await dbHelper.getPengaturan();
      expect(updated['tema'], 'gelap');
      expect(updated['ukuran_teks'], 24);
    });

    test('6. Konflik pengaturan diselesaikan per-field', () async {
      final dbHelper = DatabaseHelper.instance;

      await dbHelper.updatePengaturan({
        'tema': 'lokal-tema',
      }, terakhirDiperbarui: '2026-11-17T10:00:00.000000Z');
      await dbHelper.updatePengaturan({
        'ukuran_teks': 14,
      }, terakhirDiperbarui: '2026-11-17T08:00:00.000000Z');

      final serverTimes = <String, String>{
        for (final field in DatabaseHelper.syncedPengaturanFields)
          field: DatabaseHelper.baselineTimestamp,
        'tema': '2026-11-17T09:00:00.000000Z',
        'ukuran_teks': '2026-11-17T11:00:00.000000Z',
      };

      await dbHelper.applyServerPengaturan({
        'tema': 'server-tema',
        'ukuran_teks': 30,
        'warna_kursor': '#FACC15',
        'kontras': 'normal',
        'otomatis_putar': true,
        'kecepatan_suara': 1.0,
        'bahasa_suara': 'id-ID',
        'bahasa_aplikasi': 'id',
        'terakhir_diperbarui': '2026-11-17T11:00:00.000000Z',
        'field_timestamps': serverTimes,
      });

      final row = await dbHelper.getPengaturan();
      // Tema lokal (10:00) lebih baru dari server (09:00).
      expect(row['tema'], 'lokal-tema');
      // Ukuran teks server (11:00) lebih baru dari lokal (08:00).
      expect(row['ukuran_teks'], 30);
    });

    test(
      '7. Retensi 50 berlaku saat baris berubah menjadi tersinkron',
      () async {
        final dbHelper = DatabaseHelper.instance;
        final ids = <int>[];

        for (int i = 1; i <= 55; i++) {
          ids.add(
            await dbHelper.insertRiwayat(
              judul: 'Dokumen $i',
              isiTeks: 'Teks dokumen ke-$i',
              jumlahKata: 3,
              sumber: 'kamera',
              waktu: DateTime(2026, 1, 1, 0, i),
            ),
          );
        }

        // Belum tersinkron: tidak ada yang boleh dihapus.
        expect(await dbHelper.getRiwayatCount(), 55);

        // Begitu menjadi tersinkron, retensi 50 langsung berlaku.
        await dbHelper.markRiwayatSynced(ids);
        expect(await dbHelper.getRiwayatCount(), 50);

        final list = await dbHelper.getRiwayatModelList();
        expect(list.first.judul, 'Dokumen 55');
        expect(list.last.judul, 'Dokumen 6');
      },
    );

    test('8. Pemangkasan retensi terisolasi per pengguna', () async {
      final dbHelper = DatabaseHelper.instance;
      final db = await dbHelper.database;

      try {
        await dbHelper.setCurrentUserId(10);
        final ids = <int>[];
        for (int i = 1; i <= 55; i++) {
          ids.add(
            await dbHelper.insertRiwayat(
              judul: 'User10-$i',
              isiTeks: 'Teks $i',
              jumlahKata: 2,
              sumber: 'kamera',
              waktu: DateTime(2026, 1, 1, 0, i),
            ),
          );
        }
        await dbHelper.markRiwayatSynced(ids);
        expect(await dbHelper.getRiwayatCount(), 50);

        // Pengguna lain tidak boleh terkena pemangkasan pengguna pertama.
        await dbHelper.setCurrentUserId(20);
        for (int i = 1; i <= 3; i++) {
          await dbHelper.insertRiwayat(
            judul: 'User20-$i',
            isiTeks: 'Teks $i',
            jumlahKata: 2,
            sumber: 'kamera',
          );
        }
        expect(await dbHelper.getRiwayatCount(), 3);

        await dbHelper.setCurrentUserId(10);
        expect(await dbHelper.getRiwayatCount(), 50);
      } finally {
        await db.delete(
          'tbl_riwayat',
          where: 'user_id IN (?, ?)',
          whereArgs: [10, 20],
        );
        await dbHelper.setCurrentUserId(DatabaseHelper.legacyUserId);
      }
    });

    test(
      '9. Reassignment tidak membuat baseline menjadi pending sync',
      () async {
        final dbHelper = DatabaseHelper.instance;
        final db = await dbHelper.database;

        try {
          await db.delete('tbl_pengaturan');
          dbHelper.clearCurrentUser();

          final baseline = await dbHelper.getPengaturan();
          expect(baseline['is_synch'], 1);
          expect(
            baseline['terakhir_diperbarui'],
            DatabaseHelper.baselineTimestamp,
          );

          await dbHelper.setCurrentUserId(31);

          final moved = await dbHelper.getPengaturan(userId: 31);
          expect(moved['user_id'], 31);
          expect(moved['is_synch'], 1);
          expect(
            moved['terakhir_diperbarui'],
            DatabaseHelper.baselineTimestamp,
          );
          expect(await dbHelper.getUnsyncedPengaturan(userId: 31), isNull);
        } finally {
          await db.delete(
            'tbl_pengaturan',
            where: 'user_id IN (?, ?)',
            whereArgs: [31, DatabaseHelper.legacyUserId],
          );
          await dbHelper.setCurrentUserId(DatabaseHelper.legacyUserId);
        }
      },
    );

    test('10. Pengaturan yang benar-benar diubah tetap pending', () async {
      final dbHelper = DatabaseHelper.instance;
      final db = await dbHelper.database;
      const changedAt = '2026-11-17T10:00:00.000000Z';

      try {
        await db.delete('tbl_pengaturan');
        dbHelper.clearCurrentUser();

        await dbHelper.updatePengaturan(
          {'tema': 'gelap'},
          terakhirDiperbarui: changedAt,
          userId: DatabaseHelper.legacyUserId,
        );
        expect(
          await dbHelper.getUnsyncedPengaturan(
            userId: DatabaseHelper.legacyUserId,
          ),
          isNotNull,
        );

        await dbHelper.setCurrentUserId(32);

        final pending = await dbHelper.getUnsyncedPengaturan(userId: 32);
        expect(pending, isNotNull);
        expect(pending!['tema'], 'gelap');
        expect(pending['terakhir_diperbarui'], changedAt);
        final timestamps = DatabaseHelper.decodeFieldTimestamps(
          pending['field_timestamps'],
          pending['terakhir_diperbarui'] as String?,
        );
        expect(timestamps['tema'], changedAt);
      } finally {
        await db.delete(
          'tbl_pengaturan',
          where: 'user_id IN (?, ?)',
          whereArgs: [32, DatabaseHelper.legacyUserId],
        );
        await dbHelper.setCurrentUserId(DatabaseHelper.legacyUserId);
      }
    });

    test('11. Pergantian akun tidak menukar pengaturan', () async {
      final dbHelper = DatabaseHelper.instance;
      final db = await dbHelper.database;

      try {
        await db.delete('tbl_pengaturan');
        dbHelper.clearCurrentUser();

        await dbHelper.updatePengaturan(
          {'tema': 'gelap-akun-33'},
          terakhirDiperbarui: '2026-11-17T10:00:00.000000Z',
          userId: 33,
        );
        await dbHelper.getPengaturan(userId: DatabaseHelper.legacyUserId);

        await dbHelper.setCurrentUserId(34);

        final account33 = await dbHelper.getPengaturan(userId: 33);
        expect(account33['tema'], 'gelap-akun-33');
        expect(account33['is_synch'], 0);

        final account34 = await dbHelper.getPengaturan(userId: 34);
        expect(account34['user_id'], 34);
        expect(account34['tema'], 'light');
        expect(account34['is_synch'], 1);
        expect(
          account34['terakhir_diperbarui'],
          DatabaseHelper.baselineTimestamp,
        );
      } finally {
        await db.delete(
          'tbl_pengaturan',
          where: 'user_id IN (?, ?, ?)',
          whereArgs: [33, 34, DatabaseHelper.legacyUserId],
        );
        await dbHelper.setCurrentUserId(DatabaseHelper.legacyUserId);
      }
    });

    test(
      '12. Baseline lama yang terlanjur pending tetap tidak dikirim',
      () async {
        final dbHelper = DatabaseHelper.instance;
        final db = await dbHelper.database;

        try {
          await db.delete('tbl_pengaturan');
          dbHelper.clearCurrentUser();
          await dbHelper.getPengaturan();

          // Simulasikan baris baseline lama yang terlanjur is_synch = 0.
          await db.update(
            'tbl_pengaturan',
            {'is_synch': 0},
            where: 'user_id = ?',
            whereArgs: [DatabaseHelper.legacyUserId],
          );
          expect(
            await dbHelper.getUnsyncedPengaturan(
              userId: DatabaseHelper.legacyUserId,
            ),
            isNull,
          );

          // Perubahan nyata dengan timestamp valid tetap terdeteksi.
          await dbHelper.updatePengaturan(
            {'tema': 'gelap'},
            terakhirDiperbarui: '2026-11-17T10:00:00.000000Z',
            userId: DatabaseHelper.legacyUserId,
          );
          final pending = await dbHelper.getUnsyncedPengaturan(
            userId: DatabaseHelper.legacyUserId,
          );
          expect(pending, isNotNull);
          expect(pending!['tema'], 'gelap');
        } finally {
          await db.delete('tbl_pengaturan');
          await dbHelper.setCurrentUserId(DatabaseHelper.legacyUserId);
        }
      },
    );
  });

  group('HistoryProvider Reactive Tests', () {
    test('1. Menambah riwayat secara otomatis memuat ulang state', () async {
      final provider = HistoryProvider();
      await provider.loadRiwayat();
      expect(provider.isEmpty, isTrue);

      final saved = await provider.addRiwayat(
        text: 'Ini baris pertama teks.\nIni baris kedua teks dokumen.',
        sumber: 'kamera',
      );

      expect(saved, isNotNull);
      expect(saved!.judul, 'Ini baris pertama teks.');
      expect(provider.items.length, 1);
      expect(provider.isEmpty, isFalse);
      expect(provider.errorMessage, isNull);
    });

    test(
      '2. Menghapus riwayat mengupdate state items di memori provider',
      () async {
        final provider = HistoryProvider();
        await provider.loadRiwayat();

        final saved = await provider.addRiwayat(
          text: 'Teks hapus provider',
          sumber: 'kamera',
        );
        expect(provider.items.length, 1);

        final success = await provider.deleteRiwayat(saved!.idRiwayat!);
        expect(success, isTrue);
        expect(provider.items.isEmpty, isTrue);
      },
    );

    test('3. Menghapus semua riwayat mengosongkan state provider', () async {
      final provider = HistoryProvider();
      await provider.loadRiwayat();

      await provider.addRiwayat(text: 'Item 1', sumber: 'kamera');
      await provider.addRiwayat(text: 'Item 2', sumber: 'galeri');
      expect(provider.items.length, 2);

      final cleared = await provider.clearAll();
      expect(cleared, isTrue);
      expect(provider.items.isEmpty, isTrue);
    });
  });
}
