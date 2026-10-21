import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eye_lens/screens/speech/widgets/highlighted_text_view.dart';
import 'package:eye_lens/services/text_formatter.dart';

void main() {
  testWidgets('HighlightedTextView menampilkan paragraf dan merespon klik kata', (
    WidgetTester tester,
  ) async {
    const raw = 'Paragraf pertama terdiri dari beberapa kata.\n\nParagraf kedua.';
    final formatted = TextFormatter.formatRawText(raw);

    double updatedProgress = 0.0;
    int updatedCharIndex = -1;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HighlightedTextView(
              text: formatted.fullText,
              formattedResult: formatted,
              currentCharIndex: 0,
              fontSize: 24.0,
              cursorColorEnabled: true,
              highlightColor: Colors.blue,
              isDark: false,
              isHighContrast: false,
              progress: 0.0,
              onProgressChanged: (p) => updatedProgress = p,
              onCharIndexChanged: (idx) => updatedCharIndex = idx,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Pastikan kata-kata ter-render di layar
    expect(find.text('Paragraf'), findsNWidgets(2));
    expect(find.text('pertama'), findsOneWidget);
    expect(find.text('kedua.'), findsOneWidget);

    // Ketuk kata 'pertama'
    await tester.tap(find.text('pertama'));
    await tester.pumpAndSettle();

    expect(updatedCharIndex, greaterThanOrEqualTo(0));
    expect(updatedProgress, greaterThanOrEqualTo(0.0));
  });
}
