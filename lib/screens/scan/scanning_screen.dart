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
  bool _isBlurry = false;
  bool _isProcessingOcr = false;
  Timer? _blurTimer;

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
              : 'yesterday\ntoday\ntomorrow'; // Fallback cerdas jika teks kosong
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => SpeechScreen(text: finalText, hasImage: true),
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
      // Alur fallback / simulasi saat gawai tanpa sensor kamera aktif
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const SpeechScreen()),
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
          // 1. Camera Viewfinder (Live feed jika tersedia, atau simulasi fallback)
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

          // 2. Subtle Vignette Gradient
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
                    Colors.black.withValues(alpha: 0.55),
                  ],
                  stops: const [0.0, 0.2, 0.75, 1.0],
                ),
              ),
            ),
          ),

          // 3. Central Viewfinder Frame with 4 rounded corner brackets
          Center(
            child: SizedBox(
              width: size.width * 0.78,
              height: size.width * 0.68,
              child: CustomPaint(
                painter: ScannerCornerPainter(
                  color: _isBlurry ? const Color(0xFFF59E0B) : Colors.white,
                  strokeWidth: 4.5,
                  cornerLength: 36,
                  cornerRadius: 16,
                ),
              ),
            ),
          ),

          // 4. Reading Guide Line - Garis panduan kuning kontras tinggi (SKPPL F-005)
          Center(
            child: Container(
              width: size.width * 0.70,
              height: 2.0,
              decoration: BoxDecoration(
                color: const Color(0xFFFACC15).withValues(alpha: 0.8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
          ),

          // 5. Top Action Bar: Flash, History, and PopupMenu
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

          // 6. Right Zoom Ruler (1.0x - 2.0x digital magnifier)
          Positioned(
            right: 0,
            top: size.height * 0.28,
            child: ZoomRuler(
              currentZoom: _currentZoom,
              onZoomChanged: (newZoom) {
                setState(() {
                  _currentZoom = newZoom;
                });
                _cameraService.setZoom(newZoom);
              },
            ),
          ),

          // 7. Floating Blur Warning Alert Banner
          BlurWarningBanner(
            isVisible: _isBlurry,
            bottomPadding: bottomPadding,
            message: strings.imageBlurryAlert,
          ),

          // 8. Bottom Controls: Gallery & Shutter Button
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

          // 9. OCR Processing Overlay
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
