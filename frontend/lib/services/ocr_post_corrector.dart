import '../models/text_formatter_models.dart';
import 'ocr_dictionary.dart';
import 'ocr_noise_filter.dart';

/// Layanan post-processing OCR untuk mengoreksi karakter ambigu (confusable characters)
/// seperti '0'/'O', '1'/'I'/'l'/'|', '5'/'S', '8'/'B', '2'/'Z', '4'/'A', '3'/'E'.
///
/// Berjalan murni on-device dan offline:
/// 1. Konteks Numerik / Finansial / Waktu / Tanggal / Telepon (huruf ambigu dikoreksi jadi digit):
///    - 'Rp 5O.OOO' -> 'Rp 50.000'
///    - '14:OO' -> '14:00'
///    - '1O/12/2O24' -> '10/12/2024'
///    - 'O8123456789O' -> '081234567890'
/// 2. Konteks Kata / Alfabetik (digit ambigu dikoreksi jadi huruf berdasar kamus & morfologi):
///    - 'INDONES1A' -> 'INDONESIA'
///    - '5aya' -> 'Saya'
///    - 'd1ter1ma' -> 'diterima'
///    - 'k0mputer' -> 'komputer'
///    - 'b1sa' -> 'bisa'
///    - 'b3lum' -> 'belum'
///    - '8uku' -> 'Buku'
/// 3. Proteksi Kode Alfanumerik & Satuan (tidak dirusak):
///    - 'A4', 'B5', 'MP4', '4K', '3D', 'USB3', '100km/h', '50kg', '4.0'
class OcrPostCorrector {
  const OcrPostCorrector._();

  static const Map<String, String> _lettersToDigits = {
    'O': '0',
    'o': '0',
    'I': '1',
    'l': '1',
    '|': '1',
    'i': '1',
    'S': '5',
    's': '5',
    'B': '8',
    'Z': '2',
    'z': '2',
    'G': '6',
  };

  static const Map<String, List<String>> _confusableDigitsToLetters = {
    '0': ['o'],
    '1': ['i', 'l'],
    '2': ['z'],
    '3': ['e'],
    '4': ['a'],
    '5': ['s'],
    '6': ['g', 'b'],
    '8': ['b'],
  };

  static final RegExp _currencyPrefixRegex = RegExp(
    r'^(?:rp[\.]?|idr|\$|usd|eur|€|£|¥)$',
    caseSensitive: false,
  );

  static final RegExp _currencySelfRegex = RegExp(
    r'^(rp[\.]?|idr|\$|usd|eur|€|£|¥)(.*)$',
    caseSensitive: false,
  );

  static final RegExp _unitRegex = RegExp(
    r'^\d+(?:km|kg|ml|m|cm|g|mg|hz|ghz|v|gb|mb|kb)(?:/h)?$',
    caseSensitive: false,
  );

  static final RegExp _punctBoundaryRegex = RegExp(
    r'^([^a-zA-Z0-9]*)(.*?)([^a-zA-Z0-9]*)$',
  );

  /// Memperbaiki teks mentah multi-baris secara menyeluruh.
  static String correctText(String text, {OcrScanMode? scanMode}) {
    if (text.trim().isEmpty) return text;
    final lines = text.split('\n');
    final correctedLines = lines.map((l) => correctLine(l, scanMode: scanMode));
    return correctedLines.join('\n');
  }

  /// Memperbaiki seluruh teks dalam struktur OcrDocumentData (blok dan baris).
  static OcrDocumentData correctDocument(
    OcrDocumentData data, {
    OcrScanMode? scanMode,
  }) {
    if (data.blocks.isEmpty) {
      return OcrDocumentData(
        blocks: const [],
        rawText: correctText(data.rawText, scanMode: scanMode),
        allRawLines: data.allRawLines
            .map(
              (l) => OcrLineData(
                text: correctLine(l.text, scanMode: scanMode),
                boundingBox: l.boundingBox,
                confidence: l.confidence,
                blockIndex: l.blockIndex,
                elements: l.elements,
              ),
            )
            .toList(),
      );
    }

    final List<OcrBlockData> correctedBlocks = [];
    final List<OcrLineData> correctedAllRawLines = [];

    for (final block in data.blocks) {
      final List<OcrLineData> correctedLines = [];
      for (final line in block.lines) {
        final correctedText = correctLine(line.text, scanMode: scanMode);
        final correctedLine = OcrLineData(
          text: correctedText,
          boundingBox: line.boundingBox,
          confidence: line.confidence,
          blockIndex: line.blockIndex,
          elements: line.elements,
        );
        correctedLines.add(correctedLine);
        correctedAllRawLines.add(correctedLine);
      }

      correctedBlocks.add(
        OcrBlockData(
          text: correctedLines.map((l) => l.text).join('\n'),
          boundingBox: block.boundingBox,
          lines: correctedLines,
        ),
      );
    }

    return OcrDocumentData(
      blocks: correctedBlocks,
      rawText: correctText(data.rawText, scanMode: scanMode),
      allRawLines: correctedAllRawLines,
    );
  }

