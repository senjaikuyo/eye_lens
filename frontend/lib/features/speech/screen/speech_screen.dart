import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:eye_lens/app/theme/app_colors.dart';
import 'package:eye_lens/core/constants/app_strings.dart';
import 'package:eye_lens/features/ocr/models/ocr_element.dart';
import 'package:eye_lens/features/speech/models/text_formatter_models.dart';
import 'package:eye_lens/core/services/language_provider.dart';
import 'package:eye_lens/features/settings/logic/settings_provider.dart';
import 'package:eye_lens/core/services/display_preferences_provider.dart';
import 'package:eye_lens/features/speech/logic/auto_play_helper.dart';
import 'package:eye_lens/features/image_area/logic/lens_selection_controller.dart';
import 'package:eye_lens/features/image_area/logic/lens_selection_helper.dart';
import 'package:eye_lens/features/speech/logic/tts_service.dart';
import 'package:eye_lens/core/widgets/feedback_dialog.dart';
import 'package:eye_lens/features/camera/screen/widgets/no_text_alert_banner.dart';
import 'package:eye_lens/features/settings/screen/faq_screen.dart';
import 'package:eye_lens/features/settings/screen/settings_screen.dart';
import 'package:eye_lens/features/appearance/screen/appearance_sheet.dart';
import 'package:eye_lens/features/speech/screen/widgets/audio_player_bar.dart';
import 'package:eye_lens/features/settings/screen/widgets/language_sheet.dart';
import 'package:eye_lens/features/speech/screen/widgets/speech_body_view.dart';
import 'package:eye_lens/features/speech/screen/widgets/speech_mode_toggle_button.dart';
import 'package:eye_lens/features/speech/screen/widgets/speech_top_action_bar.dart';

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
  String _selectedLanguage = 'Indonesia'; // 'Indonesia' or 'English'
  double _speed = 1.0;
  final TtsService _ttsService = TtsService();
  late final LensSelectionController _lensSelectionController;
  bool _isAppearanceSheetOpen = false;

  late String _currentFramedText;
  FormattedTextResult? _currentFramedFormattedResult;
  bool _hasTextInFrame = true;
  String _noTextAlertTitle = '';
  String _noTextAlertMessage = '';
  bool _showNoTextAlert = false;
  Timer? _noTextAlertDismissTimer;

  String get _activeText => _currentFramedText;

  void _onFrameChanging() {
    _ttsService.stop();
    _isPlayingNotifier.value = false;
    _progressNotifier.value = 0.0;
    _currentCharIndexNotifier.value = 0;
  }

  void _onSelectionComputed(
    LensSelectionResult result,
    FrameChangeTrigger trigger,
  ) {
    if (!mounted) return;
    final strings = AppStrings.of(context);
    final alertTitle = result.validation.getAlertTitle(strings);
    final alertMessage = result.validation.getAlertInstruction(strings);

    final autoPlayEnabled = context.read<SettingsProvider>().autoPlayAudio;
    final decision = AutoPlayHelper.shouldAutoPlay(
      trigger: trigger,
      autoPlayEnabled: autoPlayEnabled,
      selectionResult: result,
    );

    setState(() {
      _hasTextInFrame = result.hasText;
      if (result.hasText) {
        _currentFramedText = result.text;
        _currentFramedFormattedResult = result.formattedResult;
        _dismissNoTextAlert();
      } else {
        _currentFramedText = '';
        _currentFramedFormattedResult = null;
        _noTextAlertTitle = alertTitle;
        _noTextAlertMessage = alertMessage;
      }
    });

    if (decision == AutoPlayDecision.alertNoText) {
      _triggerNoTextAlert(title: alertTitle, message: alertMessage);
    } else if (decision == AutoPlayDecision.speak) {
      _startSpeech();
    }
  }

  void _triggerNoTextAlert({required String title, required String message}) {
    _dismissNoTextAlert();
    _ttsService.stop();
    _isPlayingNotifier.value = false;

    setState(() {
      _showNoTextAlert = true;
      _noTextAlertTitle = title;
      _noTextAlertMessage = message;
    });

    final fullSpokenText = '$title. $message';

    HapticFeedback.mediumImpact();
    SemanticsService.sendAnnouncement(
      View.of(context),
      fullSpokenText,
      TextDirection.ltr,
    );

    final langCode = _selectedLanguage == 'Indonesia' ? 'id-ID' : 'en-US';
    _ttsService.setLanguage(langCode);
    _ttsService.speak(fullSpokenText);

    _noTextAlertDismissTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showNoTextAlert = false;
        });
      }
    });
  }

  void _dismissNoTextAlert() {
    _noTextAlertDismissTimer?.cancel();
    if (_showNoTextAlert) {
      setState(() {
        _showNoTextAlert = false;
      });
    }
  }

  Future<void> _startSpeech() async {
    if (!_hasTextInFrame || _activeText.trim().isEmpty) {
      final strings = AppStrings.of(context);
      final title = _noTextAlertTitle.isNotEmpty
          ? _noTextAlertTitle
          : strings.noTextFoundTitle;
      final msg = _noTextAlertMessage.isNotEmpty
          ? _noTextAlertMessage
          : strings.noTextFoundInstruction;
      _triggerNoTextAlert(title: title, message: msg);
      return;
    }

    if (_currentFramedFormattedResult != null) {
      await _ttsService.speakFormattedResult(_currentFramedFormattedResult!);
    } else {
      await _ttsService.speak(_activeText);
    }
  }

  @override
  void initState() {
    super.initState();
    _lensSelectionController = LensSelectionController();
    _fontSize = Provider.of<DisplayPreferencesProvider>(
      context,
      listen: false,
    ).fontSize;
    _fontSizeNotifier.value = _fontSize;
    _isTextView = widget.imageBytes == null && !widget.hasImage;

    _currentFramedText = widget.text;
    _currentFramedFormattedResult = widget.ocrResult?.formattedResult;
    _hasTextInFrame = widget.text.trim().isNotEmpty;

    final langProv = Provider.of<LanguageProvider>(context, listen: false);
    _selectedLanguage = langProv.isEnglish ? 'English' : 'Indonesia';

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

    _ttsService.onError = (_) {
      if (!mounted) return;
      _isPlayingNotifier.value = false;
      final message = AppStrings.of(context).isIndonesian
          ? 'Suara tidak tersedia. Periksa pengaturan suara di HP.'
          : 'Audio is unavailable. Check your phone sound settings.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 6)),
      );
      SemanticsService.sendAnnouncement(
        View.of(context),
        message,
        TextDirection.ltr,
      );
    };

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final langCode = _selectedLanguage == 'Indonesia' ? 'id-ID' : 'en-US';
      await _ttsService.setLanguage(langCode);
      await _ttsService.setSpeed(_speed);
      if (mounted && _hasTextInFrame && _isTextView) {
        await _startSpeech();
      }
    });
  }

  @override
  void dispose() {
    _noTextAlertDismissTimer?.cancel();
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
    _lensSelectionController.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_isPlayingNotifier.value) {
      _ttsService.pause();
    } else {
      _startSpeech();
    }
  }

  void _onToggleTextView() {
    if (!_isTextView) {
      // Ingin beralih dari gambar ke teks
      if (!_hasTextInFrame || _activeText.trim().isEmpty) {
        final strings = AppStrings.of(context);
        final title = _noTextAlertTitle.isNotEmpty
            ? _noTextAlertTitle
            : strings.noTextFoundTitle;
        final msg = _noTextAlertMessage.isNotEmpty
            ? _noTextAlertMessage
            : strings.noTextFoundInstruction;
        _triggerNoTextAlert(title: title, message: msg);
        return;
      }
      setState(() {
        _isTextView = true;
      });
    } else {
      // Kembali dari teks ke gambar: tutup sheet appearance jika terbuka
      _closeAppearanceSheetIfOpen();
      setState(() {
        _isTextView = false;
      });
    }
  }

  void _closeAppearanceSheetIfOpen() {
    if (_isAppearanceSheetOpen && mounted) {
      Navigator.of(context).maybePop();
      _isAppearanceSheetOpen = false;
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
    final themeProvider = context.watch<DisplayPreferencesProvider>();
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
          Positioned.fill(
            child: SpeechBodyView(
              isTextView: _isTextView,
              isDark: isDark,
              isHighContrast: themeProvider.isHighContrast,
              cursorColorEnabled: themeProvider.cursorColor,
              highlightColor: themeProvider.highlightColor,
              topPadding: topPadding,
              bottomPadding: bottomPadding,
              imageBytes: widget.imageBytes,
              ocrResult: widget.ocrResult,
              lensSelectionController: _lensSelectionController,
              onFrameChanging: _onFrameChanging,
              onSelectionComputed: _onSelectionComputed,
              activeText: _activeText,
              formattedResult: _currentFramedFormattedResult,
              fontSizeNotifier: _fontSizeNotifier,
              progressNotifier: _progressNotifier,
              currentCharIndexNotifier: _currentCharIndexNotifier,
              onProgressChanged: (val) {
                _progressNotifier.value = val;
                _ttsService.seekTo(val);
              },
              onCharIndexChanged: (idx) {
                _currentCharIndexNotifier.value = idx;
                _ttsService.seekToCharIndex(idx);
              },
            ),
          ),

          // TOP ACTION BAR
          Positioned(
            top: topPadding + 10,
            left: 16,
            right: 16,
            child: SpeechTopActionBar(
              isDark: isDark,
              strings: strings,
              showAppearanceButton: _isTextView,
              onBackPressed: () => Navigator.of(context).pop(),
              onAppearancePressed: () {
                _isAppearanceSheetOpen = true;
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
                ).whenComplete(() {
                  _isAppearanceSheetOpen = false;
                });
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
                onToggle: _onToggleTextView,
              ),
            ),

          // ALERT BANNER JIKA TANPA TEKS DI DALAM BINGKAI
          NoTextAlertBanner(
            isVisible: _showNoTextAlert,
            title: _noTextAlertTitle,
            message: _noTextAlertMessage,
            bottomPadding: bottomPadding + 140,
            onClose: _dismissNoTextAlert,
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
