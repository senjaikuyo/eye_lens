import 'package:eye_lens/features/ocr/correction/ocr_text_validator.dart';
import 'package:flutter_test/flutter_test.dart';

OcrTextValidationResult evaluate(String text) => OcrTextValidator.evaluate(
  rawOcrText: text,
  rawLinesCount: 1,
  filteredText: text,
  acceptedLinesCount: 1,
);

void main() {
  group('RC-03 IS-04/PM-04/PG-03 fragmen bukan teks', () {
    test('fragmen harga "Rp 5" ditolak', () {
      final result = evaluate('Rp 5');

      expect(result.hasText, isFalse);
      expect(result.reason, NoTextReason.insufficientAlphanumeric);
    });

    test('angka pendek dan dua huruf ditolak', () {
      for (final text in ['12', '3', 'ab', 'X7']) {
        expect(evaluate(text).hasText, isFalse, reason: 'Input "$text"');
      }
    });

    test('kalimat pendek yang bermakna tetap diterima', () {
      for (final text in ['Halo', 'Obat', 'Ya, ambil', 'Rp 5000']) {
        expect(evaluate(text).hasText, isTrue, reason: 'Input "$text"');
      }
    });
  });
}
