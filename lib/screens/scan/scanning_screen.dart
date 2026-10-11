import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_strings.dart';
import '../../providers/theme_provider.dart';
import '../../services/camera_service.dart';
import '../../services/ocr_service.dart';
import '../../widgets/scanner_corner_painter.dart';
import '../../widgets/zoom_ruler.dart';
import '../speech/speech_screen.dart';
import 'widgets/blur_warning_banner.dart';
import 'widgets/scan_bottom_bar.dart';
import 'widgets/scan_top_bar.dart';

class ScanningScreen extends StatefulWidget {
  const ScanningScreen({super.key});

  @override
  State<ScanningScreen> createState() => _ScanningScreenState();
}

class _ScanningScreenState extends State<ScanningScreen> {
  final CameraService _cameraService = CameraService();
  final OcrService _ocrService = OcrService();

  bool _isFlashOn = false;
  double _currentZoom = 1.0;
  double _baseScaleZoom = 1.0;
  bool _isBlurry = false;
  bool _isProcessingOcr = false;
  Timer? _blurTimer;

  static const double _minZoom = 1.0;
  static const double _maxZoom = 10.0;

  @override
  void initState() {
    super.initState();
    _initCamera();
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
          final extractedText = await _ocrService.processImageFromRAM(bytes);
          final finalText = extractedText.isNotEmpty
              ? extractedText
              : 'yesterday\ntoday\ntomorrow';

          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => SpeechScreen(
                  text: finalText,
                  hasImage: true,
                  imageBytes: bytes, // Mengirim citra foto asli
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
          // 1. Gesture Area untuk Seluruh Viewfinder Kamera
          // Mendukung:
          // - Zoom Cubit (Pinch to Zoom 2 jari hingga 10x)
          // - Swipe 1 Jari Vertikal (Swipe Atas = Zoom In, Swipe Bawah = Zoom Out)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (details) {
              _baseScaleZoom = _currentZoom;
            },
            onScaleUpdate: (details) {
              if (details.pointerCount > 1) {
                // Zoom Cubit (Pinch 2 jari)
                _updateZoom(_baseScaleZoom * details.scale);
              } else {
                // Swipe 1 Jari Vertikal: Ke atas = zoom in, ke bawah = zoom out
                final dy = details.focalPointDelta.dy;
                final sensitivity = 0.015;
                _updateZoom(_currentZoom - (dy * sensitivity));
              }
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Live Camera Preview atau fallback
                if (_cameraService.isInitialized && _cameraService.controller != null)
                  SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _cameraService.controller!.value.previewSize?.height ?? size.width,
                        height: _cameraService.controller!.value.previewSize?.width ?? size.height,
                        child: CameraPreview(_cameraService.controller!),
                      ),
                    ),
                  )
                else
                  Image.asset(
                    'assets/images/UI Scanning Teks.png',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),

                // Subtle Vignette Gradient
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.45),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.6),
                        ],
                        stops: const [0.0, 0.2, 0.7, 1.0],
                      ),
                    ),
                  ),
                ),

                // Central Viewfinder Frame - Garis tipis 2.0 & Siku-Siku (Sudut 90 Derajat) di 4 sisi
                Center(
                  child: SizedBox(
                    width: size.width * 0.78,
                    height: size.width * 0.78,
                    child: CustomPaint(
                      painter: ScannerCornerPainter(
                        color: _isBlurry
                            ? const Color(0xFFF59E0B)
                            : Colors.white.withValues(alpha: 0.85),
                        strokeWidth: 2.0,
                        cornerLength: 32,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Top Action Bar: Flash, History, and PopupMenu
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

          // 3. Slider Zoom Vertikal di Kanan Tengah (ZoomRuler hingga 10x)
          Positioned(
            right: 0,
            top: size.height * 0.30,
            child: ZoomRuler(
              currentZoom: _currentZoom,
              minZoom: _minZoom,
              maxZoom: _maxZoom,
              onZoomChanged: _updateZoom,
            ),
          ),

          // 4. Indikator Nilai Zoom (Opsi A: Kapsul Pill di Tengah Bawah Tepat di Atas Shutter)
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomPadding + 130,
            child: Center(
              child: GestureDetector(
                onTap: () => _updateZoom(1.0), // Tap untuk reset cepat ke 1.0x
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '${_currentZoom.toStringAsFixed(1)}x',
                    style: const TextStyle(
                      color: Color(0xFFFACC15),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 5. Floating Blur Warning Alert Banner
          BlurWarningBanner(
            isVisible: _isBlurry,
            bottomPadding: bottomPadding,
            message: strings.imageBlurryAlert,
          ),

          // 6. Bottom Controls: Gallery & Shutter Button
          ScanBottomBar(
            bottomPadding: bottomPadding,
            galleryText: strings.gallery,
            onGalleryPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(strings.galleryPickMsg),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            onCapturePressed: _onCapturePressed,
            onCaptureLongPressed: () => _triggerBlurAlert(strings),
          ),

          // 7. OCR Processing Overlay
          if (_isProcessingOcr)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: Color(0xFFFACC15),
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Mengekstrak teks...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
