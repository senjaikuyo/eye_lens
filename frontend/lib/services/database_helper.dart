import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/pengaturan_model.dart';
import '../models/riwayat_model.dart';

/// Penyimpanan lokal (Sqflite) EyeLens.
///
/// Sejak versi 2 setiap baris memiliki [user_id] dan [is_synch].
/// Nilai user_id = -1 adalah sentinel untuk data legacy hasil migrasi dari
/// skema versi 1 yang belum memiliki identitas pengguna; data tersebut akan
/// direasign ke pengguna aktif pada saat login pertama setelah upgrade.
class DatabaseHelper extends ChangeNotifier {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static Completer<Database>? _dbOpenCompleter;

  static DatabaseHelper get instance => _instance;
  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  static const int legacyUserId = -1;
  static const int schemaVersion = 4;

  /// Field pengaturan yang disinkronkan ke backend. `tampilkan_warna_kursor`
  /// sengaja tidak termasuk karena hanya berlaku lokal.
  static const List<String> syncedPengaturanFields = [
    'tema',
    'ukuran_teks',
    'warna_kursor',
    'kontras',
    'otomatis_putar',
    'kecepatan_suara',
    'bahasa_suara',
    'bahasa_aplikasi',
  ];

  int _currentUserId = legacyUserId;
  int get currentUserId => _currentUserId;

  int _scope(int? userId) => userId ?? _currentUserId;

  /// Menetapkan pengguna aktif. Data legacy (user_id = -1) dipindahkan ke
  /// pengguna ini di dalam satu transaksi lokal.
  Future<void> setCurrentUserId(int userId) async {
    if (_currentUserId == userId) return;
    _currentUserId = userId;
    await reassignLegacyData(userId);
    // Provider pengaturan mendengarkan perubahan scope agar tidak menampilkan
    // pengaturan akun sebelumnya setelah pergantian akun.
    notifyListeners();
  }

  void clearCurrentUser() {
    if (_currentUserId == legacyUserId) return;
    _currentUserId = legacyUserId;
    notifyListeners();
  }

  /// Timestamp baseline untuk baris pengaturan bawaan. Baris seperti ini
  /// tidak boleh menang atas pengaturan server pada aturan "terbaru menang".
  static String get baselineTimestamp =>
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toIso8601String();

  /// Timestamp baseline per field agar baris bawaan tidak menang atas server.
  static String get baselineFieldTimestamps => jsonEncode({
    for (final field in syncedPengaturanFields) field: baselineTimestamp,
  });

