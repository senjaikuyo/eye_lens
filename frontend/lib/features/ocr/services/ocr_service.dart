import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

import 'package:eye_lens/features/ocr/models/ocr_element.dart';
import 'package:eye_lens/models/text_formatter_models.dart';
import 'package:eye_lens/core/utils/image_dimension_helper.dart';
import 'package:eye_lens/features/ocr/services/ocr_diagnostic_collector.dart';
import 'package:eye_lens/features/camera/logic/image_blur_detector.dart';
import 'package:eye_lens/features/ocr/correction/ocr_noise_filter.dart';
import 'package:eye_lens/features/ocr/correction/ocr_dictionary.dart';
import 'package:eye_lens/features/ocr/correction/ocr_post_corrector.dart';
import 'package:eye_lens/features/ocr/preprocessing/ocr_preprocessor.dart';
import 'package:eye_lens/features/ocr/reading_order/ocr_orientation_resolver.dart';
import 'package:eye_lens/features/ocr/reading_order/vertical_text_detector.dart';
import 'package:eye_lens/services/text_formatter.dart';

/// Service untuk ekstraksi karakter teks on-device menggunakan Google ML Kit:
/// - Menggunakan model Latin Script berkecepatan tinggi (< 500 ms).
/// - Mendukung ekstraksi teks penuh maupun koordinat bounding box setiap elemen/baris.
/// - Merapikan hasil teks otomatis sesuai paragraf asli dan multi-kolom via TextFormatter.
/// - Menjaga privasi: memproses citra via ephemeral temp file yang langsung
///   dimusnahkan di blok `finally` (0 byte penulisan permanen di gawai).
class OcrService {
  static const int maxAdditionalPasses = 10;
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

