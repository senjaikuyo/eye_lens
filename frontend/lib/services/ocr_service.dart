import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/ocr_element.dart';

/// Service untuk ekstraksi karakter teks on-device menggunakan Google ML Kit:
/// - Menggunakan model Latin Script berkecepatan tinggi (< 500 ms).
/// - Mendukung ekstraksi teks penuh maupun koordinat bounding box setiap elemen/baris.
/// - Menjaga privasi: memproses citra via ephemeral temp file yang langsung
///   dimusnahkan di blok `finally` (0 byte penulisan permanen di gawai).
class OcrService {
  final TextRecognizer _textRecognizer;
  bool _isDisposed = false;

  OcrService({TextRecognitionScript script = TextRecognitionScript.latin})
    : _textRecognizer = TextRecognizer(script: script);

  /// Mengekstrak teks lengkap beserta koordinat bounding box setiap elemen dari RAM (Uint8List).
  Future<OcrResult> processImageWithCoordinates(Uint8List bytes) async {
    if (_isDisposed) return OcrResult.empty;

    File? tempFile;
    try {
      final decodedImage = await decodeImageFromList(bytes);
      final imageSize = Size(
        decodedImage.width.toDouble(),
        decodedImage.height.toDouble(),
      );
      decodedImage.dispose();

      final tempDir = Directory.systemTemp;
      final tempPath =
          '${tempDir.path}/ocr_ephemeral_${DateTime.now().microsecondsSinceEpoch}.jpg';
      tempFile = File(tempPath);
      await tempFile.writeAsBytes(bytes, flush: true);

      final inputImage = InputImage.fromFilePath(tempPath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );

      final List<OcrElement> elements = [];
      int elementIndex = 0;

      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          if (line.text.trim().isNotEmpty) {
            elements.add(
              OcrElement(
                id: 'elem_${elementIndex++}',
                text: line.text,
                boundingBox: line.boundingBox,
              ),
            );
          }
        }
      }

      return OcrResult(
        fullText: recognizedText.text.trim(),
        elements: elements,
        imageSize: imageSize,
      );
    } catch (e) {
      debugPrint('[OcrService] Ekstraksi OCR berkoordinat gagal: $e');
      return OcrResult.empty;
    } finally {
      if (tempFile != null) {
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (_) {}
      }
    }
  }

  /// Mengekstrak teks lengkap beserta koordinat bounding box dari file.
  Future<OcrResult> processFileWithCoordinates(String filePath) async {
    if (_isDisposed) return OcrResult.empty;

    try {
      final bytes = await File(filePath).readAsBytes();
      final decodedImage = await decodeImageFromList(bytes);
      final imageSize = Size(
        decodedImage.width.toDouble(),
        decodedImage.height.toDouble(),
      );
      decodedImage.dispose();

      final inputImage = InputImage.fromFilePath(filePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );

      final List<OcrElement> elements = [];
      int elementIndex = 0;

      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          if (line.text.trim().isNotEmpty) {
            elements.add(
              OcrElement(
                id: 'elem_${elementIndex++}',
                text: line.text,
                boundingBox: line.boundingBox,
              ),
            );
          }
        }
      }

      return OcrResult(
        fullText: recognizedText.text.trim(),
        elements: elements,
        imageSize: imageSize,
      );
    } catch (e) {
      debugPrint('[OcrService] Ekstraksi OCR file berkoordinat gagal: $e');
      return OcrResult.empty;
    }
  }

  /// Mengekstrak karakter teks dari citra foto yang berada di RAM (Uint8List).
  Future<String> processImageFromRAM(Uint8List bytes) async {
    final result = await processImageWithCoordinates(bytes);
    return result.fullText;
  }

  /// Mengekstrak teks langsung dari berkas file yang ada (misal: pilihan dari galeri).
  Future<String> processImageFromFile(String filePath) async {
    final result = await processFileWithCoordinates(filePath);
    return result.fullText;
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
