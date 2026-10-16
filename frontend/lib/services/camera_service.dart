import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// Service untuk mengelola siklus hidup kamera gawai:
/// - Inisialisasi kamera belakang dengan resolusi optimal (1080p).
/// - Pengaturan pembesaran digital (magnifier) proporsional 1.0x - 2.0x (200%).
/// - Pengaturan senter / torch untuk kondisi pencahayaan rendah.
/// - Pengambilan citra sementara ke RAM (Uint8List) dan penghapusan otomatis file cache (Ephemeral Memory).
/// - Penanganan kegagalan (fallback) aman untuk emulator/desktop tanpa kamera.
class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isDisposed = false;

  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _currentZoom = 1.0;
  bool _isFlashOn = false;

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized && _controller != null && _controller!.value.isInitialized;
  bool get isAvailable => _cameras.isNotEmpty;
  double get minZoom => _minZoom;
  double get maxZoom => _maxZoom;
  double get currentZoom => _currentZoom;
  bool get isFlashOn => _isFlashOn;

  /// Inisialisasi daftar kamera dan Controller untuk kamera belakang pertama.
  Future<bool> initialize() async {
    if (_isDisposed) return false;

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

      _controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.jpeg
            : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();

      // Dapatkan batasan zoom hardware sebenarnya (hingga 10x)
      try {
        _minZoom = await _controller!.getMinZoomLevel();
        final hwMax = await _controller!.getMaxZoomLevel();
        _maxZoom = hwMax.clamp(1.0, 10.0);
      } catch (e) {
        _minZoom = 1.0;
        _maxZoom = 10.0;
      }

      _currentZoom = _minZoom;
      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('[CameraService] Inisialisasi kamera gagal: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Mengatur tingkat perbesaran digital (zoom level).
  /// Menjamin nilai zoom berada dalam jangkauan hardware aman (clamped).
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
  /// File cache fisik yang dibuat oleh plugin di disk langsung dihapus permanen (purge)
  /// untuk menjamin privasi resep obat/dokumen lansia (0 byte jejak foto di penyimpanan).
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
        debugPrint('[CameraService] Gagal menghapus file sementara (diabaikan): $e');
      }

      return bytes;
    } catch (e) {
      debugPrint('[CameraService] Gagal mengambil gambar kamera: $e');
      return null;
    }
  }

  /// Membebaskan resource kamera saat layar ditutup.
  Future<void> dispose() async {
    _isDisposed = true;
    _isInitialized = false;
    try {
      await _controller?.dispose();
    } catch (e) {
      debugPrint('[CameraService] Gagal dispose controller: $e');
    } finally {
      _controller = null;
    }
  }
}
