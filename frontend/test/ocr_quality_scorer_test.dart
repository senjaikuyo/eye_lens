import 'dart:ui';

import 'package:eye_lens/models/text_formatter_models.dart';
import 'package:eye_lens/services/ocr_quality_scorer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('teks dengan token wajar mendapat skor lebih tinggi dari simbol', () {
    const text = OcrLineData(
      text: 'Ini teks dokumen yang terbaca',
      boundingBox: Rect.fromLTWH(10, 10, 300, 30),
      confidence: 0.9,
    );
    const noise = OcrLineData(
      text: '| ~ ^ | ~',
      boundingBox: Rect.fromLTWH(10, 10, 300, 30),
    );

    expect(
      OcrQualityScorer.scoreLines([text]),
      greaterThan(OcrQualityScorer.scoreLines([noise])),
    );
  });
}