    for (int bIdx = 0; bIdx < recognizedText.blocks.length; bIdx++) {
      final block = recognizedText.blocks[bIdx];
      originalBlockBounds.add(
        OcrPreprocessor.remapBoundingBox(
          block.boundingBox,
          cropOffset: cropOffset,
          scale: scale,
        ),
      );
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
              angle: line.angle,
              blockIndex: bIdx,
              elements: words,
            ),
          );
        }
      }
    }

    // 1. Jalankan penyaring noise di background isolate sesuai konfigurasi mode
    final effectiveConfig =
        noiseFilterConfig ??
        const OcrNoiseFilterConfig(enableAutoScreenshotDetection: true);
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
      // Do not let excluded/doubtful text leak via block-level metadata.
      final originalText = linesInBlock.map((l) => l.text).join('\n');

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
    await OcrDictionary.loadFrequencyWords();
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
      doubtfulLines: filterResult.doubtfulLines,
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
    int rotationDegrees = 0,
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
            qualityScore: OcrOrientationResolver.score(result.rawLines),
            rawLines: result.rawLinesCount,
            acceptedLines:
                result.rawLines.length -
                result.rejectedLines.length -
                result.doubtfulLines.length,
            rejectedLines: result.rejectedLines.length,
            confidence: ConfidenceStats.fromLines(result.rawLines),
            lineHeights: LineHeightStats.fromLines(result.rawLines),
            doubtfulLines: result.doubtfulLines.length,
            angles: result.rawLines.map((l) => l.angle).toList(),
            rotationDegrees: rotationDegrees,
            submittedImageSize: await ImageDimensionHelper.getImageSize(
              imageBytes,
            ),
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
    final totalStopwatch = Stopwatch()..start();

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

      final double pass1Score = OcrOrientationResolver.score(
        pass1Result.rawLines,
      );
      final verticalCandidate = await compute(
        VerticalTextDetector.hasStrongCandidate,
        pass1Result.rawLines,
      );
      inputMetrics['verticalCandidate'] = verticalCandidate;

      // Kriteria kualitas cukup tanpa perlu pass kedua:
      // Teks ditemukan, tidak ada peringatan kualitas rendah, dan skor token kuat.
      const double sufficientScoreThreshold =
          OcrOrientationResolver.sufficientScore;
      final landscape = imageSize.width > imageSize.height;
      if (OcrOrientationResolver.sufficient(pass1Result) &&
          !verticalCandidate &&
          !OcrOrientationResolver.angleSuggestsUpsideDown(pass1Result) &&
          !landscape &&
          scanMode != OcrScanMode.smallText) {
        return _attachDiagnostics(
          diagnostics: diagnostics,
          result: pass1Result,
          imageSize: imageSize,
          passRecords: passRecords,
          bytes: bytes,
          totalStopwatch: totalStopwatch,
        );
      }

      OcrResult bestResult = pass1Result;
      double bestScore = pass1Score;
      var additionalPasses = 0;

      // K5: bounded, sequential retries, always from the same original photo.
      // Missing angle never blocks recovery; 0 degrees is a valid angle.
      if (!OcrOrientationResolver.sufficient(pass1Result) ||
          OcrOrientationResolver.angleSuggestsUpsideDown(pass1Result) ||
          verticalCandidate ||
          landscape) {
        // K6 evidence permits 90/270 even in portrait. Share the K5 retry
        // budget: never repeat angles or exceed three additional attempts.
        final retries = OcrOrientationResolver.recoveryAngles(
          imageSize,
          resultSufficient: OcrOrientationResolver.sufficient(pass1Result),
          verticalCandidate: verticalCandidate,
        );
        var verticalResolved = !verticalCandidate;
        for (final degrees in retries) {
          if (_isDisposed || additionalPasses >= maxAdditionalPasses) break;
          additionalPasses++;
          final timer = Stopwatch()..start();
          try {
            final rotated = await OcrPreprocessor.rotate(bytes, degrees);
            final rotatedSize = degrees == 180
                ? imageSize
                : Size(imageSize.height, imageSize.width);
            final candidate = await _recognizeSinglePass(
              imageBytes: rotated,
              imageSize: rotatedSize,
              tempDir: tempDir,
              scanMode: scanMode,
              noiseFilterConfig: noiseFilterConfig,
              passName: verticalCandidate && degrees != 180
                  ? 'vertical_rotation_$degrees'
                  : 'rotation_$degrees',
              passRecords: passRecords,
              passStopwatch: timer,
              rotationDegrees: degrees,
            );
            final score = OcrOrientationResolver.score(candidate.rawLines);
            if ((score > bestScore ||
                    (score == bestScore &&
                        OcrOrientationResolver.angleSuggestsUpsideDown(
                          bestResult,
                        ) &&
                        !OcrOrientationResolver.angleSuggestsUpsideDown(
                          candidate,
                        ))) &&
                (!candidate.allLinesFilteredOut ||
                    bestResult.allLinesFilteredOut)) {
              bestResult = OcrOrientationResolver.mapResult(
                candidate,
                imageSize,
                degrees,
              );
              bestScore = score;
              verticalResolved = !await compute(
                VerticalTextDetector.hasStrongCandidate,
                candidate.rawLines,
              );
            }
            if (verticalResolved &&
                OcrOrientationResolver.sufficient(bestResult) &&
                (!landscape || degrees == retries.last)) {
              break;
            }
          } catch (e) {
            debugPrint(
              '[OcrService] Rotation $degrees failed: ${e.runtimeType}',
            );
          }
        }
        if (verticalResolved && OcrOrientationResolver.sufficient(bestResult)) {
          return _attachDiagnostics(
            diagnostics: diagnostics,
            result: bestResult,
            imageSize: imageSize,
            passRecords: passRecords,
            bytes: bytes,
            totalStopwatch: totalStopwatch,
          );
        }
      }

      // K0 A/B controls only image preprocessing; orientation recovery remains
      // enabled because it preserves original-image OCR ordering semantics.
      if (!enableMultiPass ||
          (kDebugMode && !DebugOcrConfig.enableLegacyPreprocessing)) {
        return _attachDiagnostics(
          diagnostics: diagnostics,
          result: bestResult,
          imageSize: imageSize,
          passRecords: passRecords,
          bytes: bytes,
          totalStopwatch: totalStopwatch,
        );
      }

      final tileResults = <OcrResult>[];
      try {
        if ((bestScore < sufficientScoreThreshold ||
                bestResult.rawLines.isEmpty) &&
            additionalPasses < maxAdditionalPasses) {
          additionalPasses++;
          final contrastBytes = await OcrPreprocessor.enhanceContrast(
            bytes,
            contrast: 1.6,
          );
          final contrastResult = await _recognizeSinglePass(
            imageBytes: contrastBytes,
            imageSize: imageSize,
            tempDir: tempDir,
            noiseFilterConfig: noiseFilterConfig,
            passName: 'fallback_contrast',
            passRecords: passRecords,
          );
          final contrastScore = OcrOrientationResolver.score(
            contrastResult.rawLines,
          );
          if (contrastScore > bestScore) {
            bestResult = contrastResult;
            bestScore = contrastScore;
          }
        }

        if ((bestScore < sufficientScoreThreshold ||
                bestResult.rawLines.isEmpty) &&
            additionalPasses < maxAdditionalPasses) {
          additionalPasses++;
          final otsuBytes = await OcrPreprocessor.binarizeOtsu(bytes);
          final otsuResult = await _recognizeSinglePass(
            imageBytes: otsuBytes,
            imageSize: imageSize,
            tempDir: tempDir,
            noiseFilterConfig: noiseFilterConfig,
            passName: 'fallback_otsu',
            passRecords: passRecords,
          );
          final otsuScore = OcrOrientationResolver.score(otsuResult.rawLines);
          if (otsuScore > bestScore) {
            bestResult = otsuResult;
            bestScore = otsuScore;
          }
        }

        if ((bestScore < sufficientScoreThreshold ||
                bestResult.rawLines.isEmpty) &&
            additionalPasses < maxAdditionalPasses) {
          if (bestResult.rawLines.isNotEmpty) {
            final roi = OcrPreprocessor.computeTextRoi(
              bestResult.rawLines,
              imageSize: imageSize,
            );
            if (roi != null &&
                roi.width * roi.height <
                    imageSize.width * imageSize.height * .65) {
              additionalPasses++;
              const scale = 1.5;
              final crop = await OcrPreprocessor.cropAndScaleRoi(
                bytes,
                cropRect: roi,
                scale: scale,
              );
              final enhancedCrop = await OcrPreprocessor.enhanceContrast(
                crop,
                contrast: 1.4,
              );
              final roiResult = await _recognizeSinglePass(
                imageBytes: enhancedCrop,
                imageSize: imageSize,
                tempDir: tempDir,
                noiseFilterConfig: noiseFilterConfig,
                cropOffset: roi.topLeft,
                scale: scale,
                passName: 'fallback_smart_crop',
                passRecords: passRecords,
              );
              final roiScore = OcrOrientationResolver.score(roiResult.rawLines);
              if (roiScore > bestScore) {
                bestResult = roiResult;
                bestScore = roiScore;
              }
            }
          }
        }

        if ((bestScore < sufficientScoreThreshold ||
                bestResult.rawLines.isEmpty) &&
            additionalPasses < maxAdditionalPasses) {
          final tiles = OcrPreprocessor.computeTileRois(imageSize);
          for (
            var i = 0;
            i < tiles.length && additionalPasses < maxAdditionalPasses;
            i++
          ) {
            if (_isDisposed) break;
            additionalPasses++;
            final tile = tiles[i];
            const scale = 1.5;
            final tileBytes = await OcrPreprocessor.cropAndScaleRoi(
              bytes,
              cropRect: tile,
              scale: scale,
            );
            final tileResult = await _recognizeSinglePass(
              imageBytes: tileBytes,
              imageSize: imageSize,
              tempDir: tempDir,
              noiseFilterConfig: noiseFilterConfig,
              cropOffset: tile.topLeft,
              scale: scale,
              passName: 'fallback_tile_${i + 1}',
              passRecords: passRecords,
            );
            tileResults.add(tileResult);
          }
          if (tileResults.isNotEmpty) {
            final combined = await _mergeTileResults(tileResults, imageSize);
            final tileScore = OcrOrientationResolver.score(combined.rawLines);
            if (tileScore > bestScore || bestResult.rawLines.isEmpty) {
              bestResult = combined;
              bestScore = tileScore;
            }
          }
        }
      } catch (e) {
        debugPrint(
          '[OcrService] Unified OCR fallback failed: ${e.runtimeType}',
        );
      }

      return _attachDiagnostics(
        diagnostics: diagnostics,
        result: bestResult,
        imageSize: imageSize,
        passRecords: passRecords,
        bytes: bytes,
        totalStopwatch: totalStopwatch,
      );
    } catch (e) {
      debugPrint('[OcrService] Ekstraksi OCR berkoordinat gagal: $e');
      return OcrResult.empty;
    }
  }

  Future<OcrResult> _mergeTileResults(
    List<OcrResult> results,
    Size imageSize,
  ) async {
    final blocks = <OcrBlockData>[];
    for (final result in results) {
      for (final block
          in result.documentData?.blocks ?? const <OcrBlockData>[]) {
        final unique = <OcrLineData>[];
        for (final line in block.lines) {
          final repeated = blocks.expand((previous) => previous.lines).any((
            previous,
          ) {
            if (previous.text.trim().toLowerCase() !=
                line.text.trim().toLowerCase()) {
              return false;
            }
            final intersection = previous.boundingBox.intersect(
              line.boundingBox,
            );
            final smallerArea = math.min(
              previous.boundingBox.width * previous.boundingBox.height,
              line.boundingBox.width * line.boundingBox.height,
            );
            return !intersection.isEmpty &&
                smallerArea > 0 &&
                intersection.width * intersection.height / smallerArea >= .6;
          });
          if (!repeated) unique.add(line);
        }
        if (unique.isEmpty) continue;
        final blockBounds = unique
            .map((line) => line.boundingBox)
            .reduce((a, b) => a.expandToInclude(b));
        final blockIndex = blocks.length;
        final indexed = unique
            .map(
              (line) => OcrLineData(
                text: line.text,
                boundingBox: line.boundingBox,
                confidence: line.confidence,
                angle: line.angle,
                blockIndex: blockIndex,
                elements: line.elements,
              ),
            )
            .toList();
        blocks.add(
          OcrBlockData(
            text: indexed.map((line) => line.text).join('\n'),
            boundingBox: blockBounds,
            lines: indexed,
          ),
        );
      }
    }
    final lines = blocks.expand((block) => block.lines).toList();
    final document = OcrDocumentData(
      blocks: blocks,
      rawText: lines.map((line) => line.text).join('\n'),
      allRawLines: lines,
    );
    final formatted = await TextFormatter.formatWithCompute(document);
    final elements = <OcrElement>[
      for (var index = 0; index < lines.length; index++)
        OcrElement(
          id: 'tile_elem_$index',
          text: lines[index].text,
          boundingBox: lines[index].boundingBox,
        ),
    ];
    return OcrResult(
      fullText: formatted.fullText,
      elements: elements,
      imageSize: imageSize,
      documentData: document,
      formattedResult: formatted,
      rawLines: lines,
      rawLinesCount: lines.length,
      rejectedLines: results.expand((result) => result.rejectedLines).toList(),
      doubtfulLines: results.expand((result) => result.doubtfulLines).toList(),
      hasLowQualityWarning: results.any(
        (result) => result.hasLowQualityWarning,
      ),
      allLinesFilteredOut: lines.isEmpty,
    );
  }

  /// Menyusun laporan diagnostik (K0) untuk satu foto dan melampirkannya
  /// ke [OcrResult] via [OcrResult.diagnosticJson].
  OcrResult _attachDiagnostics({
    required OcrDiagnosticCollector diagnostics,
    required OcrResult result,
    required Size imageSize,
    required List<OcrPassRecord> passRecords,
    required Uint8List bytes,
    required Stopwatch totalStopwatch,
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
      doubtfulLines: result.doubtfulLines
          .map(
            (r) => {
              ...rejectedLineToJson(
                line: r.line,
                reason: r.reason.name,
                explanation: r.explanation,
              ),
              'suspicionScore': r.suspicionScore,
              'signals': r.signals.map((s) => s.name).toList(),
            },
          )
          .toList(),
      rawText: result.rawLines.map((l) => l.text).join('\n'),
      filteredText: result.documentData?.rawText ?? '',
      formattedText: result.fullText,
      totalDurationMs: totalStopwatch.elapsedMilliseconds,
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
