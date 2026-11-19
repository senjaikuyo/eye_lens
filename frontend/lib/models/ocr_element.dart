import 'dart:ui';

import 'package:eye_lens/services/ocr_noise_filter.dart';
import 'package:eye_lens/models/text_formatter_models.dart';

/// Representasi elemen teks dengan posisi koordinat pada citra asli.
class OcrElement {
  final String id;
  final String text;
  final Rect boundingBox;

  const OcrElement({
    required this.id,
    required this.text,
    required this.boundingBox,
  });
}

/// Hasil lengkap ekstraksi OCR: teks penuh, daftar elemen berkoordinat, dan ukuran citra.
class OcrResult {
  final String fullText;
  final List<OcrElement> elements;
  final Size imageSize;
  final OcrDocumentData? documentData;
  final FormattedTextResult? formattedResult;
  final List<RejectedLineInfo> rejectedLines;
  final List<RejectedLineInfo> doubtfulLines;
  final bool fallbackUsed;
  final bool hasLowQualityWarning;
  final bool allLinesFilteredOut;
  final int rawLinesCount;
  final List<OcrLineData> rawLines;

  /// Laporan diagnostik K0 dalam format JSON. Hanya terisi pada build debug.
  final String? diagnosticJson;

  const OcrResult({
    required this.fullText,
    required this.elements,
    required this.imageSize,
    this.documentData,
    this.formattedResult,
    this.rejectedLines = const [],
    this.doubtfulLines = const [],
    this.fallbackUsed = false,
    this.hasLowQualityWarning = false,
    this.allLinesFilteredOut = false,
    this.rawLinesCount = 0,
    this.rawLines = const [],
    this.diagnosticJson,
  });

  /// Menyalin hasil OCR dengan laporan diagnostik opsional.
  OcrResult copyWith({String? diagnosticJson}) {
    return OcrResult(
      fullText: fullText,
      elements: elements,
      imageSize: imageSize,
      documentData: documentData,
      formattedResult: formattedResult,
      rejectedLines: rejectedLines,
      doubtfulLines: doubtfulLines,
      fallbackUsed: fallbackUsed,
      hasLowQualityWarning: hasLowQualityWarning,
      allLinesFilteredOut: allLinesFilteredOut,
      rawLinesCount: rawLinesCount,
      rawLines: rawLines,
      diagnosticJson: diagnosticJson ?? this.diagnosticJson,
    );
  }

  static const OcrResult empty = OcrResult(
    fullText: '',
    elements: [],
    imageSize: Size.zero,
    documentData: null,
    formattedResult: null,
    rejectedLines: [],
    fallbackUsed: false,
    hasLowQualityWarning: false,
    allLinesFilteredOut: false,
    rawLinesCount: 0,
    rawLines: [],
  );
}
