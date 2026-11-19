import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

import '../models/ocr_element.dart';
import '../models/text_formatter_models.dart';
import '../utils/image_dimension_helper.dart';
import 'ocr_diagnostic_collector.dart';
import 'image_blur_detector.dart';
import 'ocr_noise_filter.dart';
import 'ocr_post_corrector.dart';
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
    Offset cropOffset = Offset.zero,
    double scale = 1.0,
  }) async {
    final List<OcrLineData> allLines = [];
    final List<Rect> originalBlockBounds = [];
    final List<String> originalBlockTexts = [];

    for (int bIdx = 0; bIdx < recognizedText.blocks.length; bIdx++) {
      final block = recognizedText.blocks[bIdx];
      originalBlockBounds.add(
        OcrPreprocessor.remapBoundingBox(
          block.boundingBox,
          cropOffset: cropOffset,
          scale: scale,
        ),
      );
      originalBlockTexts.add(block.text);
      for (final line in block.lines) {
        if (line.text.trim().isNotEmpty) {
          final List<OcrWordData> words = [];
          for (final elem in line.elements) {
            if (elem.text.trim().isNotEmpty) {
              words.add(
                OcrWordData(
                  text: elem.text,
                  boundingBox: OcrPreprocessor.remapBoundingBox(
                    elem.boundingBox,
                    cropOffset: cropOffset,
                    scale: scale,
                  ),
                  confidence: elem.confidence,
                ),
              );
            }
          }

          allLines.add(
            OcrLineData(
              text: line.text,
              boundingBox: OcrPreprocessor.remapBoundingBox(
                line.boundingBox,
                cropOffset: cropOffset,
                scale: scale,
              ),
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

    // 2b. Koreksi karakter ambigu OCR via kamus leksikal on-device (Issue h)
    final correctedDocumentData = OcrPostCorrector.correctDocument(
      documentData,
      scanMode: scanMode,
    );

    // 3. Rapikan hasil teks menggunakan TextFormatter murni di isolate
    final FormattedTextResult formattedResult =
        await TextFormatter.formatWithCompute(correctedDocumentData);

    final String finalText = formattedResult.fullText.isNotEmpty
        ? formattedResult.fullText
        : correctedDocumentData.blocks
              .expand((b) => b.lines)
              .map((l) => l.text)
              .join('\n');

    // 4. Siapkan OcrElement hanya untuk baris yang lolos filter dan telah dikoreksi
    final List<OcrElement> elements = [];
    int elementIndex = 0;
    for (final block in correctedDocumentData.blocks) {
      for (final line in block.lines) {
        elements.add(
          OcrElement(
            id: 'elem_${elementIndex++}',
            text: line.text,
            boundingBox: line.boundingBox,
          ),
        );
      }
    }

    return OcrResult(
      fullText: finalText,
      elements: elements,
      imageSize: imageSize,
      documentData: correctedDocumentData,
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
    Offset cropOffset = Offset.zero,
    double scale = 1.0,
    String? passName,
    List<OcrPassRecord>? passRecords,
    Stopwatch? passStopwatch,
  }) async {
    File? tempFile;
    final localStopwatch = passStopwatch ?? Stopwatch();
    if (!localStopwatch.isRunning) localStopwatch.start();
    try {
      final tempPath =
          '${tempDir.path}/ocr_ephemeral_${DateTime.now().microsecondsSinceEpoch}.jpg';
      tempFile = File(tempPath);
      await tempFile.writeAsBytes(imageBytes, flush: true);

      final inputImage = InputImage.fromFilePath(tempPath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );

      final result = await _buildOcrResult(
        recognizedText: recognizedText,
        imageSize: imageSize,
        scanMode: scanMode,
        noiseFilterConfig: noiseFilterConfig,
        cropOffset: cropOffset,
        scale: scale,
      );

      if (passRecords != null) {
        localStopwatch.stop();
        passRecords.add(
          OcrPassRecord(
            name: passName ?? 'pass',
            durationMs: localStopwatch.elapsedMilliseconds,
            qualityScore: OcrQualityScorer.scoreLines(result.rawLines),
            rawLines: result.rawLinesCount,
            acceptedLines: result.rawLines.length - result.rejectedLines.length,
            rejectedLines: result.rejectedLines.length,
            confidence: ConfidenceStats.fromLines(result.rawLines),
            lineHeights: LineHeightStats.fromLines(result.rawLines),
          ),
        );
      }

      return result;
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
  /// Mendukung multi-pass preprocessing adaptif (Pass 1: Asli, Pass 2: Enhanced Contrast / Smart Crop,
  /// Pass 3: Otsu Binarization) dipadu OcrQualityScorer untuk memilih hasil terbaik.
  Future<OcrResult> processImageWithCoordinates(
    Uint8List bytes, {
    bool enableMultiPass = true,
    OcrScanMode scanMode = OcrScanMode.document,
    OcrNoiseFilterConfig? noiseFilterConfig,
    Map<String, Object?> captureMetadata = const {},
  }) async {
    if (_isDisposed) return OcrResult.empty;

    try {
      final imageSize = await ImageDimensionHelper.getImageSize(bytes);
      final inputMetrics = <String, Object?>{...captureMetadata};
      if (kDebugMode && DebugOcrConfig.enableDiagnostics) {
        final timer = Stopwatch()..start();
        try {
          inputMetrics['imageAnalysis'] = await ImageBlurDetector.measure(
            bytes,
          );
        } catch (e) {
          inputMetrics['imageAnalysisError'] = e.runtimeType.toString();
        }
        inputMetrics['analysisDurationMs'] = timer.elapsedMilliseconds;
      }

      Directory tempDir;
      try {
        tempDir = await getTemporaryDirectory();
      } catch (_) {
        tempDir = Directory.systemTemp;
      }

      // K0: Siapkan pengumpul diagnostik. Nonaktif di release.
      final diagnostics = OcrDiagnosticCollector.create(
        photoBytes: bytes,
        photoPixelSize: imageSize,
        cameraPreset: captureMetadata['cameraPreset'] as String? ?? 'unknown',
        exifOrientation: ImageDimensionHelper.getExifOrientation(bytes),
        deviceOrientation: captureMetadata['deviceOrientation'] as String?,
        inputMetrics: inputMetrics,
      );
      final List<OcrPassRecord> passRecords = [];

      // Pass 1: Citra asli (tanpa preprocessing apa pun)
      final pass1Result = await _recognizeSinglePass(
        imageBytes: bytes,
        imageSize: imageSize,
        tempDir: tempDir,
        scanMode: scanMode,
        noiseFilterConfig: noiseFilterConfig,
        passName: 'pass1_original',
        passRecords: passRecords,
      );

      // K0 A/B flag: lewati seluruh pass tambahan lama bila dimatikan.
      if (!enableMultiPass || !DebugOcrConfig.enableLegacyPreprocessing) {
        return _attachDiagnostics(
          diagnostics: diagnostics,
          result: pass1Result,
          imageSize: imageSize,
          passRecords: passRecords,
          bytes: bytes,
        );
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
          pass1Result.fullText.trim().isNotEmpty &&
          scanMode != OcrScanMode.smallText) {
        return _attachDiagnostics(
          diagnostics: diagnostics,
          result: pass1Result,
          imageSize: imageSize,
          passRecords: passRecords,
          bytes: bytes,
        );
      }

      OcrResult bestResult = pass1Result;
      double bestScore = pass1Score;

      try {
        if (scanMode == OcrScanMode.smallText) {
          // --- Alur Khusus Mode Teks Kecil / Teliti (Issue c) ---
          // 1. Coba smart crop ROI dari baris teks yang sudah terdeteksi di Pass 1
          final textRoi = OcrPreprocessor.computeTextRoi(
            bestResult.rawLines,
            imageSize: imageSize,
          );

          final Rect targetRoi =
              textRoi ??
              OcrPreprocessor.computeCenterRoi(imageSize, ratio: 0.70);

          try {
            const double roiScale = 2.0;
            final roiBytes = await OcrPreprocessor.cropAndScaleRoi(
              bytes,
              cropRect: targetRoi,
              scale: roiScale,
            );
            final enhancedRoiBytes = await OcrPreprocessor.enhanceContrast(
              roiBytes,
              contrast: 1.5,
            );
            final roiResult = await _recognizeSinglePass(
              imageBytes: enhancedRoiBytes,
              imageSize: imageSize,
              tempDir: tempDir,
              scanMode: scanMode,
              noiseFilterConfig: noiseFilterConfig,
              cropOffset: targetRoi.topLeft,
              scale: roiScale,
            );
            final double roiScore = OcrQualityScorer.scoreLines(
              roiResult.rawLines,
            );

            if (roiScore > bestScore ||
                (bestResult.rawLines.isEmpty &&
                    roiResult.rawLines.isNotEmpty)) {
              bestResult = roiResult;
              bestScore = roiScore;
            }
          } catch (e) {
            debugPrint('[OcrService] SmallText ROI pass gagal: $e');
          }

          // Jika skor masih rendah atau belum ada teks, coba Otsu binarization
          if (bestScore < sufficientScoreThreshold ||
              bestResult.rawLines.isEmpty) {
            try {
              final otsuBytes = await OcrPreprocessor.binarizeOtsu(bytes);
              final otsuResult = await _recognizeSinglePass(
                imageBytes: otsuBytes,
                imageSize: imageSize,
                tempDir: tempDir,
                scanMode: scanMode,
                noiseFilterConfig: noiseFilterConfig,
              );
              final double otsuScore = OcrQualityScorer.scoreLines(
                otsuResult.rawLines,
              );

              if (otsuScore > bestScore) {
                bestResult = otsuResult;
                bestScore = otsuScore;
              }
            } catch (e) {
              debugPrint('[OcrService] SmallText Otsu fallback gagal: $e');
            }
          }
        } else {
          // --- Alur Mode Dokumen, Layar, & Tulis Tangan ---
          // Pass 2: Khusus mode Layar -> Moiré suppression + Contrast,
          //         Mode Tulis Tangan -> Stroke thickening + Contrast,
          //         Mode Dokumen -> Grayscale + Contrast
          final Uint8List pass2Bytes;
          if (scanMode == OcrScanMode.screenText) {
            pass2Bytes = await OcrPreprocessor.preprocessScreenText(
              bytes,
              blurSigma: 0.8,
              contrast: 1.5,
            );
          } else if (scanMode == OcrScanMode.handwriting) {
            pass2Bytes = await OcrPreprocessor.preprocessHandwriting(
              bytes,
              contrast: 1.6,
              strokeThickening: true,
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

          // Smart crop ROI fallback jika teks terkonsentrasi di area kecil dan skor belum memadai
          if (bestScore < sufficientScoreThreshold &&
              bestResult.rawLines.isNotEmpty) {
            try {
              final textRoi = OcrPreprocessor.computeTextRoi(
                bestResult.rawLines,
                imageSize: imageSize,
              );
              if (textRoi != null) {
                final double roiArea = textRoi.width * textRoi.height;
                final double totalArea = imageSize.width * imageSize.height;
                if (roiArea < totalArea * 0.65) {
                  const double roiScale = 1.5;
                  final croppedBytes = await OcrPreprocessor.cropAndScaleRoi(
                    bytes,
                    cropRect: textRoi,
                    scale: roiScale,
                  );
                  final enhancedRoi = await OcrPreprocessor.enhanceContrast(
                    croppedBytes,
                    contrast: 1.4,
                  );
                  final smartCropResult = await _recognizeSinglePass(
                    imageBytes: enhancedRoi,
                    imageSize: imageSize,
                    tempDir: tempDir,
                    scanMode: scanMode,
                    noiseFilterConfig: noiseFilterConfig,
                    cropOffset: textRoi.topLeft,
                    scale: roiScale,
                  );
                  final double smartScore = OcrQualityScorer.scoreLines(
                    smartCropResult.rawLines,
                  );
                  if (smartScore > bestScore) {
                    bestResult = smartCropResult;
                    bestScore = smartScore;
                  }
                }
              }
            } catch (e) {
              debugPrint('[OcrService] Smart crop fallback gagal: $e');
            }
          }
        }
      } catch (e) {
        debugPrint('[OcrService] Multi-pass preprocessing gagal: $e');
      }

      return _attachDiagnostics(
        diagnostics: diagnostics,
        result: bestResult,
        imageSize: imageSize,
        passRecords: passRecords,
        bytes: bytes,
      );
    } catch (e) {
      debugPrint('[OcrService] Ekstraksi OCR berkoordinat gagal: $e');
      return OcrResult.empty;
    }
  }

  /// Menyusun laporan diagnostik (K0) untuk satu foto dan melampirkannya
  /// ke [OcrResult] via [OcrResult.diagnosticJson].
  OcrResult _attachDiagnostics({
    required OcrDiagnosticCollector diagnostics,
    required OcrResult result,
    required Size imageSize,
    required List<OcrPassRecord> passRecords,
    required Uint8List bytes,
  }) {
    if (!diagnostics.isActive) return result;

    final report = diagnostics.finalize(
      imageSentToMlKit: imageSize,
      passes: passRecords,
      rejectedLines: result.rejectedLines
          .map(
            (r) => rejectedLineToJson(
              line: r.line,
              reason: r.reason.name,
              explanation: r.explanation,
            ),
          )
          .toList(),
      rawText: result.rawLines.map((l) => l.text).join('\n'),
      filteredText: result.documentData?.rawText ?? '',
      formattedText: result.fullText,
      totalDurationMs: passRecords.fold<int>(0, (sum, p) => sum + p.durationMs),
    );
    if (report == null) return result;
    return result.copyWith(diagnosticJson: report.toJsonString());
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
