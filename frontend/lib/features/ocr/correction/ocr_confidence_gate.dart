import 'package:flutter/foundation.dart';

import 'package:eye_lens/features/speech/models/text_formatter_models.dart';

/// Mencatat confidence OCR tanpa menyembunyikan teks yang dikenali.
@immutable
class ConfidenceGateResult {
  final List<OcrLineData> acceptedLines;
  final bool hasWarning;

  const ConfidenceGateResult({
    required this.acceptedLines,
    required this.hasWarning,
  });
}

class OcrConfidenceGate {
  /// Baris di bawah ambang ini tetap ditampilkan dan dibacakan, tetapi hasil
  /// diberi peringatan kualitas.
  static const double warnBelow = 0.60;

  static ConfidenceGateResult apply(List<OcrLineData> lines) {
    if (lines.isEmpty) {
      return const ConfidenceGateResult(acceptedLines: [], hasWarning: false);
    }

    final accepted = <OcrLineData>[];
    var warning = false;

    for (final line in lines) {
      final confidence = line.confidence;
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
      hasWarning: warning,
    );
  }
}
