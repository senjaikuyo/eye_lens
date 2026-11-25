import 'dart:math' as math;

import 'package:eye_lens/features/ocr/orientation/text_orientation.dart';
import 'package:eye_lens/features/speech/models/text_formatter_models.dart';

/// Mengestimasi orientasi dari bukti geometri dan sudut ML Kit.
///
/// Sudut ML Kit bukan satu-satunya penentu: arah baseline dari pusat kata,
/// rasio bounding box baris, dan rasio bounding box kata ikut memberi suara.
class TextOrientationAnalyzer {
  const TextOrientationAnalyzer._();

  static const double _wordBoxWeight = 0.6;
  static const double _lineBoxWeight = 0.8;
  static const double _baselineWeight = 3.0;
  static const double _angleWeight = 2.0;

  static TextOrientation orientationFromAngle(double angle) {
    final a = normalizeDegrees(angle);
    final magnitude = a.abs();
    if (magnitude <= 45) return TextOrientation.up;
    if (magnitude >= 135) return TextOrientation.upsideDown;
    return a > 0 ? TextOrientation.rotated90 : TextOrientation.rotated270;
  }

  static TextOrientation orientationFromVector(double dx, double dy) {
    if (dx.abs() >= dy.abs()) {
      return dx >= 0 ? TextOrientation.up : TextOrientation.upsideDown;
    }
    return dy >= 0 ? TextOrientation.rotated90 : TextOrientation.rotated270;
  }

  /// Estimasi residual kemiringan setelah rotasi kuartal dilepas.
  static double skewFromVector(double dx, double dy, TextOrientation q) {
    final angle = math.atan2(dy, dx) * 180 / math.pi;
    return normalizeDegrees(angle - q.quarterTurns * 90);
  }

  static TextOrientationEstimate analyzeLine(OcrLineData line) {
    final votes = <TextOrientation, double>{
      for (final value in TextOrientation.values) value: 0,
    };
    final evidence = <String>[];

    final angle = line.angle;
    if (angle != null && angle.isFinite) {
      final q = orientationFromAngle(angle);
      final strength = switch (q) {
        TextOrientation.up => 1.0 - angle.abs() / 90,
        TextOrientation.upsideDown => 1.0 - (180 - angle.abs()) / 90,
        _ => 1.0 - (angle.abs() - 90) / 90,
      };
      votes[q] = votes[q]! + _angleWeight * strength.clamp(0.2, 1.0);
      evidence.add('mlKitAngle');
    }

    double? skew;
    final words = line.elements.where((w) => w.text.trim().isNotEmpty).toList();
    if (words.length >= 2) {
      final first = words.first.boundingBox.center;
      final last = words.last.boundingBox.center;
      final dx = last.dx - first.dx;
      final dy = last.dy - first.dy;
      final distance = math.sqrt(dx * dx + dy * dy);
      final minDistance = math.max(
        2.0,
        math.min(line.boundingBox.width, line.boundingBox.height) * 0.15,
      );
      if (distance >= minDistance) {
        final q = orientationFromVector(dx, dy);
        votes[q] = votes[q]! + _baselineWeight;
        skew = skewFromVector(dx, dy, q);
        evidence.add('wordBaseline');
      }
    }

    final box = line.boundingBox;
    if (box.width > 0 && box.height > 0) {
      final ratio = box.width / box.height;
      if (ratio >= 1.6) {
        // Rasio horizontal saja tidak bisa membedakan 0° dan 180°.
        // Bukti ini sengaja hanya mendukung orientasi tegak.
        votes[TextOrientation.up] = votes[TextOrientation.up]! + _lineBoxWeight;
        evidence.add('lineBoxHorizontal');
      } else if (ratio <= 0.625) {
        votes[TextOrientation.rotated90] =
            votes[TextOrientation.rotated90]! + _lineBoxWeight;
        votes[TextOrientation.rotated270] =
            votes[TextOrientation.rotated270]! + _lineBoxWeight;
        evidence.add('lineBoxVertical');
      }
    }

    final narrowWords = words
        .where((w) => w.boundingBox.width > 0 && w.boundingBox.height > 0)
        .toList();
    if (narrowWords.isNotEmpty) {
      var horizontal = 0;
      var vertical = 0;
      for (final word in narrowWords) {
        final ratio = word.boundingBox.width / word.boundingBox.height;
        if (ratio >= 1.6) {
          horizontal++;
        } else if (ratio <= 0.625) {
          vertical++;
        }
      }
      final total = narrowWords.length;
      if (horizontal / total >= 0.6) {
        votes[TextOrientation.up] = votes[TextOrientation.up]! + _wordBoxWeight;
        evidence.add('wordBoxHorizontal');
      } else if (vertical / total >= 0.6) {
        votes[TextOrientation.rotated90] =
            votes[TextOrientation.rotated90]! + _wordBoxWeight;
        votes[TextOrientation.rotated270] =
            votes[TextOrientation.rotated270]! + _wordBoxWeight;
        evidence.add('wordBoxVertical');
      }
    }

    final total = votes.values.fold<double>(0, (sum, v) => sum + v);
    if (total <= 0) return TextOrientationEstimate.upright;

    var winner = TextOrientation.up;
    for (final entry in votes.entries) {
      if (entry.value > votes[winner]! ||
          (entry.value == votes[winner]! &&
              entry.key.quarterTurns < winner.quarterTurns)) {
        winner = entry.key;
      }
    }

    return TextOrientationEstimate(
      orientation: winner,
      skewDegrees: skew ?? 0,
      confidence: votes[winner]! / total,
      evidence: List.unmodifiable(evidence),
    );
  }

