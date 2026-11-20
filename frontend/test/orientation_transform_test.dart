import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:eye_lens/features/ocr/models/ocr_element.dart';
import 'package:eye_lens/features/ocr/orientation/orientation_transform.dart';
import 'package:eye_lens/features/ocr/orientation/text_orientation.dart';
import 'package:eye_lens/features/speech/logic/text_formatter.dart';
import 'package:eye_lens/features/speech/models/text_formatter_models.dart';

void main() {
  const size = Size(100, 200);
  const box = Rect.fromLTWH(10, 20, 30, 40);

  group('OrientationTransform.inverseBox', () {
    test('180 memetakan tepat ke koordinat citra asli', () {
      final mapped = OrientationTransform.inverseBox(box, size, 180);
      expect(mapped, Rect.fromLTRB(60, 140, 90, 180));
    });

    test('90 dan 270 menukar sumbu', () {
      expect(
        OrientationTransform.inverseBox(box, size, 90),
        Rect.fromLTRB(20, 160, 60, 190),
      );
      expect(
        OrientationTransform.inverseBox(box, size, 270),
        Rect.fromLTRB(40, 10, 80, 40),
      );
    });

    test('derajat di luar kuartal ditolak', () {
      expect(
        () => OrientationTransform.inverseBox(box, size, 45),
        throwsArgumentError,
      );
    });
  });

  group('OrientationTransform.mapResultBack', () {
    test('T04 urutan disusun ulang setelah pemetaan, teks tidak dibalik', () {
      final small = OcrLineData(
        text: '600 Sheets',
        boundingBox: const Rect.fromLTWH(20, 150, 120, 20),
        orientation: const TextOrientationEstimate(
          orientation: TextOrientation.up,
          confidence: 1,
        ),
      );
      final main = OcrLineData(
        text: 'TISU LEMBUT',
        boundingBox: const Rect.fromLTWH(20, 20, 120, 20),
        orientation: const TextOrientationEstimate(
          orientation: TextOrientation.up,
          confidence: 1,
        ),
      );
      final candidateDoc = OcrDocumentData(
        blocks: [
          OcrBlockData(
            text: '${small.text}\n${main.text}',
            boundingBox: const Rect.fromLTWH(0, 0, 200, 200),
            lines: [small, main],
          ),
        ],
        rawText: '${small.text}\n${main.text}',
      );
      final candidate = OcrResult(
        fullText: '600 Sheets\n\nTISU LEMBUT',
        elements: const [],
        imageSize: const Size(200, 200),
        documentData: candidateDoc,
        formattedResult: TextFormatter.format(candidateDoc),
        rawLines: [small, main],
        rawLinesCount: 2,
      );

      final mapped = OrientationTransform.mapResultBack(
        candidate,
        const Size(200, 200),
        180,
      );

      expect(mapped.imageSize, const Size(200, 200));
      expect(mapped.fullText.contains('TISU LEMBUT'), isTrue);
      expect(
        mapped.fullText.indexOf('TISU LEMBUT'),
        lessThan(mapped.fullText.indexOf('600 Sheets')),
      );
      expect(mapped.formattedResult!.fullText, mapped.fullText);
      expect(mapped.rawLines.first.text, '600 Sheets');
      expect(
        mapped.rawLines.first.orientation!.orientation,
        TextOrientation.upsideDown,
      );
    });

    test('koreksi 270 mengembalikan orientasi 90 pada koordinat asli', () {
      final line = OcrLineData(
        text: 'buku',
        boundingBox: const Rect.fromLTWH(10, 10, 20, 120),
        orientation: const TextOrientationEstimate(
          orientation: TextOrientation.up,
          confidence: 1,
        ),
      );
      final mappedLine = OrientationTransform.mapLineBack(
        line,
        const Size(200, 200),
        270,
      );
      expect(mappedLine.orientation!.orientation, TextOrientation.rotated90);
      expect(mappedLine.text, 'buku');
    });
  });
}
