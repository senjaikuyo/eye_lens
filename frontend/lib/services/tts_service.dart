import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum TtsState { playing, stopped, paused }

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
  double _speedMultiplier = 1.0;
  double get speedMultiplier => _speedMultiplier;
  String _currentLanguage = 'id-ID';
  String get currentLanguage => _currentLanguage;

  void Function(double progress, String currentWord)? onProgress;
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

    _flutterTts.setCompletionHandler(() {
      _state = TtsState.stopped;
      _charOffset = 0;
      onProgress?.call(1.0, '');
      onCompletion?.call();
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
      final absoluteIndex = (_charOffset + start).clamp(0, _fullText.length);
      final progress = (_fullText.isNotEmpty)
          ? (absoluteIndex / _fullText.length).clamp(0.0, 1.0)
          : 0.0;
      onProgress?.call(progress, word);
    });

    _flutterTts.setErrorHandler((dynamic msg) {
      _state = TtsState.stopped;
      onError?.call(msg.toString());
    });
  }

  Future<void> setLanguage(String languageCode) async {
    _currentLanguage = languageCode;
    await _flutterTts.setLanguage(languageCode);
  }

  Future<void> setSpeed(double speedMultiplier) async {
    _speedMultiplier = speedMultiplier;
    // Pada Android & iOS flutter_tts, 0.5 adalah kecepatan normal 1.0x
    final nativeRate = (0.5 * speedMultiplier).clamp(0.1, 1.0);
    await _flutterTts.setSpeechRate(nativeRate);
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;

    // Jika sedang jeda dan teksnya sama, lanjutkan
    if (_state == TtsState.paused && _fullText == text) {
      await resume();
      return;
    }

    _fullText = text;
    _charOffset = 0;
    _state = TtsState.playing;
    await _flutterTts.stop();
    await _flutterTts.speak(text);
  }

  Future<void> pause() async {
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
      final res = await _flutterTts.speak(_fullText.substring(_charOffset));
      if (res == 1) {
        _state = TtsState.playing;
        onStart?.call();
      }
    }
  }

  Future<void> stop() async {
    _state = TtsState.stopped;
    _charOffset = 0;
    await _flutterTts.stop();
  }

  Future<void> seekRelative(double deltaFraction) async {
    if (_fullText.isEmpty) return;

    final currentFraction = _fullText.isNotEmpty
        ? (_charOffset / _fullText.length)
        : 0.0;
    final targetFraction = (currentFraction + deltaFraction).clamp(0.0, 0.98);
    await seekTo(targetFraction);
  }

  Future<void> seekTo(double fraction) async {
    if (_fullText.isEmpty) return;

    final clampedFraction = fraction.clamp(0.0, 0.98);
    _charOffset = (clampedFraction * _fullText.length).round();

    // Sesuaikan offset agar berada di awal kata terdekat
    if (_charOffset > 0 && _charOffset < _fullText.length) {
      final spaceIndex = _fullText.indexOf(' ', _charOffset);
      if (spaceIndex != -1 && spaceIndex - _charOffset < 15) {
        _charOffset = spaceIndex + 1;
      }
    }

    final remainingText = _fullText.substring(_charOffset);
    onProgress?.call(clampedFraction, '');

    if (_state == TtsState.playing) {
      await _flutterTts.stop();
      _state = TtsState.playing;
      await _flutterTts.speak(remainingText);
    }
  }

  void dispose() {
    _flutterTts.stop();
  }
}
