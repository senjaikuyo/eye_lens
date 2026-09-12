import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/history_model.dart';
import '../models/settings_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('eyelens.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Tabel Konfigurasi Preferensi Pengguna
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tbl_pengaturan (
        id INTEGER PRIMARY KEY DEFAULT 1,
        mode_tema TEXT NOT NULL DEFAULT 'light',
        skala_font TEXT NOT NULL DEFAULT 'large',
        kecepatan_suara REAL NOT NULL DEFAULT 1.0,
        bahasa_suara TEXT NOT NULL DEFAULT 'id-ID',
        garis_panduan_aktif INTEGER NOT NULL DEFAULT 1,
        umpan_balik_getar INTEGER NOT NULL DEFAULT 1,
        zoom_bawaan REAL NOT NULL DEFAULT 1.0,
        terakhir_diperbarui DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Inisialisasi baris tunggal default pengaturan
    await db.execute('''
      INSERT OR IGNORE INTO tbl_pengaturan (id) VALUES (1)
    ''');

    // 2. Tabel Riwayat Hasil Ekstraksi Teks (History)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tbl_riwayat (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        judul TEXT NOT NULL,
        isi_teks TEXT NOT NULL,
        jumlah_kata INTEGER NOT NULL DEFAULT 0,
        tanggal_pindai DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Trigger Otomatis Pembatasan 50 Catatan Terbaru (Anti Scroll Fatigue)
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_limit_riwayat_50
      AFTER INSERT ON tbl_riwayat
      BEGIN
        DELETE FROM tbl_riwayat
        WHERE id NOT IN (
          SELECT id FROM tbl_riwayat ORDER BY id DESC LIMIT 50
        );
      END
    ''');
  }

  // --- CRUD PENGATURAN ---

  Future<SettingsModel> getSettings() async {
    final db = await instance.database;
    final result = await db.query('tbl_pengaturan', where: 'id = ?', whereArgs: [1]);
    if (result.isNotEmpty) {
      return SettingsModel.fromMap(result.first);
    } else {
      final defaultSettings = SettingsModel();
      await db.insert('tbl_pengaturan', defaultSettings.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      return defaultSettings;
    }
  }

  Future<int> updateSettings(SettingsModel settings) async {
    final db = await instance.database;
    return await db.update(
      'tbl_pengaturan',
      settings.toMap(),
      where: 'id = ?',
      whereArgs: [1],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- CRUD RIWAYAT ---

  Future<int> insertHistory(String fullText) async {
    if (fullText.trim().isEmpty) return 0;
    final db = await instance.database;
    final judul = HistoryModel.generateJudul(fullText);
    final count = HistoryModel.countWords(fullText);
    final history = HistoryModel(
      judul: judul,
      isiTeks: fullText.trim(),
      jumlahKata: count,
      tanggalPindai: DateTime.now().toIso8601String(),
    );
    return await db.insert('tbl_riwayat', history.toMap());
  }

  Future<List<HistoryModel>> getAllHistory() async {
    final db = await instance.database;
    final result = await db.query('tbl_riwayat', orderBy: 'id DESC');
    return result.map((map) => HistoryModel.fromMap(map)).toList();
  }

  Future<int> deleteHistory(int id) async {
    final db = await instance.database;
    return await db.delete('tbl_riwayat', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> clearAllHistory() async {
    final db = await instance.database;
    return await db.delete('tbl_riwayat');
  }
}
