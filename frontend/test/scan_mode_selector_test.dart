import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:eye_lens/core/services/language_provider.dart';
import 'package:eye_lens/screens/scan/widgets/scan_mode_selector.dart';
import 'package:eye_lens/services/ocr_noise_filter.dart';

void main() {
  group('ScanModeSelector Widget Tests', () {
    Widget buildSelector({
      required OcrScanMode selectedMode,
      required ValueChanged<OcrScanMode> onModeChanged,
    }) {
      return ChangeNotifierProvider<LanguageProvider>(
        create: (_) => LanguageProvider(),
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                ScanModeSelector(
                  selectedMode: selectedMode,
                  onModeChanged: onModeChanged,
                  bottomPadding: 0,
                ),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('Menampilkan seluruh 4 mode pemindaian OCR', (tester) async {
      await tester.pumpWidget(
        buildSelector(
          selectedMode: OcrScanMode.document,
          onModeChanged: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dokumen'), findsOneWidget);
      expect(find.text('Teliti'), findsOneWidget);
      expect(find.text('Layar'), findsOneWidget);
      expect(find.text('Tulis Tangan'), findsOneWidget);
    });

    testWidgets('Mengetuk chip mode memicu onModeChanged dengan mode baru', (
      tester,
    ) async {
      OcrScanMode currentMode = OcrScanMode.document;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return buildSelector(
              selectedMode: currentMode,
              onModeChanged: (newMode) {
                setState(() {
                  currentMode = newMode;
                });
              },
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      // Ketuk chip "Teliti"
      await tester.tap(find.text('Teliti'));
      await tester.pumpAndSettle();
      expect(currentMode, OcrScanMode.smallText);

      // Ketuk chip "Layar"
      await tester.tap(find.text('Layar'));
      await tester.pumpAndSettle();
      expect(currentMode, OcrScanMode.screenText);

      // Ketuk chip "Tulis Tangan"
      await tester.tap(find.text('Tulis Tangan'));
      await tester.pumpAndSettle();
      expect(currentMode, OcrScanMode.handwriting);
    });

    testWidgets('Memiliki target sentuh aksesibilitas minimal 48dp', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSelector(
          selectedMode: OcrScanMode.document,
          onModeChanged: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      final chipFinders = [
        find.text('Dokumen'),
        find.text('Teliti'),
        find.text('Layar'),
        find.text('Tulis Tangan'),
      ];

      for (final finder in chipFinders) {
        final box = tester.renderObject<RenderBox>(
          find
              .ancestor(of: finder, matching: find.byType(ConstrainedBox))
              .first,
        );
        expect(box.size.height, greaterThanOrEqualTo(48.0));
        expect(box.size.width, greaterThanOrEqualTo(48.0));
      }
    });
  });
}
