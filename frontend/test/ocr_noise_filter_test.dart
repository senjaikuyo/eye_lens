import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:eye_lens/models/text_formatter_models.dart';
import 'package:eye_lens/services/ocr_noise_filter.dart';
import 'package:eye_lens/services/text_formatter.dart';

void main() {
  group('OcrNoiseFilter Tests', () {
    const defaultImageSize = Size(1000, 1000);

    test('1. Baris dengan confidence rendah dibuang, sedangkan confidence null dilewati', () {
      final lines = [
        const OcrLineData(
          text: 'Teks utama berkualitas tinggi',
          boundingBox: Rect.fromLTWH(100, 100, 400, 30),
          confidence: 0.95,
        ),
        const OcrLineData(
          text: 'Teks samar-samar tidak yakin',
          boundingBox: Rect.fromLTWH(100, 150, 400, 30),
          confidence: 0.35, // < 0.50
        ),
        const OcrLineData(
          text: 'Teks tanpa data confidence',
          boundingBox: Rect.fromLTWH(100, 200, 400, 30),
          confidence: null, // Harus dilewati tanpa gagal
        ),
      ];

      final result = OcrNoiseFilter.filter(
        lines: lines,
        imageSize: defaultImageSize,
      );

      expect(result.acceptedLines.length, 2);
      expect(result.rejectedLines.length, 1);
      expect(result.rejectedLines.first.reason, NoiseRejectionReason.lowConfidence);
      expect(result.acceptedLines[0].text, 'Teks utama berkualitas tinggi');
      expect(result.acceptedLines[1].text, 'Teks tanpa data confidence');
    });

    test('2. Tulisan sangat kecil di latar belakang (< 40% median) dibuang', () {
      // Median tinggi ~30px. 40% dari 30px = 12px.
      // Baris dengan tinggi 8px harus dibuang.
      final lines = [
        const OcrLineData(
          text: 'Judul Dokumen Utama',
          boundingBox: Rect.fromLTWH(100, 100, 400, 30),
        ),
        const OcrLineData(
          text: 'Isi teks dokumen baris pertama',
          boundingBox: Rect.fromLTWH(100, 140, 400, 30),
        ),
        const OcrLineData(
          text: 'background noise watermark',
          boundingBox: Rect.fromLTWH(100, 180, 200, 8), // 8 < 12
        ),
      ];

      final result = OcrNoiseFilter.filter(
        lines: lines,
        imageSize: defaultImageSize,
      );

      expect(result.acceptedLines.length, 2);
      expect(result.rejectedLines.length, 1);
      expect(result.rejectedLines.first.reason, NoiseRejectionReason.tooSmall);
      expect(result.rejectedLines.first.line.text, 'background noise watermark');
    });

    test('3. Baris terpotong di tepi foto dibuang', () {
      final lines = [
        // Baris normal di tengah
        const OcrLineData(
          text: 'Teks aman di tengah dokumen',
          boundingBox: Rect.fromLTWH(200, 200, 400, 30),
        ),
        // Baris terpotong di tepi kiri (left <= 4)
        const OcrLineData(
          text: 'otong di kiri',
          boundingBox: Rect.fromLTWH(2, 300, 150, 30),
        ),
        // Baris terpotong di tepi kanan (right >= 1000 - 4)
        const OcrLineData(
          text: 'terpotong di kan',
          boundingBox: Rect.fromLTWH(850, 350, 150, 30), // right = 1000
        ),
      ];

      final result = OcrNoiseFilter.filter(
        lines: lines,
        imageSize: defaultImageSize,
      );

      expect(result.acceptedLines.length, 1);
      expect(result.rejectedLines.length, 2);
      expect(result.rejectedLines[0].reason, NoiseRejectionReason.edgeBoundary);
      expect(result.rejectedLines[1].reason, NoiseRejectionReason.edgeBoundary);
      expect(result.acceptedLines.first.text, 'Teks aman di tengah dokumen');
    });

    test('4. Baris pendek yang terpencil jauh dari kelompok utama dibuang', () {
      // Tinggi median = 25. 5x median = 125.
      // Baris 'noise' berjarak 600px dari baris utama.
      final lines = [
        const OcrLineData(
          text: 'Paragraf utama dokumen halaman satu',
          boundingBox: Rect.fromLTWH(100, 100, 400, 25),
        ),
        const OcrLineData(
          text: 'Kelanjutan teks dokumen utama',
          boundingBox: Rect.fromLTWH(100, 130, 400, 25),
        ),
        const OcrLineData(
          text: 'Baris ketiga teks utama',
          boundingBox: Rect.fromLTWH(100, 160, 400, 25),
        ),
        const OcrLineData(
          text: 'artifak',
          boundingBox: Rect.fromLTWH(100, 800, 50, 25), // Jarak > 600px
        ),
      ];

      final result = OcrNoiseFilter.filter(
        lines: lines,
        imageSize: defaultImageSize,
      );

      expect(result.acceptedLines.length, 3);
      expect(result.rejectedLines.length, 1);
      expect(result.rejectedLines.first.reason, NoiseRejectionReason.isolated);
      expect(result.rejectedLines.first.line.text, 'artifak');
    });

    test('5. Simbol acak dan rasio alfanumerik rendah (< 50%) dibuang', () {
      final lines = [
        const OcrLineData(
          text: 'Teks dokumen valid dengan tanda baca standar.',
          boundingBox: Rect.fromLTWH(100, 100, 400, 25),
        ),
        const OcrLineData(
          text: '--- ... ~~~ |',
          boundingBox: Rect.fromLTWH(100, 130, 150, 25),
        ),
        const OcrLineData(
          text: 'a#%*!@&^?~', // 1 huruf dari 10 karakter = 10% alfanumerik
          boundingBox: Rect.fromLTWH(100, 160, 150, 25),
        ),
      ];

      final result = OcrNoiseFilter.filter(
        lines: lines,
        imageSize: defaultImageSize,
      );

      expect(result.acceptedLines.length, 1);
      expect(result.acceptedLines.first.text, 'Teks dokumen valid dengan tanda baca standar.');
      expect(result.rejectedLines.length, 2);
      expect(result.rejectedLines[0].reason, NoiseRejectionReason.symbolOnly);
      expect(result.rejectedLines[1].reason, NoiseRejectionReason.lowAlphaNumericRatio);
    });

    test('6. Pengecualian: kata pendek sah, angka, dan item daftar tidak boleh dibuang', () {
      final lines = [
        const OcrLineData(
          text: 'a',
          boundingBox: Rect.fromLTWH(100, 100, 20, 25),
        ),
        const OcrLineData(
          text: 'I',
          boundingBox: Rect.fromLTWH(100, 130, 20, 25),
        ),
        const OcrLineData(
          text: 'di',
          boundingBox: Rect.fromLTWH(100, 160, 30, 25),
        ),
        const OcrLineData(
          text: 'ke',
          boundingBox: Rect.fromLTWH(100, 190, 30, 25),
        ),
        const OcrLineData(
          text: '42',
          boundingBox: Rect.fromLTWH(100, 220, 40, 25),
        ),
        const OcrLineData(
          text: '1. Poin pertama',
          boundingBox: Rect.fromLTWH(100, 250, 200, 25),
        ),
        const OcrLineData(
          text: '• Item catatan',
          boundingBox: Rect.fromLTWH(100, 280, 200, 25),
        ),
      ];

      final result = OcrNoiseFilter.filter(
        lines: lines,
        imageSize: defaultImageSize,
      );

      // Semua kata sah dan list item harus lolos
      expect(result.acceptedLines.length, 7);
      expect(result.rejectedLines.isEmpty, true);
    });

    test('7. Fallback aktif jika semua baris tersaring habis', () {
      final noisyLines = [
        const OcrLineData(
          text: '~~~',
          boundingBox: Rect.fromLTWH(100, 100, 50, 25),
        ),
        const OcrLineData(
          text: '|',
          boundingBox: Rect.fromLTWH(100, 130, 20, 25),
        ),
      ];

      final result = OcrNoiseFilter.filter(
        lines: noisyLines,
        imageSize: defaultImageSize,
      );

      // Fallback harus menyertakan baris asli dan menandai warning
      expect(result.fallbackUsed, true);
      expect(result.hasLowQualityWarning, true);
      expect(result.acceptedLines.length, 2);
    });

    test('8. Filter terintegrasi dengan TextFormatter menjaga akurasi sorotan TTS', () {
      // Gabungkan tulisan utama di tengah dengan noise tepi dan simbol
      final lines = [
        const OcrLineData(
          text: 'Potongan di tepi',
          boundingBox: Rect.fromLTWH(0, 50, 120, 25), // Noise tepi
        ),
        const OcrLineData(
          text: 'Buku ini mengajarkan kita tentang',
          boundingBox: Rect.fromLTWH(100, 100, 400, 25),
        ),
        const OcrLineData(
          text: 'pentingnya membaca dengan nyaman.',
          boundingBox: Rect.fromLTWH(100, 130, 400, 25),
        ),
        const OcrLineData(
          text: '--- ^^^',
          boundingBox: Rect.fromLTWH(100, 200, 100, 25), // Simbol
        ),
      ];

      final filterResult = OcrNoiseFilter.filter(
        lines: lines,
        imageSize: defaultImageSize,
      );

      expect(filterResult.acceptedLines.length, 2);
      expect(filterResult.rejectedLines.length, 2);

      // Teruskan hanya baris yang lolos ke TextFormatter
      final doc = OcrDocumentData(
        blocks: [
          OcrBlockData(
            text: 'Buku ini mengajarkan kita tentang\npentingnya membaca dengan nyaman.',
            boundingBox: const Rect.fromLTWH(100, 100, 400, 60),
            lines: filterResult.acceptedLines,
          ),
        ],
        rawText: 'Buku ini mengajarkan kita tentang\npentingnya membaca dengan nyaman.',
      );

      final formatted = TextFormatter.format(doc);
      expect(
        formatted.fullText,
        'Buku ini mengajarkan kita tentang pentingnya membaca dengan nyaman.',
      );

      // Verifikasi seluruh indeks kata akurat
      for (final word in formatted.allWords) {
        final slice = formatted.fullText.substring(word.startIndex, word.endIndex);
        expect(slice, word.text);
      }
    });
  });
}
