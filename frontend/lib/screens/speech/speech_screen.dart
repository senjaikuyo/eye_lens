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
import 'widgets/speech_mode_toggle_button.dart';
import 'widgets/speech_top_action_bar.dart';

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
  final ValueNotifier<double> _fontSizeNotifier = ValueNotifier<double>(32.0);
  final ValueNotifier<bool> _isPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<double> _progressNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<int> _currentCharIndexNotifier = ValueNotifier<int>(0);
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
    });
    _progressNotifier.value = 0.0;
    _currentCharIndexNotifier.value = 0;

    if (_isPlayingNotifier.value) {
      _startSpeech();
    }
  }

  void _onClearSelection() {
    setState(() {
      _selectedElements.clear();
      _selectedIds.clear();
    });
    _progressNotifier.value = 0.0;
    _currentCharIndexNotifier.value = 0;

    if (_isPlayingNotifier.value) {
      _startSpeech();
    }
  }

  Future<void> _startSpeech() async {
    if (_selectedElements.isNotEmpty) {
      await _ttsService.speak(_activeText);
    } else if (widget.ocrResult?.formattedResult != null) {
      await _ttsService.speakFormattedResult(widget.ocrResult!.formattedResult!);
    } else {
      await _ttsService.speak(_activeText);
    }
  }

  @override
  void initState() {
    super.initState();
    _fontSize = Provider.of<ThemeProvider>(context, listen: false).fontSize;
    _fontSizeNotifier.value = _fontSize;
    _isTextView = widget.imageBytes == null && !widget.hasImage;

    _ttsService.onProgress = (double progress, String word, [int? charIndex]) {
      if (!mounted) return;
      _progressNotifier.value = progress;
      if (charIndex != null) {
        _currentCharIndexNotifier.value = charIndex;
      }
    };

    _ttsService.onStart = () {
      if (!mounted) return;
      _isPlayingNotifier.value = true;
    };

    _ttsService.onPause = () {
      if (!mounted) return;
      _isPlayingNotifier.value = false;
    };

    _ttsService.onCompletion = () {
      if (!mounted) return;
      _isPlayingNotifier.value = false;
      _progressNotifier.value = 0.0;
      _currentCharIndexNotifier.value = 0;
    };

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final langCode = _selectedLanguage == 'Indonesia' ? 'id-ID' : 'en-US';
      await _ttsService.setLanguage(langCode);
      await _ttsService.setSpeed(_speed);
      if (mounted) {
        await _startSpeech();
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
    _currentCharIndexNotifier.dispose();
    _progressNotifier.dispose();
    _isPlayingNotifier.dispose();
    _fontSizeNotifier.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_isPlayingNotifier.value) {
      _ttsService.pause();
    } else {
      _startSpeech();
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
            if (widget.imageBytes != null)
              Positioned.fill(
                top: topPadding + 64,
                bottom: bottomPadding + 140,
                child: OcrImageOverlay(
                  imageBytes: widget.imageBytes!,
                  imageSize: widget.ocrResult?.imageSize ?? Size.zero,
                  elements: widget.ocrResult?.elements ?? const [],
                  rejectedLines: widget.ocrResult?.rejectedLines ?? const [],
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
                  child: ValueListenableBuilder<double>(
                    valueListenable: _fontSizeNotifier,
                    builder: (context, currentFontSize, _) {
                      return ValueListenableBuilder<double>(
                        valueListenable: _progressNotifier,
                        builder: (context, progress, _) {
                          return ValueListenableBuilder<int>(
                            valueListenable: _currentCharIndexNotifier,
                            builder: (context, charIndex, _) {
                              return HighlightedTextView(
                                text: _activeText,
                                formattedResult: _selectedElements.isEmpty
                                    ? widget.ocrResult?.formattedResult
                                    : null,
                                currentCharIndex: charIndex,
                                fontSize: currentFontSize,
                                cursorColorEnabled: themeProvider.cursorColor,
                                highlightColor: themeProvider.highlightColor,
                                isDark: isDark,
                                isHighContrast: themeProvider.isHighContrast,
                                progress: progress,
                                onProgressChanged: (val) {
                                  _progressNotifier.value = val;
                                  _ttsService.seekTo(val);
                                },
                                onCharIndexChanged: (idx) {
                                  _currentCharIndexNotifier.value = idx;
                                  _ttsService.seekToCharIndex(idx);
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ],

          // TOP ACTION BAR
          Positioned(
            top: topPadding + 10,
            left: 16,
            right: 16,
            child: SpeechTopActionBar(
              isDark: isDark,
              strings: strings,
              onBackPressed: () => Navigator.of(context).pop(),
              onAppearancePressed: () {
                AppearanceBottomSheet.show(
                  context,
                  themeProvider: themeProvider,
                  strings: strings,
                  fontSize: _fontSize,
                  onFontSizeChanged: (newSize) {
                    _fontSize = newSize;
                    _fontSizeNotifier.value = newSize;
                  },
                  onFontSizeChangeEnd: (finalSize) {
                    _fontSize = finalSize;
                    _fontSizeNotifier.value = finalSize;
                    themeProvider.setFontSize(finalSize);
                  },
                );
              },
              onSettingsTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
              onFeedbackTap: () {
                FeedbackDialog.show(context, strings: strings, isDark: isDark);
              },
              onFaqTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const FaqScreen()),
                );
              },
            ),
          ),

          // FLOATING MODE TOGGLE BUTTON
          if (hasValidImage)
            Positioned(
              right: 20,
              bottom: bottomPadding + 148,
              child: SpeechModeToggleButton(
                isTextView: _isTextView,
                onToggle: () {
                  setState(() {
                    _isTextView = !_isTextView;
                  });
                },
              ),
            ),

          // BOTTOM AUDIO PLAYER CONTROLS
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ValueListenableBuilder<double>(
              valueListenable: _progressNotifier,
              builder: (context, progress, _) {
                return ValueListenableBuilder<bool>(
                  valueListenable: _isPlayingNotifier,
                  builder: (context, isPlaying, _) {
                    return AudioPlayerBar(
                      isTextView: _isTextView,
                      isDark: isDark,
                      cursorColorEnabled: themeProvider.cursorColor,
                      highlightColor: themeProvider.highlightColor,
                      progress: progress,
                      onProgressChanged: (val) {
                        _progressNotifier.value = val;
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
                            final langCode = lang == 'Indonesia'
                                ? 'id-ID'
                                : 'en-US';
                            await _ttsService.setLanguage(langCode);
                            if (_isPlayingNotifier.value) {
                              await _startSpeech();
                            }
                          },
                        );
                      },
                      onRewind: () {
                        _ttsService.seekSeconds(-10.0);
                      },
                      isPlaying: isPlaying,
                      onPlayPause: _togglePlayPause,
                      onForward: () {
                        _ttsService.seekSeconds(10.0);
                      },
                      speed: _speed,
                      onSpeedTap: _onSpeedTap,
                      bottomPadding: bottomPadding,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
