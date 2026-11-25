import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:eye_lens/features/image_area/logic/lens_selection_helper.dart';
import 'package:eye_lens/features/speech/models/text_formatter_models.dart';

void main() {
  test('crop retains low-confidence, tiny, edge and screenshot-like lines', () {
    final lines = [
      const OcrLineData(
        text: 'ab###',
        confidence: .1,
        boundingBox: Rect.fromLTWH(0, 0, 30, 1),
      ),
      for (final text in [
        '09:41',
        '85%',
        'LTE',
        'Telkomsel',
        '~~~',
        '___',
        '...',
      ])
        OcrLineData(
          text: text,
          confidence: .1,
          boundingBox: const Rect.fromLTWH(0, 1, 30, 2),
        ),
    ];
    final result = LensSelectionHelper.selectTextInCrop(
      rawLines: lines,
      imageCropRect: const Rect.fromLTWH(0, 0, 1000, 1000),
      originalImageSize: const Size(1000, 1000),
    );
    // Formatter/validator behavior is separate; this stage only removes noise filtering.
    expect(result.acceptedLines, orderedEquals(lines));
  });

  test('manual crop still excludes lines outside the selected area', () {
    const inside = OcrLineData(
      text: 'Inside',
      boundingBox: Rect.fromLTWH(10, 10, 30, 20),
    );
    const outside = OcrLineData(
      text: 'Outside',
      boundingBox: Rect.fromLTWH(500, 500, 30, 20),
    );
    final result = LensSelectionHelper.selectTextInCrop(
      rawLines: const [inside, outside],
      imageCropRect: const Rect.fromLTWH(0, 0, 100, 100),
      originalImageSize: const Size(1000, 1000),
    );
    expect(result.acceptedLines, [inside]);
  });
}
