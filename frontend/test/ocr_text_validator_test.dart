import 'dart:ui';

import 'package:eye_lens/core/app_strings.dart';
import 'package:eye_lens/models/ocr_element.dart';
import 'package:eye_lens/models/text_formatter_models.dart';
import 'package:eye_lens/services/ocr_noise_filter.dart';
import 'package:eye_lens/services/ocr_text_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const indoStrings = AppStrings(isIndonesian: true);
  const engStrings = AppStrings(isIndonesian: false);

  group('OcrTextValidator Tests', () {
    test('1. Kondisi OCR kosong menghasilkan NoTextReason.rawOcrEmpty dan pesan standar', () {
      final result = OcrTextValidator.evaluate(
        rawOcrText: '',
        rawLinesCount: 0,
        filteredText: '',
        acceptedLinesCount: 0,
      );

      expect(result.hasText, isFalse);
      expect(result.reason, equals(NoTextReason.rawOcrEmpty));
      expect(result.alphanumericCount, equals(0));

      // Verifikasi pesan bahasa Indonesia dan Inggris
      expect(
        result.getAlertMessage(indoStrings),
        equals('Teks tidak ditemukan. Arahkan kamera ke teks dan coba lagi.'),
      );
      expect(
        result.getAlertMessage(engStrings),
        equals('No text found. Point the camera at text and try again.'),
      );
    });

    test('2. Kondisi semua baris tersaring menghasilkan NoTextReason.allLinesFiltered dan pesan gambar kurang jelas', () {
      final result = OcrTextValidator.evaluate(
        rawOcrText: '5:51\n85%\n~~~',
        rawLinesCount: 3,
        filteredText: '',
        acceptedLinesCount: 0,
        allLinesFiltered: true,
      );

      expect(result.hasText, isFalse);
      expect(result.reason, equals(NoTextReason.allLinesFiltered));
      expect(result.alphanumericCount, equals(0));

      // Verifikasi penambahan kalimat "Gambar kurang jelas"
      expect(
        result.getAlertMessage(indoStrings),
        equals('Gambar kurang jelas. Teks tidak ditemukan. Arahkan kamera ke teks dan coba lagi.'),
      );
      expect(
        result.getAlertMessage(engStrings),
        equals('Image is unclear. No text found. Point the camera at text and try again.'),
      );
    });

    test('3. Kondisi teks kurang dari 2 karakter huruf atau angka menghasilkan hasText false', () {
      // Kasus A: Hanya 1 huruf
      final singleCharResult = OcrTextValidator.evaluate(
        rawOcrText: 'A',
        rawLinesCount: 1,
        filteredText: 'A',
        acceptedLinesCount: 1,
      );
      expect(singleCharResult.hasText, isFalse);
      expect(singleCharResult.alphanumericCount, equals(1));
      expect(singleCharResult.reason, equals(NoTextReason.insufficientAlphanumeric));
      expect(
        singleCharResult.getAlertMessage(indoStrings),
        equals('Teks tidak ditemukan. Arahkan kamera ke teks dan coba lagi.'),
      );

      // Kasus B: Hanya simbol / tanda baca tanpa huruf dan angka
      final symbolResult = OcrTextValidator.evaluate(
        rawOcrText: '...',
        rawLinesCount: 1,
        filteredText: '...',
        acceptedLinesCount: 1,
      );
      expect(symbolResult.hasText, isFalse);
      expect(symbolResult.alphanumericCount, equals(0));
      expect(symbolResult.reason, equals(NoTextReason.insufficientAlphanumeric));

      // Kasus C: Baris awalnya banyak lalu tersaring hingga tersisa kurang dari 2 karakter
      final filteredDownResult = OcrTextValidator.evaluate(
        rawOcrText: 'Kata pertama\nNoise baris\n1',
        rawLinesCount: 3,
        filteredText: '1',
        acceptedLinesCount: 1,
      );
      expect(filteredDownResult.hasText, isFalse);
      expect(filteredDownResult.alphanumericCount, equals(1));
      expect(filteredDownResult.reason, equals(NoTextReason.allLinesFiltered));
      expect(
        filteredDownResult.getAlertMessage(indoStrings),
        contains('Gambar kurang jelas'),
      );
    });

    test('4. Kondisi teks normal (>= 2 alfanumerik) menghasilkan hasText true', () {
      final normalResult = OcrTextValidator.evaluate(
        rawOcrText: 'Pengumuman Penting',
        rawLinesCount: 1,
        filteredText: 'Pengumuman Penting',
        acceptedLinesCount: 1,
      );

      expect(normalResult.hasText, isTrue);
      expect(normalResult.reason, equals(NoTextReason.none));
      expect(normalResult.alphanumericCount, greaterThanOrEqualTo(2));
      expect(normalResult.text, equals('Pengumuman Penting'));
      expect(normalResult.getAlertMessage(indoStrings), isEmpty);
      expect(normalResult.getAlertMessage(engStrings), isEmpty);
    });

    test('5. Validasi langsung dari objek OcrResult', () {
      // 5a. OcrResult kosong
      final emptyCheck = OcrTextValidator.validateResult(OcrResult.empty);
      expect(emptyCheck.hasText, isFalse);
      expect(emptyCheck.reason, equals(NoTextReason.rawOcrEmpty));

      // 5b. OcrResult dengan baris yang seluruhnya tersaring
      const rejectedLine = RejectedLineInfo(
        line: OcrLineData(
          text: '5:51',
          boundingBox: Rect.fromLTWH(0, 0, 50, 20),
        ),
        reason: NoiseRejectionReason.clockPattern,
        explanation: 'Status bar clock',
      );
      const filteredOcr = OcrResult(
        fullText: '',
        elements: [],
        imageSize: Size(1000, 2000),
        rejectedLines: [rejectedLine],
        allLinesFilteredOut: true,
        rawLinesCount: 1,
      );
      final filteredCheck = OcrTextValidator.validateResult(filteredOcr);
      expect(filteredCheck.hasText, isFalse);
      expect(filteredCheck.reason, equals(NoTextReason.allLinesFiltered));
      expect(filteredCheck.getAlertMessage(indoStrings), contains('Gambar kurang jelas'));

      // 5c. OcrResult normal dengan teks valid
      const validElement = OcrElement(
        id: 'elem_0',
        text: 'Selamat Datang',
        boundingBox: Rect.fromLTWH(100, 100, 200, 30),
      );
      const validOcr = OcrResult(
        fullText: 'Selamat Datang',
        elements: [validElement],
        imageSize: Size(1000, 2000),
        rawLinesCount: 1,
      );
      final validCheck = OcrTextValidator.validateResult(validOcr);
      expect(validCheck.hasText, isTrue);
      expect(validCheck.reason, equals(NoTextReason.none));
      expect(validCheck.text, equals('Selamat Datang'));
    });

    test('6. Verifikasi judul dan petunjuk terpisah untuk alert merah', () {
      final emptyResult = OcrTextValidator.evaluate(
        rawOcrText: '',
        rawLinesCount: 0,
        filteredText: '',
        acceptedLinesCount: 0,
      );

      expect(emptyResult.getAlertTitle(indoStrings), equals('Teks tidak ditemukan'));
      expect(emptyResult.getAlertTitle(engStrings), equals('No text found'));
      expect(
        emptyResult.getAlertInstruction(indoStrings),
        equals('Arahkan kamera ke teks dan coba lagi.'),
      );
      expect(
        emptyResult.getAlertInstruction(engStrings),
        equals('Point the camera at text and try again.'),
      );

      final filteredResult = OcrTextValidator.evaluate(
        rawOcrText: '123',
        rawLinesCount: 1,
        filteredText: '',
        acceptedLinesCount: 0,
        allLinesFiltered: true,
      );

      expect(filteredResult.getAlertTitle(indoStrings), equals('Gambar kurang jelas'));
      expect(filteredResult.getAlertTitle(engStrings), equals('Image is unclear'));
      expect(
        filteredResult.getAlertInstruction(indoStrings),
        equals('Arahkan kamera ke teks dan coba lagi.'),
      );
      expect(
        filteredResult.getAlertInstruction(engStrings),
        equals('Point the camera at text and try again.'),
      );
    });
  });
}
