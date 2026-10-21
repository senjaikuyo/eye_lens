import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_strings.dart';
import '../../models/ocr_element.dart';
import '../../providers/theme_provider.dart';
import '../../services/tts_service.dart';
import '../../widgets/feedback_dialog.dart';
import '../settings/faq_screen.dart';
import '../settings/settings_screen.dart';
import 'widgets/appearance_sheet.dart';
import 'widgets/audio_player_bar.dart';
import 'widgets/highlighted_text_view.dart';
import 'widgets/language_sheet.dart';
import 'widgets/ocr_image_overlay.dart';

class SpeechScreen extends StatefulWidget {
  final String text;
  final bool hasImage;
  final Uint8List? imageBytes;
  final OcrResult? ocrResult;

  const SpeechScreen({
    super.key,
    this.text = 'yesterday\ntoday\ntomorrow',
    this.hasImage = false,
    this.imageBytes,
    this.ocrResult,
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
  final TtsService _ttsService = TtsService();

  List<OcrElement> _selectedElements = [];
  Set<String> _selectedIds = {};

  String get _activeText {
    if (_selectedElements.isNotEmpty) {
      return _selectedElements.map((e) => e.text).join('\n');
    }
    return widget.text;
  }

  void _onSelectionChanged(List<OcrElement> selected) {
    setState(() {
      _selectedElements = selected;
      _selectedIds = selected.map((e) => e.id).toSet();
      _progress = 0.0;
    });

    if (_isPlaying) {
      _ttsService.speak(_activeText);
    }
  }

  void _onClearSelection() {
    setState(() {
      _selectedElements.clear();
      _selectedIds.clear();
      _progress = 0.0;
    });

    if (_isPlaying) {
      _ttsService.speak(_activeText);
    }
  }

  @override
  void initState() {
    super.initState();
    // Inisialisasi ukuran font dari preferensi pengguna yang tersimpan
    _fontSize = Provider.of<ThemeProvider>(context, listen: false).fontSize;

    // Jika tidak ada gambar jepretan, default tampilkan mode teks bersih berlatar hitam
    _isTextView = widget.imageBytes == null && !widget.hasImage;

    // Pasang callback TTS native
    _ttsService.onProgress = (progress, word) {
      if (!mounted) return;
      setState(() {
        _progress = progress;
      });
    };

    _ttsService.onStart = () {
      if (!mounted) return;
      setState(() {
        _isPlaying = true;
      });
    };

    _ttsService.onPause = () {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
      });
    };

    _ttsService.onCompletion = () {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _progress = 0.0;
      });
    };

    // Langsung bacakan teks secara otomatis saat layar dibuka (SKPPL Auto-Play)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final langCode = _selectedLanguage == 'Indonesia' ? 'id-ID' : 'en-US';
      await _ttsService.setLanguage(langCode);
      await _ttsService.setSpeed(_speed);
      if (mounted) {
        await _ttsService.speak(_activeText);
      }
    });
  }

  @override
  void dispose() {
    _ttsService.stop();
    _ttsService.onProgress = null;
    _ttsService.onStart = null;
    _ttsService.onPause = null;
    _ttsService.onCompletion = null;
    _ttsService.onError = null;
    super.dispose();
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _ttsService.pause();
    } else {
      _ttsService.speak(_activeText);
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
    _ttsService.setSpeed(_speed);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark(context);
    final strings = AppStrings.of(context);
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
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
            // Photo View with Google Lens Text Selection Overlay
            if (widget.imageBytes != null)
              Positioned.fill(
                top: topPadding + 64,
                bottom: bottomPadding + 140,
                child: OcrImageOverlay(
                  imageBytes: widget.imageBytes!,
                  imageSize: widget.ocrResult?.imageSize ?? Size.zero,
                  elements: widget.ocrResult?.elements ?? const [],
                  selectedIds: _selectedIds,
                  highlightColor: themeProvider.highlightColor,
                  isDark: isDark,
                  isHighContrast: themeProvider.isHighContrast,
                  onSelectionChanged: _onSelectionChanged,
                  onClearSelection: _onClearSelection,
                ),
              )
            else
              Container(color: Colors.black),
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
                    text: _activeText,
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
                          color: isDark
                              ? const Color(0xFF1E1E1E)
                              : Colors.white,
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
                            FeedbackDialog.show(
                              context,
                              strings: strings,
                              isDark: isDark,
                            );
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
                            height: 52,
                            child: Text(
                              strings.settings,
                              style: TextStyle(
                                color: isDark ? Colors.white : AppColors.black,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'feedback',
                            height: 52,
                            child: Text(
                              strings.feedback,
                              style: TextStyle(
                                color: isDark ? Colors.white : AppColors.black,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'faq',
                            height: 52,
                            child: Text(
                              strings.faq,
                              style: TextStyle(
                                color: isDark ? Colors.white : AppColors.black,
                                fontSize: 18,
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
                _ttsService.seekTo(val);
              },
              selectedLanguage: _selectedLanguage,
              onLanguageTap: () {
                LanguageBottomSheet.show(
                  context,
                  strings: strings,
                  isDark: isDark,
                  selectedLanguage: _selectedLanguage,
                  onLanguageSelected: (lang) async {
                    setState(() {
                      _selectedLanguage = lang;
                    });
                    final langCode = lang == 'Indonesia' ? 'id-ID' : 'en-US';
                    await _ttsService.setLanguage(langCode);
                    if (_isPlaying) {
                      await _ttsService.speak(_activeText);
                    }
                  },
                );
              },
              onRewind: () {
                _ttsService.seekRelative(-0.1);
              },
              isPlaying: _isPlaying,
              onPlayPause: _togglePlayPause,
              onForward: () {
                _ttsService.seekRelative(0.1);
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
