import 'dart:ui';

import 'package:eye_lens/features/speech/models/text_formatter_models.dart';

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

enum OcrFailureType { processing, timeout }

/// Hasil lengkap ekstraksi OCR: teks penuh, daftar elemen berkoordinat, dan ukuran citra.
class OcrResult {
  final String fullText;
  final List<OcrElement> elements;
  final Size imageSize;
  final OcrDocumentData? documentData;
  final FormattedTextResult? formattedResult;
  final bool hasLowQualityWarning;
  final int rawLinesCount;
  final List<OcrLineData> rawLines;

  /// Rotasi searah jarum jam yang dipakai OCR untuk membaca citra ini.
  /// Hasil dan koordinat publik tetap berada pada citra asli; UI dapat memakai
  /// nilai ini untuk memutar preview beserta koordinat overlay secara konsisten.
  final int appliedOrientationRotation;

  /// Laporan diagnostik K0 dalam format JSON. Hanya terisi pada build debug.
  final String? diagnosticJson;

  /// Terisi jika OCR gagal dijalankan, bukan sekadar tidak menemukan teks.
  final OcrFailureType? failureType;

  bool get hasFailure => failureType != null;

  const OcrResult({
    required this.fullText,
    required this.elements,
    required this.imageSize,
    this.documentData,
    this.formattedResult,
    this.hasLowQualityWarning = false,
    this.rawLinesCount = 0,
    this.rawLines = const [],
    this.appliedOrientationRotation = 0,
    this.diagnosticJson,
    this.failureType,
  });

  /// Menyalin hasil OCR dengan laporan diagnostik opsional.
  OcrResult copyWith({String? diagnosticJson}) {
    return OcrResult(
      fullText: fullText,
      elements: elements,
      imageSize: imageSize,
      documentData: documentData,
      formattedResult: formattedResult,
      hasLowQualityWarning: hasLowQualityWarning,
      rawLinesCount: rawLinesCount,
      rawLines: rawLines,
      appliedOrientationRotation: appliedOrientationRotation,
      diagnosticJson: diagnosticJson ?? this.diagnosticJson,
      failureType: failureType,
    );
  }

  static OcrResult failed([OcrFailureType type = OcrFailureType.processing]) {
    return OcrResult(
      fullText: '',
      elements: const [],
      imageSize: Size.zero,
      failureType: type,
    );
  }

  static const OcrResult empty = OcrResult(
    fullText: '',
    elements: [],
    imageSize: Size.zero,
    documentData: null,
    formattedResult: null,
    hasLowQualityWarning: false,
    rawLinesCount: 0,
    rawLines: [],
  );
}
