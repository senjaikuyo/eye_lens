import 'package:eye_lens/features/ocr/orientation/text_orientation.dart';

/// Mengubah bukti orientasi menjadi rencana koreksi yang terbatas.
///
/// Keputusan tidak memakai rasio width/height citra. Landscape normal dengan
/// bukti orientasi tegak tidak dimasukkan ke daftar kandidat rotasi.
class ImageOrientationAnalyzer {
  const ImageOrientationAnalyzer._();

  static ImageOrientationPlan plan(
    ImageOrientationAnalysis analysis, {
    bool verticalCandidate = false,
  }) {
    if (analysis.analyzedLines == 0) return ImageOrientationPlan.none;

    final dominant = analysis.dominantOrientation;
    final mixed = analysis.hasMixedOrientation || verticalCandidate;
    final uprightIsClear =
        dominant == TextOrientation.up && analysis.uprightShare >= 0.55;
    if (uprightIsClear && !verticalCandidate) {
      // Blok berorientasi berbeda ditangani di reading order, bukan dengan
      // memutar seluruh gambar.
      return ImageOrientationPlan(
        dominantOrientation: dominant,
        needsRecognition: false,
        mixed: mixed,
        candidateRotations: const [],
      );
    }

    final candidates = <int>[];
    void add(int degrees) {
      if (degrees == 0) return;
      if (!candidates.contains(degrees)) candidates.add(degrees);
    }

    if (dominant != TextOrientation.up) {
      add(dominant.correctionDegrees);
    }
    if (verticalCandidate || analysis.hasMixedOrientation) {
      add(90);
      add(270);
    }
    final second = analysis.secondOrientation();
    if (second != null && second != dominant && second != TextOrientation.up) {
      add(second.correctionDegrees);
    }
    if (candidates.isEmpty && dominant == TextOrientation.up) {
      add(180);
    }

    final bounded = candidates.take(3).toList(growable: false);
    return ImageOrientationPlan(
      dominantOrientation: dominant,
      needsRecognition: bounded.isNotEmpty,
      mixed: mixed,
      candidateRotations: bounded,
    );
  }
}
