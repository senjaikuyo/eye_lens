import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:eye_lens/features/ocr/services/ocr_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('OCR Device Verification on Emulator Pixel 10a', () {
    late OcrService ocrService;

    setUp(() {
      ocrService = OcrService();
    });

    tearDown(() async {
      await ocrService.dispose();
    });

    testWidgets('1. Tangkapan layar mempertahankan jam dan status bar', (
      tester,
    ) async {
      final byteData = await rootBundle.load(
        'assets/images/test_screenshot.png',
      );
      final bytes = byteData.buffer.asUint8List();
      final result = await ocrService.processImageWithCoordinates(bytes);

      expect(result.fullText.contains('5:51'), isTrue);
      expect(result.fullText.contains('85%'), isTrue);

      // Verifikasi isi konten utama tetap terbaca utuh
      expect(result.fullText.contains('Pemberitahuan Resmi'), isTrue);
      expect(result.fullText.contains('Rapat evaluasi proyek'), isTrue);
    });

    testWidgets(
      '2. Verifikasi dokumen jadwal: jam jadwal dan nomor halaman tetap terbaca utuh',
      (tester) async {
        final byteData = await rootBundle.load(
          'assets/images/test_schedule.png',
        );
        final bytes = byteData.buffer.asUint8List();
        final result = await ocrService.processImageWithCoordinates(bytes);

        // Verifikasi jam pada tabel jadwal TIDAK terbuang
        expect(result.fullText.contains('08:00'), isTrue);
        expect(result.fullText.contains('09:00'), isTrue);
        expect(result.fullText.contains('10:30'), isTrue);
        expect(result.fullText.contains('12:00'), isTrue);
        expect(result.fullText.contains('13:30'), isTrue);

        // Verifikasi kegiatan jadwal terbaca
        expect(result.fullText.contains('JADWAL KEGIATAN'), isTrue);
        expect(result.fullText.contains('Registrasi'), isTrue);
        expect(result.fullText.contains('Diskusi Panel'), isTrue);

        // Verifikasi nomor halaman "12" tetap terbaca
        expect(result.fullText.contains('12'), isTrue);

        // 3. Verifikasi akurasi sorotan kata TTS (TextFormatter allWords alignment)
        final formatted = result.formattedResult;
        expect(formatted, isNotNull);
        expect(formatted!.allWords.isNotEmpty, isTrue);
        for (final word in formatted.allWords) {
          final substring = formatted.fullText.substring(
            word.startIndex,
            word.endIndex,
          );
          expect(substring, equals(word.text));
        }
      },
    );
  });
}
