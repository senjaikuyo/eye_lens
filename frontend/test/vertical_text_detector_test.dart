import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eye_lens/models/text_formatter_models.dart';
import 'package:eye_lens/features/ocr/reading_order/vertical_text_detector.dart';

void main() {
  List<OcrLineData> stack(String text) => List.generate(
    text.length,
    (i) => OcrLineData(
      text: text[i],
      boundingBox: Rect.fromLTWH(100, 100 + i * 25, 15, 20),
    ),
  );

  test('regular single letters with aligned X form a candidate', () {
    expect(VerticalTextDetector.hasStrongCandidate(stack('BUKU')), isTrue);
    expect(VerticalTextDetector.hasStrongCandidate(stack('MAKANAN')), isTrue);
  });
  test('alphabetic lists and numeric serials are never assembled', () {
    for (final text in ['ABC', 'ABCD', 'DCBA', '12345', 'AAAA']) {
      expect(VerticalTextDetector.hasStrongCandidate(stack(text)), isFalse);
    }
  });
  test('labels with neighboring row content are not vertical words', () {
    final labels = stack('BUKU');
    final lines = [
      ...labels,
      ...labels.map(
        (l) => OcrLineData(
          text: 'Pilihan jawaban',
          boundingBox: l.boundingBox.shift(const Offset(100, 0)),
        ),
      ),
    ];
    expect(VerticalTextDetector.hasStrongCandidate(lines), isFalse);
  });
  test('irregular Y steps are not evidence', () {
    final letters = stack('BUKU');
    letters[3] = const OcrLineData(
      text: 'U',
      boundingBox: Rect.fromLTWH(100, 500, 15, 20),
    );
    expect(VerticalTextDetector.hasStrongCandidate(letters), isFalse);
  });
  test('horizontal letters and short stacks are ignored', () {
    expect(VerticalTextDetector.hasStrongCandidate(stack('BUK')), isFalse);
    final lines = List.generate(
      4,
      (i) => OcrLineData(
        text: 'BUKU'[i],
        boundingBox: Rect.fromLTWH(100 + i * 25, 100, 15, 20),
      ),
    );
    expect(VerticalTextDetector.hasStrongCandidate(lines), isFalse);
    expect(VerticalTextDetector.hasStrongCandidate([]), isFalse);
  });
  test('punctuated list labels do not enter the detector', () {
    final lines = stack('ABCD')
        .map((l) => OcrLineData(text: '${l.text}.', boundingBox: l.boundingBox))
        .toList();
    expect(VerticalTextDetector.hasStrongCandidate(lines), isFalse);
  });
  test('compute matches sync and leaves input text/order unchanged', () async {
    final letters = stack('BUKU').reversed.toList();
    final before = letters.map((l) => l.text).toList();
    expect(
      await compute(VerticalTextDetector.hasStrongCandidate, letters),
      isTrue,
    );
    expect(letters.map((l) => l.text), before);
  });
  test('pathological volumes are bounded', () {
    expect(VerticalTextDetector.hasStrongCandidate(stack('B' * 257)), isFalse);
  });
}
