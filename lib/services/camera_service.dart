import 'package:camera/camera.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isFlashOn = false;
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 10.0;

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized && _controller != null && _controller!.value.isInitialized;
  bool get isFlashOn => _isFlashOn;
  double get currentZoom => _currentZoom;
  double get minZoom => _minZoom;
  double get maxZoom => _maxZoom;

  Future<void> initialize() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;

    // Prioritize back camera
    final backCamera = _cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras.first,
    );

    _controller = CameraController(
      backCamera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await _controller!.initialize();
    _isInitialized = true;

    _minZoom = await _controller!.getMinZoomLevel();
    final hwMax = await _controller!.getMaxZoomLevel();
    _maxZoom = hwMax > 10.0 ? 10.0 : hwMax;
    _currentZoom = _minZoom;
  }

  Future<void> toggleFlash() async {
    if (!isInitialized) return;
    _isFlashOn = !_isFlashOn;
    await _controller!.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
  }

  Future<void> setZoom(double zoom) async {
    if (!isInitialized) return;
    double clamped = zoom.clamp(_minZoom, _maxZoom);
    _currentZoom = clamped;
    await _controller!.setZoomLevel(clamped);
  }

  Future<void> zoomIn({double step = 0.5}) async {
    await setZoom(_currentZoom + step);
  }

  Future<void> zoomOut({double step = 0.5}) async {
    await setZoom(_currentZoom - step);
  }

  Future<XFile?> takePicture() async {
    if (!isInitialized || _controller!.value.isTakingPicture) return null;
    try {
      return await _controller!.takePicture();
    } catch (e) {
      return null;
    }
  }

  void dispose() {
    _controller?.dispose();
    _isInitialized = false;
  }
}
