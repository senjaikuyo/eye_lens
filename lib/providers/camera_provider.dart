import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/camera_service.dart';

class CameraProvider with ChangeNotifier {
  final CameraService _cameraService = CameraService();
  final ImagePicker _picker = ImagePicker();

  bool _isInitializing = false;
  String? _capturedImagePath;
  bool _isTakingPhoto = false;

  CameraService get service => _cameraService;
  bool get isInitialized => _cameraService.isInitialized;
  bool get isFlashOn => _cameraService.isFlashOn;
  double get currentZoom => _cameraService.currentZoom;
  double get minZoom => _cameraService.minZoom;
  double get maxZoom => _cameraService.maxZoom;
  String? get capturedImagePath => _capturedImagePath;
  bool get isTakingPhoto => _isTakingPhoto;

  Future<void> initCamera() async {
    if (_isInitializing || _cameraService.isInitialized) return;
    _isInitializing = true;
    notifyListeners();
    try {
      await _cameraService.initialize();
    } catch (e) {
      debugPrint('Camera init error: $e');
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> toggleFlash() async {
    await _cameraService.toggleFlash();
    notifyListeners();
  }

  Future<void> zoomIn() async {
    await _cameraService.zoomIn();
    notifyListeners();
  }

  Future<void> zoomOut() async {
    await _cameraService.zoomOut();
    notifyListeners();
  }

  Future<void> setZoom(double zoom) async {
    await _cameraService.setZoom(zoom);
    notifyListeners();
  }

  Future<String?> capturePhoto() async {
    _isTakingPhoto = true;
    notifyListeners();
    try {
      final XFile? file = await _cameraService.takePicture();
      if (file != null) {
        _capturedImagePath = file.path;
        return file.path;
      }
      return null;
    } finally {
      _isTakingPhoto = false;
      notifyListeners();
    }
  }

  Future<String?> pickFromGallery() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );
    if (image != null) {
      _capturedImagePath = image.path;
      notifyListeners();
      return image.path;
    }
    return null;
  }

  void clearCapturedPhoto() {
    if (_capturedImagePath != null) {
      try {
        final file = File(_capturedImagePath!);
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (_) {}
      _capturedImagePath = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
  }
}
