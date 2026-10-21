import 'package:flutter/foundation.dart';

import '../core/app_strings.dart';
import '../models/ocr_element.dart';

/// Alasan mengapa sebuah hasil ekstraksi OCR diklasifikasikan sebagai kondisi tanpa teks.
enum NoTextReason {
  /// Teks sah ditemukan (memenuhi syarat minimal 2 karakter alfanumerik).
  none,

  /// Hasil OCR mentah kosong (tidak ada teks atau baris yang terdeteksi dari sensor/gambar).
  rawOcrEmpty,

  /// Seluruh baris teks terbuang oleh filter noise OCR.
  allLinesFiltered,

  /// Teks yang tersisa kurang dari 2 huruf atau angka (kurang dari 2 alfanumerik).
  insufficientAlphanumeric,
}

/// DTO hasil evaluasi kondisi teks pada alur pemindaian OCR.
@immutable
class OcrTextValidationResult {
  /// Apakah ada teks sah yang dapat dibaca dan ditampilkan ke pengguna.
  final bool hasText;

  /// Alasan jika tidak ada teks sah.
  final NoTextReason reason;

  /// Teks akhir yang telah tervalidasi.
  final String text;

  /// Jumlah karakter huruf dan angka (alfanumerik) pada teks akhir.
  final int alphanumericCount;

  const OcrTextValidationResult({
    required this.hasText,
    required this.reason,
    required this.text,
    required this.alphanumericCount,
  });

  /// Mengembalikan pesan peringatan sesuai bahasa aplikasi yang sedang aktif:
  /// - Jika alasan kosongnya adalah semua baris tersaring, menyertakan kalimat "Gambar kurang jelas".
  /// - Untuk kasus kosong lainnya, mengembalikan pesan standar teks tidak ditemukan.
  String getAlertMessage(AppStrings strings) {
    if (hasText) return '';
    if (reason == NoTextReason.allLinesFiltered) {
      return strings.unclearImageNoTextAlert;
    }
    return strings.noTextFoundAlert;
  }
}

/// Pemeriksa kondisi tanpa teks murni (pure function) untuk alur pemindaian kamera & galeri EyeLens.
class OcrTextValidator {
  static final RegExp _alphaNumericRegex = RegExp(r'[a-zA-Z0-9]');

  /// Menghitung jumlah karakter huruf dan angka (alfanumerik) di dalam teks.
  static int countAlphanumeric(String text) {
    if (text.isEmpty) return 0;
    return _alphaNumericRegex.allMatches(text).length;
  }

  /// Mengevaluasi kondisi ada/tidaknya teks berdasarkan teks mentah, baris terfilter, dan jumlah alfanumerik.
  ///
  /// Kriteria kondisi tanpa teks:
  /// 1. Hasil OCR mentah kosong (`rawLinesCount == 0` atau `rawOcrText.trim().isEmpty`).
  /// 2. Seluruh baris terbuang oleh penyaring (`acceptedLinesCount == 0` ketika `rawLinesCount > 0`,
  ///    atau `allLinesFiltered == true`).
  /// 3. Teks yang tersisa kurang dari 2 huruf atau angka (`alphanumericCount < 2`).
  static OcrTextValidationResult evaluate({
    required String rawOcrText,
    required int rawLinesCount,
    required String filteredText,
    required int acceptedLinesCount,
    bool allLinesFiltered = false,
  }) {
    // 1. Periksa apakah OCR mentah kosong
    final trimmedRaw = rawOcrText.trim();
    if (rawLinesCount == 0 || trimmedRaw.isEmpty) {
      return const OcrTextValidationResult(
        hasText: false,
        reason: NoTextReason.rawOcrEmpty,
        text: '',
        alphanumericCount: 0,
      );
    }

    // 2. Periksa apakah seluruh baris terbuang oleh OcrNoiseFilter
    final isAllFiltered = allLinesFiltered ||
        (rawLinesCount > 0 && acceptedLinesCount == 0);
    if (isAllFiltered) {
      return const OcrTextValidationResult(
        hasText: false,
        reason: NoTextReason.allLinesFiltered,
        text: '',
        alphanumericCount: 0,
      );
    }

    // 3. Periksa apakah teks yang tersisa kurang dari 2 huruf atau angka
    final alphaCount = countAlphanumeric(filteredText);
    if (alphaCount < 2) {
      // Jika awalnya ada baris yang tersaring sehingga yang tersisa kurang dari 2 huruf/angka
      final wasFilteredDown = acceptedLinesCount < rawLinesCount || allLinesFiltered;
      return OcrTextValidationResult(
        hasText: false,
        reason: wasFilteredDown
            ? NoTextReason.allLinesFiltered
            : NoTextReason.insufficientAlphanumeric,
        text: filteredText,
        alphanumericCount: alphaCount,
      );
    }

    // 4. Teks sah ditemukan
    return OcrTextValidationResult(
      hasText: true,
      reason: NoTextReason.none,
      text: filteredText,
      alphanumericCount: alphaCount,
    );
  }

  /// Helper untuk mengevaluasi langsung dari objek [OcrResult].
  static OcrTextValidationResult validateResult(OcrResult result) {
    final rawCount = result.rawLinesCount > 0
        ? result.rawLinesCount
        : (result.elements.length + result.rejectedLines.length);

    final rawText = (result.fullText.isNotEmpty || result.elements.isNotEmpty)
        ? result.fullText
        : (result.rejectedLines.isNotEmpty
            ? result.rejectedLines.map((r) => r.line.text).join('\n')
            : '');

    return evaluate(
      rawOcrText: rawText,
      rawLinesCount: rawCount,
      filteredText: result.fullText,
      acceptedLinesCount: result.elements.length,
      allLinesFiltered: result.allLinesFilteredOut ||
          (rawCount > 0 && result.elements.isEmpty),
    );
  }
}
