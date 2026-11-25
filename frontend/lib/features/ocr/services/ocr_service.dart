import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

import 'package:eye_lens/features/ocr/models/ocr_element.dart';
import 'package:eye_lens/features/speech/models/text_formatter_models.dart';
import 'package:eye_lens/core/utils/image_dimension_helper.dart';
import 'package:eye_lens/features/ocr/services/ocr_diagnostic_collector.dart';
import 'package:eye_lens/features/camera/logic/image_blur_detector.dart';
import 'package:eye_lens/features/ocr/correction/ocr_confidence_gate.dart';
import 'package:eye_lens/features/ocr/preprocessing/ocr_preprocessor.dart';
import 'package:eye_lens/features/ocr/reading_order/vertical_text_detector.dart';
import 'package:eye_lens/features/ocr/orientation/image_orientation_analyzer.dart';
import 'package:eye_lens/features/ocr/orientation/orientation_transform.dart';
import 'package:eye_lens/features/ocr/orientation/text_orientation_analyzer.dart';
import 'package:eye_lens/features/speech/logic/text_formatter.dart';

/// Service untuk ekstraksi karakter teks on-device menggunakan Google ML Kit:
/// - Menggunakan model Latin Script berkecepatan tinggi (< 500 ms).
/// - Mendukung ekstraksi teks penuh maupun koordinat bounding box setiap elemen/baris.
/// - Merapikan hasil teks otomatis sesuai paragraf asli dan multi-kolom via TextFormatter.
/// - Menjaga privasi: memproses citra via ephemeral temp file yang langsung
///   dimusnahkan di blok `finally` (0 byte penulisan permanen di gawai).
class OcrService {
  static const Duration _passTimeout = Duration(seconds: 20);
  static const Duration _totalTimeout = Duration(seconds: 60);
  final TextRecognizer _textRecognizer;
  bool _isDisposed = false;

  OcrService({TextRecognitionScript script = TextRecognitionScript.latin})
    : _textRecognizer = TextRecognizer(script: script);

