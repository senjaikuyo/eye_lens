import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:eye_lens/features/ocr/orientation/image_orientation_analyzer.dart';
import 'package:eye_lens/features/ocr/orientation/text_orientation.dart';
import 'package:eye_lens/features/ocr/orientation/text_orientation_analyzer.dart';
import 'package:eye_lens/features/speech/models/text_formatter_models.dart';

OcrWordData word(String text, double x, double y) =>
    OcrWordData(text: text, boundingBox: Rect.fromLTWH(x, y, 30, 14));

OcrLineData line(
  String text, {
  double? angle,
  Rect? box,
  List<OcrWordData> words = const [],
}) => OcrLineData(
  text: text,
  boundingBox: box ?? const Rect.fromLTWH(10, 20, 120, 20),
  angle: angle,
  elements: words,
);

void main() {
  group('TextOrientationAnalyzer - arah karakter dan baseline', () {
    test('T01/T02 sudut ML Kit dipetakan ke empat orientasi', () {
      expect(
        TextOrientationAnalyzer.orientationFromAngle(0),
        TextOrientation.up,
      );
      expect(
        TextOrientationAnalyzer.orientationFromAngle(90),
        TextOrientation.rotated90,
      );
      expect(
        TextOrientationAnalyzer.orientationFromAngle(180),
        TextOrientation.upsideDown,
      );
      expect(
        TextOrientationAnalyzer.orientationFromAngle(-90),
        TextOrientation.rotated270,
      );
      expect(
        TextOrientationAnalyzer.orientationFromAngle(270),
        TextOrientation.rotated270,
      );
      expect(
        TextOrientationAnalyzer.orientationFromAngle(-180),
        TextOrientation.upsideDown,
      );
    });

    test('baseline kata menentukan arah tanpa sudut ML Kit (iOS null)', () {
      final horizontal = TextOrientationAnalyzer.analyzeLine(
        line('buku baru', words: [word('buku', 10, 20), word('baru', 60, 20)]),
      );
      expect(horizontal.orientation, TextOrientation.up);

      final reversed = TextOrientationAnalyzer.analyzeLine(
        line('buku baru', words: [word('buku', 60, 20), word('baru', 10, 20)]),
      );
      expect(reversed.orientation, TextOrientation.upsideDown);

      final down = TextOrientationAnalyzer.analyzeLine(
        line(
          'buku baru',
          box: const Rect.fromLTWH(10, 20, 20, 120),
          words: [word('buku', 10, 20), word('baru', 10, 70)],
        ),
      );
      expect(down.orientation, TextOrientation.rotated90);

      final up = TextOrientationAnalyzer.analyzeLine(
        line(
          'buku baru',
          box: const Rect.fromLTWH(10, 20, 20, 120),
          words: [word('buku', 10, 70), word('baru', 10, 20)],
        ),
      );
      expect(up.orientation, TextOrientation.rotated270);
    });

    test('confidence tinggi tidak mengalahkan bukti geometri', () {
      final estimate = TextOrientationAnalyzer.analyzeLine(
        OcrLineData(
          text: 'buku baru',
          boundingBox: const Rect.fromLTWH(10, 20, 20, 120),
          confidence: 0.99,
          angle: 0,
          elements: [word('buku', 10, 20), word('baru', 10, 70)],
        ),
      );
      expect(estimate.orientation, TextOrientation.rotated90);
      expect(estimate.evidence, contains('wordBaseline'));
    });

    test('kemiringan kecil diestimasi sebagai skew, bukan kuartal baru', () {
      final estimate = TextOrientationAnalyzer.analyzeLine(
        line('buku baru', words: [word('buku', 10, 20), word('baru', 70, 30)]),
      );
      expect(estimate.orientation, TextOrientation.up);
      expect(estimate.skewDegrees, greaterThan(0));
      expect(estimate.skewDegrees, lessThan(20));
    });

    test('orientasi tidak berubah karena kata dikenal atau tidak dikenal', () {
      final known = TextOrientationAnalyzer.analyze([
        line('buku', angle: 0),
        line('buku', angle: 90),
      ]);
      final unknown = TextOrientationAnalyzer.analyze([
        line('zxqv', angle: 0),
        line('buku', angle: 90),
      ]);
      expect(unknown.weightedShares, known.weightedShares);
      expect(unknown.dominantOrientation, known.dominantOrientation);
      expect(unknown.confidence, known.confidence);
    });
  });

  group('ImageOrientationAnalyzer - keputusan global', () {
    test('landscape normal dengan bukti tegak tidak dirotasi', () {
      final analysis = TextOrientationAnalyzer.analyze([
        line('judul utama kemasan', box: const Rect.fromLTWH(10, 10, 300, 24)),
        line('600 sheets', box: const Rect.fromLTWH(10, 50, 120, 20)),
      ]);
      expect(analysis.dominantOrientation, TextOrientation.up);
      final plan = ImageOrientationAnalyzer.plan(analysis);
      expect(plan.needsRecognition, isFalse);
      expect(plan.candidateRotations, isEmpty);
    });

    test('rotasi 180 menghasilkan kandidat 180', () {
      final analysis = TextOrientationAnalyzer.analyze([
        line('judul utama', angle: 180),
        line('600 sheets', angle: 179),
      ]);
      expect(analysis.dominantOrientation, TextOrientation.upsideDown);
      final plan = ImageOrientationAnalyzer.plan(analysis);
      expect(plan.candidateRotations, contains(180));
      expect(plan.candidateRotations.length, lessThanOrEqualTo(3));
    });

    test('rotasi 90 menghasilkan koreksi 270', () {
      final analysis = TextOrientationAnalyzer.analyze([
        line('judul utama', angle: 90),
        line('600 sheets', angle: 88),
      ]);
      expect(analysis.dominantOrientation, TextOrientation.rotated90);
      expect(ImageOrientationAnalyzer.plan(analysis).candidateRotations, [270]);
    });

    test('rotasi 270 menghasilkan koreksi 90', () {
      final analysis = TextOrientationAnalyzer.analyze([
        line('judul utama', angle: -90),
        line('600 sheets', angle: -88),
      ]);
      expect(analysis.dominantOrientation, TextOrientation.rotated270);
      expect(ImageOrientationAnalyzer.plan(analysis).candidateRotations, [90]);
    });

    test('orientasi campuran terdeteksi dan kandidat tetap terbatas', () {
      final analysis = TextOrientationAnalyzer.analyze([
        line('judul utama', angle: 0),
        line('600 sheets', angle: 90),
      ]);
      expect(analysis.hasMixedOrientation, isTrue);
      final plan = ImageOrientationAnalyzer.plan(analysis);
      expect(plan.mixed, isTrue);
      expect(plan.candidateRotations.length, lessThanOrEqualTo(3));
    });

    test(
      'kandidat vertikal ditambahkan hanya saat ada bukti vertikal kuat',
      () {
        final analysis = TextOrientationAnalyzer.analyze([
          line('judul utama', box: const Rect.fromLTWH(10, 10, 300, 24)),
        ]);
        final plan = ImageOrientationAnalyzer.plan(
          analysis,
          verticalCandidate: true,
        );
        expect(plan.candidateRotations, containsAll([90, 270]));
        expect(plan.candidateRotations.length, lessThanOrEqualTo(3));
      },
    );

    test('koreksi kuartal sesuai arah rotasi konten', () {
      expect(TextOrientation.up.correctionDegrees, 0);
      expect(TextOrientation.rotated90.correctionDegrees, 270);
      expect(TextOrientation.upsideDown.correctionDegrees, 180);
      expect(TextOrientation.rotated270.correctionDegrees, 90);
    });
  });
}
