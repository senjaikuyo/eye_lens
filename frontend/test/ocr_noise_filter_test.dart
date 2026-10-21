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

    test('7. Semua baris tersaring habis ditandai allLinesFilteredOut tanpa fallback OCR mentah', () {
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

      // Semua baris tersaring harus menghasilkan acceptedLines kosong dan penanda allLinesFilteredOut
      expect(result.acceptedLines.isEmpty, true);
      expect(result.allLinesFilteredOut, true);
      expect(result.hasLowQualityWarning, true);
      expect(result.fallbackUsed, false);
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

    test('9. Jam di zona atas (status bar) harus dibuang', () {
      final lines = [
        const OcrLineData(
          text: '5:51',
          boundingBox: Rect.fromLTWH(50, 20, 80, 25), // Zona atas (y: 20 <= 80px)
        ),
        const OcrLineData(
          text: '05.51',
          boundingBox: Rect.fromLTWH(50, 40, 80, 25), // Zona atas
        ),
        const OcrLineData(
          text: 'Judul Dokumen Resmi',
          boundingBox: Rect.fromLTWH(100, 200, 400, 30),
        ),
      ];

      final result = OcrNoiseFilter.filter(
        lines: lines,
        imageSize: defaultImageSize,
      );

      expect(result.acceptedLines.length, 1);
      expect(result.acceptedLines.first.text, 'Judul Dokumen Resmi');
      expect(result.rejectedLines.length, 2);
      expect(result.rejectedLines[0].reason, NoiseRejectionReason.clockPattern);
      expect(result.rejectedLines[1].reason, NoiseRejectionReason.clockPattern);
    });

    test('10. Persen baterai, nama operator, dan sinyal di zona atas harus dibuang', () {
      final lines = [
        const OcrLineData(
          text: '85%',
          boundingBox: Rect.fromLTWH(850, 20, 60, 25), // Baterai di kanan atas
        ),
        const OcrLineData(
          text: 'Telkomsel 4G',
          boundingBox: Rect.fromLTWH(50, 20, 150, 25), // Operator + sinyal di kiri atas
        ),
        const OcrLineData(
          text: 'LTE',
          boundingBox: Rect.fromLTWH(220, 20, 50, 25), // Sinyal
        ),
        const OcrLineData(
          text: 'Wi-Fi',
          boundingBox: Rect.fromLTWH(280, 20, 60, 25), // Wi-Fi
        ),
        const OcrLineData(
          text: 'Bab 1 Pendahuluan Penelitian',
          boundingBox: Rect.fromLTWH(100, 250, 400, 30),
        ),
      ];

      final result = OcrNoiseFilter.filter(
        lines: lines,
        imageSize: defaultImageSize,
      );

      expect(result.acceptedLines.length, 1);
      expect(result.acceptedLines.first.text, 'Bab 1 Pendahuluan Penelitian');
      expect(result.rejectedLines.length, 4);
      for (final rej in result.rejectedLines) {
        expect(rej.reason, NoiseRejectionReason.statusBarPattern);
      }
    });

    test('11. Jam di dalam tabel jadwal harus tetap lolos', () {
      // Dalam tabel jadwal, jam berdekatan dengan baris kegiatan
      final lines = [
        const OcrLineData(
          text: 'JADWAL ACARA SEMINAR',
          boundingBox: Rect.fromLTWH(100, 200, 400, 30),
        ),
        const OcrLineData(
          text: '08:00',
          boundingBox: Rect.fromLTWH(100, 260, 80, 25),
        ),
        const OcrLineData(
          text: 'Registrasi dan Sarapan Pagi',
          boundingBox: Rect.fromLTWH(200, 260, 300, 25),
        ),
        const OcrLineData(
          text: '09:00',
          boundingBox: Rect.fromLTWH(100, 300, 80, 25),
        ),
        const OcrLineData(
          text: 'Sambutan dan Pembukaan',
          boundingBox: Rect.fromLTWH(200, 300, 300, 25),
        ),
        const OcrLineData(
          text: '10:30',
          boundingBox: Rect.fromLTWH(100, 340, 80, 25),
        ),
        const OcrLineData(
          text: 'Sesi Diskusi Panel',
          boundingBox: Rect.fromLTWH(200, 340, 300, 25),
        ),
      ];

      final result = OcrNoiseFilter.filter(
        lines: lines,
        imageSize: defaultImageSize,
      );

      // Seluruh baris jadwal termasuk jam ("08:00", "09:00", "10:30") harus lolos
      expect(result.acceptedLines.length, 7);
      expect(result.rejectedLines.isEmpty, true);
      expect(result.acceptedLines.any((l) => l.text == '08:00'), true);
      expect(result.acceptedLines.any((l) => l.text == '09:00'), true);
      expect(result.acceptedLines.any((l) => l.text == '10:30'), true);
    });

    test('12. Kalimat yang memuat waktu/jam harus tetap lolos', () {
      final lines = [
        const OcrLineData(
          text: 'Pertemuan akan dimulai pukul 14:30 WIB di ruang rapat utama.',
          boundingBox: Rect.fromLTWH(100, 300, 500, 28),
        ),
        const OcrLineData(
          text: 'Penerbangan dijadwalkan tiba pada 5:51 PM waktu setempat.',
          boundingBox: Rect.fromLTWH(100, 340, 500, 28),
        ),
      ];

      final result = OcrNoiseFilter.filter(
        lines: lines,
        imageSize: defaultImageSize,
      );

      expect(result.acceptedLines.length, 2);
      expect(result.rejectedLines.isEmpty, true);
    });

    test('13. Angka biasa seperti harga atau nomor halaman harus tetap lolos', () {
      final lines = [
        const OcrLineData(
          text: 'Total Belanja:',
          boundingBox: Rect.fromLTWH(100, 200, 200, 28),
        ),
        const OcrLineData(
          text: 'Rp 50.000',
          boundingBox: Rect.fromLTWH(100, 240, 150, 28),
        ),
        const OcrLineData(
          text: '15.99', // Harga desimal bukan waktu
          boundingBox: Rect.fromLTWH(100, 280, 80, 28),
        ),
        const OcrLineData(
          text: '42', // Angka biasa
          boundingBox: Rect.fromLTWH(100, 320, 40, 28),
        ),
        const OcrLineData(
          text: '12', // Nomor halaman di bagian bawah (y: 950 >= 920)
          boundingBox: Rect.fromLTWH(500, 950, 30, 25),
        ),
      ];

      final result = OcrNoiseFilter.filter(
        lines: lines,
        imageSize: defaultImageSize,
      );

      expect(result.acceptedLines.length, 5);
      expect(result.rejectedLines.isEmpty, true);
      expect(result.acceptedLines.any((l) => l.text == 'Rp 50.000'), true);
      expect(result.acceptedLines.any((l) => l.text == '15.99'), true);
      expect(result.acceptedLines.any((l) => l.text == '12'), true);
    });

    test('14. Deteksi tangkapan layar antarmuka memperketat zona tepi', () {
      // 5 baris pendek khas komponen UI
      final screenshotLines = [
        const OcrLineData(
          text: '9:41', // Status bar atas (y: 90 berada di zona 12% tangkapan layar)
          boundingBox: Rect.fromLTWH(40, 90, 60, 20),
        ),
        const OcrLineData(
          text: 'Beranda',
          boundingBox: Rect.fromLTWH(50, 300, 80, 20),
        ),
        const OcrLineData(
          text: 'Profil',
          boundingBox: Rect.fromLTWH(50, 350, 80, 20),
        ),
        const OcrLineData(
          text: 'Pengaturan',
          boundingBox: Rect.fromLTWH(50, 400, 100, 20),
        ),
        const OcrLineData(
          text: 'Keluar',
          boundingBox: Rect.fromLTWH(50, 450, 80, 20),
        ),
      ];

      final result = OcrNoiseFilter.filter(
        lines: screenshotLines,
        imageSize: defaultImageSize,
      );

      // Jam 9:41 di y=90 dibuang karena zona tepi screenshot diperketat (12% = 120px)
      expect(result.rejectedLines.any((r) => r.reason == NoiseRejectionReason.clockPattern), true);
      expect(result.acceptedLines.any((l) => l.text == 'Beranda'), true);
      expect(result.acceptedLines.any((l) => l.text == 'Pengaturan'), true);
    });
  });
}
