import '../models/text_formatter_models.dart';

/// Skor deterministik untuk membandingkan hasil OCR dari pass yang berbeda.
/// Skor ini bukan confidence ML Kit dan tidak boleh ditampilkan sebagai akurasi.
class OcrQualityScorer {
  static double scoreLines(Iterable<OcrLineData> lines) {
    var score = 0.0;
    for (final line in lines) {
      final text = line.text.trim();
      if (text.isEmpty) continue;
      final alphaNumeric = RegExp(r'[A-Za-z0-9]').allMatches(text).length;
      final tokens = text.split(RegExp(r'\s+'));
      final plausibleTokens = tokens.where((token) => token.length >= 2).length;
      final singleCharacterTokens = tokens
          .where((token) => token.length == 1)
          .length;

      score += alphaNumeric;
      score += plausibleTokens * 2;
      score -= singleCharacterTokens * 1.5;
      if (line.confidence != null) {
        score += line.confidence! * 5;
      }
    }
    return score;
  }
}
