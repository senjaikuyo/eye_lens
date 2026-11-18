import 'dart:ui';

import 'package:eye_lens/models/text_formatter_models.dart';
import 'package:eye_lens/services/ocr_dictionary.dart';
import 'package:eye_lens/services/ocr_noise_filter.dart';
import 'package:eye_lens/services/ocr_post_corrector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OcrDictionary Tests', () {
    test('1. contains memvalidasi kata dasar dengan benar', () {
      expect(OcrDictionary.contains('indonesia'), isTrue);
      expect(OcrDictionary.contains('saya'), isTrue);
      expect(OcrDictionary.contains('buku'), isTrue);
      expect(OcrDictionary.contains('xyz999tidakada'), isFalse);
    });

    test(
      '2. isValidWord mengenali afiksasi Bahasa Indonesia secara akurat',
      () {
        // Prefiks di-
        expect(OcrDictionary.isValidWord('diterima'), isTrue);
        expect(OcrDictionary.isValidWord('dibeli'), isTrue);

        // Me- dan nasal
        expect(OcrDictionary.isValidWord('membeli'), isTrue);
        expect(OcrDictionary.isValidWord('menulis'), isTrue);
        expect(OcrDictionary.isValidWord('membaca'), isTrue);
        expect(OcrDictionary.isValidWord('pengiriman'), isTrue);

        // Konfiks ke-...-an, pe-...-an
        expect(OcrDictionary.isValidWord('kebijakan'), isTrue);
        expect(OcrDictionary.isValidWord('pembelian'), isTrue);

        // Sufiks -nya, -kan, -lah
        expect(OcrDictionary.isValidWord('bukunya'), isTrue);
        expect(OcrDictionary.isValidWord('diterimanya'), isTrue);
        expect(OcrDictionary.isValidWord('membacakan'), isTrue);
      },
    );
  });

  group('OcrPostCorrector Unit Tests', () {
    test('3. Mengoreksi kata HURUF BESAR dengan digit ambigu (Issue h)', () {
      expect(
        OcrPostCorrector.correctLine('REPUBLIK INDONES1A'),
        'REPUBLIK INDONESIA',
      );
      expect(
        OcrPostCorrector.correctLine('KABUPATEN BOG0R'),
        'KABUPATEN BOGOR',
      );
      expect(
        OcrPostCorrector.correctLine('PEMER1NTAH PUSAT'),
        'PEMERINTAH PUSAT',
      );
      expect(OcrPostCorrector.correctLine('5ELAMAT DATANG'), 'SELAMAT DATANG');
      expect(OcrPostCorrector.correctLine('H0TEL INDAH'), 'HOTEL INDAH');
    });

    test('4. Mengoreksi kata huruf kecil dan kapitalisasi dengan kamus & morfologi', () {
      expect(
        OcrPostCorrector.correctLine('5aya b1sa membaca'),
        'Saya bisa membaca',
      );
      expect(
        OcrPostCorrector.correctLine('paket telah d1ter1ma'),
        'paket telah diterima',
      );
      expect(
        OcrPostCorrector.correctLine('k0mputer jinjing'),
        'komputer jinjing',
      );
      expect(
        OcrPostCorrector.correctLine('mereka b3lum m4kan'),
        'mereka belum makan',
      );
      expect(
        OcrPostCorrector.correctLine('membawa 8uku tulis'),
        'membawa Buku tulis',
      );
    });

    test('5. Mengoreksi kata pendek khusus Bahasa Indonesia', () {
      expect(
        OcrPostCorrector.correctLine('tinggal d1 kota'),
        'tinggal di kota',
      );
      expect(OcrPostCorrector.correctLine('pergi k3 pasar'), 'pergi ke pasar');
      expect(
        OcrPostCorrector.correctLine('1a adalah dokter'),
        'ia adalah dokter',
      );
    });

    test(
      '6. Mengoreksi kata turunan dengan konfiks yang mengandung OCR noise',
      () {
        expect(
          OcrPostCorrector.correctLine('sesuai kebij4kan kantor'),
          'sesuai kebijakan kantor',
        );
        expect(
          OcrPostCorrector.correctLine('bukti pembel1an sah'),
          'bukti pembelian sah',
        );
        expect(
          OcrPostCorrector.correctLine('status pengir1man cepat'),
          'status pengiriman cepat',
        );
      },
    );

    test('7. Mengoreksi kata Bahasa Inggris', () {
      expect(OcrPostCorrector.correctLine('welcome H0ME'), 'welcome HOME');
      expect(
        OcrPostCorrector.correctLine('display scr33n clear'),
        'display screen clear',
      );
      expect(OcrPostCorrector.correctLine('c4mera device'), 'camera device');
      expect(
        OcrPostCorrector.correctLine('audio v0ice output'),
        'audio voice output',
      );
    });

    test('8. Mengoreksi format mata uang & harga numerik', () {
      expect(
        OcrPostCorrector.correctLine('Total: Rp 5O.OOO'),
        'Total: Rp 50.000',
      );
      expect(
        OcrPostCorrector.correctLine('Biaya: Rp.1O.5OO,-'),
        'Biaya: Rp.10.500,-',
      );
      expect(
        OcrPostCorrector.correctLine('Subtotal Rp2S.OOO'),
        'Subtotal Rp25.000',
      );
      expect(OcrPostCorrector.correctLine('Harga \$ 1O.OO'), 'Harga \$ 10.00');
    });

    test('9. Mengoreksi format waktu, tanggal, dan nomor telepon', () {
      // Waktu
      expect(
        OcrPostCorrector.correctLine('Pukul 12:OO WIB'),
        'Pukul 12:00 WIB',
      );
      expect(OcrPostCorrector.correctLine('Jam O8:3O pagi'), 'Jam 08:30 pagi');
      expect(
        OcrPostCorrector.correctLine('Waktu 14:SO sore'),
        'Waktu 14:50 sore',
      );

      // Tanggal
      expect(
        OcrPostCorrector.correctLine('Tanggal: 1O/12/2O24'),
        'Tanggal: 10/12/2024',
      );
      expect(
        OcrPostCorrector.correctLine('Berlaku: 2S-O8-2O23'),
        'Berlaku: 25-08-2023',
      );

      // Nomor Telepon Indonesia
      expect(
        OcrPostCorrector.correctLine('Telp: O8123456789O'),
        'Telp: 081234567890',
      );
      expect(
        OcrPostCorrector.correctLine('HP: +6281234S6789O'),
        'HP: +6281234567890',
      );
    });

    test('10. Mengoreksi karakter pipa | di awal kata', () {
      expect(
        OcrPostCorrector.correctLine('|ndonesia tanah air'),
        'Indonesia tanah air',
      );
      expect(OcrPostCorrector.correctLine('|bu dan anak'), 'Ibu dan anak');
    });

    test(
      '11. PROTEKSI KETAT: Tidak merusak kode alfanumerik, satuan, dan versi',
      () {
        // Ukuran kertas & format
        expect(
          OcrPostCorrector.correctLine('Kertas A4 dan B5'),
          'Kertas A4 dan B5',
        );
        expect(
          OcrPostCorrector.correctLine('Resolusi 4K dan 3D'),
          'Resolusi 4K dan 3D',
        );
        expect(
          OcrPostCorrector.correctLine('File format MP4 video'),
          'File format MP4 video',
        );
        expect(
          OcrPostCorrector.correctLine('Port USB3 aktif'),
          'Port USB3 aktif',
        );

        // Kecepatan & Satuan fisik
        expect(
          OcrPostCorrector.correctLine('Kecepatan 100km/h berat 50kg'),
          'Kecepatan 100km/h berat 50kg',
        );
        expect(
          OcrPostCorrector.correctLine('Isi 250ml tegangan 12V'),
          'Isi 250ml tegangan 12V',
        );

        // Nomor versi & desimal
        expect(
          OcrPostCorrector.correctLine('revolusi industri 4.0'),
          'revolusi industri 4.0',
        );
      },
    );

    test('12. correctDocument memperbarui teks seluruh blok dan baris dengan koordinat utuh', () {
      final doc = OcrDocumentData(
        blocks: [
          OcrBlockData(
            text: 'REPUBLIK INDONES1A\nTotal Rp 5O.OOO',
            boundingBox: const Rect.fromLTWH(0, 0, 300, 100),
            lines: [
              OcrLineData(
                text: 'REPUBLIK INDONES1A',
                boundingBox: const Rect.fromLTWH(0, 0, 300, 45),
                blockIndex: 0,
              ),
              OcrLineData(
                text: 'Total Rp 5O.OOO',
                boundingBox: const Rect.fromLTWH(0, 50, 300, 45),
                blockIndex: 0,
              ),
            ],
          ),
        ],
        rawText: 'REPUBLIK INDONES1A\nTotal Rp 5O.OOO',
        allRawLines: [
          OcrLineData(
            text: 'REPUBLIK INDONES1A',
            boundingBox: const Rect.fromLTWH(0, 0, 300, 45),
            blockIndex: 0,
          ),
          OcrLineData(
            text: 'Total Rp 5O.OOO',
            boundingBox: const Rect.fromLTWH(0, 50, 300, 45),
            blockIndex: 0,
          ),
        ],
      );

      final corrected = OcrPostCorrector.correctDocument(
        doc,
        scanMode: OcrScanMode.document,
      );

      expect(corrected.blocks.first.lines[0].text, 'REPUBLIK INDONESIA');
      expect(corrected.blocks.first.lines[1].text, 'Total Rp 50.000');
      expect(
        corrected.blocks.first.text,
        'REPUBLIK INDONESIA\nTotal Rp 50.000',
      );
      expect(corrected.rawText, 'REPUBLIK INDONESIA\nTotal Rp 50.000');

      // Koordinat bounding box harus 100% terjaga
      expect(
        corrected.blocks.first.lines[0].boundingBox,
        const Rect.fromLTWH(0, 0, 300, 45),
      );
      expect(
        corrected.blocks.first.lines[1].boundingBox,
        const Rect.fromLTWH(0, 50, 300, 45),
      );
    });
  });
}
