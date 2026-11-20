import 'package:eye_lens/features/ocr/correction/ocr_text_validator.dart';
import 'package:flutter_test/flutter_test.dart';

OcrTextValidationResult evaluate(String text) => OcrTextValidator.evaluate(
  rawOcrText: text,
  rawLinesCount: 1,
  filteredText: text,
  acceptedLinesCount: 1,
);

void main() {
  group('RC-03 fragmen teks pendek tetap diterima', () {
    test('fragmen harga dan angka pendek diterima', () {
      for (final text in ['Rp 5', '12', '3', 'X7']) {
        expect(evaluate(text).hasText, isTrue, reason: 'Input "$text"');
      }
    });

    test('dua huruf dan karakter tunggal diterima', () {
      for (final text in ['ab', 'd', 'g']) {
        expect(evaluate(text).hasText, isTrue, reason: 'Input "$text"');
      }
    });

    test('kalimat pendek yang bermakna tetap diterima', () {
      for (final text in ['Halo', 'Obat', 'Ya, ambil', 'Rp 5000']) {
        expect(evaluate(text).hasText, isTrue, reason: 'Input "$text"');
      }
    });

    test('teks tanpa alfanumerik ditolak', () {
      for (final text in ['', '   ', '~~~', '---']) {
        expect(evaluate(text).hasText, isFalse, reason: 'Input "$text"');
      }
    });
  });
}
