import 'dart:async';
import 'package:flutter/foundation.dart';

/// Status siklus hidup kamera.
enum CameraStatus {
  idle,
  starting,
  ready,
  stopping,
  error,
}

/// Tipe fungsi async untuk menjalankan inisialisasi / start hardware kamera.
typedef CameraStartAction = Future<bool> Function();

/// Tipe fungsi async untuk melepaskan / stop hardware kamera.
typedef CameraStopAction = Future<void> Function();

/// State machine murni untuk mengelola transisi siklus hidup kamera.
/// Menjamin eksekusi serial tanpa balapan (race condition) menggunakan Sequential Queue.
class CameraLifecycleManager extends ChangeNotifier {
  final CameraStartAction _onStart;
  final CameraStopAction _onStop;

  CameraStatus _status = CameraStatus.idle;
  String? _errorMessage;

  // Queue serial untuk eksekusi terurut start/stop
  Future<dynamic> _queue = Future.value();

  CameraLifecycleManager({
    required this._onStart,
    required this._onStop,
  });

  CameraStatus get status => _status;
  bool get isReady => _status == CameraStatus.ready;
  bool get isStarting => _status == CameraStatus.starting;
  bool get isStopping => _status == CameraStatus.stopping;
  bool get isIdle => _status == CameraStatus.idle;
  bool get isError => _status == CameraStatus.error;
  String? get errorMessage => _errorMessage;

  void _setStatus(CameraStatus newStatus, {String? error}) {
    if (_status == newStatus && _errorMessage == error) return;
    _status = newStatus;
    _errorMessage = error;
    notifyListeners();
  }

  /// Memulai inisialisasi kamera secara aman.
  Future<bool> start() {
    if (_status == CameraStatus.ready) {
      return Future.value(true);
    }
    _setStatus(CameraStatus.starting);
    final next = _queue.then((_) => _executeStart());
    _queue = next;
    return next;
  }

  /// Menghentikan dan melepas kamera secara aman.
  Future<void> stop() {
    if (_status == CameraStatus.idle) {
      return Future.value();
    }
    _setStatus(CameraStatus.stopping);
    final next = _queue.then((_) => _executeStop());
    _queue = next;
    return next;
  }

  Future<bool> _executeStart() async {
    if (_status == CameraStatus.ready) {
      return true;
    }

    _setStatus(CameraStatus.starting);
    try {
      final success = await _onStart();
      if (success) {
        _setStatus(CameraStatus.ready);
        return true;
      } else {
        _setStatus(CameraStatus.error, error: 'Inisialisasi kamera gagal');
        return false;
      }
    } catch (e) {
      _setStatus(CameraStatus.error, error: e.toString());
      return false;
    }
  }

  Future<void> _executeStop() async {
    if (_status == CameraStatus.idle) {
      return;
    }

    _setStatus(CameraStatus.stopping);
    try {
      await _onStop();
      _setStatus(CameraStatus.idle);
    } catch (e) {
      _setStatus(CameraStatus.error, error: e.toString());
    }
  }
}
