import 'package:flutter/foundation.dart';

import 'package:eye_lens/features/speech/models/text_formatter_models.dart';

// Retained for scan-mode callers until their separate cleanup.
enum OcrScanMode { document, smallText, screenText, handwriting }

// Legacy diagnostic types remain readable; no noise classification runs.
enum NoiseRejectionReason {
  lowConfidence,
  tooSmall,
  edgeBoundary,
  isolated,
  lowAlphaNumericRatio,
  symbolOnly,
  emptyOrWhitespace,
  clockPattern,
  statusBarPattern,
  combinedSuspicion,
  shortText,
}

@immutable
class RejectedLineInfo {
  final OcrLineData line;
  final NoiseRejectionReason reason;
  final String explanation;
  final double suspicionScore;
  final List<NoiseRejectionReason> signals;

  const RejectedLineInfo({
    required this.line,
    required this.reason,
    required this.explanation,
    this.suspicionScore = 0,
    this.signals = const [],
  });
}
