import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_strings.dart';
import '../../widgets/scanner_corner_painter.dart';
import '../../widgets/zoom_ruler.dart';
import '../settings/settings_screen.dart';
import 'validation_screen.dart';

class ScanningScreen extends StatefulWidget {
  const ScanningScreen({super.key});

  @override
  State<ScanningScreen> createState() => _ScanningScreenState();
}

class _ScanningScreenState extends State<ScanningScreen> {
  bool _isFlashOn = false;
  double _currentZoom = 1.0;

  void _onCapturePressed() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ValidationScreen()),
    );
  }

  void _onSettingsPressed() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final strings = AppStrings.of(context);

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
                    Colors.black.withValues(alpha: 0.35),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.45),
                  ],
                  stops: const [0.0, 0.18, 0.75, 1.0],
                ),
              ),
            ),
          ),

          // Central Viewfinder Frame with 4 rounded corner brackets
          Center(
            child: SizedBox(
              width: size.width * 0.78,
              height: size.width * 0.68,
              child: const CustomPaint(
                painter: ScannerCornerPainter(
                  color: Colors.white,
                  strokeWidth: 4.5,
                  cornerLength: 36,
                  cornerRadius: 16,
                ),
              ),
            ),
          ),

          // Top Action Bar (Flash & Settings with high visibility buttons)
          Positioned(
            top: topPadding + 14,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Flash Toggle Button
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () {
                        setState(() {
                          _isFlashOn = !_isFlashOn;
                        });
                      },
                      child: Center(
                        child: Icon(
                          _isFlashOn
                              ? Icons.flash_on_rounded
                              : Icons.flash_off_rounded,
                          color: _isFlashOn ? const Color(0xFFFBBF24) : Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),

                // Settings Button
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: _onSettingsPressed,
                      child: const Center(
                        child: Icon(
                          Icons.settings_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
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

          // Bottom Controls (Gallery & Shutter Button)
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomPadding + 36,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Gallery Button on the left
                Positioned(
                  left: 40,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E384D).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: IconButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(strings.galleryPickMsg),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.photo_library_outlined,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        strings.gallery,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Shutter Camera Button (Center)
                GestureDetector(
                  onTap: _onCapturePressed,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.camera_alt_outlined,
                        color: Colors.black,
                        size: 36,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