  /// Memperbaiki satu baris teks dengan mempertahankan tokenisasi dan seluruh spasi asli.
  static String correctLine(String line, {OcrScanMode? scanMode}) {
    if (line.trim().isEmpty) return line;

    // Tokenisasi dengan mempertahankan spasi asli persis
    final matches = RegExp(r'\S+|\s+').allMatches(line);
    final buffer = StringBuffer();
    String? prevNonSpaceToken;

    for (final m in matches) {
      final token = m.group(0)!;
      if (token.trim().isEmpty) {
        buffer.write(token);
        continue;
      }

      final corrected = _correctToken(
        token,
        prevToken: prevNonSpaceToken,
        scanMode: scanMode,
      );
      buffer.write(corrected);
      prevNonSpaceToken = corrected;
    }

    return buffer.toString();
  }

  /// Memperbaiki satu token kata atau angka.
  static String _correctToken(
    String token, {
    String? prevToken,
    OcrScanMode? scanMode,
  }) {
    if (token.isEmpty) return token;

    // 1. Cek apakah token merupakan konteks angka/waktu/tanggal/keuangan
    final numericCorrection = _tryCorrectNumericToken(
      token,
      prevToken: prevToken,
    );
    if (numericCorrection != null) {
      return numericCorrection;
    }

    // 2. Cek apakah token merupakan kata alfabetik yang terdistorsi digit
    final wordCorrection = _tryCorrectWordToken(token, scanMode: scanMode);
    if (wordCorrection != null) {
      return wordCorrection;
    }

    return token;
  }

  /// Koreksi token dalam konteks angka (mengubah huruf ambigu menjadi digit).
  static String? _tryCorrectNumericToken(String token, {String? prevToken}) {
    // A. Waktu (misal: "12:OO", "O8:3O", "14:SO")
    final timeMatch = RegExp(
      r'^([0-2OoiI]?\d|[OoiI][0-9OoiI])[:.]([0-5OoSs]\d|[0-5OoSs][OoiI0-9])$',
    ).firstMatch(token);
    if (timeMatch != null) {
      return _replaceLettersWithDigits(token);
    }

    // B. Tanggal (misal: "1O/12/2O24", "2S-O8-2O23")
    final dateMatch = RegExp(
      r'^([0-3OoiISs]?[0-9OoiISs])[/-]([0-1OoiISs]?[0-9OoiISs])[/-]([1-2OoiI][0-9OoiISs]{3})$',
    ).firstMatch(token);
    if (dateMatch != null) {
      return _replaceLettersWithDigits(token);
    }

    // C. Nomor Telepon / NIK Indonesia (diawali O8, 08, +628)
    final isPhonePattern = RegExp(
      r'^(?:[Oo0]8|\+628|628)[0-9OoIilSsBbZz\-\.]{7,13}$',
    ).hasMatch(token);
    if (isPhonePattern) {
      return _replaceLettersWithDigits(token);
    }

    // D. Mata Uang & Format Ribuan / Desimal
    final isPrevCurrency =
        prevToken != null &&
        _currencyPrefixRegex.hasMatch(prevToken.replaceAll('.', ''));

    final currencyMatch = _currencySelfRegex.firstMatch(token);
    final String currencyPrefix = currencyMatch != null
        ? currencyMatch.group(1)!
        : '';
    final String rawAmount = currencyMatch != null
        ? currencyMatch.group(2)!
        : token;

    final hasSeparators = RegExp(r'[.,]').hasMatch(rawAmount);
    final hasDigits = RegExp(r'\d').hasMatch(rawAmount);

    if (isPrevCurrency ||
        currencyPrefix.isNotEmpty ||
        (hasSeparators && hasDigits)) {
      final String converted = _replaceLettersWithDigits(rawAmount);
      // Validasi apakah hasil konversi merupakan pola angka yang valid (misal: "50.000", "10.500,-", "10,50", "4.0")
      if (RegExp(r'^\d+(?:[.,]\d+)*(?:,-|[.,\-])?$').hasMatch(converted)) {
        return currencyPrefix + converted;
      }
    }

    return null;
  }

