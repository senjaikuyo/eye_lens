import 'dart:io';
import 'dart:ui' show Offset;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import 'package:eye_lens/services/camera_lifecycle_manager.dart';

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
  Future<void>? _focusOperation;
  Map<String, Object?> lastCaptureMetadata = const {};
  static const resolutionPreset = ResolutionPreset.veryHigh;

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
        resolutionPreset,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.jpeg
            : ImageFormatGroup.bgra8888,
      );

      await newController.initialize();
      _controller = newController;
      try {
        await newController.setFocusMode(FocusMode.auto);
      } on CameraException catch (e) {
        debugPrint('[CameraService] Autofocus unavailable: ${e.code}');
      }

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
    await _focusOperation;
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

  /// Focus on the tapped point, then keep that point locked until next tap/restart.
  Future<void> focusAt(Offset point) async {
    final controller = _controller;
    if (!isInitialized ||
        controller == null ||
        _focusOperation != null ||
        controller.value.isTakingPicture ||
        !controller.value.focusPointSupported) {
      return;
    }
    final operation = _focusAt(controller, point);
    _focusOperation = operation;
    try {
      await operation;
    } finally {
      _focusOperation = null;
    }
  }

  Future<void> _focusAt(CameraController controller, Offset point) async {
    try {
      await controller.setFocusMode(FocusMode.auto);
      await controller.setFocusPoint(point);
      if (controller.value.exposurePointSupported) {
        await controller.setExposurePoint(point);
      }
      // CameraX awaits its focus/metering operation. No artificial delay.
      await controller.setFocusMode(FocusMode.locked);
    } on CameraException catch (e) {
      debugPrint('[CameraService] Tap focus failed: ${e.code}');
      if (!controller.value.isInitialized) return;
      try {
        await controller.setFocusMode(FocusMode.auto);
      } on CameraException catch (restoreError) {
        debugPrint(
          '[CameraService] Focus restore failed: ${restoreError.code}',
        );
      }
    }
  }

  /// Read original JPEG bytes and remove the temporary file even on failure.
  Future<Uint8List?> captureFrameToRAM() async {
    if (!isInitialized || _isDisposed) return null;

    XFile? xFile;
    try {
      await _focusOperation;
      final controller = _controller;
      if (!isInitialized || controller == null) return null;
      lastCaptureMetadata = {
        'cameraPreset': resolutionPreset.name,
        'deviceOrientation': controller.value.deviceOrientation.name,
        'focusMode': controller.value.focusMode.name,
        'focusPointSupported': controller.value.focusPointSupported,
        // Public camera API does not expose native AF success state.
        'focusSuccess': null,
      };
      xFile = await controller.takePicture();
      final Uint8List bytes = await xFile.readAsBytes();
      return bytes;
    } catch (e) {
      debugPrint('[CameraService] Gagal mengambil gambar kamera: $e');
      return null;
    } finally {
      // Also delete if readAsBytes throws; never re-encode camera JPEG.
      try {
        final tempFile = xFile == null ? null : File(xFile.path);
        if (tempFile != null && await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (e) {
        debugPrint(
          '[CameraService] Gagal menghapus file sementara (diabaikan): $e',
        );
      }
    }
  }

  /// Membebaskan resource kamera secara permanen saat layar dihancurkan.
  Future<void> dispose() async {
    _isDisposed = true;
    await stop();
    _lifecycle.dispose();
  }
}
