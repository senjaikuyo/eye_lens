import 'package:eye_lens/features/speech/screen/widgets/speech_text_editor_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('RC-10 UB-07 pengguna dapat mengubah teks sebelum TTS', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showSpeechTextEditor(
                  context: context,
                  initialText: 'Prednison 5 mg',
                  isIndonesian: true,
                );
              },
              child: const Text('Edit'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Edit teks'), findsOneWidget);
    expect(find.byKey(const Key('speech-text-editor-field')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('speech-text-editor-field')),
      'Prednison 10 mg',
    );
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(result, 'Prednison 10 mg');
  });

  testWidgets('RC-10 teks kosong tidak disimpan', (tester) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showSpeechTextEditor(
                  context: context,
                  initialText: 'Teks awal',
                  isIndonesian: true,
                );
              },
              child: const Text('Edit'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('speech-text-editor-field')),
      '   ',
    );
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.text('Edit teks'), findsOneWidget);
  });
}
