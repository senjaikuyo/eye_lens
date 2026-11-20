import 'package:eye_lens/features/speech/logic/tts_text_chunker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RC-09 PP-08/UB-06 teks panjang dipecah untuk TTS', () {
    test('teks pendek tidak dipecah', () {
      const text = 'Halo, ini teks pendek.';
      expect(TtsTextChunker.split(text), [text]);
    });

    test('teks panjang dipecah tanpa kehilangan karakter', () {
      final text = List.generate(
        400,
        (i) => 'Kalimat nomor $i menjelaskan hasil pemeriksaan mata.',
      ).join(' ');

      final chunks = TtsTextChunker.split(text, maxChars: 500);

      expect(chunks.length, greaterThan(1));
      expect(chunks.join(), text);
      expect(chunks.every((c) => c.isNotEmpty), isTrue);
      expect(chunks.every((c) => c.length <= 500), isTrue);
    });

    test('pecahan diutamakan pada batas kalimat', () {
      final text =
          '${List.filled(240, 'A').join()}. '
          '${List.filled(240, 'B').join()}.';
      final chunks = TtsTextChunker.split(text, maxChars: 300);

      expect(chunks.first.endsWith('.'), isTrue);
      expect(chunks.join(), text);
    });

    test('kata sangat panjang tetap dipotong agar tidak melebihi batas', () {
      final text = List.filled(900, 'x').join();
      final chunks = TtsTextChunker.split(text, maxChars: 300);

      expect(chunks.length, 3);
      expect(chunks.every((c) => c.length <= 300), isTrue);
      expect(chunks.join(), text);
    });

    test('teks kosong menghasilkan daftar kosong', () {
      expect(TtsTextChunker.split('   '), isEmpty);
    });
  });
}
