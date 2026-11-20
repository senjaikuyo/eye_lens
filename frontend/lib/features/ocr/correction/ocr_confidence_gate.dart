import 'package:flutter/foundation.dart';

import 'package:eye_lens/features/ocr/correction/ocr_noise_filter.dart';
import 'package:eye_lens/features/speech/models/text_formatter_models.dart';

/// Gerbang confidence sebelum teks masuk ke layar hasil dan TTS.
///
/// Nilai ambang adalah ASUMSI awal dari laporan QA, belum dikalibrasi pada
/// keluaran ML Kit di perangkat asli.
@immutable
class ConfidenceGateResult {
  final List<OcrLineData> acceptedLines;
  final List<RejectedLineInfo> quarantinedLines;
  final bool hasWarning;

  const ConfidenceGateResult({
    required this.acceptedLines,
    required this.quarantinedLines,
    required this.hasWarning,
  });
}

class OcrConfidenceGate {
  /// Baris di bawah ambang ini tidak boleh dibacakan sebagai hasil final.
  static const double quarantineBelow = 0.30;

  /// Baris di bawah ambang ini tetap ditampilkan, tetapi diberi peringatan.
  static const double warnBelow = 0.60;

  static ConfidenceGateResult apply(List<OcrLineData> lines) {
    if (lines.isEmpty) {
      return const ConfidenceGateResult(
        acceptedLines: [],
        quarantinedLines: [],
        hasWarning: false,
      );
    }

    final accepted = <OcrLineData>[];
    final quarantined = <RejectedLineInfo>[];
    var warning = false;

    for (final line in lines) {
      final confidence = line.confidence;
      if (confidence != null &&
          confidence.isFinite &&
          confidence >= 0 &&
          confidence < quarantineBelow) {
        quarantined.add(
          RejectedLineInfo(
            line: line,
            reason: NoiseRejectionReason.lowConfidence,
            explanation: 'confidence ${confidence.toStringAsFixed(2)} '
                'di bawah $quarantineBelow',
            signals: const [NoiseRejectionReason.lowConfidence],
          ),
        );
        warning = true;
        continue;
      }

      // ML Kit iOS tidak mengisi confidence. Teks tetap ditampilkan, tetapi
      // kualitasnya belum diketahui sehingga pengguna harus memeriksa.
      if (confidence == null ||
          !confidence.isFinite ||
          confidence < warnBelow) {
        warning = true;
      }
      accepted.add(line);
    }

    return ConfidenceGateResult(
      acceptedLines: List.unmodifiable(accepted),
      quarantinedLines: List.unmodifiable(quarantined),
      hasWarning: warning,
    );
  }
}
