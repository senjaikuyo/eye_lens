import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:eye_lens/features/speech/logic/text_formatter.dart';
import 'package:eye_lens/features/speech/models/text_formatter_models.dart';

void main() {
  void checkIndices(FormattedTextResult result) {
    for (final word in result.allWords) {
      expect(
        result.fullText.substring(word.startIndex, word.endIndex),
        word.text,
      );
    }
    for (final paragraph in result.paragraphs) {
      expect(
        result.fullText.substring(paragraph.startIndex, paragraph.endIndex),
        paragraph.text,
      );
    }
  }

  test(
    'raw fallback preserves whitespace, blank lines, symbols and hyphens',
    () {
      const text = '\n  ~~A\t  B__  \n\nrevolu-\nsi\n';
      final result = TextFormatter.formatRawText(text);
      expect(result.fullText, text);
      checkIndices(result);
    },
  );

  test('positioned lines preserve symbols and internal/edge whitespace', () {
    const text = '  | A\t  B ^  ';
    const box = Rect.fromLTWH(10, 10, 300, 30);
    final result = TextFormatter.format(
      const OcrDocumentData(
        rawText: text,
        blocks: [
          OcrBlockData(
            text: text,
            boundingBox: box,
            lines: [OcrLineData(text: text, boundingBox: box)],
          ),
        ],
      ),
    );
    expect(result.fullText, text);
    expect(result.allWords.map((word) => word.text), ['|', 'A', 'B', '^']);
    checkIndices(result);
  });
}
