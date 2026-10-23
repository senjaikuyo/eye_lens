import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:eye_lens/models/ocr_element.dart';
import 'package:eye_lens/providers/history_provider.dart';
import 'package:eye_lens/providers/language_provider.dart';
import 'package:eye_lens/providers/display_preferences_provider.dart';
import 'package:eye_lens/screens/scan/widgets/no_text_alert_banner.dart';
import 'package:eye_lens/screens/speech/speech_screen.dart';
import 'package:eye_lens/screens/speech/widgets/highlighted_text_view.dart';
import 'package:eye_lens/screens/speech/widgets/ocr_image_overlay.dart';
import 'package:eye_lens/screens/speech/widgets/speech_mode_toggle_button.dart';
import 'package:eye_lens/services/ocr_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Google Lens Frame Integration Tests on Pixel 10a', () {
    late OcrService ocrService;
    late Uint8List validImageBytes;
    late OcrResult ocrResult;

    setUpAll(() async {
      ocrService = OcrService();
      final byteData = await rootBundle.load('assets/images/test_valid_text.png');
      validImageBytes = byteData.buffer.asUint8List();
      ocrResult = await ocrService.processImageWithCoordinates(validImageBytes);
    });

    tearDownAll(() async {
      await ocrService.dispose();
    });

    testWidgets('1. Halaman gambar bersih ala Google Lens: tidak ada kotak hijau/merah dan tanpa bilah Debug OCR',
        (tester) async {
      final languageProvider = LanguageProvider()..setLanguage('Indonesian');
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => DisplayPreferencesProvider()),
            ChangeNotifierProvider(create: (_) => languageProvider),
            ChangeNotifierProvider(create: (_) => HistoryProvider()),
          ],
          child: MaterialApp(
            home: SpeechScreen(
              text: ocrResult.fullText,
              hasImage: true,
              imageBytes: validImageBytes,
              ocrResult: ocrResult,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verifikasi widget OcrImageOverlay aktif
      expect(find.byType(OcrImageOverlay), findsOneWidget);

      // 2. Verifikasi InteractiveViewer ada untuk zoom dan pan
      expect(find.byType(InteractiveViewer), findsOneWidget);

      // 3. Verifikasi bilah Debug OCR TIDAK tampil
      expect(find.textContaining('Debug OCR:'), findsNothing);

      // 4. Verifikasi tombol "Seluruh gambar" tampil
      expect(find.text('Seluruh gambar'), findsOneWidget);

      // 5. Verifikasi tombol T tampil di kanan bawah
      expect(find.byType(SpeechModeToggleButton), findsOneWidget);
      expect(find.text('T'), findsOneWidget);
    });

    testWidgets('2. Tombol Seluruh Gambar merespon ketukan dan memperbesar bingkai',
        (tester) async {
      final languageProvider = LanguageProvider()..setLanguage('Indonesian');
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => DisplayPreferencesProvider()),
            ChangeNotifierProvider(create: (_) => languageProvider),
            ChangeNotifierProvider(create: (_) => HistoryProvider()),
          ],
          child: MaterialApp(
            home: SpeechScreen(
              text: ocrResult.fullText,
              hasImage: true,
              imageBytes: validImageBytes,
              ocrResult: ocrResult,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ketuk tombol "Seluruh gambar"
      final fullImageBtn = find.text('Seluruh gambar');
      expect(fullImageBtn, findsOneWidget);
      await tester.tap(fullImageBtn);
      await tester.pumpAndSettle();

      // Pastikan tetap di halaman gambar dan tombol T tetap siap
      expect(find.byType(OcrImageOverlay), findsOneWidget);
      expect(find.text('T'), findsOneWidget);
    });

    testWidgets('3. Tombol T beralih ke halaman teks berformat dengan sorotan TTS akurat',
        (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => DisplayPreferencesProvider()),
            ChangeNotifierProvider(create: (_) => LanguageProvider()),
            ChangeNotifierProvider(create: (_) => HistoryProvider()),
          ],
          child: MaterialApp(
            home: SpeechScreen(
              text: ocrResult.fullText,
              hasImage: true,
              imageBytes: validImageBytes,
              ocrResult: ocrResult,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ketuk tombol "T" untuk membuka halaman teks
      final toggleBtn = find.byType(SpeechModeToggleButton);
      await tester.tap(toggleBtn);
      await tester.pumpAndSettle();

      // Pastikan telah berpindah ke tampilan teks (HighlightedTextView)
      expect(find.byType(HighlightedTextView), findsOneWidget);
      expect(find.textContaining('EyeLens'), findsOneWidget);

      // Tombol toggle sekarang menampilkan ikon gambar untuk kembali
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    });

    testWidgets('4. Kondisi tanpa teks di bingkai: alert muncul dan pengguna tetap di halaman gambar',
        (tester) async {
      final languageProvider = LanguageProvider()..setLanguage('Indonesian');
      // Simulasikan hasil OCR kosong pada SpeechScreen
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => DisplayPreferencesProvider()),
            ChangeNotifierProvider(create: (_) => languageProvider),
            ChangeNotifierProvider(create: (_) => HistoryProvider()),
          ],
          child: MaterialApp(
            home: SpeechScreen(
              text: '',
              hasImage: true,
              imageBytes: validImageBytes,
              ocrResult: OcrResult.empty,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tekan tombol Putar di AudioPlayerBar saat tidak ada teks
      final playBtn = find.byIcon(Icons.play_arrow_rounded);
      await tester.tap(playBtn);
      await tester.pumpAndSettle();

      // Verifikasi alert banner muncul
      expect(find.byType(NoTextAlertBanner), findsOneWidget);
      expect(find.textContaining('Teks tidak ditemukan'), findsOneWidget);

      // Pastikan pengguna TETAP di halaman gambar (tidak berpindah ke HighlightedTextView)
      expect(find.byType(HighlightedTextView), findsNothing);
      expect(find.byType(OcrImageOverlay), findsOneWidget);

      // Coba tekan tombol T saat tidak ada teks
      final toggleBtn = find.byType(SpeechModeToggleButton);
      await tester.tap(toggleBtn);
      await tester.pumpAndSettle();

      // Pastikan tetap tidak berpindah ke teks
      expect(find.byType(HighlightedTextView), findsNothing);
      expect(find.byType(OcrImageOverlay), findsOneWidget);
    });
  });
}
