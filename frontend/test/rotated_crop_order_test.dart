import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:eye_lens/features/image_area/logic/lens_selection_helper.dart';
import 'package:eye_lens/features/ocr/orientation/orientation_transform.dart';
import 'package:eye_lens/features/ocr/orientation/text_orientation.dart';
import 'package:eye_lens/features/speech/models/text_formatter_models.dart';

void main() {
  for (final rotation in [0, 90, 180, 270]) {
    test('crop preserves reading order after $rotation degree mapping', () {
      const size = Size(400, 400);
      final lines = [
        for (var index = 0; index < 2; index++)
          OcrLineData(
            text: index == 0 ? 'First line' : 'Second line',
            boundingBox: Rect.fromLTWH(20, 20 + index * 100, 200, 20),
            angle: 0,
            orientation: const TextOrientationEstimate(
              orientation: TextOrientation.up,
              confidence: 1,
            ),
            elements: [
              OcrWordData(
                text: index == 0 ? 'First' : 'Second',
                boundingBox: Rect.fromLTWH(20, 20 + index * 100, 80, 20),
              ),
              OcrWordData(
                text: 'line',
                boundingBox: Rect.fromLTWH(120, 20 + index * 100, 80, 20),
              ),
            ],
          ),
      ];
      final mapped = [
        for (final line in lines)
          rotation == 0
              ? line
              : OrientationTransform.mapLineBack(line, size, rotation),
      ];
      final selected = LensSelectionHelper.selectTextInCrop(
        rawLines: mapped,
        imageCropRect: Offset.zero & size,
        originalImageSize: size,
      );
      expect(selected.acceptedLines.first.elements.first.text, 'First');
      expect(selected.acceptedLines.first.orientation, mapped.first.orientation);
      expect(selected.text.indexOf('First line'), greaterThanOrEqualTo(0));
      expect(
        selected.text.indexOf('First line'),
        lessThan(selected.text.indexOf('Second line')),
      );

      // Selecting only one word must keep the same orientation metadata too.
      final partial = LensSelectionHelper.selectTextInCrop(
        rawLines: mapped,
        imageCropRect: mapped.first.elements.first.boundingBox.inflate(1),
        originalImageSize: size,
      );
      expect(partial.text, 'First');
      expect(partial.acceptedLines.single.angle, mapped.first.angle);
      expect(partial.acceptedLines.single.orientation, mapped.first.orientation);
    });
  }
}
