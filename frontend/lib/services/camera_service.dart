import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import 'camera_lifecycle_manager.dart';

/// Service untuk mengelola siklus hidup kamera gawai:
/// - Inisialisasi kamera belakang dengan resolusi optimal (1080p).
/// - Pengaturan pembesaran digital (magnifier) proporsional 1.0x - 10.0x.
/// - Pengaturan senter / torch untuk kondisi pencahayaan rendah (otomatis dimatikan saat kamera nonaktif).
/// - Penghentian aman (stop) saat berpindah ke halaman gambar/teks untuk menghemat baterai & memori.
/// - Pemulihan status kamera (start) saat kembali ke halaman pemindaian tanpa balapan (race condition).
/// - Pengambilan citra sementara ke RAM (Uint8List) dan penghapusan otomatis file cache (Ephemeral Memory).
class CameraService {
  late final CameraLifecycleManager _lifecycle;

  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isDisposed = false;

  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _currentZoom = 1.0;
  bool _isFlashOn = false;

  CameraService() {
    _lifecycle = CameraLifecycleManager(
      onStart: _internalStart,
      onStop: _internalStop,
    );
  }

  CameraLifecycleManager get lifecycle => _lifecycle;
  CameraStatus get status => _lifecycle.status;

  CameraController? get controller => _controller;
  bool get isInitialized =>
      _lifecycle.isReady &&
      _controller != null &&
      _controller!.value.isInitialized;
  bool get isAvailable => _cameras.isNotEmpty;
  double get minZoom => _minZoom;
  double get maxZoom => _maxZoom;
  double get currentZoom => _currentZoom;
  bool get isFlashOn => _isFlashOn;

  /// Memulai inisialisasi kamera (kompatibel dengan API lama).
  Future<bool> initialize() => start();

  /// Menyalakan kembali sensor kamera secara aman.
  Future<bool> start() async {
    if (_isDisposed) return false;
    return await _lifecycle.start();
  }

  /// Mematikan dan membebaskan sensor kamera sementara (misal saat di halaman gambar/teks).
  Future<void> stop() async {
    await _lifecycle.stop();
  }

  Future<bool> _internalStart() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        debugPrint('[CameraService] Tidak ada kamera fisik yang terdeteksi.');
        return false;
      }

      // Prioritaskan kamera belakang untuk pemindaian dokumen/objek
      final backCamera = _cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      final newController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.jpeg
            : ImageFormatGroup.bgra8888,
      );

      await newController.initialize();
      _controller = newController;

      // Dapatkan batasan zoom hardware sebenarnya (hingga 10x)
      try {
        _minZoom = await _controller!.getMinZoomLevel();
        final hwMax = await _controller!.getMaxZoomLevel();
        _maxZoom = hwMax.clamp(1.0, 10.0);
      } catch (e) {
        _minZoom = 1.0;
        _maxZoom = 10.0;
      }

      // Pulihkan tingkat zoom sebelumnya jika masih dalam rentang hardware
      if (_currentZoom > _minZoom) {
        final targetZoom = _currentZoom.clamp(_minZoom, _maxZoom);
        try {
          await _controller!.setZoomLevel(targetZoom);
          _currentZoom = targetZoom;
        } catch (e) {
          debugPrint('[CameraService] Gagal memulihkan zoom sebelumnya: $e');
        }
      } else {
        _currentZoom = _minZoom;
      }

      return true;
    } catch (e) {
      debugPrint('[CameraService] Inisialisasi kamera gagal: $e');
      _controller = null;
      return false;
    }
  }

  Future<void> _internalStop() async {
    // 1. Matikan lampu senter terlebih dahulu jika masih aktif
    if (_isFlashOn && _controller != null && _controller!.value.isInitialized) {
      try {
        await _controller!.setFlashMode(FlashMode.off);
      } catch (e) {
        debugPrint('[CameraService] Gagal mematikan senter saat stop: $e');
      }
      _isFlashOn = false;
    }

    // 2. Dispose controller dan lepaskan hardware kamera
    try {
      await _controller?.dispose();
    } catch (e) {
      debugPrint('[CameraService] Gagal dispose controller: $e');
    } finally {
      _controller = null;
    }
  }

  /// Mengatur tingkat perbesaran digital (zoom level).
  Future<void> setZoom(double zoom) async {
    if (!isInitialized || _isDisposed) return;

    try {
      final clampedZoom = zoom.clamp(_minZoom, _maxZoom);
      await _controller!.setZoomLevel(clampedZoom);
      _currentZoom = clampedZoom;
    } catch (e) {
      debugPrint('[CameraService] Gagal mengatur zoom: $e');
    }
  }

  /// Mengaktifkan / menonaktifkan lampu senter (torch).
  Future<bool> toggleFlash() async {
    if (!isInitialized || _isDisposed) return false;

    try {
      final targetMode = _isFlashOn ? FlashMode.off : FlashMode.torch;
      await _controller!.setFlashMode(targetMode);
      _isFlashOn = !_isFlashOn;
      return _isFlashOn;
    } catch (e) {
      debugPrint('[CameraService] Gagal mengatur flash mode: $e');
      return _isFlashOn;
    }
  }

  /// Menangkap citra foto langsung ke RAM (Uint8List).
  Future<Uint8List?> captureFrameToRAM() async {
    if (!isInitialized || _isDisposed) return null;

    try {
      final XFile xFile = await _controller!.takePicture();
      final Uint8List bytes = await xFile.readAsBytes();

      // Ephemeral Memory: Hapus file sementara dari penyimpanan internal
      try {
        final tempFile = File(xFile.path);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (e) {
        debugPrint(
          '[CameraService] Gagal menghapus file sementara (diabaikan): $e',
        );
      }

      return bytes;
    } catch (e) {
      debugPrint('[CameraService] Gagal mengambil gambar kamera: $e');
      return null;
    }
  }

  /// Membebaskan resource kamera secara permanen saat layar dihancurkan.
  Future<void> dispose() async {
    _isDisposed = true;
    await stop();
    _lifecycle.dispose();
  }
}
