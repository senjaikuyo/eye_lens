import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:eye_lens/core/models/history_model.dart';
import 'package:eye_lens/core/services/database_helper.dart';
import 'package:eye_lens/core/services/sync_service.dart';

class HistoryProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final SyncService _syncService = SyncService.instance;

  List<HistoryModel> _items = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _errorMessage;

  List<HistoryModel> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  bool get isEmpty => _items.isEmpty;
  String? get errorMessage => _errorMessage;

  HistoryProvider() {
    loadRiwayat();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> loadRiwayat() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _items = await _dbHelper.getRiwayatModelList();
    } catch (e) {
      _errorMessage = 'Gagal memuat riwayat';
      _items = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<HistoryModel?> addRiwayat({
    required String text,
    required String sumber,
    String? customTitle,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return null;

    String title = customTitle ?? '';
    if (title.isEmpty) {
      final firstLine = cleanText.split('\n').first.trim();
      if (firstLine.length > 30) {
        title = '${firstLine.substring(0, 30)}...';
      } else if (firstLine.isNotEmpty) {
        title = firstLine;
      } else {
        title = 'Teks Pindaian';
      }
    }

    final wordCount = cleanText
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .length;
    final waktu = DateTime.now().toIso8601String();

    final model = HistoryModel(
      clientUuid: DatabaseHelper.newClientUuid(),
      judul: title,
      isiTeks: cleanText,
      jumlahKata: wordCount,
      sumber: sumber,
      waktu: waktu,
      statusSinkron: 0,
    );

    try {
      final id = await _dbHelper.insertRiwayatModel(model);
      final savedModel = model.copyWith(idRiwayat: id);

      // Reload agar trigger data di SQLite langsung sinkron dengan list di UI
      await loadRiwayat();

      // Otomatis mencoba sinkron saat ada data baru. Jika offline, status
      // lokal tetap 0 dan akan dicoba lagi oleh SyncCoordinator.
      unawaited(syncToServer());

      return savedModel;
    } catch (e) {
      _errorMessage = 'Gagal menyimpan riwayat';
      notifyListeners();
      return null;
    }
  }

  /// Menjalankan proses sinkronisasi riwayat lokal ke server.
  /// Kredensial diambil oleh [SyncService] dari AuthService, bukan dari UI.
  Future<bool> syncToServer() async {
    if (_isSyncing) {
      return false;
    }

    _isSyncing = true;
    notifyListeners();

    try {
      final result = await _syncService.syncPending();
      if (result.success) {
        // Muat ulang agar indikator is_synch = 1 tampil di UI.
        _items = await _dbHelper.getRiwayatModelList();
      }
      return result.success;
    } catch (e) {
      debugPrint('Error syncing history: ${e.runtimeType}');
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<bool> deleteRiwayat(int idRiwayat) async {
    try {
      final rows = await _dbHelper.deleteRiwayat(idRiwayat);
      if (rows > 0) {
        _items.removeWhere((item) => item.idRiwayat == idRiwayat);
        _errorMessage = null;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = 'Gagal menghapus riwayat';
      notifyListeners();
    }
    return false;
  }

  Future<bool> clearAll() async {
    try {
      await _dbHelper.clearAllRiwayat();
      _items.clear();
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal membersihkan riwayat';
      notifyListeners();
      return false;
    }
  }
}
