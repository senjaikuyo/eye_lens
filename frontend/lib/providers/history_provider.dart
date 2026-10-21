import 'package:flutter/foundation.dart';

import '../models/riwayat_model.dart';
import '../services/database_helper.dart';

class HistoryProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<RiwayatModel> _items = [];
  bool _isLoading = false;

  List<RiwayatModel> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  bool get isEmpty => _items.isEmpty;

  HistoryProvider() {
    loadRiwayat();
  }

  Future<void> loadRiwayat() async {
    _isLoading = true;
    notifyListeners();

    try {
      _items = await _dbHelper.getRiwayatModelList();
    } catch (e) {
      debugPrint('Error loading history: $e');
      _items = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<RiwayatModel?> addRiwayat({
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

    final model = RiwayatModel(
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
      // Reload agar trigger 50 data di SQLite langsung sinkron dengan list di UI
      await loadRiwayat();
      return savedModel;
    } catch (e) {
      debugPrint('Error saving history: $e');
      return null;
    }
  }

  Future<bool> deleteRiwayat(int idRiwayat) async {
    try {
      final rows = await _dbHelper.deleteRiwayat(idRiwayat);
      if (rows > 0) {
        _items.removeWhere((item) => item.idRiwayat == idRiwayat);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error deleting history item: $e');
    }
    return false;
  }

  Future<bool> clearAll() async {
    try {
      await _dbHelper.clearAllRiwayat();
      _items.clear();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error clearing history: $e');
      return false;
    }
  }
}
