import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eye_lens/features/speech/models/text_formatter_models.dart';
import 'package:eye_lens/features/ocr/reading_order/vertical_text_detector.dart';

void main() {
  List<OcrLineData> stack(String text, {double size = 20, double step = 25}) =>
      List.generate(
        text.length,
        (i) => OcrLineData(
          text: text[i],
          boundingBox: Rect.fromLTWH(100, 100 + i * step, size * 0.75, size),
        ),
      );

  test('aligned single letters form a vertical column', () {
    expect(VerticalTextDetector.hasStrongCandidate(stack('BUKU')), isTrue);
    expect(VerticalTextDetector.hasStrongCandidate(stack('MAKANAN')), isTrue);
  });

  test('column keeps every character separate, never joined into a word', () {
    final lines = stack('dornng');
    final columns = VerticalTextDetector.characterColumns(lines);
    expect(columns, hasLength(1));
    expect(columns.single.map((l) => l.text), ['d', 'o', 'r', 'n', 'n', 'g']);
    expect(columns.single, hasLength(6));
    for (final line in columns.single) {
      expect(line.text.length, 1);
    }
  });

  test('small vertical characters still form a column', () {
    expect(
      VerticalTextDetector.hasStrongCandidate(
        stack('dornng', size: 6, step: 7.5),
      ),
      isTrue,
    );
  });

  test('alphabetic lists and numeric serials are not columns', () {
    // Serial angka adalah pola label daftar, bukan teks vertikal. Label ini
    // tetap dipertahankan sebagai teks horizontal oleh filter, tetapi tidak
    // boleh dianggap kolom vertikal.
    expect(VerticalTextDetector.characterColumns(stack('12345')), isEmpty);
  });

  test('single letters at different positions stay independent', () {
    final lines = [
      const OcrLineData(
        text: 'd',
        boundingBox: Rect.fromLTWH(120, 100, 15, 20),
      ),
      const OcrLineData(
        text: 'g',
        boundingBox: Rect.fromLTWH(400, 600, 15, 20),
      ),
    ];
    final columns = VerticalTextDetector.characterColumns(lines);
    expect(columns, isEmpty);
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

  test('horizontal letters are ignored', () {
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
