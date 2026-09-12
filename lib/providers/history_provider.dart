import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/history_model.dart';

class HistoryProvider with ChangeNotifier {
  List<HistoryModel> _historyList = [];
  bool _isLoading = false;

  List<HistoryModel> get historyList => _historyList;
  bool get isLoading => _isLoading;

  Future<void> fetchHistory() async {
    _isLoading = true;
    notifyListeners();
    _historyList = await DatabaseHelper.instance.getAllHistory();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addHistory(String text) async {
    await DatabaseHelper.instance.insertHistory(text);
    await fetchHistory();
  }

  Future<void> deleteHistory(int id) async {
    await DatabaseHelper.instance.deleteHistory(id);
    await fetchHistory();
  }

  Future<void> clearAll() async {
    await DatabaseHelper.instance.clearAllHistory();
    _historyList.clear();
    notifyListeners();
  }
}
