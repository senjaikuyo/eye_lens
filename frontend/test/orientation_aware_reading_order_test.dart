import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:eye_lens/features/ocr/orientation/orientation_aware_reading_order.dart';
import 'package:eye_lens/features/ocr/orientation/text_orientation.dart';
import 'package:eye_lens/features/speech/models/text_formatter_models.dart';

OcrLineData oriented(
  String text,
  Rect box,
  TextOrientation orientation, {
  double confidence = 1,
}) => OcrLineData(
  text: text,
  boundingBox: box,
  orientation: TextOrientationEstimate(
    orientation: orientation,
    confidence: confidence,
    evidence: const ['test'],
  ),
);

OcrBlockData block(String name, Rect box, List<OcrLineData> lines) =>
    OcrBlockData(text: name, boundingBox: box, lines: lines);

List<String> texts(List<OcrBlockData> blocks) =>
    blocks.expand((b) => b.lines).map((l) => l.text).toList();

void main() {
  group('OrientationAwareReadingOrder - T01/T02/T07/T08/T11', () {
    test('T01 portrait normal dibaca atas ke bawah', () {
      final result = OrientationAwareReadingOrder.resolve([
        block('doc', const Rect.fromLTWH(0, 0, 200, 100), [
          oriented('judul', const Rect.fromLTWH(10, 10, 180, 20), TextOrientation.up),
          oriented('isi', const Rect.fromLTWH(10, 50, 180, 20), TextOrientation.up),
        ]),
      ]);
      expect(texts(result), ['judul', 'isi']);
    });

    test('T02 landscape normal tidak dibalik urutannya', () {
      final result = OrientationAwareReadingOrder.resolve([
        block('doc', const Rect.fromLTWH(0, 0, 500, 120), [
          oriented('baris satu', const Rect.fromLTWH(20, 10, 460, 24), TextOrientation.up),
          oriented('baris dua', const Rect.fromLTWH(20, 60, 460, 24), TextOrientation.up),
        ]),
      ]);
      expect(texts(result), ['baris satu', 'baris dua']);
    });

    test('T07 banyak blok mengikuti posisi searah baca', () {
      final result = OrientationAwareReadingOrder.resolve([
        block('bawah', const Rect.fromLTWH(10, 110, 180, 20), [
          oriented('bawah', const Rect.fromLTWH(10, 110, 180, 20), TextOrientation.up),
        ]),
        block('atas', const Rect.fromLTWH(10, 10, 180, 20), [
          oriented('atas', const Rect.fromLTWH(10, 10, 180, 20), TextOrientation.up),
        ]),
        block('tengah', const Rect.fromLTWH(10, 60, 180, 20), [
          oriented('tengah', const Rect.fromLTWH(10, 60, 180, 20), TextOrientation.up),
        ]),
      ]);
      expect(texts(result), ['atas', 'tengah', 'bawah']);
    });

    test('T08 ukuran berbeda tidak mengubah urutan kiri-ke-kanan', () {
      final result = OrientationAwareReadingOrder.resolve([
        block('doc', const Rect.fromLTWH(0, 0, 400, 100), [
          oriented('kecil', const Rect.fromLTWH(10, 40, 60, 16), TextOrientation.up),
          oriented('besar', const Rect.fromLTWH(120, 30, 240, 40), TextOrientation.up),
        ]),
      ]);
      expect(texts(result), ['kecil', 'besar']);
    });

    test('T11 teks utama sebelum informasi pendukung', () {
      final result = OrientationAwareReadingOrder.resolve([
        block('kemasan', const Rect.fromLTWH(0, 0, 400, 160), [
          oriented('600 Sheets', const Rect.fromLTWH(20, 70, 120, 18), TextOrientation.up),
          oriented('2 ply', const Rect.fromLTWH(20, 110, 80, 18), TextOrientation.up),
          oriented('TISU LEMBUT', const Rect.fromLTWH(20, 10, 300, 44), TextOrientation.up),
        ]),
      ]);
      expect(texts(result), ['TISU LEMBUT', '600 Sheets', '2 ply']);
    });

    test('string asli tidak dibalik atau diubah', () {
      const original = 'high of joy';
      final result = OrientationAwareReadingOrder.resolve([
        block('doc', const Rect.fromLTWH(0, 0, 200, 50), [
          oriented(original, const Rect.fromLTWH(10, 10, 180, 20), TextOrientation.up),
        ]),
      ]);
      expect(texts(result).single, original);
    });
  });

  group('OrientationAwareReadingOrder - T03/T04/T05/T06/T09', () {
    test('T03 rotasi 90 dibaca searah baseline ke bawah', () {
      final result = OrientationAwareReadingOrder.resolve([
        block('doc', const Rect.fromLTWH(0, 0, 200, 200), [
          oriented('kanan', const Rect.fromLTWH(100, 10, 20, 150), TextOrientation.rotated90),
          oriented('kiri', const Rect.fromLTWH(60, 10, 20, 150), TextOrientation.rotated90),
        ]),
      ]);
      expect(texts(result), ['kanan', 'kiri']);
    });

    test('T04 rotasi 180 dibaca dari arah teks, bukan koordinat gambar', () {
      final result = OrientationAwareReadingOrder.resolve([
        block('doc', const Rect.fromLTWH(0, 0, 300, 160), [
          oriented('600 Sheets', const Rect.fromLTWH(20, 20, 160, 18), TextOrientation.upsideDown),
          oriented('TISU LEMBUT', const Rect.fromLTWH(20, 100, 260, 30), TextOrientation.upsideDown),
        ]),
      ]);
      expect(texts(result), ['TISU LEMBUT', '600 Sheets']);
    });

    test('T05 rotasi 270 dibaca searah baseline ke atas', () {
      final result = OrientationAwareReadingOrder.resolve([
        block('doc', const Rect.fromLTWH(0, 0, 200, 200), [
          oriented('kanan', const Rect.fromLTWH(100, 10, 20, 150), TextOrientation.rotated270),
          oriented('kiri', const Rect.fromLTWH(60, 10, 20, 150), TextOrientation.rotated270),
        ]),
      ]);
      expect(texts(result), ['kiri', 'kanan']);
    });

    test('T06 landscape terbalik memakai arah teks 180', () {
      final result = OrientationAwareReadingOrder.resolve([
        block('doc', const Rect.fromLTWH(0, 0, 500, 160), [
          oriented('2 ply', const Rect.fromLTWH(30, 20, 100, 16), TextOrientation.upsideDown),
          oriented('JUDUL UTAMA', const Rect.fromLTWH(30, 110, 420, 30), TextOrientation.upsideDown),
        ]),
      ]);
      expect(texts(result), ['JUDUL UTAMA', '2 ply']);
    });

    test('T09 blok orientasi berbeda dianalisis terpisah, dominan lebih dulu', () {
      final result = OrientationAwareReadingOrder.resolve([
        block('vertikal', const Rect.fromLTWH(10, 10, 30, 150), [
          oriented('vertikal', const Rect.fromLTWH(10, 10, 30, 150), TextOrientation.rotated90),
        ]),
        block('utama', const Rect.fromLTWH(60, 200, 300, 30), [
          oriented('utama', const Rect.fromLTWH(60, 200, 300, 30), TextOrientation.up),
          oriented('pendukung', const Rect.fromLTWH(60, 240, 200, 20), TextOrientation.up),
        ]),
      ]);
      expect(texts(result), ['utama', 'pendukung', 'vertikal']);
    });
  });
}
