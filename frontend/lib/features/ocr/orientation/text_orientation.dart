import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Arah konten teks di dalam koordinat citra yang dikirim ke OCR.
///
/// Nilai merepresentasikan rotasi searah jarum jam yang diterapkan pada teks
/// tegak agar tampil seperti pada citra.
enum TextOrientation {
  up,
  rotated90,
  upsideDown,
  rotated270;

  int get quarterTurns => switch (this) {
    TextOrientation.up => 0,
    TextOrientation.rotated90 => 1,
    TextOrientation.upsideDown => 2,
    TextOrientation.rotated270 => 3,
  };

  bool get isHorizontal => this == up || this == upsideDown;

  /// Rotasi searah jarum jam yang dibutuhkan untuk mengembalikan teks ke tegak.
  int get correctionDegrees => (4 - quarterTurns) % 4 * 90;

  static TextOrientation fromQuarterTurns(int turns) {
    return switch (((turns % 4) + 4) % 4) {
      0 => TextOrientation.up,
      1 => TextOrientation.rotated90,
      2 => TextOrientation.upsideDown,
      _ => TextOrientation.rotated270,
    };
  }
}

/// Estimasi orientasi satu baris beserta bukti yang menyertainya.
@immutable
class TextOrientationEstimate {
  final TextOrientation orientation;
  final double skewDegrees;
  final double confidence;
  final List<String> evidence;

  const TextOrientationEstimate({
    required this.orientation,
    this.skewDegrees = 0,
    this.confidence = 0,
    this.evidence = const [],
  });

  static const TextOrientationEstimate upright = TextOrientationEstimate(
    orientation: TextOrientation.up,
    confidence: 1,
    evidence: ['default'],
  );

  int get quarterTurns => orientation.quarterTurns;

  Map<String, Object?> toJson() => {
    'orientation': orientation.name,
    'quarterTurns': quarterTurns,
    'skewDegrees': skewDegrees,
    'confidence': confidence,
    'evidence': evidence,
  };
}

/// Agregat bukti orientasi untuk seluruh citra.
@immutable
class ImageOrientationAnalysis {
  final TextOrientation dominantOrientation;
  final double confidence;
  final double uprightShare;
  final bool hasMixedOrientation;
  final Map<TextOrientation, double> weightedShares;
  final int analyzedLines;
  final int nullAngleLines;

  const ImageOrientationAnalysis({
    required this.dominantOrientation,
    required this.confidence,
    required this.uprightShare,
    required this.hasMixedOrientation,
    required this.weightedShares,
    required this.analyzedLines,
    required this.nullAngleLines,
  });

  static const ImageOrientationAnalysis empty = ImageOrientationAnalysis(
    dominantOrientation: TextOrientation.up,
    confidence: 0,
    uprightShare: 0,
    hasMixedOrientation: false,
    weightedShares: {},
    analyzedLines: 0,
    nullAngleLines: 0,
  );

  double shareOf(TextOrientation orientation) =>
      weightedShares[orientation] ?? 0;

  TextOrientation? secondOrientation() {
    final sorted = weightedShares.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.length < 2 || sorted[1].value <= 0) return null;
    return sorted[1].key;
  }

  Map<String, Object?> toJson() => {
    'dominant': dominantOrientation.name,
    'confidence': confidence,
    'uprightShare': uprightShare,
    'hasMixedOrientation': hasMixedOrientation,
    'analyzedLines': analyzedLines,
    'nullAngleLines': nullAngleLines,
    'shares': weightedShares.map((key, value) => MapEntry(key.name, value)),
  };
}

/// Rencana koreksi yang dibangun dari bukti orientasi, bukan rasio citra.
@immutable
class ImageOrientationPlan {
  final TextOrientation dominantOrientation;
  final bool needsRecognition;
  final bool mixed;
  final List<int> candidateRotations;

  const ImageOrientationPlan({
    required this.dominantOrientation,
    required this.needsRecognition,
    required this.mixed,
    required this.candidateRotations,
  });

  static const ImageOrientationPlan none = ImageOrientationPlan(
    dominantOrientation: TextOrientation.up,
    needsRecognition: false,
    mixed: false,
    candidateRotations: [],
  );

  Map<String, Object?> toJson() => {
    'dominant': dominantOrientation.name,
    'needsRecognition': needsRecognition,
    'mixed': mixed,
    'candidateRotations': candidateRotations,
  };
}

double normalizeDegrees(double degrees) {
  var value = degrees % 360;
  if (value > 180) value -= 360;
  if (value < -180) value += 360;
  return value;
}

/// Membangkitkan vektor satuan searah baca untuk suatu orientasi.
Offset readingAxisFor(TextOrientation orientation, {double skewDegrees = 0}) {
  final base = switch (orientation) {
    TextOrientation.up => const Offset(1, 0),
    TextOrientation.rotated90 => const Offset(0, 1),
    TextOrientation.upsideDown => const Offset(-1, 0),
    TextOrientation.rotated270 => const Offset(0, -1),
  };
  final radians = skewDegrees * math.pi / 180;
  final cos = math.cos(radians);
  final sin = math.sin(radians);
  return Offset(
    base.dx * cos - base.dy * sin,
    base.dx * sin + base.dy * cos,
  );
}

/// Sumbu tempat baris berikutnya berada (tegak lurus searah baca).
Offset crossAxisFor(Offset readingAxis) =>
    Offset(-readingAxis.dy, readingAxis.dx);
