/// Memecah teks menjadi bagian kecil sebelum dikirim ke mesin TTS.
///
/// Sebagian mesin TTS membatasi panjang teks per permintaan. Pemecahan
/// diutamakan pada batas kalimat/baris, lalu spasi, tanpa membuang karakter.
class TtsTextChunker {
  static const int defaultMaxChars = 3000;

  static List<String> split(String text, {int maxChars = defaultMaxChars}) {
    if (text.trim().isEmpty) return const [];
    if (maxChars < 1) {
      throw ArgumentError.value(maxChars, 'maxChars', 'harus lebih dari 0');
    }

    final chunks = <String>[];
    var start = 0;

    while (start < text.length) {
      var end = start + maxChars;
      if (end > text.length) end = text.length;

      if (end < text.length) {
        final minimumBreak = start + (maxChars * 0.6).floor();

        // Baris baru adalah batas paling aman.
        for (var i = end - 1; i >= minimumBreak; i--) {
          if (text[i] == '\n') {
            end = i + 1;
            break;
          }
        }

        // Lalu akhir kalimat.
        if (end == start + maxChars || end == text.length) {
          for (var i = end - 1; i >= minimumBreak; i--) {
            final ch = text[i];
            final nextIsBoundary =
                i + 1 >= text.length || _isWhitespace(text[i + 1]);
            if ((ch == '.' || ch == '!' || ch == '?') && nextIsBoundary) {
              end = i + 1;
              break;
            }
          }
        }

        // Terakhir, potong pada spasi terdekat.
        if (end == start + maxChars || end == text.length) {
          for (var i = end - 1; i >= minimumBreak; i--) {
            if (_isWhitespace(text[i])) {
              end = i + 1;
              break;
            }
          }
        }
      }

      chunks.add(text.substring(start, end));
      start = end;
    }

    return chunks;
  }

  static bool _isWhitespace(String ch) => ch == ' ' || ch == '\t' || ch == '\n';
}
