import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:eye_lens/models/text_formatter_models.dart';
import 'package:eye_lens/services/ocr_diagnostic_collector.dart';

void main() {
  group('ConfidenceStats', () {
    test('memisahkan null, 0.0, dan nilai normal', () {
      final stats = ConfidenceStats.fromLines([
        const OcrLineData(
          text: 'a',
          boundingBox: Rect.fromLTWH(0, 0, 10, 10),
          confidence: null,
        ),
        const OcrLineData(
          text: 'b',
          boundingBox: Rect.fromLTWH(0, 10, 10, 10),
          confidence: 0.0,
        ),
        const OcrLineData(
          text: 'c',
          boundingBox: Rect.fromLTWH(0, 20, 10, 10),
          confidence: 0.8,
        ),
        const OcrLineData(
          text: 'd',
          boundingBox: Rect.fromLTWH(0, 30, 10, 10),
          confidence: 0.6,
        ),
      ]);

      expect(stats.total, 4);
      expect(stats.nullCount, 1);
      expect(stats.zeroCount, 1);
      expect(stats.normalCount, 2);
      expect(stats.min, 0.0);
      expect(stats.max, 0.8);
    });

    test('tanpa baris mengembalikan statistik kosong', () {
      final stats = ConfidenceStats.fromLines(const []);
      expect(stats.total, 0);
      expect(stats.min, isNull);
      expect(stats.mean, isNull);
    });
  });

  group('LineHeightStats', () {
    test('menghitung tinggi minimum, rata-rata, dan jumlah di bawah 16px', () {
      final stats = LineHeightStats.fromLines([
        const OcrLineData(
          text: 'a',
          boundingBox: Rect.fromLTWH(0, 0, 10, 10),
        ),
        const OcrLineData(
          text: 'b',
          boundingBox: Rect.fromLTWH(0, 10, 10, 30),
        ),
        const OcrLineData(
          text: 'c',
          boundingBox: Rect.fromLTWH(0, 40, 10, 50),
        ),
      ]);

      expect(stats.min, 10);
      expect(stats.max, 50);
      expect(stats.mean, 30);
      expect(stats.below16px, 1);
      expect(stats.linesTotal, 3);
    });
  });

  group('OcrDiagnosticCollector', () {
    test('nonaktif mengembalikan collector kosong', () {
      final saved = DebugOcrConfig.enableDiagnostics;
      DebugOcrConfig.enableDiagnostics = false;
      addTearDown(() => DebugOcrConfig.enableDiagnostics = saved);

      final collector = OcrDiagnosticCollector.create(
        photoBytes: Uint8List(4),
        photoPixelSize: const Size(100, 100),
        cameraPreset: 'high',
        exifOrientation: null,
        deviceOrientation: null,
      );

      expect(collector.isActive, isFalse);
      expect(
        collector.finalize(
          imageSentToMlKit: const Size(100, 100),
          passes: const [],
          rejectedLines: const [],
          rawText: '',
          filteredText: '',
          formattedText: '',
          totalDurationMs: 0,
        ),
        isNull,
      );
    });

    test('aktif membangun laporan JSON lengkap', () {
      final saved = DebugOcrConfig.enableDiagnostics;
      DebugOcrConfig.enableDiagnostics = true;
      addTearDown(() => DebugOcrConfig.enableDiagnostics = saved);

      final collector = OcrDiagnosticCollector.create(
        photoBytes: Uint8List(16),
        photoPixelSize: const Size(1080, 1920),
        cameraPreset: 'high',
        exifOrientation: 6,
        deviceOrientation: 'portraitUp',
      );

      final report = collector.finalize(
        imageSentToMlKit: const Size(1080, 1920),
        passes: [
          const OcrPassRecord(
            name: 'pass1_original',
            durationMs: 320,
            qualityScore: 42.5,
            rawLines: 10,
            acceptedLines: 9,
            rejectedLines: 1,
            confidence: ConfidenceStats(
              total: 10,
              nullCount: 0,
              zeroCount: 0,
              normalCount: 10,
            ),
            lineHeights: LineHeightStats(mean: 22, min: 14, max: 30),
          ),
        ],
        rejectedLines: const [
          {'rule': 'tooSmall', 'text': 'x', 'explanation': 'demo'},
        ],
        rawText: 'Halo dunia',
        filteredText: 'Halo dunia',
        formattedText: 'Halo dunia',
        totalDurationMs: 320,
      );

      expect(report, isNotNull);
      final json = report!.toJson();
      final photo = json['photo'] as Map<String, Object?>;
      final exif = json['exif'] as Map<String, Object?>;
      final texts = json['texts'] as Map<String, Object?>;
      expect(photo['pixelWidth'], 1080);
      expect(photo['cameraPreset'], 'high');
      expect(exif['present'], isTrue);
      expect(exif['orientation'], 6);
      expect((json['passes'] as List).length, 1);
      expect(texts['raw'], 'Halo dunia');
    });
  });

  group('OcrDiagnosticReport.toJson', () {
    OcrDiagnosticReport buildReport() {
      return OcrDiagnosticReport(
        id: 'ocr_1',
        timestamp: DateTime.utc(2026, 11, 19, 8),
        legacyPreprocessingEnabled: true,
        photoBytes: 1024,
        photoPixelSize: const Size(1080, 1920),
        cameraPreset: 'high',
        exifOrientation: null,
        exifPresent: false,
        deviceOrientation: 'portraitUp',
        imageSentToMlKit: const Size(1080, 1920),
        passes: const [],
        rejectedLines: const [],
        rawText: 'Teks rahasia pengguna',
        filteredText: 'Teks rahasia',
        formattedText: 'Teks rahasia',
        totalDurationMs: 100,
      );
    }

    test('includeText false menyensor isi teks', () {
      final json = buildReport().toJson(includeText: false);
      final texts = json['texts'] as Map<String, Object?>;

      expect(texts.containsKey('raw'), isFalse);
      expect(texts['rawLength'], 'Teks rahasia pengguna'.length);

      final encoded = jsonEncode(json);
      expect(encoded.contains('rahasia'), isFalse);
    });

    test('includeText true menyertakan isi teks', () {
      final json = buildReport().toJson(includeText: true);
      expect((json['texts'] as Map)['raw'], 'Teks rahasia pengguna');
    });
  });

  group('rejectedLineToJson', () {
    test('menyembunyikan teks bila includeText false', () {
      final json = rejectedLineToJson(
        line: const OcrLineData(
          text: 'sampah',
          boundingBox: Rect.fromLTWH(1, 2, 3, 4),
          confidence: 0.4,
        ),
        reason: 'lowConfidence',
        explanation: 'contoh',
        includeText: false,
      );

      expect(json['text'], '<disembunyikan>');
      expect(json['length'], 'sampah'.length);
      expect(json['rule'], 'lowConfidence');
    });
  });

  group('DebugOcrConfig', () {
    test('reset mengembalikan legacy preprocessing ke true', () {
      DebugOcrConfig.enableLegacyPreprocessing = false;
      DebugOcrConfig.reset();
      expect(DebugOcrConfig.enableLegacyPreprocessing, isTrue);
    });
  });
}
