import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:eye_lens/features/auth/logic/auth_service.dart';
import 'package:eye_lens/core/services/database_helper.dart';

/// Hasil satu kali percobaan sinkronisasi.
class SyncResult {
  final bool success;
  final int syncedCount;
  final bool settingsSynced;
  final String? message;

  const SyncResult({
    required this.success,
    this.syncedCount = 0,
    this.settingsSynced = false,
    this.message,
  });
}

class _SettingsPushResult {
  final bool success;
  final Map<String, dynamic>? serverPengaturan;

  const _SettingsPushResult({required this.success, this.serverPengaturan});
}

/// Mengirim data lokal yang belum tersinkronisasi ke backend Laravel.
///
/// Identitas pengguna selalu berasal dari [AuthService] (token Sanctum),
/// bukan dari body request. Seluruh siklus memakai `userId` yang sama
/// (di-pin di awal) agar respons akun lama tidak pernah menimpa akun baru
/// ketika pengguna berganti akun saat request masih berjalan.
class SyncService {
  final DatabaseHelper _dbHelper;
  final AuthService _authService;
  final http.Client _client;
  final Connectivity _connectivity;

  static const int maxRiwayatPerBatch = 100;

  /// Instance bersama untuk seluruh pemanggil produksi.
  static final SyncService instance = SyncService();

  /// Mutex bersama: HistoryProvider dan SyncCoordinator masing-masing membuat
  /// instance SyncService, sehingga flag harus bersifat statis agar dua instance
  /// tidak pernah menjalankan sinkronisasi bersamaan di dalam isolate yang sama.
  static bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  SyncService({
    DatabaseHelper? dbHelper,
    AuthService? authService,
    http.Client? client,
    Connectivity? connectivity,
  }) : _dbHelper = dbHelper ?? DatabaseHelper.instance,
       _authService = authService ?? AuthService(),
       _client = client ?? http.Client(),
       _connectivity = connectivity ?? Connectivity();

