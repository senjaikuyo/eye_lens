import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:eye_lens/features/ocr/models/ocr_element.dart';
import 'package:eye_lens/models/text_formatter_models.dart';
import 'package:eye_lens/features/ocr/reading_order/ocr_orientation_resolver.dart';
import 'package:eye_lens/features/ocr/preprocessing/ocr_preprocessor.dart';
import 'package:eye_lens/features/ocr/correction/ocr_post_corrector.dart';
import 'package:eye_lens/services/text_formatter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  OcrLineData line(String text, {double? confidence, double? angle}) =>
      OcrLineData(
        text: text,
        boundingBox: const Rect.fromLTWH(10, 20, 30, 40),
        confidence: confidence,
        angle: angle,
      );

  test('portrait retries 180 only; landscape is bounded to three retries', () {
    expect(OcrOrientationResolver.retryAngles(const Size(100, 200)), [180]);
    expect(OcrOrientationResolver.retryAngles(const Size(200, 100)), [
      180,
      90,
      270,
    ]);
    expect(
      OcrOrientationResolver.retryAngles(const Size(200, 100)).length,
      OcrOrientationResolver.maxRetries,
    );
  });
  test('sufficient landscape still checks 180-degree orientation', () {
    expect(
      OcrOrientationResolver.recoveryAngles(
        const Size(200, 100),
        resultSufficient: true,
        verticalCandidate: false,
      ),
      [180],
    );
    expect(
      OcrOrientationResolver.recoveryAngles(
        const Size(200, 100),
        resultSufficient: false,
        verticalCandidate: false,
      ),
      [180, 90, 270],
    );
  });
  test('deterministic score prefers valid words over singleton fragments', () {
    final valid = [line('makanan dan buku')];
    expect(
      OcrOrientationResolver.score(valid),
      greaterThan(
        OcrOrientationResolver.score([line('m a k a n a n d a n b u k u')]),
      ),
    );
    expect(
      OcrOrientationResolver.score(valid),
      OcrOrientationResolver.score(valid),
    );
    expect(
      OcrOrientationResolver.score([line('buku', confidence: 0)]),
      OcrOrientationResolver.score([line('buku')]),
    );
  });
  test('inverse mapping recovers original boxes for every quarter-turn', () {
    const size = Size(100, 200);
    const original = Rect.fromLTWH(10, 20, 30, 40);
    expect(
      OcrOrientationResolver.inverseBox(
        const Rect.fromLTRB(60, 140, 90, 180),
        size,
        180,
      ),
      original,
    );
    expect(
      OcrOrientationResolver.inverseBox(
        const Rect.fromLTRB(140, 10, 180, 40),
        size,
        90,
      ),
      original,
    );
    expect(
      OcrOrientationResolver.inverseBox(
        const Rect.fromLTRB(20, 60, 60, 90),
        size,
        270,
      ),
      original,
    );
    expect(
      () => OcrOrientationResolver.inverseBox(original, size, 45),
      throwsArgumentError,
    );
  });
  test('angle survives correction; null is supported; 180 is evidence', () {
    final l = line('buku', angle: 180);
    final doc = OcrDocumentData(
      blocks: [
        OcrBlockData(text: 'buku', boundingBox: l.boundingBox, lines: [l]),
      ],
      rawText: 'buku',
    );
    expect(
      OcrPostCorrector.correctDocument(doc).blocks.single.lines.single.angle,
      180,
    );
    final result = OcrResult(
      fullText: 'buku',
      elements: const [],
      imageSize: const Size(100, 200),
      rawLines: [l],
    );
    expect(OcrOrientationResolver.angleSuggestsUpsideDown(result), isTrue);
    final mapped = OcrOrientationResolver.mapResult(
      result,
      const Size(100, 200),
      180,
    );
    expect(mapped.rawLines.single.angle, 0);
    expect(OcrOrientationResolver.angleSuggestsUpsideDown(mapped), isFalse);
  });
  test(
    'mapping preserves formatted offsets, word boxes and exclusion lists',
    () {
      final l = line('buku dan makanan', angle: 0);
      final doc = OcrDocumentData(
        blocks: [
          OcrBlockData(text: l.text, boundingBox: l.boundingBox, lines: [l]),
        ],
        rawText: l.text,
      );
      final formatted = TextFormatter.format(doc);
      final mapped = OcrOrientationResolver.mapResult(
        OcrResult(
          fullText: formatted.fullText,
          elements: [
            OcrElement(id: '0', text: l.text, boundingBox: l.boundingBox),
          ],
          imageSize: const Size(100, 200),
          documentData: doc,
          formattedResult: formatted,
          rawLines: [l],
          rawLinesCount: 1,
        ),
        const Size(100, 200),
        180,
      );
      expect(
        mapped.elements.single.boundingBox,
        const Rect.fromLTWH(60, 140, 30, 40),
      );
      expect(mapped.formattedResult, same(formatted));
      for (final word in formatted.allWords) {
        expect(
          mapped.fullText.substring(word.startIndex, word.endIndex),
          word.text,
        );
      }
    },
  );
  test('180-degree coordinate remap does not reverse upright reading text', () {
    final title = OcrLineData(
      text: 'Judul',
      boundingBox: const Rect.fromLTWH(10, 10, 40, 12),
    );
    final body = OcrLineData(
      text: 'Baris pertama',
      boundingBox: const Rect.fromLTWH(10, 30, 80, 12),
    );
    final uprightText = 'Judul\nBaris pertama';
    final mapped = OcrOrientationResolver.mapResult(
      OcrResult(
        fullText: uprightText,
        elements: const [],
        imageSize: const Size(100, 100),
        rawLines: [title, body],
      ),
      const Size(100, 100),
      180,
    );

    expect(mapped.fullText, uprightText);
    expect(mapped.rawLines.map((line) => line.text), [
      'Judul',
      'Baris pertama',
    ]);
    expect(mapped.rawLines.first.boundingBox.top, 78);
    expect(mapped.rawLines.last.boundingBox.top, 58);
  });
  testWidgets(
    'rotation produces swapped dimensions without touching original bytes',
    (tester) async {
      await tester.runAsync(() async {
        final recorder = PictureRecorder();
        Canvas(recorder).drawColor(const Color(0xFFFFFFFF), BlendMode.src);
        final picture = recorder.endRecording();
        final image = await picture.toImage(30, 20);
        final data = await image.toByteData(format: ImageByteFormat.png);
        try {
          for (final degrees in [90, 180, 270]) {
            final rotated = await OcrPreprocessor.rotate(
              data!.buffer.asUint8List(),
              degrees,
            );
            final codec = await instantiateImageCodec(rotated);
            final frame = await codec.getNextFrame();
            expect(frame.image.width, degrees == 180 ? 30 : 20);
            expect(frame.image.height, degrees == 180 ? 20 : 30);
            frame.image.dispose();
            codec.dispose();
          }
        } finally {
          image.dispose();
          picture.dispose();
        }
      });
    },
  );
}
