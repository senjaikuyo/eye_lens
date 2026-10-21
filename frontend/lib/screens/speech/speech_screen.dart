import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_strings.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/feedback_dialog.dart';
import '../settings/faq_screen.dart';
import '../settings/settings_screen.dart';
import 'widgets/appearance_sheet.dart';
import 'widgets/audio_player_bar.dart';
import 'widgets/highlighted_text_view.dart';
import 'widgets/language_sheet.dart';

class SpeechScreen extends StatefulWidget {
  final String text;
  final bool hasImage;
  final Uint8List? imageBytes;

  const SpeechScreen({
    super.key,
    this.text = 'yesterday\ntoday\ntomorrow',
    this.hasImage = false,
    this.imageBytes,
  });

  @override
  State<SpeechScreen> createState() => _SpeechScreenState();
}

class _SpeechScreenState extends State<SpeechScreen> {
  late bool _isTextView;
  double _fontSize = 32.0;
  bool _isPlaying = false;
  double _progress = 0.0;
  String _selectedLanguage = 'English'; // 'Indonesia' or 'English'
  double _speed = 1.0;
  Timer? _playbackTimer;

  @override
  void initState() {
    super.initState();
    // Inisialisasi ukuran font dari preferensi pengguna yang tersimpan
    _fontSize = Provider.of<ThemeProvider>(context, listen: false).fontSize;

    // Jika tidak ada gambar jepretan, default tampilkan mode teks bersih berlatar hitam
    _isTextView = widget.imageBytes == null && !widget.hasImage;

    // Langsung bacakan teks secara otomatis saat layar dibuka (SKPPL Auto-Play)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isPlaying) {
        _togglePlayPause();
      }
    });
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
    });

    if (_isPlaying) {
      _playbackTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
        if (!mounted) return;
        setState(() {
          _progress += 0.01 * _speed;
          if (_progress >= 1.0) {
            _progress = 0.0;
            _isPlaying = false;
            timer.cancel();
          }
        });
      });
    } else {
      _playbackTimer?.cancel();
    }
  }

  void _onSpeedTap() {
    setState(() {
      if (_speed == 1.0) {
        _speed = 1.25;
      } else if (_speed == 1.25) {
        _speed = 1.5;
      } else if (_speed == 1.5) {
        _speed = 2.0;
      } else {
        _speed = 1.0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark(context);
    final strings = AppStrings.of(context);
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final size = MediaQuery.of(context).size;
    final hasValidImage = widget.imageBytes != null || widget.hasImage;

    return Scaffold(
      backgroundColor: _isTextView
          ? (isDark ? AppColors.black : Colors.white)
          : AppColors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // MAIN BODY
          if (!_isTextView) ...[
            // Photo View Background: Menampilkan foto asli hasil jepretan kamera (jika ada)
            if (widget.imageBytes != null)
              Image.memory(
                widget.imageBytes!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              )
            else
              Container(color: Colors.black),

            // Subtle gradient
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.4),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.5),
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),

            // Captured frame preview border
            Center(
              child: Container(
                width: size.width * 0.82,
                height: size.width * 0.72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
              ),
            ),
          ] else ...[
            // Pure Text View with Dark Mode support (latar hitam elegan / tema aktif)
            Positioned.fill(
              child: Container(
                color: isDark ? AppColors.black : Colors.white,
                padding: EdgeInsets.only(
                  top: topPadding + 80,
                  left: 28,
                  right: 28,
                  bottom: 160,
                ),
                child: SingleChildScrollView(
                  child: HighlightedTextView(
                    text: widget.text,
                    fontSize: _fontSize,
                    cursorColorEnabled: themeProvider.cursorColor,
                    highlightColor: themeProvider.highlightColor,
                    isDark: isDark,
                    isHighContrast: themeProvider.isHighContrast,
                    progress: _progress,
                    onProgressChanged: (val) {
                      setState(() {
                        _progress = val;
                      });
                    },
                  ),
                ),
              ),
            ),
          ],

          // TOP ACTION BAR: Back (Left) | Aa & Three Dots (Right)
          Positioned(
            top: topPadding + 10,
            left: 16,
            right: 16,
            child: Row(
              children: [
                // Back Button
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
                      onTap: () => Navigator.of(context).pop(),
                      child: const Center(
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.black,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // "Aa" Appearance Button
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
                        AppearanceBottomSheet.show(
                          context,
                          themeProvider: themeProvider,
                          strings: strings,
                          fontSize: _fontSize,
                          onFontSizeChanged: (newSize) {
                            setState(() {
                              _fontSize = newSize;
                            });
                            themeProvider.setFontSize(newSize);
                          },
                        );
                      },
                      child: const Center(
                        child: Text(
                          'Aa',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Three Dots Overflow Menu
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
                              MaterialPageRoute(builder: (context) => const SettingsScreen()),
                            );
                          } else if (value == 'feedback') {
                            FeedbackDialog.show(context, strings: strings, isDark: isDark);
                          } else if (value == 'faq') {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => const FaqScreen()),
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
          ),

          // FLOATING MODE TOGGLE BUTTON (Hanya jika ada foto jepretan)
          if (hasValidImage)
            Positioned(
              right: 20,
              bottom: bottomPadding + 148,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(28),
                    onTap: () {
                      setState(() {
                        _isTextView = !_isTextView;
                      });
                    },
                    child: Center(
                      child: _isTextView
                          ? const Icon(
                              Icons.image_outlined,
                              color: Colors.black,
                              size: 28,
                            )
                          : const Text(
                              'T',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),

          // BOTTOM AUDIO PLAYER CONTROLS
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AudioPlayerBar(
              isTextView: _isTextView,
              isDark: isDark,
              cursorColorEnabled: themeProvider.cursorColor,
              highlightColor: themeProvider.highlightColor,
              progress: _progress,
              onProgressChanged: (val) {
                setState(() {
                  _progress = val;
                });
              },
              selectedLanguage: _selectedLanguage,
              onLanguageTap: () {
                LanguageBottomSheet.show(
                  context,
                  strings: strings,
                  isDark: isDark,
                  selectedLanguage: _selectedLanguage,
                  onLanguageSelected: (lang) {
                    setState(() {
                      _selectedLanguage = lang;
                    });
                  },
                );
              },
              onRewind: () {
                setState(() {
                  _progress = (_progress - 0.1).clamp(0.0, 1.0);
                });
              },
              isPlaying: _isPlaying,
              onPlayPause: _togglePlayPause,
              onForward: () {
                setState(() {
                  _progress = (_progress + 0.1).clamp(0.0, 1.0);
                });
              },
              speed: _speed,
              onSpeedTap: _onSpeedTap,
              bottomPadding: bottomPadding,
            ),
          ),
        ],
      ),
    );
  }
}
