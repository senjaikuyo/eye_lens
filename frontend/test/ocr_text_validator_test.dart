import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:eye_lens/core/constants/app_strings.dart';
import 'package:eye_lens/features/ocr/correction/ocr_text_validator.dart';
import 'package:eye_lens/features/ocr/models/ocr_element.dart';

void main() {
  const strings = AppStrings(isIndonesian: true);

  test('empty output produces the no-text alert', () {
    final result = OcrTextValidator.validateResult(OcrResult.empty);
    expect(result.hasText, isFalse);
    expect(result.reason, NoTextReason.rawOcrEmpty);
    expect(result.getAlertTitle(strings), strings.noTextFoundTitle);
    expect(result.getAlertMessage(strings), strings.noTextFoundAlert);
    expect(result.getAlertInstruction(strings), strings.noTextFoundInstruction);
  });

  test('processing failure remains distinct from empty output', () {
    final result = OcrTextValidator.validateResult(OcrResult.failed());
    expect(result.reason, NoTextReason.processingFailed);
    expect(result.getAlertTitle(strings), strings.ocrFailedTitle);
    expect(result.getAlertMessage(strings), strings.ocrFailedAlert);
    expect(result.getAlertInstruction(strings), strings.ocrFailedInstruction);
  });

  for (final text in ['~~~', '___', '...', 'A', '日本語', '  A\t  B  ']) {
    test('nonempty text survives unchanged: $text', () {
      final result = OcrTextValidator.validateResult(
        OcrResult(fullText: text, elements: const [], imageSize: Size.zero),
      );
      expect(result.hasText, isTrue);
      expect(result.text, text);
      expect(result.getAlertMessage(strings), isEmpty);
    });
  }

  test('whitespace-only output is empty', () {
    final result = OcrTextValidator.evaluate(
      rawOcrText: ' \n\t ',
      rawLinesCount: 1,
      filteredText: ' \n\t ',
      acceptedLinesCount: 1,
    );
    expect(result.hasText, isFalse);
  });
}
