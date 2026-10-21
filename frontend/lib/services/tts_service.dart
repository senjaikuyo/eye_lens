import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/text_formatter_models.dart';
import 'text_formatter.dart';

enum TtsState { playing, stopped, paused }

typedef TtsProgressCallback =
    void Function(double progress, String currentWord, [int? charIndex]);

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;

  final FlutterTts _flutterTts = FlutterTts();

  TtsState _state = TtsState.stopped;
  TtsState get state => _state;
  bool get isPlaying => _state == TtsState.playing;
  bool get isPaused => _state == TtsState.paused;
  bool get isStopped => _state == TtsState.stopped;

  String _fullText = '';
  int _charOffset = 0;
  int _currentCharIndex = 0;
  double _speedMultiplier = 1.0;
  double get speedMultiplier => _speedMultiplier;
  String _currentLanguage = 'id-ID';
  String get currentLanguage => _currentLanguage;

  // Manajemen paragraf
  FormattedTextResult? _formattedResult;
  int _currentParagraphIndex = 0;
  int _charOffsetInParagraph = 0;
  Timer? _paragraphPauseTimer;
  int _playbackSessionId = 0;

  TtsProgressCallback? onProgress;
  VoidCallback? onStart;
  VoidCallback? onCompletion;
  VoidCallback? onPause;
  void Function(String error)? onError;

  TtsService._internal() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage(_currentLanguage);
    await _flutterTts.setSpeechRate(0.5); // FlutterTts normal rate is ~0.5
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      _state = TtsState.playing;
      onStart?.call();
    });

    _flutterTts.setCompletionHandler(() async {
      if (_formattedResult != null) {
        await _handleParagraphCompletion();
      } else {
        _state = TtsState.stopped;
        _charOffset = 0;
        _currentCharIndex = 0;
        onProgress?.call(1.0, '', _fullText.length);
        onCompletion?.call();
      }
    });

    _flutterTts.setPauseHandler(() {
      _state = TtsState.paused;
      onPause?.call();
    });

    _flutterTts.setContinueHandler(() {
      _state = TtsState.playing;
      onStart?.call();
    });

    _flutterTts.setProgressHandler((
      String text,
      int start,
      int end,
      String word,
    ) {
      if (_fullText.isEmpty) return;

      int absoluteIndex;
      if (_formattedResult != null &&
          _currentParagraphIndex < _formattedResult!.paragraphs.length) {
        final currentPara =
            _formattedResult!.paragraphs[_currentParagraphIndex];
        absoluteIndex =
            (currentPara.startIndex + _charOffsetInParagraph + start).clamp(
              0,
              _fullText.length,
            );
      } else {
        absoluteIndex = (_charOffset + start).clamp(0, _fullText.length);
      }

      _currentCharIndex = absoluteIndex;
      final progress = (_fullText.isNotEmpty)
          ? (absoluteIndex / _fullText.length).clamp(0.0, 1.0)
          : 0.0;
      onProgress?.call(progress, word, absoluteIndex);
    });

    _flutterTts.setErrorHandler((dynamic msg) {
      _state = TtsState.stopped;
      _paragraphPauseTimer?.cancel();
      onError?.call(msg.toString());
    });
  }

  /// Menangani penyelesaian satu paragraf dan memberikan jeda 300 ms sebelum paragraf berikutnya.
  Future<void> _handleParagraphCompletion() async {
    final result = _formattedResult;
    if (result == null) return;

    final nextIndex = _currentParagraphIndex + 1;
    if (nextIndex < result.paragraphs.length) {
      _currentParagraphIndex = nextIndex;
      _charOffsetInParagraph = 0;
      final sessionId = ++_playbackSessionId;

      _paragraphPauseTimer?.cancel();
      _paragraphPauseTimer = Timer(
        const Duration(milliseconds: TextFormatterConfig.paragraphPauseMs),
        () async {
          if (sessionId != _playbackSessionId || _state != TtsState.playing) {
            return;
          }
          await _speakCurrentParagraph();
        },
      );
    } else {
      // Seluruh paragraf selesai dibacakan
      _state = TtsState.stopped;
      _charOffset = 0;
      _currentCharIndex = 0;
      _currentParagraphIndex = 0;
      _charOffsetInParagraph = 0;
      onProgress?.call(1.0, '', _fullText.length);
      onCompletion?.call();
    }
  }

  Future<void> _speakCurrentParagraph() async {
    final result = _formattedResult;
    if (result == null ||
        _currentParagraphIndex >= result.paragraphs.length) {
      return;
    }

    final para = result.paragraphs[_currentParagraphIndex];
    String textToSpeak = para.text;
    if (_charOffsetInParagraph > 0 &&
        _charOffsetInParagraph < textToSpeak.length) {
      textToSpeak = textToSpeak.substring(_charOffsetInParagraph);
    }

    if (textToSpeak.trim().isEmpty) {
      // Lewati paragraf kosong
      await _handleParagraphCompletion();
      return;
    }

    await _flutterTts.speak(textToSpeak);
  }

  Future<void> setLanguage(String languageCode) async {
    _currentLanguage = languageCode;
    await _flutterTts.setLanguage(languageCode);
  }

  Future<void> setSpeed(double speedMultiplier) async {
    _speedMultiplier = speedMultiplier;
    final nativeRate = (0.5 * speedMultiplier).clamp(0.1, 1.0);
    await _flutterTts.setSpeechRate(nativeRate);
  }

  /// Membacakan teks terformat berbasis paragraf dengan jeda 300 ms antar paragraf.
  Future<void> speakFormattedResult(
    FormattedTextResult result, {
    int startCharIndex = 0,
  }) async {
    _paragraphPauseTimer?.cancel();
    _playbackSessionId++;

    _formattedResult = result;
    _fullText = result.fullText;

    if (result.paragraphs.isEmpty) {
      await speak(result.fullText);
      return;
    }

    // Tentukan paragraf awal berdasarkan startCharIndex
    int pIdx = 0;
    int offsetInP = 0;
    for (int i = 0; i < result.paragraphs.length; i++) {
      final p = result.paragraphs[i];
      if (startCharIndex >= p.startIndex && startCharIndex <= p.endIndex) {
        pIdx = i;
        offsetInP = startCharIndex - p.startIndex;
        break;
      }
    }

    _currentParagraphIndex = pIdx;
    _charOffsetInParagraph = offsetInP;
    _currentCharIndex = startCharIndex;
    _state = TtsState.playing;

    await _flutterTts.stop();
    await _speakCurrentParagraph();
  }

  /// Membacakan teks mentah (fallback).
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;

    _paragraphPauseTimer?.cancel();
    _playbackSessionId++;
    _formattedResult = null;

    if (_state == TtsState.paused && _fullText == text) {
      await resume();
      return;
    }

    _fullText = text;
    _charOffset = 0;
    _currentCharIndex = 0;
    _state = TtsState.playing;
    await _flutterTts.stop();
    await _flutterTts.speak(text);
  }

  Future<void> pause() async {
    _paragraphPauseTimer?.cancel();
    if (_state == TtsState.playing) {
      final res = await _flutterTts.pause();
      if (res == 1) {
        _state = TtsState.paused;
        onPause?.call();
      }
    }
  }

  Future<void> resume() async {
    if (_state == TtsState.paused) {
      _state = TtsState.playing;
      onStart?.call();

      if (_formattedResult != null) {
        await _speakCurrentParagraph();
      } else {
        final remaining = _fullText.substring(
          _charOffset.clamp(0, _fullText.length),
        );
        final res = await _flutterTts.speak(remaining);
        if (res != 1) {
          _state = TtsState.stopped;
        }
      }
    }
  }

  Future<void> stop() async {
    _paragraphPauseTimer?.cancel();
    _playbackSessionId++;
    _state = TtsState.stopped;
    _charOffset = 0;
    _currentCharIndex = 0;
    _currentParagraphIndex = 0;
    _charOffsetInParagraph = 0;
    await _flutterTts.stop();
  }

  /// Melompat relatif berdasarkan detik (misal: -10.0 atau +10.0 detik).
  Future<void> seekSeconds(double seconds) async {
    if (_fullText.isEmpty) return;
    // Rata-rata pelafalan ~15 karakter per detik disesuaikan kecepatan
    final deltaChars = (seconds * 15.0 * _speedMultiplier).round();
    final int maxLen = max(0, _fullText.length - 1);
    final int targetChar =
        (_currentCharIndex + deltaChars).clamp(0, maxLen).toInt();
    await seekToCharIndex(targetChar);
  }

  /// Melompat relatif berdasarkan fraksi (0.0 s.d. 1.0).
  Future<void> seekRelative(double deltaFraction) async {
    if (_fullText.isEmpty) return;

    final currentFraction = _fullText.isNotEmpty
        ? (_currentCharIndex / _fullText.length)
        : 0.0;
    final targetFraction = (currentFraction + deltaFraction).clamp(0.0, 0.98);
    await seekTo(targetFraction);
  }

  /// Melompat ke fraksi progres tertentu.
  Future<void> seekTo(double fraction) async {
    if (_fullText.isEmpty) return;
    final targetChar =
        (fraction.clamp(0.0, 0.98) * _fullText.length).round();
    await seekToCharIndex(targetChar);
  }

  /// Melompat ke indeks karakter tertentu pada teks akhir.
  Future<void> seekToCharIndex(int targetCharIndex) async {
    if (_fullText.isEmpty) return;

    final int maxLen = max(0, _fullText.length - 1);
    final int targetChar = targetCharIndex.clamp(0, maxLen).toInt();
    _currentCharIndex = targetChar;
    final progress = targetChar / _fullText.length;

    if (_formattedResult != null) {
      final result = _formattedResult!;
      int pIdx = 0;
      int offsetInP = 0;
      for (int i = 0; i < result.paragraphs.length; i++) {
        final p = result.paragraphs[i];
        if (targetChar >= p.startIndex && targetChar <= p.endIndex) {
          pIdx = i;
          offsetInP = targetChar - p.startIndex;
          break;
        }
      }

      _currentParagraphIndex = pIdx;
      _charOffsetInParagraph = offsetInP;

      onProgress?.call(progress, '', targetChar);

      if (_state == TtsState.playing) {
        _paragraphPauseTimer?.cancel();
        _playbackSessionId++;
        await _flutterTts.stop();
        _state = TtsState.playing;
        await _speakCurrentParagraph();
      }
    } else {
      _charOffset = targetChar;
      if (_charOffset > 0 && _charOffset < _fullText.length) {
        final spaceIndex = _fullText.indexOf(' ', _charOffset);
        if (spaceIndex != -1 && spaceIndex - _charOffset < 15) {
          _charOffset = spaceIndex + 1;
        }
      }

      final remainingText = _fullText.substring(_charOffset);
      onProgress?.call(progress, '', _charOffset);

      if (_state == TtsState.playing) {
        await _flutterTts.stop();
        _state = TtsState.playing;
        await _flutterTts.speak(remainingText);
      }
    }
  }

  void dispose() {
    _paragraphPauseTimer?.cancel();
    _flutterTts.stop();
  }
}
