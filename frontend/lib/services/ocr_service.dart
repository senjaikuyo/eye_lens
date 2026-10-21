import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/ocr_element.dart';
import '../models/text_formatter_models.dart';
import '../utils/image_dimension_helper.dart';
import 'ocr_noise_filter.dart';
import 'text_formatter.dart';

/// Service untuk ekstraksi karakter teks on-device menggunakan Google ML Kit:
/// - Menggunakan model Latin Script berkecepatan tinggi (< 500 ms).
/// - Mendukung ekstraksi teks penuh maupun koordinat bounding box setiap elemen/baris.
/// - Merapikan hasil teks otomatis sesuai paragraf asli dan multi-kolom via TextFormatter.
/// - Menjaga privasi: memproses citra via ephemeral temp file yang langsung
///   dimusnahkan di blok `finally` (0 byte penulisan permanen di gawai).
class OcrService {
  final TextRecognizer _textRecognizer;
  bool _isDisposed = false;

  OcrService({TextRecognitionScript script = TextRecognitionScript.latin})
    : _textRecognizer = TextRecognizer(script: script);

  /// Helper untuk membangun OcrResult lengkap dari RecognizedText dan imageSize.
  /// Menerapkan OcrNoiseFilter sebelum TextFormatter agar teks sampah tidak masuk
  /// ke hasil, halaman speech, maupun TTS.
  Future<OcrResult> _buildOcrResult({
    required RecognizedText recognizedText,
    required Size imageSize,
  }) async {
    final List<OcrLineData> allLines = [];
    final List<Rect> originalBlockBounds = [];
    final List<String> originalBlockTexts = [];

    for (int bIdx = 0; bIdx < recognizedText.blocks.length; bIdx++) {
      final block = recognizedText.blocks[bIdx];
      originalBlockBounds.add(block.boundingBox);
      originalBlockTexts.add(block.text);
      for (final line in block.lines) {
        if (line.text.trim().isNotEmpty) {
          allLines.add(
            OcrLineData(
              text: line.text,
              boundingBox: line.boundingBox,
              confidence: line.confidence,
              blockIndex: bIdx,
            ),
          );
        }
      }
    }

    // 1. Jalankan penyaring noise di background isolate
    final filterResult = await OcrNoiseFilter.filterWithCompute(
      OcrNoiseFilterInput(
        lines: allLines,
        imageSize: imageSize,
      ),
    );

    // 2. Kelompokkan baris yang lolos kembali ke dalam blok masing-masing
    final Map<int, List<OcrLineData>> blockMap = {};
    for (final line in filterResult.acceptedLines) {
      blockMap.putIfAbsent(line.blockIndex, () => []).add(line);
    }

    final List<OcrBlockData> filteredBlocks = [];
    for (final entry in blockMap.entries) {
      final bIdx = entry.key;
      final linesInBlock = entry.value;
      final originalBounds = (bIdx >= 0 && bIdx < originalBlockBounds.length)
          ? originalBlockBounds[bIdx]
          : linesInBlock.first.boundingBox;
      final originalText = (bIdx >= 0 && bIdx < originalBlockTexts.length)
          ? originalBlockTexts[bIdx]
          : linesInBlock.map((l) => l.text).join('\n');

      filteredBlocks.add(
        OcrBlockData(
          text: originalText,
          boundingBox: originalBounds,
          lines: linesInBlock,
        ),
      );
    }

    final documentData = OcrDocumentData(
      blocks: filteredBlocks,
      rawText: filterResult.acceptedLines.map((l) => l.text).join('\n'),
    );

    // 3. Rapikan hasil teks menggunakan TextFormatter murni di isolate
    final FormattedTextResult formattedResult =
        await TextFormatter.formatWithCompute(documentData);

    final String finalText = formattedResult.fullText.isNotEmpty
        ? formattedResult.fullText
        : (filterResult.acceptedLines.isNotEmpty
            ? filterResult.acceptedLines.map((l) => l.text).join('\n')
            : recognizedText.text.trim());

    // 4. Siapkan OcrElement hanya untuk baris yang lolos filter
    final List<OcrElement> elements = [];
    int elementIndex = 0;
    for (final line in filterResult.acceptedLines) {
      elements.add(
        OcrElement(
          id: 'elem_${elementIndex++}',
          text: line.text,
          boundingBox: line.boundingBox,
        ),
      );
    }

    return OcrResult(
      fullText: finalText,
      elements: elements,
      imageSize: imageSize,
      documentData: documentData,
      formattedResult: formattedResult,
      rejectedLines: filterResult.rejectedLines,
      fallbackUsed: filterResult.fallbackUsed,
      hasLowQualityWarning: filterResult.hasLowQualityWarning,
    );
  }

  /// Mengekstrak teks lengkap beserta koordinat bounding box setiap elemen dari RAM (Uint8List).
  Future<OcrResult> processImageWithCoordinates(Uint8List bytes) async {
    if (_isDisposed) return OcrResult.empty;

    File? tempFile;
    try {
      final imageSize = await ImageDimensionHelper.getImageSize(bytes);

      final tempDir = Directory.systemTemp;
      final tempPath =
          '${tempDir.path}/ocr_ephemeral_${DateTime.now().microsecondsSinceEpoch}.jpg';
      tempFile = File(tempPath);
      await tempFile.writeAsBytes(bytes, flush: true);

      final inputImage = InputImage.fromFilePath(tempPath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );

      return await _buildOcrResult(
        recognizedText: recognizedText,
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
      final imageSize = await ImageDimensionHelper.getImageSize(bytes);

      final inputImage = InputImage.fromFilePath(filePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );

      return await _buildOcrResult(
        recognizedText: recognizedText,
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
