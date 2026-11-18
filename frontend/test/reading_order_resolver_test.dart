import 'dart:ui';

import 'package:eye_lens/models/text_formatter_models.dart';
import 'package:eye_lens/services/reading_order_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

OcrBlockData block(String text, Rect rect, {List<OcrLineData>? lines}) {
  return OcrBlockData(
    text: text,
    boundingBox: rect,
    lines: lines ?? [OcrLineData(text: text, boundingBox: rect)],
  );
}

void main() {
  group('ReadingOrderResolver', () {
    test('menyelesaikan seluruh kolom kiri sebelum kolom kanan', () {
      final ordered = ReadingOrderResolver.resolve([
        block('kanan atas', const Rect.fromLTWH(500, 100, 200, 30)),
        block('kiri bawah', const Rect.fromLTWH(100, 160, 200, 30)),
        block('kiri atas', const Rect.fromLTWH(100, 100, 200, 30)),
        block('kanan bawah', const Rect.fromLTWH(500, 160, 200, 30)),
      ]);

      expect(ordered.map((item) => item.text), [
        'kiri atas',
        'kiri bawah',
        'kanan atas',
        'kanan bawah',
      ]);
    });

    test('mempertahankan satu blok kartu secara utuh', () {
      final ordered = ReadingOrderResolver.resolve([
        block('kartu kanan', const Rect.fromLTWH(480, 100, 200, 100)),
        block(
          'kartu kiri',
          const Rect.fromLTWH(100, 100, 200, 100),
          lines: const [
            OcrLineData(
              text: 'baris kedua',
              boundingBox: Rect.fromLTWH(100, 145, 180, 20),
            ),
            OcrLineData(
              text: 'baris pertama',
              boundingBox: Rect.fromLTWH(100, 115, 180, 20),
            ),
          ],
        ),
      ]);

      expect(ordered.first.text, 'kartu kiri');
      expect(ordered.first.lines.map((line) => line.text), [
        'baris pertama',
        'baris kedua',
      ]);
    });
  });
}