  /// Koreksi token kata alfabetik (mengubah digit ambigu menjadi huruf sesuai kamus).
  static String? _tryCorrectWordToken(String token, {OcrScanMode? scanMode}) {
    // Ekstraksi tanda baca di awal dan akhir token
    final match = _punctBoundaryRegex.firstMatch(token);
    if (match == null) return null;

    var prefix = match.group(1) ?? '';
    var core = match.group(2) ?? '';
    final suffix = match.group(3) ?? '';

    // Tangani kasus karakter '|' di awal kata yang tertangkap di prefix (misal: "|ndonesia" -> prefix: "|", core: "ndonesia")
    if (prefix.endsWith('|') && core.isNotEmpty) {
      final candWithI = 'I$core';
      if (OcrDictionary.isValidWord(candWithI)) {
        final cleanPrefix = prefix.substring(0, prefix.length - 1);
        return '$cleanPrefix$candWithI$suffix';
      }
    }

    if (core.isEmpty) return null;

    // Proteksi: satuan (misal: "100km/h", "50kg")
    if (_unitRegex.hasMatch(core)) {
      return null;
    }

    // Proteksi: kode pendek <= 2 karakter kecuali pengecualian kata pendek Indonesia
    if (core.length <= 2) {
      final lower = core.toLowerCase();
      if (lower == 'd1') return '${prefix}di$suffix';
      if (lower == 'k3') return '${prefix}ke$suffix';
      if (lower == '1a') return '${prefix}ia$suffix';
      return null; // Melindungi "A4", "4K", "3D", dll.
    }

    // Token harus mengandung huruf DAN digit (atau '|')
    final hasLetters = RegExp(r'[a-zA-Z]').hasMatch(core);
    final hasDigits = RegExp(r'[0-9|]').hasMatch(core);
    if (!hasLetters || !hasDigits) {
      return null;
    }

    // Cari posisi karakter ambigu
    final positions = <int>[];
    for (int i = 0; i < core.length; i++) {
      final ch = core[i];
      if (_confusableDigitsToLetters.containsKey(ch) || ch == '|') {
        positions.add(i);
      }
    }

    // Batasi hingga 3 posisi ambigu untuk mencegah ledakan kombinatorik
    if (positions.isEmpty || positions.length > 3) {
      return null;
    }

    final isAllUpper = core.toUpperCase() == core;
    final isCapitalized = core[0].toUpperCase() == core[0];

    // Bangun daftar kandidat kata
    List<List<String>> candidates = [core.toLowerCase().split('')];
    for (final pos in positions) {
      final ch = core.toLowerCase()[pos];
      final replacements = ch == '|'
          ? const ['i', 'l']
          : (_confusableDigitsToLetters[ch] ?? const []);

      final List<List<String>> nextCandidates = [];
      for (final current in candidates) {
        for (final rep in replacements) {
          final copy = List<String>.from(current);
          copy[pos] = rep;
          nextCandidates.add(copy);
        }
      }
      candidates = nextCandidates;
    }

    // Cari kandidat yang sah dalam kamus
    for (final candList in candidates) {
      final candStr = candList.join();
      if (OcrDictionary.isValidWord(candStr)) {
        final String casedResult;
        if (isAllUpper) {
          casedResult = candStr.toUpperCase();
        } else if (isCapitalized) {
          casedResult = candStr[0].toUpperCase() + candStr.substring(1);
        } else {
          casedResult = candStr;
        }
        return prefix + casedResult + suffix;
      }
    }

    // Fallback heuristik: digit tunggal di antara huruf kecil (misal: d-1-t -> i)
    if (!isAllUpper && core.length >= 3) {
      final chars = core.split('');
      bool modified = false;

      for (int i = 1; i < chars.length - 1; i++) {
        final prev = chars[i - 1];
        final next = chars[i + 1];
        final isSurroundedByAlpha =
            RegExp(r'[a-zA-Z]').hasMatch(prev) &&
            RegExp(r'[a-zA-Z]').hasMatch(next);

        if (isSurroundedByAlpha) {
          final ch = chars[i];
          if (ch == '1') {
            chars[i] = 'i';
            modified = true;
          } else if (ch == '0') {
            chars[i] = 'o';
            modified = true;
          } else if (ch == '3') {
            chars[i] = 'e';
            modified = true;
          } else if (ch == '4') {
            chars[i] = 'a';
            modified = true;
          } else if (ch == '5') {
            chars[i] = 's';
            modified = true;
          }
        }
      }

      if (modified) {
        return prefix + chars.join() + suffix;
      }
    }

    return null;
  }

  static String _replaceLettersWithDigits(String text) {
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final ch = text[i];
      buffer.write(_lettersToDigits[ch] ?? ch);
    }
    return buffer.toString();
  }
}
