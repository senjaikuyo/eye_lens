import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

import '../models/ocr_element.dart';
import '../models/text_formatter_models.dart';
import '../utils/image_dimension_helper.dart';
import 'ocr_noise_filter.dart';
import 'ocr_preprocessor.dart';
import 'ocr_quality_scorer.dart';
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
    OcrNoiseFilterConfig? noiseFilterConfig,
    OcrScanMode scanMode = OcrScanMode.document,
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
          final List<OcrWordData> words = [];
          for (final elem in line.elements) {
            if (elem.text.trim().isNotEmpty) {
              words.add(
                OcrWordData(
                  text: elem.text,
                  boundingBox: elem.boundingBox,
                  confidence: elem.confidence,
                ),
              );
            }
          }

          allLines.add(
            OcrLineData(
              text: line.text,
              boundingBox: line.boundingBox,
              confidence: line.confidence,
              blockIndex: bIdx,
              elements: words,
            ),
          );
        }
      }
    }

    // 1. Jalankan penyaring noise di background isolate sesuai konfigurasi mode
    final effectiveConfig =
        noiseFilterConfig ?? OcrNoiseFilterConfig.fromMode(scanMode);
    final filterResult = await OcrNoiseFilter.filterWithCompute(
      OcrNoiseFilterInput(
        lines: allLines,
        imageSize: imageSize,
        config: effectiveConfig,
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
      allRawLines: allLines,
    );

    // 3. Rapikan hasil teks menggunakan TextFormatter murni di isolate
    final FormattedTextResult formattedResult =
        await TextFormatter.formatWithCompute(documentData);

    final String finalText = formattedResult.fullText.isNotEmpty
        ? formattedResult.fullText
        : filterResult.acceptedLines.map((l) => l.text).join('\n');

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
      allLinesFilteredOut: filterResult.allLinesFilteredOut,
      rawLinesCount: allLines.length,
      rawLines: allLines,
    );
  }

  /// Membersihkan sisa file cache sementara ocr_ephemeral_* saat aplikasi baru dimulai.
  static Future<void> purgeOrphanedCache() async {
    try {
      Directory tempDir;
      try {
        tempDir = await getTemporaryDirectory();
      } catch (_) {
        tempDir = Directory.systemTemp;
      }
      if (!await tempDir.exists()) return;
      final entities = tempDir.listSync();
      for (final entity in entities) {
        if (entity is File && entity.path.contains('ocr_ephemeral_')) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[OcrService] Gagal membersihkan cache yatim: $e');
    }
  }

  /// Menjalankan satu putaran (pass) pengenalan teks ML Kit pada file sementara di disk.
  Future<OcrResult> _recognizeSinglePass({
    required Uint8List imageBytes,
    required Size imageSize,
    required Directory tempDir,
    OcrScanMode scanMode = OcrScanMode.document,
    OcrNoiseFilterConfig? noiseFilterConfig,
  }) async {
    File? tempFile;
    try {
      final tempPath =
          '${tempDir.path}/ocr_ephemeral_${DateTime.now().microsecondsSinceEpoch}.jpg';
      tempFile = File(tempPath);
      await tempFile.writeAsBytes(imageBytes, flush: true);

      final inputImage = InputImage.fromFilePath(tempPath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );

      return await _buildOcrResult(
        recognizedText: recognizedText,
        imageSize: imageSize,
        scanMode: scanMode,
        noiseFilterConfig: noiseFilterConfig,
      );
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

  /// Mengekstrak teks lengkap beserta koordinat bounding box setiap elemen dari RAM (Uint8List).
  /// Mendukung multi-pass preprocessing adaptif (Pass 1: Asli, Pass 2: Enhanced Contrast,
  /// Pass 3: Otsu Binarization) dipadu OcrQualityScorer untuk memilih hasil terbaik.
  Future<OcrResult> processImageWithCoordinates(
    Uint8List bytes, {
    bool enableMultiPass = true,
    OcrScanMode scanMode = OcrScanMode.document,
    OcrNoiseFilterConfig? noiseFilterConfig,
  }) async {
    if (_isDisposed) return OcrResult.empty;

    try {
      final imageSize = await ImageDimensionHelper.getImageSize(bytes);

      Directory tempDir;
      try {
        tempDir = await getTemporaryDirectory();
      } catch (_) {
        tempDir = Directory.systemTemp;
      }

      // Pass 1: Citra asli
      final pass1Result = await _recognizeSinglePass(
        imageBytes: bytes,
        imageSize: imageSize,
        tempDir: tempDir,
        scanMode: scanMode,
        noiseFilterConfig: noiseFilterConfig,
      );

      if (!enableMultiPass) {
        return pass1Result;
      }

      final double pass1Score = OcrQualityScorer.scoreLines(
        pass1Result.rawLines,
      );

      // Kriteria kualitas cukup tanpa perlu pass kedua:
      // Teks ditemukan, tidak ada peringatan kualitas rendah, dan skor token kuat.
      const double sufficientScoreThreshold = 35.0;
      if (pass1Score >= sufficientScoreThreshold &&
          !pass1Result.hasLowQualityWarning &&
          !pass1Result.allLinesFilteredOut &&
          pass1Result.fullText.trim().isNotEmpty) {
        return pass1Result;
      }

      // Pass 2: Khusus mode Layar -> Moiré suppression + Contrast, Mode lainnya -> Grayscale + Contrast
      OcrResult bestResult = pass1Result;
      double bestScore = pass1Score;

      try {
        final Uint8List pass2Bytes;
        if (scanMode == OcrScanMode.screenText) {
          pass2Bytes = await OcrPreprocessor.preprocessScreenText(
            bytes,
            blurSigma: 0.8,
            contrast: 1.5,
          );
        } else {
          pass2Bytes = await OcrPreprocessor.enhanceContrast(
            bytes,
            contrast: 1.6,
          );
        }
        final pass2Result = await _recognizeSinglePass(
          imageBytes: pass2Bytes,
          imageSize: imageSize,
          tempDir: tempDir,
          scanMode: scanMode,
          noiseFilterConfig: noiseFilterConfig,
        );
        final double pass2Score = OcrQualityScorer.scoreLines(
          pass2Result.rawLines,
        );

        if (pass2Score > bestScore) {
          bestResult = pass2Result;
          bestScore = pass2Score;
        }

        // Pass 3: Otsu Adaptive Binarization jika skor masih rendah atau belum ada teks
        if (bestScore < sufficientScoreThreshold ||
            bestResult.rawLines.isEmpty) {
          try {
            final pass3Bytes = await OcrPreprocessor.binarizeOtsu(bytes);
            final pass3Result = await _recognizeSinglePass(
              imageBytes: pass3Bytes,
              imageSize: imageSize,
              tempDir: tempDir,
              scanMode: scanMode,
              noiseFilterConfig: noiseFilterConfig,
            );
            final double pass3Score = OcrQualityScorer.scoreLines(
              pass3Result.rawLines,
            );

            if (pass3Score > bestScore) {
              bestResult = pass3Result;
              bestScore = pass3Score;
            }
          } catch (e) {
            debugPrint('[OcrService] Pass 3 Otsu gagal: $e');
          }
        }
      } catch (e) {
        debugPrint('[OcrService] Multi-pass preprocessing gagal: $e');
      }

      return bestResult;
    } catch (e) {
      debugPrint('[OcrService] Ekstraksi OCR berkoordinat gagal: $e');
      return OcrResult.empty;
    }
  }

  /// Mengekstrak teks lengkap beserta koordinat bounding box dari file.
  Future<OcrResult> processFileWithCoordinates(
    String filePath, {
    bool enableMultiPass = true,
    OcrScanMode scanMode = OcrScanMode.document,
    OcrNoiseFilterConfig? noiseFilterConfig,
  }) async {
    if (_isDisposed) return OcrResult.empty;

    try {
      final bytes = await File(filePath).readAsBytes();
      return await processImageWithCoordinates(
        bytes,
        enableMultiPass: enableMultiPass,
        scanMode: scanMode,
        noiseFilterConfig: noiseFilterConfig,
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
