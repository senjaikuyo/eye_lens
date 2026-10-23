import 'package:flutter/material.dart';

import '../services/lens_selection_helper.dart';

/// Controller untuk menyimpan state bingkai seleksi,
/// matriks zoom/pan, dan hasil kalkulasi seleksi teks agar bertahan
/// saat berpindah antara mode citra dan mode teks (SpeechScreen).
class LensSelectionController extends ChangeNotifier {
  Rect _imageCropRect = Rect.zero;
  Matrix4 _transformMatrix = Matrix4.identity();
  bool _isManual = false;
  bool _isInitialized = false;
  LensSelectionResult? _cachedResult;
  Rect? _lastComputedCropRect;

  Rect get imageCropRect => _imageCropRect;
  Matrix4 get transformMatrix => _transformMatrix;
  bool get isManual => _isManual;
  bool get isInitialized => _isInitialized;
  LensSelectionResult? get cachedResult => _cachedResult;
  Rect? get lastComputedCropRect => _lastComputedCropRect;

  /// Memperbarui posisi bingkai seleksi dalam piksel citra asli.
  void setCropRect(Rect rect, {bool isManual = true}) {
    if (_imageCropRect == rect) return;
    _imageCropRect = rect;
    _isManual = isManual;
    _isInitialized = true;
    notifyListeners();
  }

  /// Memperbarui matriks transformasi zoom & pan.
  void setTransformMatrix(Matrix4 matrix) {
    _transformMatrix = matrix;
    notifyListeners();
  }

  /// Menandai inisialisasi awal dari deteksi kelompok teks pertama kali.
  void markInitialized(Rect initialRect) {
    _imageCropRect = initialRect;
    _isManual = false;
    _isInitialized = true;
    notifyListeners();
  }

  /// Memperbarui cache hasil kalkulasi teks seleksi.
  void cacheResult(LensSelectionResult result, Rect cropRect) {
    _cachedResult = result;
    _lastComputedCropRect = cropRect;
  }

  /// Mengecek apakah kalkulasi teks perlu dijalankan ulang.
  bool shouldRecompute(Rect newRect) {
    if (_lastComputedCropRect == null || _cachedResult == null) {
      return true;
    }
    return _lastComputedCropRect != newRect;
  }

  /// Mereset zoom ke 1x dan membentangkan bingkai ke seluruh citra.
  void resetToFullImage(Size imageSize) {
    _transformMatrix = Matrix4.identity();
    _imageCropRect = Rect.fromLTWH(0, 0, imageSize.width, imageSize.height);
    _isManual = false;
    _isInitialized = true;
    notifyListeners();
  }

  /// Mengatur bingkai ke kelompok teks target.
  void animateToCluster(Rect targetBoundingBox) {
    _imageCropRect = targetBoundingBox;
    _isManual = false;
    _isInitialized = true;
    notifyListeners();
  }
}