  /// Membaca peta timestamp per field. Baris lama tanpa peta memakai
  /// `terakhir_diperbarui` sebagai timestamp seluruh field.
  static Map<String, String> decodeFieldTimestamps(
    dynamic raw,
    String? fallback,
  ) {
    final fallbackTime = fallback ?? baselineTimestamp;
    final result = <String, String>{
      for (final field in syncedPengaturanFields) field: fallbackTime,
    };

    if (raw is Map) {
      for (final field in syncedPengaturanFields) {
        final value = raw[field];
        if (value is String && DateTime.tryParse(value) != null) {
          result[field] = value;
        }
      }
    } else if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          for (final field in syncedPengaturanFields) {
            final value = decoded[field];
            if (value is String && DateTime.tryParse(value) != null) {
              result[field] = value;
            }
          }
        }
      } catch (_) {
        // Peta rusak: gunakan fallback baris.
      }
    }
    return result;
  }

  static String maxTimestamp(Iterable<String> values) {
    DateTime? max;
    String? maxRaw;
    for (final value in values) {
      final parsed = DateTime.tryParse(value);
      if (parsed == null) continue;
      if (max == null || parsed.isAfter(max)) {
        max = parsed;
        maxRaw = value;
      }
    }
    return maxRaw ?? baselineTimestamp;
  }

  /// True bila baris hanya berisi nilai bawaan (belum pernah diubah pengguna).
  bool isBaselinePengaturan(Map<String, dynamic> row) {
    return (row['tema'] == 'light' || row['tema'] == 'sistem') &&
        row['ukuran_teks'] == 18 &&
        row['warna_kursor'] == '#FACC15' &&
        ((row['tampilkan_warna_kursor'] as num?)?.toInt() ?? 1) == 1 &&
        row['kontras'] == 'normal' &&
        ((row['otomatis_putar'] as num?)?.toInt() ?? 1) == 1 &&
        ((row['kecepatan_suara'] as num?)?.toDouble() ?? 1.0) == 1.0 &&
        row['bahasa_suara'] == 'id-ID' &&
        row['bahasa_aplikasi'] == 'id';
  }

  Future<Database> get database {
    final existing = _database;
    if (existing != null) return Future.value(existing);

    final pending = _dbOpenCompleter;
    if (pending != null) return pending.future;

    return _openDatabaseOnce();
  }

  /// Satu future dibagikan ke semua pemanggil agar error inisialisasi
  /// ditangani oleh masing-masing pemanggil, bukan sebagai error completer
  /// yang tidak terikat (unhandled).
  Future<Database> _openDatabaseOnce() {
    final completer = Completer<Database>();
    _dbOpenCompleter = completer;

    _initDatabase()
        .then(
          (db) {
            _database = db;
            if (!completer.isCompleted) {
              completer.complete(db);
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!completer.isCompleted) {
              completer.completeError(error, stackTrace);
            }
          },
        )
        .whenComplete(() {
          _dbOpenCompleter = null;
        });

    return completer.future;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'eyelens.db');

    return await openDatabase(
      path,
      version: schemaVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// UUID v4 sederhana tanpa dependensi tambahan.
  static String newClientUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<void> _createSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE tbl_pengaturan (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL UNIQUE,
        tema TEXT NOT NULL DEFAULT 'sistem',
        ukuran_teks INTEGER NOT NULL DEFAULT 18,
        warna_kursor TEXT NOT NULL DEFAULT '#FACC15',
        tampilkan_warna_kursor INTEGER NOT NULL DEFAULT 1,
        kontras TEXT NOT NULL DEFAULT 'normal',
        otomatis_putar INTEGER NOT NULL DEFAULT 1,
        kecepatan_suara REAL NOT NULL DEFAULT 1.0,
        bahasa_suara TEXT NOT NULL DEFAULT 'id-ID',
        bahasa_aplikasi TEXT NOT NULL DEFAULT 'id',
        terakhir_diperbarui TEXT NOT NULL,
        field_timestamps TEXT,
        is_synch INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE tbl_riwayat (
        id_riwayat INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        client_uuid TEXT NOT NULL UNIQUE,
        judul TEXT NOT NULL,
        isi_teks TEXT NOT NULL,
        jumlah_kata INTEGER NOT NULL,
        sumber TEXT NOT NULL,
        waktu TEXT NOT NULL,
        is_synch INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_riwayat_waktu
      ON tbl_riwayat (user_id, waktu DESC, id_riwayat DESC)
    ''');

    await db.execute('''
      CREATE INDEX idx_riwayat_sync
      ON tbl_riwayat (user_id, is_synch, waktu ASC)
    ''');

    // Baris yang BELUM tersinkron tidak pernah dihapus otomatis.
    await db.execute('''
      CREATE TRIGGER trg_limit_riwayat_50 AFTER INSERT ON tbl_riwayat
      BEGIN
        DELETE FROM tbl_riwayat
        WHERE user_id = NEW.user_id
          AND is_synch = 1
          AND id_riwayat NOT IN (
            SELECT id_riwayat FROM tbl_riwayat
            WHERE user_id = NEW.user_id AND is_synch = 1
            ORDER BY waktu DESC, id_riwayat DESC LIMIT 50
          );
      END;
    ''');

    // Retensi juga harus berlaku saat baris berubah dari belum tersinkron
    // menjadi tersinkron (mis. setelah konfirmasi batch sinkronisasi).
    await db.execute('''
      CREATE TRIGGER trg_limit_riwayat_50_update
      AFTER UPDATE OF is_synch ON tbl_riwayat
      WHEN NEW.is_synch = 1
      BEGIN
        DELETE FROM tbl_riwayat
        WHERE user_id = NEW.user_id
          AND is_synch = 1
          AND id_riwayat NOT IN (
            SELECT id_riwayat FROM tbl_riwayat
            WHERE user_id = NEW.user_id AND is_synch = 1
            ORDER BY waktu DESC, id_riwayat DESC LIMIT 50
          );
      END;
    ''');
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createSchema(db);
  }

  /// Migrasi v1 -> v2 -> v3 -> v4. Semua langkah berada dalam satu transaksi
  /// lokal (kecuali ALTER TABLE yang memang harus berurutan).
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion >= 4) return;

    if (oldVersion == 2 || oldVersion == 3) {
      if (oldVersion == 2) {
        // v3 menambahkan preferensi tampilan kursor yang hanya berlaku lokal
        // (tidak dikirim ke backend karena tidak ada kolomnya di kontrak API).
        await db.execute(
          'ALTER TABLE tbl_pengaturan '
          'ADD COLUMN tampilkan_warna_kursor INTEGER NOT NULL DEFAULT 1',
        );
      }
      // v4 menyimpan timestamp per field untuk konflik newest-wins per-field.
      await db.execute(
        'ALTER TABLE tbl_pengaturan ADD COLUMN field_timestamps TEXT',
      );
      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS trg_limit_riwayat_50_update
        AFTER UPDATE OF is_synch ON tbl_riwayat
        WHEN NEW.is_synch = 1
        BEGIN
          DELETE FROM tbl_riwayat
          WHERE user_id = NEW.user_id
            AND is_synch = 1
            AND id_riwayat NOT IN (
              SELECT id_riwayat FROM tbl_riwayat
              WHERE user_id = NEW.user_id AND is_synch = 1
              ORDER BY waktu DESC, id_riwayat DESC LIMIT 50
            );
        END;
      ''');
      return;
    }

    if (oldVersion >= 2) return;

    await db.transaction((txn) async {
      await txn.execute('DROP TRIGGER IF EXISTS trg_limit_riwayat_50');
      await txn.execute('DROP INDEX IF EXISTS idx_riwayat_waktu');

      await txn.execute('ALTER TABLE tbl_riwayat RENAME TO tbl_riwayat_v1');
      await txn.execute(
        'ALTER TABLE tbl_pengaturan RENAME TO tbl_pengaturan_v1',
      );

      await _createSchema(txn);

      final oldRiwayat = await txn.query('tbl_riwayat_v1');
      final now = DateTime.now().toIso8601String();
      for (final row in oldRiwayat) {
        await txn.insert('tbl_riwayat', {
          'id_riwayat': row['id_riwayat'],
          'user_id': legacyUserId,
          'client_uuid': newClientUuid(),
          'judul': row['judul'] ?? '',
          'isi_teks': row['isi_teks'] ?? '',
          'jumlah_kata': row['jumlah_kata'] ?? 0,
          'sumber': row['sumber'] ?? 'kamera',
          'waktu': row['waktu'] ?? now,
          'is_synch': 0,
          'updated_at': row['waktu'] ?? now,
        });
      }

      final oldPengaturan = await txn.query(
        'tbl_pengaturan_v1',
        where: 'id = ?',
        whereArgs: [1],
        limit: 1,
      );
      if (oldPengaturan.isNotEmpty) {
        final row = oldPengaturan.first;
        await txn.insert('tbl_pengaturan', {
          'user_id': legacyUserId,
          'tema': row['tema'] ?? 'sistem',
          'ukuran_teks': row['ukuran_teks'] ?? 18,
          'warna_kursor': row['warna_kursor'] ?? '#FACC15',
          'kontras': row['kontras'] ?? 'normal',
          'otomatis_putar': row['otomatis_putar'] ?? 1,
          'kecepatan_suara': row['kecepatan_suara'] ?? 1.0,
          'bahasa_suara': row['bahasa_suara'] ?? 'id-ID',
          'bahasa_aplikasi': row['bahasa_aplikasi'] ?? 'id',
          'terakhir_diperbarui': row['terakhir_diperbarui'] ?? now,
          'is_synch': 0,
        });
      }

      await txn.execute('DROP TABLE tbl_riwayat_v1');
      await txn.execute('DROP TABLE tbl_pengaturan_v1');
    });
  }

  /// Memindahkan data legacy ke [userId]. Tidak ada baris yang dihapus.
  Future<void> reassignLegacyData(int userId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE tbl_riwayat SET user_id = ?, is_synch = 0 WHERE user_id = ?',
        [userId, legacyUserId],
      );

      final legacy = await txn.query(
        'tbl_pengaturan',
        where: 'user_id = ?',
        whereArgs: [legacyUserId],
        limit: 1,
      );
      if (legacy.isEmpty) return;

      final existing = await txn.query(
        'tbl_pengaturan',
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (existing.isEmpty) {
        await txn.update(
          'tbl_pengaturan',
          {'user_id': userId, 'is_synch': 0},
          where: 'user_id = ?',
          whereArgs: [legacyUserId],
        );
      } else {
        // Baris pengguna sudah ada. Terapkan aturan "terbaru menang" agar
        // data legacy tidak menimpa pengaturan yang lebih baru.
        final legacyTime = DateTime.tryParse(
          legacy.first['terakhir_diperbarui'] as String? ?? '',
        );
        final existingTime = DateTime.tryParse(
          existing.first['terakhir_diperbarui'] as String? ?? '',
        );
        final legacyIsNewer =
            legacyTime != null &&
            (existingTime == null || legacyTime.isAfter(existingTime));

        if (legacyIsNewer) {
          final merged = Map<String, dynamic>.from(legacy.first)
            ..remove('id')
            ..['user_id'] = userId
            ..['is_synch'] = 0;
          await txn.update(
            'tbl_pengaturan',
            merged,
            where: 'user_id = ?',
            whereArgs: [userId],
          );
        }
        await txn.delete(
          'tbl_pengaturan',
          where: 'user_id = ?',
          whereArgs: [legacyUserId],
        );
      }
    });
  }

  // --- Operasi tbl_pengaturan (selalu discoping oleh user aktif) ---

  Map<String, dynamic> _defaultPengaturanRow(int scope) => {
    'user_id': scope,
    // 'light' mempertahankan tampilan bawaan lama aplikasi. Nilai 'system'
    // dari backend tetap dipetakan ke ThemeMode.system oleh provider.
    'tema': 'light',
    'ukuran_teks': 18,
    'warna_kursor': '#FACC15',
    'tampilkan_warna_kursor': 1,
    'kontras': 'normal',
    'otomatis_putar': 1,
    'kecepatan_suara': 1.0,
    'bahasa_suara': 'id-ID',
    'bahasa_aplikasi': 'id',
    'terakhir_diperbarui': baselineTimestamp,
    'field_timestamps': baselineFieldTimestamps,
    // Baris bawaan bukan perubahan pengguna, jadi jangan dikirim ke server.
    // Ini mencegah perangkat baru menimpa pengaturan akun yang sudah ada.
    'is_synch': 1,
  };

  Future<Map<String, dynamic>> getPengaturan({int? userId}) async {
    final db = await database;
    final scope = _scope(userId);
    final res = await db.query(
      'tbl_pengaturan',
      where: 'user_id = ?',
      whereArgs: [scope],
      limit: 1,
    );
    if (res.isNotEmpty) return res.first;

    final defaultSettings = _defaultPengaturanRow(scope);
    await db.insert(
      'tbl_pengaturan',
      defaultSettings,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final inserted = await db.query(
      'tbl_pengaturan',
      where: 'user_id = ?',
      whereArgs: [scope],
      limit: 1,
    );
    return inserted.isNotEmpty ? inserted.first : defaultSettings;
  }

  /// Menjadikan baris bawaan sebagai baseline yang tidak perlu disinkronkan.
  Future<int> resetPengaturanBaseline({int? userId}) async {
    final db = await database;
    final scope = _scope(userId);
    final current = await getPengaturan(userId: scope);
    if (!isBaselinePengaturan(current)) return 0;
    return await db.update(
      'tbl_pengaturan',
      {
        'terakhir_diperbarui': baselineTimestamp,
        'field_timestamps': baselineFieldTimestamps,
        'is_synch': 1,
      },
      where: 'user_id = ?',
      whereArgs: [scope],
    );
  }

  /// Menyimpan seluruh snapshot pengaturan dan menandainya belum sinkron.
  Future<int> updatePengaturan(
    Map<String, dynamic> data, {
    String? terakhirDiperbarui,
    int? userId,
  }) {
    return updatePengaturanFields(
      data,
      terakhirDiperbarui: terakhirDiperbarui,
      userId: userId,
    );
  }

  /// Memperbarui hanya field yang diberikan dan mencatat timestamp per field.
  ///
  /// Perubahan pada field lokal (`tampilkan_warna_kursor`) tidak menandai
  /// pengaturan perlu disinkronkan karena tidak ada di kontrak backend.
  Future<int> updatePengaturanFields(
    Map<String, dynamic> fields, {
    String? terakhirDiperbarui,
    int? userId,
  }) async {
    final db = await database;
    final scope = _scope(userId);
    final changedAt =
        terakhirDiperbarui ?? DateTime.now().toUtc().toIso8601String();

    final cleaned = Map<String, dynamic>.from(fields)
      ..remove('id')
      ..remove('user_id')
      ..remove('is_synch')
      ..remove('field_timestamps')
      ..remove('terakhir_diperbarui');
    if (cleaned.isEmpty) return 0;

    final syncedChanges = cleaned.keys
        .where(syncedPengaturanFields.contains)
        .toList();

    return await db.transaction((txn) async {
      var rows = await txn.query(
        'tbl_pengaturan',
        where: 'user_id = ?',
        whereArgs: [scope],
        limit: 1,
      );
      if (rows.isEmpty) {
        await txn.insert(
          'tbl_pengaturan',
          _defaultPengaturanRow(scope),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        rows = await txn.query(
          'tbl_pengaturan',
          where: 'user_id = ?',
          whereArgs: [scope],
          limit: 1,
        );
      }

      if (syncedChanges.isEmpty) {
        // Hanya preferensi lokal; jangan mengubah status sinkronisasi.
        return await txn.update(
          'tbl_pengaturan',
          cleaned,
          where: 'user_id = ?',
          whereArgs: [scope],
        );
      }

      final current = rows.first;
      final timestamps = decodeFieldTimestamps(
        current['field_timestamps'],
        current['terakhir_diperbarui'] as String?,
      );
      for (final field in syncedChanges) {
        timestamps[field] = changedAt;
      }

      final values = <String, dynamic>{
        ...cleaned,
        'field_timestamps': jsonEncode(timestamps),
        'terakhir_diperbarui': maxTimestamp(timestamps.values),
        'is_synch': 0,
      };

      return await txn.update(
        'tbl_pengaturan',
        values,
        where: 'user_id = ?',
        whereArgs: [scope],
      );
    });
  }

  Future<Map<String, dynamic>?> getUnsyncedPengaturan({int? userId}) async {
    final db = await database;
    final res = await db.query(
      'tbl_pengaturan',
      where: 'user_id = ? AND is_synch = ?',
      whereArgs: [_scope(userId), 0],
      limit: 1,
    );
    return res.isNotEmpty ? res.first : null;
  }

  /// Konfirmasi hanya diberikan setelah backend menjawab sukses.
  Future<int> confirmPengaturanSynced(
    String terakhirDiperbarui, {
    int? userId,
  }) async {
    final db = await database;
    return await db.transaction((txn) async {
      return await txn.update(
        'tbl_pengaturan',
        {'is_synch': 1},
        where: 'user_id = ? AND terakhir_diperbarui = ? AND is_synch = 0',
        whereArgs: [_scope(userId), terakhirDiperbarui],
      );
    });
  }

  /// Menggabungkan pengaturan server dengan lokal memakai aturan
  /// "terbaru menang" PER-FIELD berdasarkan timestamp masing-masing field.
  ///
  /// Field lokal yang lebih baru tidak ditimpa. [markSynced] hanya boleh true
  /// bila tidak ada perubahan lokal sejak snapshot yang dikirim.
  Future<int> applyServerPengaturan(
    Map<String, dynamic> data, {
    int? userId,
    bool markSynced = true,
  }) async {
    final db = await database;
    final scope = _scope(userId);

    final changed = await db.transaction((txn) async {
      final rows = await txn.query(
        'tbl_pengaturan',
        where: 'user_id = ?',
        whereArgs: [scope],
        limit: 1,
      );
      if (rows.isEmpty) return 0;

      final current = rows.first;
      final localTimestamps = decodeFieldTimestamps(
        current['field_timestamps'],
        current['terakhir_diperbarui'] as String?,
      );
      final serverTimestamps = decodeFieldTimestamps(
        data['field_timestamps'],
        data['terakhir_diperbarui'] as String?,
      );

      final values = <String, dynamic>{};
      final mergedTimestamps = Map<String, String>.from(localTimestamps);

      for (final field in syncedPengaturanFields) {
        final serverValue = data[field];
        if (serverValue == null) continue;

        final serverTime = DateTime.tryParse(serverTimestamps[field] ?? '');
        if (serverTime == null) continue;
        final localTime = DateTime.tryParse(localTimestamps[field] ?? '');
        final serverIsNewer =
            localTime == null || !serverTime.isBefore(localTime);

        if (serverIsNewer) {
          values[field] = _normalizePengaturanValue(field, serverValue);
          mergedTimestamps[field] = serverTimestamps[field]!;
        }
      }

      values['field_timestamps'] = jsonEncode(mergedTimestamps);
      values['terakhir_diperbarui'] = maxTimestamp(mergedTimestamps.values);
      if (markSynced) {
        values['is_synch'] = 1;
      }

      return await txn.update(
        'tbl_pengaturan',
        values,
        where: 'user_id = ?',
        whereArgs: [scope],
      );
    });

    if (changed > 0) {
      // Beri tahu provider agar UI langsung memakai nilai server.
      notifyListeners();
    }
    return changed;
  }

  dynamic _normalizePengaturanValue(String field, dynamic value) {
    switch (field) {
      case 'otomatis_putar':
        if (value is bool) return value ? 1 : 0;
        return (value as num?)?.toInt() ?? 1;
      case 'kecepatan_suara':
        return (value as num?)?.toDouble() ?? 1.0;
      case 'ukuran_teks':
        return (value as num?)?.toInt() ?? 18;
      default:
        return value;
    }
  }

  // --- Operasi tbl_riwayat (selalu discoping oleh user aktif) ---

  Future<int> insertRiwayat({
    required String judul,
    required String isiTeks,
    required int jumlahKata,
    required String sumber,
    DateTime? waktu,
    String? clientUuid,
  }) async {
    final db = await database;
    final waktuStr = (waktu ?? DateTime.now()).toIso8601String();
    return await db.insert('tbl_riwayat', {
      'user_id': _currentUserId,
      'client_uuid': clientUuid ?? newClientUuid(),
      'judul': judul,
      'isi_teks': isiTeks,
      'jumlah_kata': jumlahKata,
      'sumber': sumber,
      'waktu': waktuStr,
      'is_synch': 0,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getRiwayatList({int limit = 50}) async {
    final db = await database;
    return await db.query(
      'tbl_riwayat',
      where: 'user_id = ?',
      whereArgs: [_currentUserId],
      orderBy: 'waktu DESC, id_riwayat DESC',
      limit: limit,
    );
  }

  Future<Map<String, dynamic>?> getRiwayatById(int id) async {
    final db = await database;
    final res = await db.query(
      'tbl_riwayat',
      where: 'id_riwayat = ? AND user_id = ?',
      whereArgs: [id, _currentUserId],
      limit: 1,
    );
    return res.isNotEmpty ? res.first : null;
  }

  Future<int> deleteRiwayatById(int id) async {
    final db = await database;
    return await db.delete(
      'tbl_riwayat',
      where: 'id_riwayat = ? AND user_id = ?',
      whereArgs: [id, _currentUserId],
    );
  }

  Future<int> deleteRiwayat(int id) => deleteRiwayatById(id);

  Future<int> clearAllRiwayat() async {
    final db = await database;
    return await db.delete(
      'tbl_riwayat',
      where: 'user_id = ?',
      whereArgs: [_currentUserId],
    );
  }

  Future<int> getRiwayatCount() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM tbl_riwayat WHERE user_id = ?', [
        _currentUserId,
      ]),
    );
    return count ?? 0;
  }

  Future<List<Map<String, dynamic>>> getUnsyncedRiwayat({
    int? userId,
    int? limit,
  }) async {
    final db = await database;
    return await db.query(
      'tbl_riwayat',
      where: 'user_id = ? AND is_synch = ?',
      whereArgs: [_scope(userId), 0],
      orderBy: 'waktu ASC',
      limit: limit,
    );
  }

  /// Kompatibilitas dengan pemanggil lama/tes: tandai berdasarkan id lokal.
  Future<int> markRiwayatSynced(List<int> ids) async {
    if (ids.isEmpty) return 0;
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    return await db.rawUpdate(
      'UPDATE tbl_riwayat SET is_synch = 1 '
      'WHERE user_id = ? AND is_synch = 0 AND id_riwayat IN ($placeholders)',
      [_currentUserId, ...ids],
    );
  }

  /// Digunakan oleh [SyncService]. Hanya baris yang masih `is_synch = 0`
  /// DAN belum berubah (`updated_at` sama dengan saat dikirim) yang ditandai.
  /// Ini mencegah data yang diedit saat sync ikut hilang statusnya.
  Future<int> confirmRiwayatSynced(
    List<Map<String, dynamic>> confirmations, {
    int? userId,
  }) async {
    if (confirmations.isEmpty) return 0;
    final db = await database;
    final scope = _scope(userId);
    return await db.transaction((txn) async {
      var changed = 0;
      for (final item in confirmations) {
        changed += await txn.update(
          'tbl_riwayat',
          {'is_synch': 1},
          where:
              'user_id = ? AND client_uuid = ? AND updated_at = ? '
              'AND is_synch = 0',
          whereArgs: [scope, item['client_uuid'], item['updated_at']],
        );
      }
      return changed;
    });
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
    return await insertRiwayat(
      judul: model.judul,
      isiTeks: model.isiTeks,
      jumlahKata: model.jumlahKata,
      sumber: model.sumber,
      waktu: model.waktuDateTime,
      clientUuid: model.clientUuid.isEmpty ? null : model.clientUuid,
    );
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
    _dbOpenCompleter = null;
  }
}
