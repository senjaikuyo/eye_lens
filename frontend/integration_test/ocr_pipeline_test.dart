import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:eye_lens/services/ocr_service.dart';
import 'package:eye_lens/services/ocr_noise_filter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('OCR Device Verification on Emulator Pixel 10a', () {
    late OcrService ocrService;

    setUp(() {
      ocrService = OcrService();
    });

    testWidgets('1. Verifikasi tangkapan layar status bar: jam dan status bar terbuang', (tester) async {
      final byteData = await rootBundle.load('assets/images/test_screenshot.png');
      final bytes = byteData.buffer.asUint8List();
      final result = await ocrService.processImageWithCoordinates(bytes);

      // Verifikasi baris yang dibuang memuat jam dan status bar
      final hasClockRejected = result.rejectedLines.any(
        (r) => r.reason == NoiseRejectionReason.clockPattern && r.line.text.contains('5:51'),
      );
      final hasStatusBarRejected = result.rejectedLines.any(
        (r) => r.reason == NoiseRejectionReason.statusBarPattern,
      );

      expect(hasClockRejected, isTrue, reason: 'Jam 5:51 di status bar harus terbuang sebagai clockPattern');
      expect(hasStatusBarRejected, isTrue, reason: 'Baterai/sinyal di status bar harus terbuang sebagai statusBarPattern');

      // Verifikasi teks status bar tidak masuk ke teks akhir (fullText)
      expect(result.fullText.contains('5:51'), isFalse);
      expect(result.fullText.contains('85%'), isFalse);

      // Verifikasi isi konten utama tetap terbaca utuh
      expect(result.fullText.contains('Pemberitahuan Resmi'), isTrue);
      expect(result.fullText.contains('Rapat evaluasi proyek'), isTrue);
    });

    testWidgets('2. Verifikasi dokumen jadwal: jam jadwal dan nomor halaman tetap terbaca utuh', (tester) async {
      final byteData = await rootBundle.load('assets/images/test_schedule.png');
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

      // Verifikasi tidak ada jam tabel yang masuk daftar rejectedLines
      final rejectedScheduleHours = result.rejectedLines.where(
        (r) => r.line.text.contains('08:00') ||
               r.line.text.contains('09:00') ||
               r.line.text.contains('10:30'),
      );
      expect(rejectedScheduleHours.isEmpty, isTrue);

      // 3. Verifikasi akurasi sorotan kata TTS (TextFormatter allWords alignment)
      final formatted = result.formattedResult;
      expect(formatted, isNotNull);
      expect(formatted!.allWords.isNotEmpty, isTrue);
      for (final word in formatted.allWords) {
        final substring = formatted.fullText.substring(word.startIndex, word.endIndex);
        expect(substring, equals(word.text));
      }
    });
  });
}
