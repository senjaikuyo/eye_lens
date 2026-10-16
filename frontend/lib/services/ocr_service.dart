import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Service untuk ekstraksi karakter teks on-device menggunakan Google ML Kit:
/// - Menggunakan model Latin Script berkecepatan tinggi (< 500 ms).
/// - Menerima citra foto dari memori RAM (Uint8List).
/// - Menjaga privasi: memproses citra via ephemeral temp file yang langsung
///   dimusnahkan di blok `finally` (0 byte penulisan permanen di gawai).
/// - Mengembalikan teks hasil ekstraksi bersih.
class OcrService {
  final TextRecognizer _textRecognizer;
  bool _isDisposed = false;

  OcrService({TextRecognitionScript script = TextRecognitionScript.latin})
      : _textRecognizer = TextRecognizer(script: script);

  /// Mengekstrak karakter teks dari citra foto yang berada di RAM (Uint8List).
  Future<String> processImageFromRAM(Uint8List bytes) async {
    if (_isDisposed) return '';

    File? tempFile;
    try {
      // Tulis sementara ke direktori cache sementara OS untuk mempertahankan EXIF rotation
      final tempDir = Directory.systemTemp;
      final tempPath =
          '${tempDir.path}/ocr_ephemeral_${DateTime.now().microsecondsSinceEpoch}.jpg';
      tempFile = File(tempPath);
      await tempFile.writeAsBytes(bytes, flush: true);

      final inputImage = InputImage.fromFilePath(tempPath);
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);

      return recognizedText.text.trim();
    } catch (e) {
      debugPrint('[OcrService] Ekstraksi OCR gagal: $e');
      return '';
    } finally {
      // Ephemeral Memory: Pastikan file sementara selalu terhapus dari disk
      if (tempFile != null) {
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (_) {
          // Abaikan jika sudah terhapus
        }
      }
    }
  }

  /// Mengekstrak teks langsung dari berkas file yang ada (misal: pilihan dari galeri).
  Future<String> processImageFromFile(String filePath) async {
    if (_isDisposed) return '';

    try {
      final inputImage = InputImage.fromFilePath(filePath);
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);
      return recognizedText.text.trim();
    } catch (e) {
      debugPrint('[OcrService] Ekstraksi OCR file gagal: $e');
      return '';
    }
  }

  /// Membebaskan memori native C++ Google ML Kit.
  Future<void> dispose() async {
    _isDisposed = true;
    try {
      await _textRecognizer.close();
    } catch (e) {
      debugPrint('[OcrService] Gagal menutup text recognizer: $e');
    }
  }
}