  Future<bool> isOnline() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.any((result) => result != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  /// Satu siklus sinkronisasi: pengaturan (PUT) lalu riwayat (POST).
  Future<SyncResult> syncPending() async {
    if (_isSyncing) {
      return const SyncResult(
        success: false,
        message: 'Sinkronisasi sedang berlangsung',
      );
    }
    _isSyncing = true;

    try {
      // Snapshot tunggal: token dan user_id selalu berasal dari sesi yang sama.
      final session = await _authService.getSession();
      final token = session?.token;
      final userId = session?.userId;

      if (token == null || token.isEmpty || userId == null) {
        return const SyncResult(success: false, message: 'Sesi tidak valid');
      }

      // Pastikan scope database lokal sesuai akun yang sedang login.
      await _dbHelper.setCurrentUserId(userId);

      if (!await isOnline()) {
        return const SyncResult(
          success: false,
          message: 'Tidak ada koneksi internet',
        );
      }

      // Pastikan baris lokal ada. Baris bawaan tidak dianggap perubahan.
      await _dbHelper.getPengaturan(userId: userId);
      final pendingPengaturan = await _dbHelper.getUnsyncedPengaturan(
        userId: userId,
      );

      var settingsSynced = false;
      if (pendingPengaturan != null) {
        final push = await _pushPengaturan(token, pendingPengaturan);
        if (push.success) {
          settingsSynced = true;
          await _reconcilePengaturan(
            serverPengaturan: push.serverPengaturan,
            pendingPengaturan: pendingPengaturan,
            userId: userId,
          );
        }
      }

      // Batasi 100 sesuai validasi backend. Sisa data akan dicoba pada
      // pemicu sinkronisasi berikutnya.
      final pending = await _dbHelper.getUnsyncedRiwayat(
        userId: userId,
        limit: maxRiwayatPerBatch,
      );

      final payload = <String, dynamic>{
        'riwayat': pending
            .map(
              (row) => <String, dynamic>{
                'client_uuid': row['client_uuid'],
                'judul': row['judul'],
                'isi_teks': row['isi_teks'],
                'jumlah_kata': row['jumlah_kata'],
                'sumber': row['sumber'],
                'waktu': row['waktu'],
              },
            )
            .toList(),
      };

      final response = await _client
          .post(
            Uri.parse('${AuthService.baseUrl}/sync'),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return SyncResult(
          success: false,
          settingsSynced: settingsSynced,
          message: 'Server merespons ${response.statusCode}',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> ||
          decoded['status'] != 'success' ||
          decoded['synced_riwayat'] is! List) {
        return SyncResult(
          success: false,
          settingsSynced: settingsSynced,
          message: 'Respons server tidak valid',
        );
      }

      // Hanya tandai baris yang benar-benar dikonfirmasi server DAN masih
      // memiliki updated_at yang sama dengan saat dikirim.
      final acknowledged = (decoded['synced_riwayat'] as List)
          .whereType<String>()
          .toSet();
      final confirmations = pending
          .where((row) => acknowledged.contains(row['client_uuid']))
          .map(
            (row) => <String, dynamic>{
              'client_uuid': row['client_uuid'],
              'updated_at': row['updated_at'],
            },
          )
          .toList();
      final changed = await _dbHelper.confirmRiwayatSynced(
        confirmations,
        userId: userId,
      );

      // Tarik pengaturan server hanya bila tidak ada perubahan lokal yang
      // gagal dikirim. Jika push gagal, jangan menandai snapshot sebagai
      // tersinkron atau menimpa perubahan lokal yang belum terkirim.
      if (pendingPengaturan == null) {
        final serverPengaturan = decoded['pengaturan'] is Map<String, dynamic>
            ? decoded['pengaturan'] as Map<String, dynamic>
            : null;
        await _reconcilePengaturan(
          serverPengaturan: serverPengaturan,
          pendingPengaturan: null,
          userId: userId,
        );
      }

      return SyncResult(
        success: true,
        syncedCount: changed,
        settingsSynced: settingsSynced,
      );
    } on TimeoutException {
      return const SyncResult(success: false, message: 'Permintaan timeout');
    } on http.ClientException {
      return const SyncResult(success: false, message: 'Koneksi terputus');
    } catch (e) {
      // Jangan memuat token atau isi data ke dalam log.
      debugPrint('Sinkronisasi gagal: ${e.runtimeType}');
      return const SyncResult(success: false, message: 'Sinkronisasi gagal');
    } finally {
      _isSyncing = false;
    }
  }

  Future<_SettingsPushResult> _pushPengaturan(
    String token,
    Map<String, dynamic> pending,
  ) async {
    try {
      final response = await _client
          .put(
            Uri.parse('${AuthService.baseUrl}/pengaturan'),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(_settingsPayload(pending)),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const _SettingsPushResult(success: false);
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> || decoded['status'] != 'success') {
        return const _SettingsPushResult(success: false);
      }

      final server = decoded['pengaturan'];
      return _SettingsPushResult(
        success: true,
        serverPengaturan: server is Map<String, dynamic> ? server : null,
      );
    } on TimeoutException {
      return const _SettingsPushResult(success: false);
    } on http.ClientException {
      return const _SettingsPushResult(success: false);
    } catch (_) {
      return const _SettingsPushResult(success: false);
    }
  }

  Map<String, dynamic> _settingsPayload(Map<String, dynamic> row) {
    return <String, dynamic>{
      'tema': row['tema'],
      'ukuran_teks': row['ukuran_teks'],
      'warna_kursor': row['warna_kursor'],
      'kontras': row['kontras'],
      'otomatis_putar': ((row['otomatis_putar'] as num?)?.toInt() ?? 1) != 0,
      'kecepatan_suara': (row['kecepatan_suara'] as num?)?.toDouble() ?? 1.0,
      'bahasa_suara': row['bahasa_suara'],
      'bahasa_aplikasi': row['bahasa_aplikasi'],
      'terakhir_diperbarui': row['terakhir_diperbarui'],
      'field_timestamps': DatabaseHelper.decodeFieldTimestamps(
        row['field_timestamps'],
        row['terakhir_diperbarui'] as String?,
      ),
    };
  }

  /// Menerapkan aturan "terbaru menang" PER-FIELD untuk pengaturan.
  Future<void> _reconcilePengaturan({
    required Map<String, dynamic>? serverPengaturan,
    required Map<String, dynamic>? pendingPengaturan,
    required int userId,
  }) async {
    if (serverPengaturan == null) return;

    // Baca ulang lokal untuk mendeteksi perubahan yang terjadi saat request.
    final latestLocal = await _dbHelper.getPengaturan(userId: userId);
    final snapshotTime = pendingPengaturan?['terakhir_diperbarui'] as String?;
    final latestTime = latestLocal['terakhir_diperbarui'] as String?;

    // Snapshot dianggap belum berubah bila timestamp baris masih sama.
    // Bila tidak ada yang dikirim, baris harus sudah tersinkron (is_synch=1).
    final unchangedSinceSend = pendingPengaturan == null
        ? ((latestLocal['is_synch'] as num?)?.toInt() ?? 0) == 1
        : snapshotTime != null && latestTime == snapshotTime;

    await _dbHelper.applyServerPengaturan(
      serverPengaturan,
      userId: userId,
      markSynced: unchangedSinceSend,
    );
  }
}
