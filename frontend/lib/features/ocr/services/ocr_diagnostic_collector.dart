import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'package:eye_lens/features/speech/models/text_formatter_models.dart';

/// Flag konfigurasi khusus DEBUG untuk mengaktifkan/mematikan fitur pipeline
/// lama saat pengujian A/B di perangkat. Tidak pernah ditampilkan sebagai
/// tombol di UI.
class DebugOcrConfig {
  DebugOcrConfig._();

  /// Jalankan pass tambahan lama (kontras, Otsu, moiré, stroke thickening,
  /// smart crop ROI). Default `true` agar perilaku sama dengan pipeline saat
  /// ini (BASELINE). Set `false` untuk menguji citra mentah murni (Pass 1 saja).
  static bool enableLegacyPreprocessing = true;

  /// Kumpulkan data diagnostik. Hanya relevan pada build debug/profile.
  static bool enableDiagnostics = kDebugMode;

  static void reset() {
    enableLegacyPreprocessing = true;
    enableDiagnostics = kDebugMode;
  }
}

/// Statistik confidence per baris OCR.
@immutable
class ConfidenceStats {
  final int total;
  final int nullCount;
  final int zeroCount;
  final int normalCount;
  final double? min;
  final double? max;
  final double? mean;

  const ConfidenceStats({
    required this.total,
    required this.nullCount,
    required this.zeroCount,
    required this.normalCount,
    this.min,
    this.max,
    this.mean,
  });

  factory ConfidenceStats.fromLines(List<OcrLineData> lines) {
    final values = <double>[];
    int nulls = 0;
    int zeros = 0;
    for (final line in lines) {
      final c = line.confidence;
      if (c == null) {
        nulls++;
      } else if (c == 0.0) {
        zeros++;
        values.add(c);
      } else {
        values.add(c);
      }
    }
    if (values.isEmpty) {
      return ConfidenceStats(
        total: lines.length,
        nullCount: nulls,
        zeroCount: zeros,
        normalCount: 0,
      );
    }
    values.sort();
    final sum = values.fold<double>(0, (a, b) => a + b);
    return ConfidenceStats(
      total: lines.length,
      nullCount: nulls,
      zeroCount: zeros,
      normalCount: values.length - zeros,
      min: values.first,
      max: values.last,
      mean: sum / values.length,
    );
  }

  Map<String, Object?> toJson() => {
    'total': total,
    'null': nullCount,
    'zero': zeroCount,
    'normal': normalCount,
    'min': min,
    'max': max,
    'mean': mean,
  };
}

/// Statistik tinggi huruf (dalam piksel) berdasarkan bounding box baris.
@immutable
class LineHeightStats {
  final double? mean;
  final double? min;
  final double? max;
  final int below16px;
  final int linesTotal;

  const LineHeightStats({
    this.mean,
    this.min,
    this.max,
    this.below16px = 0,
    this.linesTotal = 0,
  });

  factory LineHeightStats.fromLines(List<OcrLineData> lines) {
    final heights =
        lines.map((l) => l.boundingBox.height).where((h) => h > 0).toList()
          ..sort();
    if (heights.isEmpty) return const LineHeightStats();
    final sum = heights.fold<double>(0, (a, b) => a + b);
    return LineHeightStats(
      mean: sum / heights.length,
      min: heights.first,
      max: heights.last,
      below16px: heights.where((h) => h < 16).length,
      linesTotal: heights.length,
    );
  }

  Map<String, Object?> toJson() => {
    'mean': mean,
    'min': min,
    'max': max,
    'below16px': below16px,
    'linesTotal': linesTotal,
  };
}

/// Data satu pass OCR.
@immutable
class OcrPassRecord {
  final String name;
  final int durationMs;
  final double qualityScore;
  final int rawLines;
  final int acceptedLines;
  final int rejectedLines;
  final ConfidenceStats confidence;
  final LineHeightStats lineHeights;
  final String? note;
  final int doubtfulLines;
  final List<double?> angles;
  final int rotationDegrees;
  final Size? submittedImageSize;
  final Map<String, Object?>? orientation;

