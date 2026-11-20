import 'package:eye_lens/core/constants/app_strings.dart';
import 'package:eye_lens/features/ocr/correction/ocr_text_validator.dart';
import 'package:eye_lens/features/ocr/models/ocr_element.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RC-14 UB-04/JD-01 kegagalan OCR bukan tanpa teks', () {
    test('hasil gagal membawa tipe kegagalan', () {
      final result = OcrResult.failed(OcrFailureType.timeout);

      expect(result.hasFailure, isTrue);
      expect(result.failureType, OcrFailureType.timeout);
      expect(result.fullText, isEmpty);
    });

    test('validator membedakan kegagalan proses dari gambar tanpa teks', () {
      final result = OcrResult.failed(OcrFailureType.processing);
      final check = OcrTextValidator.validateResult(result);
      const strings = AppStrings(isIndonesian: true);

      expect(check.hasText, isFalse);
      expect(check.reason, NoTextReason.processingFailed);
      expect(check.getAlertTitle(strings), 'Gagal memproses gambar');
      expect(check.getAlertMessage(strings), contains('Coba lagi'));
    });
  });
}
