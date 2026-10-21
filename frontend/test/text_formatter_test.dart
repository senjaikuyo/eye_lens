import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:eye_lens/models/text_formatter_models.dart';
import 'package:eye_lens/services/text_formatter.dart';

void main() {
  group('TextFormatter Tests', () {
    test('1. De-hyphenation menyambung kata terpotong di akhir baris', () {
      final doc = OcrDocumentData(
        blocks: [
          OcrBlockData(
            text: 'revolu-\nsi industri 4.0',
            boundingBox: const Rect.fromLTWH(50, 100, 300, 60),
            lines: [
              OcrLineData(
                text: 'revolu-',
                boundingBox: const Rect.fromLTWH(50, 100, 300, 25),
              ),
              OcrLineData(
                text: 'si industri 4.0',
                boundingBox: const Rect.fromLTWH(50, 130, 300, 25),
              ),
            ],
          ),
        ],
        rawText: 'revolu-\nsi industri 4.0',
      );

      final result = TextFormatter.format(doc);
      expect(result.paragraphs.length, 1);
      expect(result.fullText, 'revolusi industri 4.0');
      expect(result.paragraphs.first.text, 'revolusi industri 4.0');
    });

    test('2. Menggabungkan baris dalam satu paragraf yang mengalir', () {
      final doc = OcrDocumentData(
        blocks: [
          OcrBlockData(
            text: 'Ini adalah kalimat pertama dari buku ini\nyang mengalir bersambung ke baris kedua.',
            boundingBox: const Rect.fromLTWH(40, 100, 400, 65),
            lines: [
              OcrLineData(
                text: 'Ini adalah kalimat pertama dari buku ini',
                boundingBox: const Rect.fromLTWH(40, 100, 380, 26),
              ),
              OcrLineData(
                text: 'yang mengalir bersambung ke baris kedua.',
                boundingBox: const Rect.fromLTWH(40, 132, 350, 26),
              ),
            ],
          ),
        ],
        rawText: 'Ini adalah kalimat pertama dari buku ini\nyang mengalir bersambung ke baris kedua.',
      );

      final result = TextFormatter.format(doc);
      expect(result.paragraphs.length, 1);
      expect(
        result.fullText,
        'Ini adalah kalimat pertama dari buku ini yang mengalir bersambung ke baris kedua.',
      );
    });

    test('3. Memisahkan paragraf baru jika jarak vertikal > 0.8x tinggi baris', () {
      // Tinggi baris 20. Jarak baris 1 ke baris 2 = 180 - 120 = 60 (> 0.8 * 20 = 16)
      final doc = OcrDocumentData(
        blocks: [
          OcrBlockData(
            text: 'Paragraf pembuka selesai.',
            boundingBox: const Rect.fromLTWH(50, 100, 400, 20),
            lines: [
              OcrLineData(
                text: 'Paragraf pembuka selesai.',
                boundingBox: const Rect.fromLTWH(50, 100, 400, 20),
              ),
            ],
          ),
          OcrBlockData(
            text: 'Paragraf kedua dimulai di sini.',
            boundingBox: const Rect.fromLTWH(50, 180, 400, 20),
            lines: [
              OcrLineData(
                text: 'Paragraf kedua dimulai di sini.',
                boundingBox: const Rect.fromLTWH(50, 180, 400, 20),
              ),
            ],
          ),
        ],
        rawText: 'Paragraf pembuka selesai.\nParagraf kedua dimulai di sini.',
      );

      final result = TextFormatter.format(doc);
      expect(result.paragraphs.length, 2);
      expect(result.fullText, 'Paragraf pembuka selesai.\n\nParagraf kedua dimulai di sini.');
      expect(result.paragraphs[0].text, 'Paragraf pembuka selesai.');
      expect(result.paragraphs[1].text, 'Paragraf kedua dimulai di sini.');
    });

    test('4. Item daftar (angka, bullet) tetap berdiri sendiri satu baris per item', () {
      final doc = OcrDocumentData(
        blocks: [
          OcrBlockData(
            text: '1. Langkah pertama\n2. Langkah kedua\n• Catatan tambahan',
            boundingBox: const Rect.fromLTWH(50, 100, 300, 90),
            lines: [
              OcrLineData(
                text: '1. Langkah pertama',
                boundingBox: const Rect.fromLTWH(50, 100, 300, 24),
              ),
              OcrLineData(
                text: '2. Langkah kedua',
                boundingBox: const Rect.fromLTWH(50, 130, 300, 24),
              ),
              OcrLineData(
                text: '• Catatan tambahan',
                boundingBox: const Rect.fromLTWH(50, 160, 300, 24),
              ),
            ],
          ),
        ],
        rawText: '1. Langkah pertama\n2. Langkah kedua\n• Catatan tambahan',
      );

      final result = TextFormatter.format(doc);
      expect(result.paragraphs.length, 3);
      expect(result.paragraphs[0].isListItem, true);
      expect(result.paragraphs[1].isListItem, true);
      expect(result.paragraphs[2].isListItem, true);
      expect(
        result.fullText,
        '1. Langkah pertama\n\n2. Langkah kedua\n\n• Catatan tambahan',
      );
    });

    test('5. Multi-kolom diurutkan kolom demi kolom dari kiri ke kanan', () {
      // Kolom 1 di X: 40..240, Kolom 2 di X: 300..500
      final doc = OcrDocumentData(
        blocks: [
          // Blok kolom kanan (atas)
          OcrBlockData(
            text: 'Kolom Kanan Baris 1',
            boundingBox: const Rect.fromLTWH(300, 100, 200, 30),
            lines: [
              OcrLineData(
                text: 'Kolom Kanan Baris 1',
                boundingBox: const Rect.fromLTWH(300, 100, 200, 30),
              ),
            ],
          ),
          // Blok kolom kiri (atas)
          OcrBlockData(
            text: 'Kolom Kiri Baris 1',
            boundingBox: const Rect.fromLTWH(40, 100, 200, 30),
            lines: [
              OcrLineData(
                text: 'Kolom Kiri Baris 1',
                boundingBox: const Rect.fromLTWH(40, 100, 200, 30),
              ),
            ],
          ),
          // Blok kolom kiri (bawah)
          OcrBlockData(
            text: 'Kolom Kiri Baris 2',
            boundingBox: const Rect.fromLTWH(40, 140, 200, 30),
            lines: [
              OcrLineData(
                text: 'Kolom Kiri Baris 2',
                boundingBox: const Rect.fromLTWH(40, 140, 200, 30),
              ),
            ],
          ),
        ],
        rawText: 'Kolom Kanan Baris 1\nKolom Kiri Baris 1\nKolom Kiri Baris 2',
      );

      final result = TextFormatter.format(doc);
      // Kolom kiri harus dibaca dulu semua baru kolom kanan
      final firstPara = result.paragraphs.first.text;
      expect(firstPara.contains('Kolom Kiri'), true);
      final lastPara = result.paragraphs.last.text;
      expect(lastPara.contains('Kolom Kanan'), true);
    });

    test('6. Sanitasi noise simbol di tepi baris teks OCR', () {
      final doc = OcrDocumentData(
        blocks: [
          OcrBlockData(
            text: '| Teks bersih di tengah ^',
            boundingBox: const Rect.fromLTWH(50, 100, 300, 30),
            lines: [
              OcrLineData(
                text: '| Teks bersih di tengah ^',
                boundingBox: const Rect.fromLTWH(50, 100, 300, 30),
              ),
            ],
          ),
        ],
        rawText: '| Teks bersih di tengah ^',
      );

      final result = TextFormatter.format(doc);
      expect(result.fullText, 'Teks bersih di tengah');
    });

    test('7. Pemetaan indeks kata dan paragraf persis dan sinkron', () {
      final doc = OcrDocumentData(
        blocks: [
          OcrBlockData(
            text: 'Satu dua tiga',
            boundingBox: const Rect.fromLTWH(50, 100, 200, 25),
            lines: [
              OcrLineData(
                text: 'Satu dua tiga',
                boundingBox: const Rect.fromLTWH(50, 100, 200, 25),
              ),
            ],
          ),
          OcrBlockData(
            text: 'Empat lima',
            boundingBox: const Rect.fromLTWH(50, 200, 200, 25),
            lines: [
              OcrLineData(
                text: 'Empat lima',
                boundingBox: const Rect.fromLTWH(50, 200, 200, 25),
              ),
            ],
          ),
        ],
        rawText: 'Satu dua tiga\nEmpat lima',
      );

      final result = TextFormatter.format(doc);
      final fullText = result.fullText;

      for (final word in result.allWords) {
        final extracted = fullText.substring(word.startIndex, word.endIndex);
        expect(extracted, word.text, reason: 'Word slice harus persis sama');
      }

      for (final para in result.paragraphs) {
        final extracted = fullText.substring(para.startIndex, para.endIndex);
        expect(extracted, para.text, reason: 'Paragraph slice harus persis sama');
      }
    });

    test('8. Fallback teks mentah jika bounding box kosong', () {
      const raw = 'yesterday\ntoday\ntomorrow';
      final result = TextFormatter.formatRawText(raw);

      expect(result.paragraphs.length, 3);
      expect(result.paragraphs[0].text, 'yesterday');
      expect(result.paragraphs[1].text, 'today');
      expect(result.paragraphs[2].text, 'tomorrow');
      expect(result.fullText, 'yesterday\n\ntoday\n\ntomorrow');
    });
  });
}
