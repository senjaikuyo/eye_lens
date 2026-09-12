import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../services/ocr_service.dart';
import '../services/tts_service.dart';

class ReaderProvider with ChangeNotifier {
  final OcrService _ocrService = OcrService();
  final TtsService _ttsService = TtsService();

  bool _isProcessing = false;
  OcrResult? _ocrResult;
  String _activeImagePath = '';
  TtsState _ttsState = TtsState.stopped;

  int _highlightStart = 0;
  int _highlightEnd = 0;
  String _highlightWord = '';

  bool _isInitialized = false;

  bool get isProcessing => _isProcessing;
  OcrResult? get ocrResult => _ocrResult;
  String get activeImagePath => _activeImagePath;
  TtsState get ttsState => _ttsState;
  bool get isPlaying => _ttsState == TtsState.playing;

  int get highlightStart => _highlightStart;
  int get highlightEnd => _highlightEnd;
  String get highlightWord => _highlightWord;

  Future<void> init() async {
    if (_isInitialized) return;
    await _ttsService.init();

    _ttsService.onStateChanged = (state) {
      _ttsState = state;
      notifyListeners();
    };

    _ttsService.onProgress = (start, end, word) {
      _highlightStart = start;
      _highlightEnd = end;
      _highlightWord = word;
      notifyListeners();
    };

    _ttsService.onCompletion = () {
      _ttsState = TtsState.stopped;
      _highlightStart = 0;
      _highlightEnd = 0;
      _highlightWord = '';
      notifyListeners();
    };

    _isInitialized = true;
  }

  Future<bool> processAndRead({
    required String imagePath,
    required double speechRate,
    required String language,
  }) async {
    await init();
    _isProcessing = true;
    _activeImagePath = imagePath;
    notifyListeners();

    try {
      _ocrResult = await _ocrService.processImage(imagePath);

      if (_ocrResult == null || _ocrResult!.isEmpty) {
        _isProcessing = false;
        notifyListeners();
        // Beri panduan suara ramah jika foto goyang/kosong
        await _ttsService.speakBlurWarning();
        return false;
      }

      // Simpan ke SQLite Riwayat
      await DatabaseHelper.instance.insertHistory(_ocrResult!.fullText);

      _isProcessing = false;
      notifyListeners();

      // Auto-play TTS seketika
      await _ttsService.speak(
        _ocrResult!.fullText,
        rateMultiplier: speechRate,
        lang: language,
      );

      return true;
    } catch (e) {
      _isProcessing = false;
      notifyListeners();
      await _ttsService.speakBlurWarning();
      return false;
    }
  }

  Future<void> readExistingText({
    required String text,
    required double speechRate,
    required String language,
  }) async {
    await init();
    _ocrResult = OcrResult(
      fullText: text,
      words: [],
      imageSize: const Size(1080, 1920),
    );
    _activeImagePath = '';
    notifyListeners();

    await _ttsService.speak(
      text,
      rateMultiplier: speechRate,
      lang: language,
    );
  }

  Future<void> togglePlayPause() async {
    if (_ttsState == TtsState.playing) {
      await _ttsService.pause();
    } else {
      await _ttsService.resume();
    }
  }

  Future<void> seekForward10s({double speechRate = 1.0}) async {
    await _ttsService.seekOffset(10, rateMultiplier: speechRate);
  }

  Future<void> seekBackward10s({double speechRate = 1.0}) async {
    await _ttsService.seekOffset(-10, rateMultiplier: speechRate);
  }

  Future<void> stop() async {
    await _ttsService.stop();
  }

  @override
  void dispose() {
    _ttsService.dispose();
    _ocrService.dispose();
    super.dispose();
  }
}
