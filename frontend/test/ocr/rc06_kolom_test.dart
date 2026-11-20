import 'dart:ui';

import 'package:eye_lens/features/ocr/orientation/orientation_aware_reading_order.dart';
import 'package:eye_lens/features/speech/models/text_formatter_models.dart';
import 'package:flutter_test/flutter_test.dart';

OcrLineData line(String text, double x, double y) => OcrLineData(
  text: text,
  boundingBox: Rect.fromLTWH(x, y, 140, 20),
);

void main() {
  group('RC-06 IS-01/OD-04 kolom dalam satu blok', () {
    test('kolom kiri diselesaikan sebelum kolom kanan', () {
      final block = OcrBlockData(
        text: 'kiri satu\nkanan satu\nkiri dua\nkanan dua\nkiri tiga\nkanan tiga',
        boundingBox: const Rect.fromLTWH(0, 0, 400, 120),
        lines: [
          line('kiri satu', 10, 10),
          line('kanan satu', 250, 10),
          line('kiri dua', 10, 50),
          line('kanan dua', 250, 50),
          line('kiri tiga', 10, 90),
          line('kanan tiga', 250, 90),
        ],
      );

      final ordered = OrientationAwareReadingOrder.resolve([block]);

      expect(ordered.single.lines.map((l) => l.text), [
        'kiri satu',
        'kiri dua',
        'kiri tiga',
        'kanan satu',
        'kanan dua',
        'kanan tiga',
      ]);
    });

    test('judul yang membentang mencegah pemisahan kolom', () {
      final block = OcrBlockData(
        text: 'judul lebar\nkiri\nkanan',
        boundingBox: const Rect.fromLTWH(0, 0, 400, 100),
        lines: [
          OcrLineData(
            text: 'judul lebar',
            boundingBox: const Rect.fromLTWH(10, 5, 380, 20),
          ),
          line('kiri', 10, 50),
          line('kanan', 250, 50),
        ],
      );

      final ordered = OrientationAwareReadingOrder.resolve([block]);

      expect(ordered.single.lines.map((l) => l.text), [
        'judul lebar',
        'kiri',
        'kanan',
      ]);
    });
  });
}