  /// Helper untuk membangun OcrResult lengkap dari RecognizedText dan imageSize.
  /// Semua baris nonkosong diteruskan tanpa filter noise atau karantina.
  @visibleForTesting
  static Future<OcrResult> buildOcrResult({
    required RecognizedText recognizedText,
    required Size imageSize,
  }) async {
    final List<OcrLineData> allLines = [];
    final List<Rect> originalBlockBounds = [];

    for (int bIdx = 0; bIdx < recognizedText.blocks.length; bIdx++) {
      final block = recognizedText.blocks[bIdx];
      originalBlockBounds.add(block.boundingBox);
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
              angle: line.angle,
              blockIndex: bIdx,
              elements: words,
            ),
          );
        }
      }
    }

    // Orientasi diestimasi sekali per baris memakai sudut ML Kit + geometri.
    // Estimasi ini ikut ke resolver urutan baca dan ke diagnostik.
    final orientedLines = [
      for (final line in allLines)
        line.withOrientation(TextOrientationAnalyzer.analyzeLine(line)),
    ];

    // 2. Confidence hanya menandai kualitas; tidak menghapus teks OCR.
    final confidenceGate = OcrConfidenceGate.apply(orientedLines);

    // Karakter dalam satu kolom vertikal menjadi blok tersendiri. Teksnya
    // tidak pernah dirangkai, sehingga formatter dan TTS tetap menerimanya
    // sebagai karakter individual dari atas ke bawah.
    final verticalColumns = VerticalTextDetector.characterColumns(
      confidenceGate.acceptedLines,
    );
    final verticalLines = <OcrLineData>{
      for (final column in verticalColumns) ...column,
    };

    // 2b. Kelompokkan baris horizontal kembali ke blok ML Kit.
    final Map<int, List<OcrLineData>> blockMap = {};
    for (final line in confidenceGate.acceptedLines) {
      if (verticalLines.contains(line)) continue;
      blockMap.putIfAbsent(line.blockIndex, () => []).add(line);
    }

    final List<OcrBlockData> filteredBlocks = [];
    for (final entry in blockMap.entries) {
      final bIdx = entry.key;
      final linesInBlock = entry.value;
      final originalBounds = (bIdx >= 0 && bIdx < originalBlockBounds.length)
          ? originalBlockBounds[bIdx]
          : linesInBlock.first.boundingBox;
      // Rebuild block text from the retained ML Kit lines.
      final originalText = linesInBlock.map((l) => l.text).join('\n');

      filteredBlocks.add(
        OcrBlockData(
          text: originalText,
          boundingBox: originalBounds,
          lines: linesInBlock,
        ),
      );
    }

    for (final column in verticalColumns) {
      final bounds = column
          .map((line) => line.boundingBox)
          .reduce((a, b) => a.expandToInclude(b));
      filteredBlocks.add(
        OcrBlockData(
          text: column.map((line) => line.text).join('\n'),
          boundingBox: bounds,
          lines: column,
        ),
      );
    }

    final documentData = OcrDocumentData(
      blocks: filteredBlocks,
      rawText: confidenceGate.acceptedLines.map((l) => l.text).join('\n'),
      allRawLines: orientedLines,
    );

    // 3. Rapikan hasil teks menggunakan TextFormatter murni di isolate
    final FormattedTextResult formattedResult =
        await TextFormatter.formatWithCompute(documentData);

    final String finalText = formattedResult.fullText.isNotEmpty
        ? formattedResult.fullText
        : documentData.blocks
              .expand((b) => b.lines)
              .map((l) => l.text)
              .join('\n');

    // 4. Pertahankan karakter ML Kit pada setiap elemen.
    final List<OcrElement> elements = [];
    int elementIndex = 0;
    for (final block in documentData.blocks) {
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
      documentData: documentData,
      formattedResult: formattedResult,
      hasLowQualityWarning: confidenceGate.hasWarning,
      rawLinesCount: orientedLines.length,
      rawLines: orientedLines,
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
      final RecognizedText recognizedText = await _textRecognizer
          .processImage(inputImage)
          .timeout(_passTimeout);

      final result = await buildOcrResult(
        recognizedText: recognizedText,
        imageSize: imageSize,
      );

      if (passRecords != null) {
        localStopwatch.stop();
        passRecords.add(
          OcrPassRecord(
            name: passName ?? 'pass',
            durationMs: localStopwatch.elapsedMilliseconds,
            orientation: TextOrientationAnalyzer.analyze(result.rawLines)
                .toJson(),
            rawLines: result.rawLinesCount,
            acceptedLines: result.rawLines.length,
            rejectedLines: 0,
            confidence: ConfidenceStats.fromLines(result.rawLines),
            lineHeights: LineHeightStats.fromLines(result.rawLines),
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
  /// Membaca gambar asli dan mencoba rotasi berdasarkan bukti orientasi saja.
  Future<OcrResult> processImageWithCoordinates(
    Uint8List bytes, {
    Map<String, Object?> captureMetadata = const {},
  }) async {
    try {
      return await _processImageWithCoordinates(
        bytes,
        captureMetadata: captureMetadata,
      ).timeout(_totalTimeout);
    } on TimeoutException {
      return OcrResult.failed(OcrFailureType.timeout);
    }
  }

  Future<OcrResult> _processImageWithCoordinates(
    Uint8List bytes, {
    required Map<String, Object?> captureMetadata,
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
        passName: 'pass1_original',
        passRecords: passRecords,
      );

      final pass1Analysis = TextOrientationAnalyzer.analyze(
        pass1Result.rawLines,
      );
      final verticalCandidate = await compute(
        VerticalTextDetector.hasStrongCandidate,
        pass1Result.rawLines,
      );
      inputMetrics['verticalCandidate'] = verticalCandidate;
      inputMetrics['orientationAnalysis'] = pass1Analysis.toJson();

      final orientationPlan = ImageOrientationAnalyzer.plan(
        pass1Analysis,
        verticalCandidate: verticalCandidate,
      );
      inputMetrics['orientationPlan'] = orientationPlan.toJson();

      if (!orientationPlan.needsRecognition) {
        return _attachDiagnostics(
          diagnostics: diagnostics,
          result: pass1Result,
          imageSize: imageSize,
          passRecords: passRecords,
          totalStopwatch: totalStopwatch,
        );
      }

      OcrResult bestResult = pass1Result;

      // Kandidat rotasi berasal dari bukti orientasi teks, bukan rasio citra.
      // Hasil diterima hanya jika bukti orientasi tegak menguat.
      if (orientationPlan.needsRecognition) {
        for (final degrees in orientationPlan.candidateRotations) {
          if (_isDisposed) break;
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
              passName: 'orientation_$degrees',
              passRecords: passRecords,
              passStopwatch: timer,
              rotationDegrees: degrees,
            );
            final candidateAnalysis = TextOrientationAnalyzer.analyze(
              candidate.rawLines,
            );
            final candidateBetter =
                candidate.fullText.trim().isNotEmpty &&
                candidateAnalysis.uprightShare >
                    pass1Analysis.uprightShare + 0.05 &&
                candidateAnalysis.confidence >= 0.4;
            if (candidateBetter) {
              bestResult = OrientationTransform.mapResultBack(
                candidate,
                imageSize,
                degrees,
              );
              inputMetrics['appliedOrientationRotation'] = degrees;
              break;
            }
          } catch (e) {
            debugPrint(
              '[OcrService] Orientation rotation $degrees failed: ${e.runtimeType}',
            );
          }
        }
      }

      return _attachDiagnostics(
        diagnostics: diagnostics,
        result: bestResult,
        imageSize: imageSize,
        passRecords: passRecords,
        totalStopwatch: totalStopwatch,
      );
    } on TimeoutException catch (e) {
      debugPrint('[OcrService] OCR melewati batas waktu: $e');
      return OcrResult.failed(OcrFailureType.timeout);
    } catch (e) {
      debugPrint('[OcrService] Ekstraksi OCR berkoordinat gagal: $e');
      return OcrResult.failed();
    }
  }

  /// Menyusun laporan diagnostik (K0) untuk satu foto dan melampirkannya
  /// ke [OcrResult] via [OcrResult.diagnosticJson].
  OcrResult _attachDiagnostics({
    required OcrDiagnosticCollector diagnostics,
    required OcrResult result,
    required Size imageSize,
    required List<OcrPassRecord> passRecords,
    required Stopwatch totalStopwatch,
  }) {
    if (!diagnostics.isActive) return result;

    final report = diagnostics.finalize(
      imageSentToMlKit: imageSize,
      passes: passRecords,
      rejectedLines: const [],
      rawText: result.rawLines.map((l) => l.text).join('\n'),
      filteredText: result.documentData?.rawText ?? '',
      formattedText: result.fullText,
      totalDurationMs: totalStopwatch.elapsedMilliseconds,
    );
    if (report == null) return result;
    return result.copyWith(diagnosticJson: report.toJsonString());
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
