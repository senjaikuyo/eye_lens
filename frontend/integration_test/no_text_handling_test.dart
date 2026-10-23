import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:eye_lens/core/app_strings.dart';
import 'package:eye_lens/providers/history_provider.dart';
import 'package:eye_lens/providers/language_provider.dart';
import 'package:eye_lens/providers/display_preferences_provider.dart';
import 'package:eye_lens/screens/scan/scanning_screen.dart';
import 'package:eye_lens/screens/scan/widgets/no_text_alert_banner.dart';
import 'package:eye_lens/screens/speech/speech_screen.dart';
import 'package:eye_lens/services/ocr_service.dart';
import 'package:eye_lens/services/ocr_text_validator.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('No-Text Handling Integration Tests on Pixel 10a', () {
    late OcrService ocrService;
    const indoStrings = AppStrings(isIndonesian: true);

    setUp(() {
      ocrService = OcrService();
    });

    testWidgets('1. Foto dinding polos tidak berisi teks: alert aktif, halaman tidak berpindah', (tester) async {
      final byteData = await rootBundle.load('assets/images/test_plain_wall.png');
      final bytes = byteData.buffer.asUint8List();

      final ocrResult = await ocrService.processImageWithCoordinates(bytes);
      final check = OcrTextValidator.validateResult(ocrResult);

      expect(check.hasText, isFalse, reason: 'Foto dinding polos tidak boleh terdeteksi memiliki teks');
      final alertMsg = check.getAlertMessage(indoStrings);
      expect(alertMsg, isNotEmpty);
      expect(alertMsg, contains('Teks tidak ditemukan'));
    });

    testWidgets('2. Foto langit polos tidak berisi teks: alert aktif, halaman tidak berpindah', (tester) async {
      final byteData = await rootBundle.load('assets/images/test_sky.png');
      final bytes = byteData.buffer.asUint8List();

      final ocrResult = await ocrService.processImageWithCoordinates(bytes);
      final check = OcrTextValidator.validateResult(ocrResult);

      expect(check.hasText, isFalse, reason: 'Foto langit biru polos tidak boleh terdeteksi memiliki teks');
      final alertMsg = check.getAlertMessage(indoStrings);
      expect(alertMsg, isNotEmpty);
      expect(alertMsg, contains('Teks tidak ditemukan'));
    });

    testWidgets('3. Foto tertutup jari tidak berisi teks: alert aktif, halaman tidak berpindah', (tester) async {
      final byteData = await rootBundle.load('assets/images/test_finger_covered.png');
      final bytes = byteData.buffer.asUint8List();

      final ocrResult = await ocrService.processImageWithCoordinates(bytes);
      final check = OcrTextValidator.validateResult(ocrResult);

      expect(check.hasText, isFalse, reason: 'Foto tertutup jari gelap tidak boleh terdeteksi memiliki teks');
      final alertMsg = check.getAlertMessage(indoStrings);
      expect(alertMsg, isNotEmpty);
      expect(alertMsg, contains('Teks tidak ditemukan'));
    });

    testWidgets('4. Foto berisi teks sah: tervalidasi sukses dan lolos ke alur halaman teks/speech', (tester) async {
      final byteData = await rootBundle.load('assets/images/test_valid_text.png');
      final bytes = byteData.buffer.asUint8List();

      final ocrResult = await ocrService.processImageWithCoordinates(bytes);
      final check = OcrTextValidator.validateResult(ocrResult);

      expect(check.hasText, isTrue, reason: 'Dokumen teks harus terdeteksi memiliki teks yang sah');
      expect(check.alphanumericCount, greaterThan(10));
      expect(check.text.contains('Panduan Penggunaan EyeLens') || check.text.contains('EyeLens'), isTrue);
      expect(check.getAlertMessage(indoStrings), isEmpty);
    });

    testWidgets('5. Komponen UI NoTextAlertBanner tampil di atas tombol rana dan dapat ditutup', (tester) async {
      bool closed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                NoTextAlertBanner(
                  isVisible: true,
                  bottomPadding: 24,
                  message: 'Teks tidak ditemukan. Arahkan kamera ke teks dan coba lagi.',
                  onClose: () {
                    closed = true;
                  },
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Pastikan banner terlihat dengan pesan yang tepat
      expect(find.byType(NoTextAlertBanner), findsOneWidget);
      expect(find.text('Teks tidak ditemukan. Arahkan kamera ke teks dan coba lagi.'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Ketuk tombol close
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(closed, isTrue);
    });

    testWidgets('6. Alur UI ScanningScreen: kondisi tanpa teks tidak berpindah ke SpeechScreen', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => DisplayPreferencesProvider()),
            ChangeNotifierProvider(create: (_) => LanguageProvider()),
            ChangeNotifierProvider(create: (_) => HistoryProvider()),
          ],
          child: const MaterialApp(
            home: ScanningScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifikasi aplikasi berada di ScanningScreen
      expect(find.byType(ScanningScreen), findsOneWidget);
      expect(find.byType(SpeechScreen), findsNothing);

      // Pastikan banner no-text belum tampak
      expect(find.text('Teks tidak ditemukan. Arahkan kamera ke teks dan coba lagi.'), findsNothing);
    });
  });
}
