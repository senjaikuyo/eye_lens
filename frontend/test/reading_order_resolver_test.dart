import 'dart:ui';

import 'package:eye_lens/features/speech/models/text_formatter_models.dart';
import 'package:eye_lens/features/ocr/reading_order/reading_order_resolver.dart';
import 'package:eye_lens/features/speech/logic/text_formatter.dart';
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
    test('vertically disjoint groups are not columns', () {
      final ordered = ReadingOrderResolver.resolve([
        block('left lower one', const Rect.fromLTWH(10, 500, 100, 30)),
        block('left lower two', const Rect.fromLTWH(10, 540, 100, 30)),
        block('right upper one', const Rect.fromLTWH(400, 10, 100, 30)),
        block('right upper two', const Rect.fromLTWH(400, 50, 100, 30)),
      ]);
      expect(ordered.map((b) => b.text), [
        'right upper one',
        'right upper two',
        'left lower one',
        'left lower two',
      ]);
    });

    test('formatter never joins hyphenation across block boundaries', () {
      final result = TextFormatter.format(
        OcrDocumentData(
          blocks: [
            block(
              'first',
              const Rect.fromLTWH(100, 100, 200, 20),
              lines: const [
                OcrLineData(
                  text: 'revolu-',
                  boundingBox: Rect.fromLTWH(100, 100, 200, 20),
                ),
              ],
            ),
            block(
              'second',
              const Rect.fromLTWH(100, 125, 200, 20),
              lines: const [
                OcrLineData(
                  text: 'tion',
                  boundingBox: Rect.fromLTWH(100, 125, 200, 20),
                ),
              ],
            ),
          ],
          rawText: '',
        ),
      );
      expect(result.fullText, 'revolu-\n\ntion');
    });
    test('offset cards without repeated column evidence use top then left', () {
      final ordered = ReadingOrderResolver.resolve([
        block('lower left', const Rect.fromLTWH(10, 200, 100, 30)),
        block('upper right', const Rect.fromLTWH(400, 10, 100, 30)),
      ]);
      expect(ordered.map((b) => b.text), ['upper right', 'lower left']);
    });

    test('narrow gutter does not prove columns', () {
      final ordered = ReadingOrderResolver.resolve([
        block('left lower', const Rect.fromLTWH(100, 150, 200, 30)),
        block('right upper', const Rect.fromLTWH(305, 100, 200, 30)),
        block('left upper', const Rect.fromLTWH(100, 100, 200, 30)),
        block('right lower', const Rect.fromLTWH(305, 150, 200, 30)),
      ]);
      expect(ordered.map((b) => b.text), [
        'left upper',
        'right upper',
        'left lower',
        'right lower',
      ]);
    });

    test(
      'spanning title conservatively falls back without inventing columns',
      () {
        final ordered = ReadingOrderResolver.resolve([
          block('right', const Rect.fromLTWH(500, 100, 200, 30)),
          block('title', const Rect.fromLTWH(100, 10, 600, 30)),
          block('left', const Rect.fromLTWH(100, 100, 200, 30)),
        ]);
        expect(ordered.map((b) => b.text), ['title', 'left', 'right']);
      },
    );

    test(
      'formatter finishes each block; highlight offsets survive compute',
      () async {
        final blocks = [
          block(
            'right',
            const Rect.fromLTWH(500, 100, 200, 100),
            lines: [
              const OcrLineData(
                text: 'Right first',
                boundingBox: Rect.fromLTWH(500, 100, 200, 20),
              ),
              const OcrLineData(
                text: 'Right second',
                boundingBox: Rect.fromLTWH(500, 140, 200, 20),
              ),
            ],
          ),
          block(
            'left',
            const Rect.fromLTWH(100, 100, 200, 100),
            lines: [
              const OcrLineData(
                text: 'Left second',
                boundingBox: Rect.fromLTWH(100, 140, 200, 20),
              ),
              const OcrLineData(
                text: 'Left first',
                boundingBox: Rect.fromLTWH(100, 100, 200, 20),
              ),
            ],
          ),
        ];
        final originalOrder = blocks.last.lines.map((l) => l.text).toList();
        final doc = OcrDocumentData(blocks: blocks, rawText: '');
        final result = await TextFormatter.formatWithCompute(doc);
        expect(
          result.fullText.indexOf('Left second'),
          lessThan(result.fullText.indexOf('Right first')),
        );
        expect(
          result.fullText.indexOf('Left first'),
          lessThan(result.fullText.indexOf('Left second')),
        );
        expect(blocks.last.lines.map((l) => l.text), originalOrder);
        for (final word in result.allWords) {
          expect(
            result.fullText.substring(word.startIndex, word.endIndex),
            word.text,
          );
        }
        expect(result.fullText, TextFormatter.format(doc).fullText);
      },
    );

    test('close line tops use deterministic top-first ordering', () {
      final ordered = ReadingOrderResolver.resolve([
        block(
          'card',
          const Rect.fromLTWH(0, 0, 200, 100),
          lines: const [
            OcrLineData(
              text: 'third',
              boundingBox: Rect.fromLTWH(0, 16, 50, 20),
            ),
            OcrLineData(
              text: 'first',
              boundingBox: Rect.fromLTWH(100, 0, 50, 20),
            ),
            OcrLineData(
              text: 'second',
              boundingBox: Rect.fromLTWH(50, 8, 50, 20),
            ),
          ],
        ),
      ]);
      expect(ordered.single.lines.map((l) => l.text), [
        'first',
        'second',
        'third',
      ]);
    });
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
