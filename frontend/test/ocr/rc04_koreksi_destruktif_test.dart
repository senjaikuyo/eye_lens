import 'dart:ui';

import 'package:eye_lens/features/ocr/correction/ocr_dictionary.dart';
import 'package:eye_lens/features/ocr/correction/ocr_post_corrector.dart';
import 'package:eye_lens/features/speech/logic/text_formatter.dart';
import 'package:eye_lens/features/speech/models/text_formatter_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await OcrDictionary.loadFrequencyWords();
  });

  group('RC-04 PP-01/PP-02/OD-02/PG-02 nama dan obat tidak diubah', () {
    test('nama orang tetap sama', () {
      for (final name in ['Rizky', 'Fatimah', 'Nabila']) {
        expect(
          OcrPostCorrector.correctLine(name),
          name,
          reason: 'Nama "$name" tidak boleh diubah koreksi otomatis',
        );
      }
    });

    test('nama obat tetap sama', () {
      for (final drug in ['Prednison', 'Parasetamol']) {
        expect(
          OcrPostCorrector.correctLine(drug),
          drug,
          reason: 'Nama obat "$drug" tidak boleh diubah koreksi otomatis',
        );
      }
    });

    test('kata alfabetik yang tidak ada di kamus tidak ditebak', () {
      expect(OcrPostCorrector.correctLine('clari'), 'clari');
    });

    test('koreksi ganda di formatter tidak mengubah nama', () {
      final doc = OcrDocumentData(
        blocks: [
          OcrBlockData(
            text: 'Prednison 5 mg',
            boundingBox: const Rect.fromLTWH(10, 10, 300, 40),
            lines: const [
              OcrLineData(
                text: 'Prednison 5 mg',
                boundingBox: Rect.fromLTWH(10, 10, 300, 20),
              ),
            ],
          ),
        ],
        rawText: 'Prednison 5 mg',
      );

      expect(TextFormatter.format(doc).fullText, 'Prednison 5 mg');
    });
  });

  group('RC-04 PP-04 angka dan harga tidak diubah', () {
    test('harga bertitik tetap sama', () {
      expect(OcrPostCorrector.correctLine('Rp 12.500'), 'Rp 12.500');
    });

    test('desimal berkoma yang benar tetap sama', () {
      expect(OcrPostCorrector.correctLine('Rp 12,500'), 'Rp 12,500');
    });

    test('huruf O pada desimal tidak dipaksa menjadi nol', () {
      expect(OcrPostCorrector.correctLine('Rp 12,5OO'), 'Rp 12,5OO');
    });

    test('koreksi angka ribuan yang jelas tetap berfungsi', () {
      expect(OcrPostCorrector.correctLine('Rp 5O.OOO'), 'Rp 50.000');
    });

    test('koreksi karakter ambigu pada kata tetap berfungsi', () {
      expect(OcrPostCorrector.correctLine('INDONES1A'), 'INDONESIA');
      expect(OcrPostCorrector.correctLine('d1ter1ma'), 'diterima');
    });
  });
}
