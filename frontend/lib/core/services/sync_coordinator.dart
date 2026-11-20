import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

import 'package:eye_lens/core/services/sync_service.dart';

/// Mengoordinasikan sinkronisasi otomatis:
///  - saat aplikasi dibuka,
///  - saat koneksi internet kembali tersedia,
///  - saat aplikasi kembali ke foreground.
///
/// Semua pemicu melewati [SyncService.syncPending] yang memiliki mutex,
/// sehingga tidak ada dua proses sinkronisasi yang berjalan bersamaan.
class SyncCoordinator with WidgetsBindingObserver {
  final SyncService _syncService;
  final Connectivity _connectivity;
  final Future<void> Function()? onConnectivityRestored;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _started = false;

  SyncCoordinator({
    SyncService? syncService,
    Connectivity? connectivity,
    this.onConnectivityRestored,
  }) : _syncService = syncService ?? SyncService(),
       _connectivity = connectivity ?? Connectivity();

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        unawaited(onConnectivityRestored?.call());
        unawaited(_syncService.syncPending());
      }
    });

    // Validasi sesi (bila online) lalu percobaan sinkronisasi awal.
    unawaited(onConnectivityRestored?.call());
    unawaited(_syncService.syncPending());
  }

  void stop() {
    if (!_started) return;
    _started = false;
    _subscription?.cancel();
    _subscription = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(onConnectivityRestored?.call());
      unawaited(_syncService.syncPending());
    }
  }
}
