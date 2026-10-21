import 'dart:async';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/pengaturan_model.dart';
import '../models/riwayat_model.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'eyelens.db');

    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Tabel tbl_pengaturan (id = 1 constraint)
    await db.execute('''
      CREATE TABLE tbl_pengaturan (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        tema TEXT NOT NULL DEFAULT 'sistem',
        ukuran_teks INTEGER NOT NULL DEFAULT 18,
        warna_kursor TEXT NOT NULL DEFAULT '#FACC15',
        kontras TEXT NOT NULL DEFAULT 'normal',
        otomatis_putar INTEGER NOT NULL DEFAULT 1,
        kecepatan_suara REAL NOT NULL DEFAULT 1.0,
        bahasa_suara TEXT NOT NULL DEFAULT 'id-ID',
        bahasa_aplikasi TEXT NOT NULL DEFAULT 'id',
        terakhir_diperbarui TEXT NOT NULL
      )
    ''');

    // Seed default pengaturan
    final nowIso = DateTime.now().toIso8601String();
    await db.insert('tbl_pengaturan', {
      'id': 1,
      'tema': 'sistem',
      'ukuran_teks': 18,
      'warna_kursor': '#FACC15',
      'kontras': 'normal',
      'otomatis_putar': 1,
      'kecepatan_suara': 1.0,
      'bahasa_suara': 'id-ID',
      'bahasa_aplikasi': 'id',
      'terakhir_diperbarui': nowIso,
    });

    // 2. Tabel tbl_riwayat
    await db.execute('''
      CREATE TABLE tbl_riwayat (
        id_riwayat INTEGER PRIMARY KEY AUTOINCREMENT,
        judul TEXT NOT NULL,
        isi_teks TEXT NOT NULL,
        jumlah_kata INTEGER NOT NULL,
        sumber TEXT NOT NULL,
        waktu TEXT NOT NULL,
        status_sinkron INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 3. Trigger trg_limit_riwayat_50
    await db.execute('''
      CREATE TRIGGER trg_limit_riwayat_50 AFTER INSERT ON tbl_riwayat BEGIN
        DELETE FROM tbl_riwayat WHERE id_riwayat NOT IN (
          SELECT id_riwayat FROM tbl_riwayat ORDER BY waktu DESC, id_riwayat DESC LIMIT 50
        );
      END;
    ''');
  }

  // --- Operasi tbl_pengaturan ---

  Future<Map<String, dynamic>> getPengaturan() async {
    final db = await database;
    final res = await db.query(
      'tbl_pengaturan',
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (res.isNotEmpty) {
      return res.first;
    }

    final nowIso = DateTime.now().toIso8601String();
    final defaultSettings = <String, dynamic>{
      'id': 1,
      'tema': 'sistem',
      'ukuran_teks': 18,
      'warna_kursor': '#FACC15',
      'kontras': 'normal',
      'otomatis_putar': 1,
      'kecepatan_suara': 1.0,
      'bahasa_suara': 'id-ID',
      'bahasa_aplikasi': 'id',
      'terakhir_diperbarui': nowIso,
    };
    await db.insert(
      'tbl_pengaturan',
      defaultSettings,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return defaultSettings;
  }

  Future<int> updatePengaturan(Map<String, dynamic> data) async {
    final db = await database;
    final updated = Map<String, dynamic>.from(data);
    updated['id'] = 1;
    updated['terakhir_diperbarui'] = DateTime.now().toIso8601String();
    return await db.update(
      'tbl_pengaturan',
      updated,
      where: 'id = ?',
      whereArgs: [1],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- Operasi tbl_riwayat ---

  Future<int> insertRiwayat({
    required String judul,
    required String isiTeks,
    required int jumlahKata,
    required String sumber,
    DateTime? waktu,
    int statusSinkron = 0,
  }) async {
    final db = await database;
    final waktuStr = (waktu ?? DateTime.now()).toIso8601String();
    return await db.insert('tbl_riwayat', {
      'judul': judul,
      'isi_teks': isiTeks,
      'jumlah_kata': jumlahKata,
      'sumber': sumber,
      'waktu': waktuStr,
      'status_sinkron': statusSinkron,
    });
  }

  Future<List<Map<String, dynamic>>> getRiwayatList({int limit = 50}) async {
    final db = await database;
    return await db.query(
      'tbl_riwayat',
      orderBy: 'waktu DESC, id_riwayat DESC',
      limit: limit,
    );
  }

  Future<Map<String, dynamic>?> getRiwayatById(int id) async {
    final db = await database;
    final res = await db.query(
      'tbl_riwayat',
      where: 'id_riwayat = ?',
      whereArgs: [id],
      limit: 1,
    );
    return res.isNotEmpty ? res.first : null;
  }

  Future<int> deleteRiwayatById(int id) async {
    final db = await database;
    return await db.delete(
      'tbl_riwayat',
      where: 'id_riwayat = ?',
      whereArgs: [id],
    );
  }

  Future<int> clearAllRiwayat() async {
    final db = await database;
    return await db.delete('tbl_riwayat');
  }

  Future<int> getRiwayatCount() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM tbl_riwayat'),
    );
    return count ?? 0;
  }

  Future<List<Map<String, dynamic>>> getUnsyncedRiwayat() async {
    final db = await database;
    return await db.query(
      'tbl_riwayat',
      where: 'status_sinkron = ?',
      whereArgs: [0],
      orderBy: 'waktu ASC',
    );
  }

  Future<int> markRiwayatSynced(List<int> ids) async {
    if (ids.isEmpty) return 0;
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    return await db.rawUpdate(
      'UPDATE tbl_riwayat SET status_sinkron = 1 WHERE id_riwayat IN ($placeholders)',
      ids,
    );
  }

  // --- Typed Model Helpers ---

  Future<PengaturanModel> getPengaturanModel() async {
    final map = await getPengaturan();
    return PengaturanModel.fromMap(map);
  }

  Future<int> updatePengaturanModel(PengaturanModel model) async {
    return await updatePengaturan(model.toMap());
  }

  Future<int> insertRiwayatModel(RiwayatModel model) async {
    final db = await database;
    return await db.insert('tbl_riwayat', model.toMap());
  }

  Future<List<RiwayatModel>> getRiwayatModelList({int limit = 50}) async {
    final list = await getRiwayatList(limit: limit);
    return list.map((map) => RiwayatModel.fromMap(map)).toList();
  }

  Future<RiwayatModel?> getRiwayatModelById(int id) async {
    final map = await getRiwayatById(id);
    return map != null ? RiwayatModel.fromMap(map) : null;
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
