import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:eye_lens/services/database_helper.dart';
import 'package:eye_lens/providers/history_provider.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final dbHelper = DatabaseHelper.instance;
    await dbHelper.clearAllRiwayat();
    final db = await dbHelper.database;
    await db.update('tbl_pengaturan', {
      'tema': 'sistem',
      'ukuran_teks': 18,
      'warna_kursor': '#FACC15',
      'kontras': 'normal',
      'otomatis_putar': 1,
      'kecepatan_suara': 1.0,
      'bahasa_suara': 'id-ID',
      'bahasa_aplikasi': 'id',
      'terakhir_diperbarui': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [1]);
  });

  tearDownAll(() async {
    await DatabaseHelper.instance.close();
  });

  group('DatabaseHelper SQLite Unit Tests', () {
    test('1. Insert dan get riwayat bekerja sesuai urutan waktu terbaru', () async {
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
    });

    test('2. Trigger trg_limit_riwayat_50 membatasi riwayat maksimal 50 entri', () async {
      final dbHelper = DatabaseHelper.instance;

      for (int i = 1; i <= 55; i++) {
        await dbHelper.insertRiwayat(
          judul: 'Dokumen $i',
          isiTeks: 'Teks dokumen ke-$i',
          jumlahKata: 3,
          sumber: 'kamera',
          waktu: DateTime(2026, 1, 1, 0, i),
        );
      }

      final count = await dbHelper.getRiwayatCount();
      expect(count, 50);

      final list = await dbHelper.getRiwayatModelList();
      expect(list.length, 50);
      expect(list.first.judul, 'Dokumen 55');
      expect(list.last.judul, 'Dokumen 6');
    });

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
        statusSinkron: 0,
      );
      final id2 = await dbHelper.insertRiwayat(
        judul: 'Unsynced 2',
        isiTeks: 'Teks 2',
        jumlahKata: 2,
        sumber: 'kamera',
        statusSinkron: 0,
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
      expect(initial['id'], 1);
      expect(initial['tema'], 'sistem');

      await dbHelper.updatePengaturan({
        'tema': 'gelap',
        'ukuran_teks': 24,
      });

      final updated = await dbHelper.getPengaturan();
      expect(updated['tema'], 'gelap');
      expect(updated['ukuran_teks'], 24);
    });
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

    test('2. Menghapus riwayat mengupdate state items di memori provider', () async {
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
    });

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
