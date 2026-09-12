import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';

enum TtsState { playing, paused, stopped }

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  TtsState _state = TtsState.stopped;

  String _currentText = '';
  int _currentWordStart = 0;
  int _currentWordEnd = 0;
  String _currentWord = '';

  Function(TtsState)? onStateChanged;
  Function(int start, int end, String word)? onProgress;
  Function()? onCompletion;

  TtsState get state => _state;
  String get currentWord => _currentWord;
  int get currentWordStart => _currentWordStart;
  int get currentWordEnd => _currentWordEnd;

  Future<void> init() async {
    await _flutterTts.setLanguage('id-ID');
    await _flutterTts.setSpeechRate(0.45); // Natural baseline rate for elderly
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      _state = TtsState.playing;
      onStateChanged?.call(_state);
    });

    _flutterTts.setCompletionHandler(() {
      _state = TtsState.stopped;
      _currentWord = '';
      _currentWordStart = 0;
      _currentWordEnd = 0;
      onStateChanged?.call(_state);
      onCompletion?.call();
    });

    _flutterTts.setPauseHandler(() {
      _state = TtsState.paused;
      onStateChanged?.call(_state);
    });

    _flutterTts.setContinueHandler(() {
      _state = TtsState.playing;
      onStateChanged?.call(_state);
    });

    _flutterTts.setErrorHandler((msg) {
      _state = TtsState.stopped;
      onStateChanged?.call(_state);
    });

    _flutterTts.setProgressHandler((String text, int startOffset, int endOffset, String word) {
      _currentWordStart = startOffset;
      _currentWordEnd = endOffset;
      _currentWord = word;
      onProgress?.call(startOffset, endOffset, word);
    });
  }

  Future<void> setLanguage(String lang) async {
    await _flutterTts.setLanguage(lang);
  }

  Future<void> setRate(double rateMultiplier) async {
    // FlutterTTS rate range is 0.0 - 1.0 (0.45 is ~1.0x normal in flutter_tts)
    double rate = 0.45 * rateMultiplier;
    if (rate > 1.0) rate = 1.0;
    if (rate < 0.2) rate = 0.2;
    await _flutterTts.setSpeechRate(rate);
  }

  Future<void> speak(String text, {double rateMultiplier = 1.0, String lang = 'id-ID'}) async {
    if (text.trim().isEmpty) return;
    await stop();
    _currentText = text;
    await setLanguage(lang);
    await setRate(rateMultiplier);
    await _flutterTts.speak(text);
  }

  Future<void> pause() async {
    await _flutterTts.pause();
    _state = TtsState.paused;
    onStateChanged?.call(_state);
  }

  Future<void> resume() async {
    if (_state == TtsState.paused) {
      if (_currentWordEnd > 0 && _currentWordEnd < _currentText.length) {
        final remaining = _currentText.substring(_currentWordStart);
        await _flutterTts.speak(remaining);
      } else {
        await _flutterTts.speak(_currentText);
      }
    } else {
      await _flutterTts.speak(_currentText);
    }
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    _state = TtsState.stopped;
    _currentWordStart = 0;
    _currentWordEnd = 0;
    _currentWord = '';
    onStateChanged?.call(_state);
  }

  // Navigasi 10 Detik (+/- 10s perkiraan lompat kata)
  Future<void> seekOffset(int seconds, {double rateMultiplier = 1.0}) async {
    if (_currentText.isEmpty) return;
    // Rata-rata 2.5 kata per detik bicara
    final wordsPerSec = 2.5 * rateMultiplier;
    final wordOffset = (seconds * wordsPerSec).round();

    final allWords = _currentText.split(' ');
    // Cari index kata saat ini
    int currentWordIndex = 0;
    int charAcc = 0;
    for (int i = 0; i < allWords.length; i++) {
      if (charAcc >= _currentWordStart) {
        currentWordIndex = i;
        break;
      }
      charAcc += allWords[i].length + 1;
    }

    int targetWordIndex = currentWordIndex + wordOffset;
    if (targetWordIndex < 0) targetWordIndex = 0;
    if (targetWordIndex >= allWords.length) targetWordIndex = allWords.length - 1;

    // Susun teks dari target index
    final newText = allWords.sublist(targetWordIndex).join(' ');
    await stop();
    await _flutterTts.speak(newText);
  }

  Future<void> speakBlurWarning() async {
    await stop();
    await _flutterTts.speak("Tulisan belum terbaca jelas. Mohon tahan ponsel lebih tenang dan coba lagi.");
  }

  void dispose() {
    _flutterTts.stop();
  }
}
