import 'dart:ui';

import 'package:eye_lens/features/ocr/correction/ocr_confidence_gate.dart';
import 'package:eye_lens/features/speech/models/text_formatter_models.dart';
import 'package:flutter_test/flutter_test.dart';

OcrLineData line(String text, double? confidence) => OcrLineData(
  text: text,
  boundingBox: const Rect.fromLTWH(10, 10, 300, 22),
  confidence: confidence,
);

void main() {
  group('RC-02 confidence hanya informasi kualitas', () {
    test('confidence sangat rendah tetap diterima', () {
      final result = OcrConfidenceGate.apply([
        line('Teks sampah hasil OCR', 0.2),
      ]);

      expect(result.acceptedLines, hasLength(1));
      expect(result.quarantinedLines, isEmpty);
      expect(result.hasWarning, isTrue);
    });

    test('confidence 0.30 sampai 0.60 diterima dengan peringatan', () {
      final result = OcrConfidenceGate.apply([line('Teks meragukan', 0.45)]);

      expect(result.acceptedLines, hasLength(1));
      expect(result.quarantinedLines, isEmpty);
      expect(result.hasWarning, isTrue);
    });

    test('confidence tinggi tidak memicu peringatan', () {
      final result = OcrConfidenceGate.apply([line('Teks jelas', 0.9)]);

      expect(result.acceptedLines, hasLength(1));
      expect(result.hasWarning, isFalse);
    });

    test('confidence null dianggap belum diketahui dan memicu peringatan', () {
      final result = OcrConfidenceGate.apply([line('Teks iOS', null)]);

      expect(result.acceptedLines, hasLength(1));
      expect(result.hasWarning, isTrue);
    });

    test('baris buruk dan baik sama-sama lolos tanpa dibuang', () {
      final result = OcrConfidenceGate.apply([
        line('baris buruk', 0.1),
        line('baris baik', 0.8),
      ]);

      expect(result.acceptedLines.map((l) => l.text), [
        'baris buruk',
        'baris baik',
      ]);
      expect(result.quarantinedLines, isEmpty);
      expect(result.hasWarning, isTrue);
    });

    test('daftar kosong tidak menghasilkan peringatan', () {
      final result = OcrConfidenceGate.apply(const []);

      expect(result.acceptedLines, isEmpty);
      expect(result.hasWarning, isFalse);
    });
  });
}
