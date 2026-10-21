import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_strings.dart';
import '../../models/ocr_element.dart';
import '../../providers/history_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/camera_service.dart';
import '../../services/hardware_key_service.dart';
import '../../services/ocr_service.dart';
import '../../widgets/zoom_ruler.dart';
import '../speech/speech_screen.dart';
import 'widgets/blur_warning_banner.dart';
import 'widgets/camera_viewfinder.dart';
import 'widgets/ocr_processing_overlay.dart';
import 'widgets/scan_bottom_bar.dart';
import 'widgets/scan_top_bar.dart';
import 'widgets/zoom_pill_indicator.dart';

class ScanningScreen extends StatefulWidget {
  const ScanningScreen({super.key});

  @override
  State<ScanningScreen> createState() => _ScanningScreenState();
}

class _ScanningScreenState extends State<ScanningScreen> {
  final CameraService _cameraService = CameraService();
  final OcrService _ocrService = OcrService();
  final ImagePicker _imagePicker = ImagePicker();
  final HardwareKeyService _hardwareKeyService = HardwareKeyService();

  bool _isFlashOn = false;
  double _currentZoom = 1.0;
  bool _isBlurry = false;
  bool _isProcessingOcr = false;
  Timer? _blurTimer;

  static const double _minZoom = 1.0;
  static const double _maxZoom = 10.0;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _hardwareKeyService.startListening(() {
      if (mounted && !_isProcessingOcr) {
        _onCapturePressed();
      }
    });
  }

  Future<void> _initCamera() async {
    final success = await _cameraService.initialize();
    if (success && mounted) {
      setState(() {
        _currentZoom = _cameraService.currentZoom;
      });
    }
  }

  @override
  void dispose() {
    _hardwareKeyService.stopListening();
    _blurTimer?.cancel();
    _cameraService.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  void _triggerBlurAlert(AppStrings strings) {
    setState(() {
      _isBlurry = true;
    });

    HapticFeedback.heavyImpact();

    SemanticsService.sendAnnouncement(
      View.of(context),
      strings.imageBlurryAlert,
      TextDirection.ltr,
    );

    _blurTimer?.cancel();
    _blurTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _isBlurry = false;
        });
      }
    });
  }

  void _updateZoom(double newZoom) {
    final clamped = newZoom.clamp(_minZoom, _maxZoom);
    if ((clamped - _currentZoom).abs() > 0.01) {
      setState(() {
        _currentZoom = clamped;
      });
      _cameraService.setZoom(clamped);
    }
  }

  Future<void> _onCapturePressed() async {
    HapticFeedback.mediumImpact();

    if (_cameraService.isInitialized) {
      setState(() {
        _isProcessingOcr = true;
      });

      try {
        final bytes = await _cameraService.captureFrameToRAM();
        if (bytes != null && mounted) {
          final ocrResult = await _ocrService.processImageWithCoordinates(
            bytes,
          );
          final finalText = ocrResult.fullText.isNotEmpty
              ? ocrResult.fullText
              : 'yesterday\ntoday\ntomorrow';

          if (mounted) {
            _checkAndShowLowQualityWarning(ocrResult);

            // Simpan hasil pemindaian langsung ke SQLite
            context.read<HistoryProvider>().addRiwayat(
              text: finalText,
              sumber: 'kamera',
            );

            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => SpeechScreen(
                  text: finalText,
                  hasImage: true,
                  imageBytes: bytes, // Mengirim citra foto asli
                  ocrResult: ocrResult,
                ),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('[ScanningScreen] Tangkap & OCR gagal: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isProcessingOcr = false;
          });
        }
      }
    } else {
      // Alur fallback / simulasi (misal di simulator tanpa sensor kamera)
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const SpeechScreen(
            text: 'yesterday\ntoday\ntomorrow',
            hasImage: false,
            imageBytes: null,
          ),
        ),
      );
    }
  }

  Future<void> _onGalleryPressed() async {
    HapticFeedback.selectionClick();

    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );

      if (pickedFile == null || !mounted) return;

      setState(() {
        _isProcessingOcr = true;
      });

      final bytes = await pickedFile.readAsBytes();
      final ocrResult = await _ocrService.processFileWithCoordinates(
        pickedFile.path,
      );
      final extractedText = ocrResult.fullText;

      if (!mounted) return;

      if (extractedText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppStrings.of(context).isIndonesian
                  ? 'Tidak ditemukan teks pada gambar galeri.'
                  : 'No readable text found in the gallery image.',
              style: const TextStyle(fontSize: 16),
            ),
            backgroundColor: AppColors.black,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        _checkAndShowLowQualityWarning(ocrResult);

        // Simpan hasil pemindaian galeri langsung ke SQLite
        context.read<HistoryProvider>().addRiwayat(
          text: extractedText,
          sumber: 'galeri',
        );

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SpeechScreen(
              text: extractedText,
              hasImage: true,
              imageBytes: bytes,
              ocrResult: ocrResult,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[ScanningScreen] Ambil gambar galeri gagal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppStrings.of(context).isIndonesian
                  ? 'Gagal memuat gambar dari galeri.'
                  : 'Failed to pick image from gallery.',
              style: const TextStyle(fontSize: 16),
            ),
            backgroundColor: AppColors.black,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingOcr = false;
        });
      }
    }
  }

  void _checkAndShowLowQualityWarning(OcrResult ocrResult) {
    if (ocrResult.hasLowQualityWarning && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.of(context).isIndonesian
                ? 'Gambar kurang jelas, teks mungkin kurang akurat.'
                : 'Image is unclear, text may be less accurate.',
            style: const TextStyle(fontSize: 16),
          ),
          backgroundColor: const Color(0xFFE58E1B),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final strings = AppStrings.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark(context);

    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Viewfinder Kamera dengan gesture pinch & swipe zoom
          CameraViewfinder(
            cameraService: _cameraService,
            currentZoom: _currentZoom,
            onZoomChanged: _updateZoom,
            isBlurry: _isBlurry,
            size: size,
          ),

          // 2. Top Action Bar: Flash, History, dan Popup Menu
          ScanTopBar(
            topPadding: topPadding,
            isFlashOn: _isFlashOn,
            onToggleFlash: () async {
              final status = await _cameraService.toggleFlash();
              setState(() {
                _isFlashOn = status;
              });
            },
            isDark: isDark,
            strings: strings,
          ),

          // 3. Slider Zoom Vertikal di Kanan Tengah
          Positioned(
            right: 0,
            top: (size.height - 190) / 2,
            child: ZoomRuler(
              currentZoom: _currentZoom,
              minZoom: _minZoom,
              maxZoom: _maxZoom,
              onZoomChanged: _updateZoom,
            ),
          ),

          // 4. Indikator Nilai Zoom di Tengah Bawah
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomPadding + 130,
            child: ZoomPillIndicator(
              currentZoom: _currentZoom,
              onTap: () => _updateZoom(1.0),
            ),
          ),

          // 5. Floating Blur Warning Alert Banner
          BlurWarningBanner(
            isVisible: _isBlurry,
            bottomPadding: bottomPadding,
            message: strings.imageBlurryAlert,
          ),

          // 6. Bottom Controls: Galeri & Shutter
          ScanBottomBar(
            bottomPadding: bottomPadding,
            galleryText: strings.gallery,
            onGalleryPressed: _onGalleryPressed,
            onCapturePressed: _onCapturePressed,
            onCaptureLongPressed: () => _triggerBlurAlert(strings),
          ),

          // 7. OCR Processing Overlay
          if (_isProcessingOcr) OcrProcessingOverlay(strings: strings),
        ],
      ),
    );
  }
}