  /// Agregasi orientasi memakai panjang teks, tanpa kamus atau penilaian ejaan.
  static ImageOrientationAnalysis analyze(Iterable<OcrLineData> lines) {
    var total = 0.0;
    var nullAngles = 0;
    var countedLines = 0;
    final shares = <TextOrientation, double>{
      for (final value in TextOrientation.values) value: 0,
    };
    final counts = <TextOrientation, int>{
      for (final value in TextOrientation.values) value: 0,
    };

    for (final line in lines) {
      if (line.text.trim().isEmpty) continue;
      countedLines++;
      if (line.angle == null || !line.angle!.isFinite) nullAngles++;
      final estimate = line.orientation ?? analyzeLine(line);
      final weight = _lineWeight(line);
      shares[estimate.orientation] =
          shares[estimate.orientation]! + weight * estimate.confidence;
      counts[estimate.orientation] = counts[estimate.orientation]! + 1;
      total += weight;
    }

    if (total <= 0 || shares.values.every((v) => v <= 0)) {
      return ImageOrientationAnalysis(
        dominantOrientation: TextOrientation.up,
        confidence: 0,
        uprightShare: 0,
        hasMixedOrientation: false,
        weightedShares: shares,
        analyzedLines: 0,
        nullAngleLines: nullAngles,
      );
    }

    final normalized = shares.map((key, value) => MapEntry(key, value / total));
    var dominant = TextOrientation.up;
    for (final entry in normalized.entries) {
      if (entry.value > normalized[dominant]! ||
          (entry.value == normalized[dominant]! &&
              entry.key.quarterTurns < dominant.quarterTurns)) {
        dominant = entry.key;
      }
    }

    final second = normalized.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final nonDominantLines = countedLines - counts[dominant]!;
    final mixed =
        (second.length >= 2 && second[1].value >= 0.25) ||
        (countedLines >= 2 && nonDominantLines / countedLines >= 0.25);
    final analyzed = countedLines;

    return ImageOrientationAnalysis(
      dominantOrientation: dominant,
      confidence: normalized[dominant]!,
      uprightShare: normalized[TextOrientation.up]!,
      hasMixedOrientation: mixed,
      weightedShares: Map.unmodifiable(normalized),
      analyzedLines: analyzed,
      nullAngleLines: nullAngles,
    );
  }

  static double _lineWeight(OcrLineData line) {
    final length = line.text.replaceAll(RegExp(r'\s'), '').length;
    return math.min(30.0, math.max(3.0, length.toDouble()));
  }
}