  const OcrPassRecord({
    required this.name,
    required this.durationMs,
    required this.qualityScore,
    required this.rawLines,
    required this.acceptedLines,
    required this.rejectedLines,
    required this.confidence,
    required this.lineHeights,
    this.note,
    this.doubtfulLines = 0,
    this.angles = const [],
    this.rotationDegrees = 0,
    this.submittedImageSize,
    this.orientation,
  });

  Map<String, Object?> toJson() => {
    'name': name,
    'durationMs': durationMs,
    'qualityScore': qualityScore,
    'rawLines': rawLines,
    'acceptedLines': acceptedLines,
    'rejectedLines': rejectedLines,
    'doubtfulLines': doubtfulLines,
    'rotationDegrees': rotationDegrees,
    'submittedImageSize': submittedImageSize == null
        ? null
        : {
            'width': submittedImageSize!.width,
            'height': submittedImageSize!.height,
          },
    'angles': {
      'values': angles,
      'null': angles.where((a) => a == null).length,
      'zero': angles.where((a) => a == 0).length,
      'normal': angles.where((a) => a != null && a != 0).length,
    },
    'confidence': confidence.toJson(),
    'lineHeights': lineHeights.toJson(),
    if (orientation != null) 'orientation': orientation,
    if (note != null) 'note': note,
  };
}

/// Satu foto pemindaian beserta seluruh metadata diagnostiknya.
@immutable
class OcrDiagnosticReport {
  final String? id;
  final DateTime timestamp;
  final bool legacyPreprocessingEnabled;

  final int photoBytes;
  final Size photoPixelSize;
  final String cameraPreset;

  final int? exifOrientation;
  final bool exifPresent;

  final String? deviceOrientation;

  final Size imageSentToMlKit;

  final List<OcrPassRecord> passes;

  final List<Map<String, Object?>> rejectedLines;
  final List<Map<String, Object?>> doubtfulLines;

  final String rawText;
  final String filteredText;
  final String formattedText;

  final int totalDurationMs;
  final Map<String, Object?> inputMetrics;

  const OcrDiagnosticReport({
    this.id,
    required this.timestamp,
    required this.legacyPreprocessingEnabled,
    required this.photoBytes,
    required this.photoPixelSize,
    required this.cameraPreset,
    required this.exifOrientation,
    required this.exifPresent,
    required this.deviceOrientation,
    required this.imageSentToMlKit,
    required this.passes,
    required this.rejectedLines,
    this.doubtfulLines = const [],
    required this.rawText,
    required this.filteredText,
    required this.formattedText,
    required this.totalDurationMs,
    this.inputMetrics = const {},
  });

  Map<String, Object?> toJson({bool includeText = true}) {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'legacyPreprocessingEnabled': legacyPreprocessingEnabled,
      'photo': {
        'bytes': photoBytes,
        'pixelWidth': photoPixelSize.width,
        'pixelHeight': photoPixelSize.height,
        'cameraPreset': cameraPreset,
      },
      'exif': {'present': exifPresent, 'orientation': exifOrientation},
      'deviceOrientation': deviceOrientation,
      'imageSentToMlKit': {
        'width': imageSentToMlKit.width,
        'height': imageSentToMlKit.height,
      },
      'passes': passes.map((p) => p.toJson()).toList(),
      'rejectedLines': _lineJson(rejectedLines, includeText),
      'doubtfulLines': _lineJson(doubtfulLines, includeText),
      'texts': includeText
          ? {
              'raw': rawText,
              'filtered': filteredText,
              'formatted': formattedText,
            }
          : {
              'rawLength': rawText.length,
              'filteredLength': filteredText.length,
              'formattedLength': formattedText.length,
            },
      'totalDurationMs': totalDurationMs,
      'inputMetrics': inputMetrics,
    };
  }

  String toJsonString({bool includeText = true}) {
    return const JsonEncoder.withIndent('  ')
        .convert(toJson(includeText: includeText));
  }

  static List<Map<String, Object?>> _lineJson(
    List<Map<String, Object?>> lines,
    bool includeText,
  ) => lines
      .map(
        (line) => includeText
            ? {...line}
            : {
                ...line,
                'text': '<disembunyikan>',
                // Legacy explanations may embed recognized words. Omit them as well.
                'explanation': '<disembunyikan>',
              },
      )
      .toList();
}

