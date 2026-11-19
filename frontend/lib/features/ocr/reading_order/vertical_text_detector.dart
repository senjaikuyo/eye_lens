import 'dart:math';

import 'package:eye_lens/models/text_formatter_models.dart';

/// Conservative candidate detection only; never assembles or rewrites text.
class VerticalTextDetector {
  const VerticalTextDetector._();
  static const minimumCharacters = 4;
  static const maxCenterSpreadFactor = .6;
  static const minStepHeightFactor = .7;
  static const maxStepHeightFactor = 2.5;
  static const maxStepDeviationRatio = .25;
  static final _letter = RegExp(r'^[A-Za-z]$');

  static bool hasStrongCandidate(List<OcrLineData> lines) {
    if (lines.length > 1024) return false;
    final letters =
        lines
            .where(
              (l) =>
                  _letter.hasMatch(l.text.trim()) &&
                  l.boundingBox.width > 0 &&
                  l.boundingBox.height > 0 &&
                  l.boundingBox.center.dx.isFinite &&
                  l.boundingBox.center.dy.isFinite,
            )
            .toList()
          ..sort(
            (a, b) =>
                a.boundingBox.center.dx.compareTo(b.boundingBox.center.dx),
          );
    // Bound geometry work for pathological OCR output. No image is retained.
    if (letters.length < minimumCharacters || letters.length > 256) {
      return false;
    }
    for (var start = 0; start < letters.length; start++) {
      final anchor = letters[start];
      final group =
          letters
              .where(
                (l) =>
                    (l.boundingBox.center.dx - anchor.boundingBox.center.dx)
                        .abs() <=
                    anchor.boundingBox.height * maxCenterSpreadFactor,
              )
              .toList()
            ..sort(
              (a, b) =>
                  a.boundingBox.center.dy.compareTo(b.boundingBox.center.dy),
            );
      if (group.length < minimumCharacters) continue;
      // Reject list labels next to longer text or numeric serials on same row.
      final hasRowContent = group.any(
        (l) => lines.any(
          (other) =>
              !identical(l, other) &&
              other.text.trim().isNotEmpty &&
              !group.contains(other) &&
              (other.boundingBox.center.dy - l.boundingBox.center.dy).abs() <
                  l.boundingBox.height * .5,
        ),
      );
      if (hasRowContent) continue;
      final codes = group
          .map((l) => l.text.trim().toUpperCase().codeUnitAt(0))
          .toList();
      final sequential = List.generate(
        codes.length - 1,
        (i) => codes[i + 1] - codes[i],
      );
      if (sequential.every((d) => d == 1) || sequential.every((d) => d == -1)) {
        continue;
      }
      // Repeated labels do not provide convincing word structure.
      if (codes.toSet().length < 2) continue;
      final heights = group.map((l) => l.boundingBox.height).toList()..sort();
      final height = heights[heights.length ~/ 2];
      final steps = List.generate(
        group.length - 1,
        (i) =>
            group[i + 1].boundingBox.center.dy - group[i].boundingBox.center.dy,
      );
      final mean = steps.reduce((a, b) => a + b) / steps.length;
      if (mean < height * minStepHeightFactor ||
          mean > height * maxStepHeightFactor) {
        continue;
      }
      if (steps.any((s) => (s - mean).abs() > mean * maxStepDeviationRatio)) {
        continue;
      }
      final xs = group.map((l) => l.boundingBox.center.dx);
      if (xs.reduce(max) - xs.reduce(min) > height * maxCenterSpreadFactor) {
        continue;
      }
      return true;
    }
    return false;
  }
}
