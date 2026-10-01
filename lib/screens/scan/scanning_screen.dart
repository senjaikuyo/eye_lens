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
import '../history/history_screen.dart';
import '../settings/faq_screen.dart';
import '../settings/settings_screen.dart';
import '../speech/speech_screen.dart';

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
    // Direct navigation to SpeechScreen (bypassing validation screen)
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SpeechScreen()),
    );
  }

  void _onHistoryPressed() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const HistoryScreen()),
    );
  }

  void _showFeedbackDialog(AppStrings strings, bool isDark) {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          strings.feedbackTitle,
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              maxLines: 4,
              cursorColor: isDark ? Colors.white : Colors.black,
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.black,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: strings.feedbackHint,
                hintStyle: TextStyle(
                  color: isDark ? const Color(0xFF777777) : const Color(0xFFAAAAAA),
                  fontSize: 13,
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF2F4F7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              strings.cancel,
              style: TextStyle(
                color: isDark ? const Color(0xFFAAAAAA) : const Color(0xFF777777),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.white : AppColors.black,
              foregroundColor: isDark ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(strings.feedbackSent),
                  backgroundColor: AppColors.black,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Text(strings.send, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
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

          // Top Action Bar: Flash (Left) | History & Menu (Right) - Clean White Buttons (matching Frame 4533979 / Image 4)
          Positioned(
            top: topPadding + 10,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Flash Toggle Button (Clean White Circle 48x48)
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFD0D7DE),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
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
                          color: _isFlashOn ? const Color(0xFFE58E1B) : Colors.black,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ),

                // Right Actions: History & PopupMenu (Clean White Circles 48x48)
                Row(
                  children: [
                    // History Button (Clock Icon)
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFD0D7DE),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: _onHistoryPressed,
                          child: const Center(
                            child: Icon(
                              Icons.history_rounded,
                              color: Colors.black,
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Three Dots Overflow Menu (Settings, Feedback, FAQ)
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFD0D7DE),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            popupMenuTheme: PopupMenuThemeData(
                              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                          child: PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_vert_rounded,
                              color: Colors.black,
                              size: 26,
                            ),
                            padding: EdgeInsets.zero,
                            onSelected: (value) {
                              if (value == 'settings') {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const SettingsScreen(),
                                  ),
                                );
                              } else if (value == 'feedback') {
                                _showFeedbackDialog(strings, isDark);
                              } else if (value == 'faq') {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const FaqScreen(),
                                  ),
                                );
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'settings',
                                child: Text(
                                  strings.settings,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : AppColors.black,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'feedback',
                                child: Text(
                                  strings.feedback,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : AppColors.black,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'faq',
                                child: Text(
                                  strings.faq,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : AppColors.black,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
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

          // Floating Blur Warning Alert Banner (above shutter)
          if (_isBlurry)
            Positioned(
              left: 24,
              right: 24,
              bottom: bottomPadding + 130,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _isBlurry ? 1.0 : 0.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFF59E0B),
                        size: 26,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          strings.imageBlurryAlert,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
                  onLongPress: () => _triggerBlurAlert(strings), // Hold to test blur warning
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