/// Pengumpul diagnostik per foto. Aman dipanggil walau diagnostik nonaktif:
/// semua operasi bernilai nol.
class OcrDiagnosticCollector {
  final OcrDiagnosticReport? _report;
  const OcrDiagnosticCollector._(this._report);

  static const OcrDiagnosticCollector disabled = OcrDiagnosticCollector._(null);

  factory OcrDiagnosticCollector.create({
    required Uint8List photoBytes,
    required Size photoPixelSize,
    required String cameraPreset,
    required int? exifOrientation,
    required String? deviceOrientation,
    Map<String, Object?> inputMetrics = const {},
  }) {
    if (!DebugOcrConfig.enableDiagnostics) return disabled;
    return OcrDiagnosticCollector._(
      OcrDiagnosticReport(
        id: 'ocr_${DateTime.now().microsecondsSinceEpoch}',
        timestamp: DateTime.now(),
        legacyPreprocessingEnabled: DebugOcrConfig.enableLegacyPreprocessing,
        photoBytes: photoBytes.length,
        photoPixelSize: photoPixelSize,
        cameraPreset: cameraPreset,
        exifOrientation: exifOrientation,
        exifPresent: exifOrientation != null,
        deviceOrientation: deviceOrientation,
        imageSentToMlKit: Size.zero,
        passes: const [],
        rejectedLines: const [],
        rawText: '',
        filteredText: '',
        formattedText: '',
        totalDurationMs: 0,
        inputMetrics: inputMetrics,
      ),
    );
  }

  bool get isActive => _report != null;

  /// Laporan terakhir yang dibangun. Null bila diagnostik nonaktif.
  OcrDiagnosticReport? get report => _report;

  /// Menyusun laporan akhir. Mengembalikan `null` bila diagnostik nonaktif.
  OcrDiagnosticReport? finalize({
    required Size imageSentToMlKit,
    required List<OcrPassRecord> passes,
    required List<Map<String, Object?>> rejectedLines,
    required String rawText,
    required String filteredText,
    required String formattedText,
    required int totalDurationMs,
    List<Map<String, Object?>> doubtfulLines = const [],
  }) {
    final r = _report;
    if (r == null) return null;
    return OcrDiagnosticReport(
      id: r.id,
      timestamp: r.timestamp,
      legacyPreprocessingEnabled: r.legacyPreprocessingEnabled,
      photoBytes: r.photoBytes,
      photoPixelSize: r.photoPixelSize,
      cameraPreset: r.cameraPreset,
      exifOrientation: r.exifOrientation,
      exifPresent: r.exifPresent,
      deviceOrientation: r.deviceOrientation,
      imageSentToMlKit: imageSentToMlKit,
      passes: passes,
      rejectedLines: rejectedLines,
      doubtfulLines: doubtfulLines,
      rawText: rawText,
      filteredText: filteredText,
      formattedText: formattedText,
      totalDurationMs: totalDurationMs,
      inputMetrics: r.inputMetrics,
    );
  }
}

/// Serialisasi baris yang ditolak filter agar mudah dibaca di log.
Map<String, Object?> rejectedLineToJson({
  required OcrLineData line,
  required String reason,
  required String explanation,
  bool includeText = true,
}) {
  return {
    'rule': reason,
    'text': includeText ? line.text : '<disembunyikan>',
    'length': line.text.length,
    'confidence': line.confidence,
    'box': {
      'left': line.boundingBox.left,
      'top': line.boundingBox.top,
      'width': line.boundingBox.width,
      'height': line.boundingBox.height,
    },
    'explanation': includeText ? explanation : '<disembunyikan>',
  };
}
