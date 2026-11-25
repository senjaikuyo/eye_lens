import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:eye_lens/features/ocr/orientation/orientation_aware_reading_order.dart';
import 'package:eye_lens/features/ocr/orientation/text_orientation.dart';
import 'package:eye_lens/features/speech/logic/text_formatter.dart';
import 'package:eye_lens/features/speech/models/text_formatter_models.dart';

OcrLineData line(
  String text,
  Rect box, {
  double confidence = 0.9,
  TextOrientation orientation = TextOrientation.up,
}) => OcrLineData(
  text: text,
  boundingBox: box,
  confidence: confidence,
  orientation: TextOrientationEstimate(
    orientation: orientation,
    confidence: 1,
    evidence: const ['test'],
  ),
);

OcrLineData glyph(String text, double left, double top, {double? confidence}) =>
    line(text, Rect.fromLTWH(left, top, 15, 20), confidence: confidence ?? 0.9);

OcrBlockData block(String text, List<OcrLineData> lines) => OcrBlockData(
  text: text,
  boundingBox: lines
      .map((l) => l.boundingBox)
      .reduce((a, b) => a.expandToInclude(b)),
  lines: lines,
);

List<String> texts(List<OcrBlockData> blocks) =>
    blocks.expand((b) => b.lines).map((l) => l.text).toList();

void main() {
  group('Teks vertikal', () {
    test('karakter vertikal tetap individual dan tidak digabung', () {
      final column = [
        glyph('d', 120, 100),
        glyph('o', 120, 130),
        glyph('r', 120, 160),
        glyph('n', 120, 190),
        glyph('g', 120, 220),
      ];
      final formatted = TextFormatter.format(
        OcrDocumentData(
          blocks: [block('d\no\nr\nn\ng', column)],
          rawText: 'd\no\nr\nn\ng',
        ),
      );

      expect(formatted.allWords.map((w) => w.text), ['d', 'o', 'r', 'n', 'g']);
      for (final word in formatted.allWords) {
        expect(word.text.length, 1);
      }
    });

    test('teks vertikal kecil tetap terbaca sebagai karakter', () {
      final column = [
        for (var i = 0; i < 4; i++)
          line(
            'buku'[i],
            Rect.fromLTWH(200, 300 + i * 7.5, 6, 6),
            confidence: 0.2,
          ),
      ];
      final formatted = TextFormatter.format(
        OcrDocumentData(blocks: [block('BUKU', column)], rawText: 'BUKU'),
      );
      expect(formatted.allWords.map((w) => w.text), ['b', 'u', 'k', 'u']);
    });

    test('karakter tunggal berdiri sendiri tetap ditampilkan', () {
      final formatted = TextFormatter.format(
        OcrDocumentData(
          blocks: [
            block('g', [glyph('g', 50, 400)]),
          ],
          rawText: 'g',
        ),
      );
      expect(formatted.fullText.trim(), 'g');
    });

    test('confidence rendah tetap masuk hasil dan TTS', () {
      final formatted = TextFormatter.format(
        OcrDocumentData(
          blocks: [
            block('Teks buram', [
              line(
                'Teks buram',
                const Rect.fromLTWH(10, 10, 200, 22),
                confidence: 0.05,
              ),
            ]),
          ],
          rawText: 'Teks buram',
        ),
      );
      expect(formatted.fullText, contains('Teks buram'));
    });
  });

  group('Horizontal dan vertikal bersama', () {
    test('blok horizontal dan vertikal dipisah, urut posisi visual', () {
      final blocks = [
        block('d\no\nr\nn\ng', [
          glyph('d', 300, 100),
          glyph('o', 300, 140),
          glyph('r', 300, 180),
          glyph('n', 300, 220),
          glyph('g', 300, 260),
        ]),
        block('Judul halaman', [
          line('Judul halaman', const Rect.fromLTWH(40, 40, 220, 24)),
        ]),
      ];
      final resolved = OrientationAwareReadingOrder.resolve(blocks);
      expect(texts(resolved), ['Judul halaman', 'd', 'o', 'r', 'n', 'g']);

      final formatted = TextFormatter.format(
        OcrDocumentData(
          blocks: blocks,
          rawText: 'Judul halaman\nd\no\nr\nn\ng',
        ),
      );
      expect(formatted.allWords.map((w) => w.text), [
        'Judul',
        'halaman',
        'd',
        'o',
        'r',
        'n',
        'g',
      ]);
    });

    test('teks vertikal di samping teks horizontal tidak saling hilang', () {
      final blocks = [
        block('Arahkan kamera ke teks', [
          line('Arahkan kamera ke teks', const Rect.fromLTWH(60, 300, 400, 26)),
        ]),
        block('B\nU\nK\nU', [
          glyph('B', 20, 60),
          glyph('U', 20, 100),
          glyph('K', 20, 140),
          glyph('U', 20, 180),
        ]),
      ];
      final resolved = OrientationAwareReadingOrder.resolve(blocks);
      expect(texts(resolved).take(4), ['B', 'U', 'K', 'U']);
      expect(texts(resolved).last, 'Arahkan kamera ke teks');
    });

    test('noise yang benar-benar tidak terbaca tetap tersaring', () {
      final formatted = TextFormatter.format(
        OcrDocumentData(
          blocks: [
            block('Teks sah', [
              line('Teks sah', const Rect.fromLTWH(10, 10, 120, 22)),
            ]),
          ],
          rawText: 'Teks sah',
        ),
      );
      expect(formatted.fullText, 'Teks sah');
    });
  });

  group('Urutan TTS', () {
    test('TTS menerima urutan visual horizontal lalu karakter vertikal', () {
      final formatted = TextFormatter.format(
        OcrDocumentData(
          blocks: [
            block('Langkah 1', [
              line('Langkah 1', const Rect.fromLTWH(40, 40, 200, 24)),
            ]),
            block('sign', [
              glyph('s', 320, 100),
              glyph('i', 320, 130),
              glyph('g', 320, 160),
              glyph('n', 320, 190),
            ]),
            block('Langkah 2', [
              line('Langkah 2', const Rect.fromLTWH(40, 260, 200, 24)),
            ]),
          ],
          rawText: 'Langkah 1\nLangkah 2',
        ),
      );

      final spoken = formatted.paragraphs.map((p) => p.text).toList();
      expect(spoken.first, 'Langkah 1');
      expect(spoken.last, 's\ni\ng\nn');
      expect(spoken, contains('Langkah 2'));
      expect(
        formatted.allWords
            .where((w) => const {'s', 'i', 'g', 'n'}.contains(w.text))
            .map((w) => w.text),
        ['s', 'i', 'g', 'n'],
      );
      // Setiap kata memiliki indeks karakter yang konsisten dengan fullText.
      for (final word in formatted.allWords) {
        expect(
          formatted.fullText.substring(word.startIndex, word.endIndex),
          word.text,
        );
      }
    });
  });
}
