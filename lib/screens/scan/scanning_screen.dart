import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_strings.dart';
import '../../providers/theme_provider.dart';
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
  bool _isFlashOn = false;
  double _currentZoom = 1.0;
  bool _isBlurry = false;
  Timer? _blurTimer;

  @override
  void dispose() {
    _blurTimer?.cancel();
    super.dispose();
  }

  void _triggerBlurAlert(AppStrings strings) {
    setState(() {
      _isBlurry = true;
    });

    // Provide haptic vibration feedback for accessibility
    HapticFeedback.heavyImpact();

    // Voice announcement cue for screen readers and visually impaired users
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

  void _onCapturePressed() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SpeechScreen()),
    );
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
          // Background (Simulated camera viewfinder with paper sample)
          Image.asset(
            'assets/images/UI Scanning Teks.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),

          // Dark subtle vignette gradient for readability of controls
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.4),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.5),
                  ],
                  stops: const [0.0, 0.2, 0.75, 1.0],
                ),
              ),
            ),
          ),

          // Central Viewfinder Frame with 4 rounded corner brackets
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

          // Top Action Bar: Flash, History, and PopupMenu
          ScanTopBar(
            topPadding: topPadding,
            isFlashOn: _isFlashOn,
            onToggleFlash: () {
              setState(() {
                _isFlashOn = !_isFlashOn;
              });
            },
            isDark: isDark,
            strings: strings,
          ),

          // Right Zoom Ruler
          Positioned(
            right: 0,
            top: size.height * 0.28,
            child: ZoomRuler(
              currentZoom: _currentZoom,
              onZoomChanged: (newZoom) {
                setState(() {
                  _currentZoom = newZoom;
                });
              },
            ),
          ),

          // Floating Blur Warning Alert Banner
          BlurWarningBanner(
            isVisible: _isBlurry,
            bottomPadding: bottomPadding,
            message: strings.imageBlurryAlert,
          ),

          // Bottom Controls: Gallery & Shutter Button
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
        ],
      ),
    );
  }
}
