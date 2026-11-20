import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eye_lens/core/constants/app_strings.dart';
import 'package:eye_lens/features/speech/logic/feedback_service.dart';
import 'package:eye_lens/core/widgets/feedback_dialog.dart';

class FakeFeedbackService extends FeedbackService {
  final Future<void> Function(String pesan) handler;
  int calls = 0;
  String? lastPesan;

  FakeFeedbackService(this.handler);

  @override
  Future<void> submit(String pesan) {
    calls++;
    lastPesan = pesan;
    return handler(pesan);
  }
}

void main() {
  const strings = AppStrings(isIndonesian: true);

  Future<void> openDialog(WidgetTester tester, FeedbackService service) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => FeedbackDialog.show(
                context,
                strings: strings,
                isDark: false,
                service: service,
              ),
              child: const Text('Buka'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();
  }

  testWidgets('1. Pesan kosong tidak dikirim dan menampilkan error', (
    tester,
  ) async {
    final service = FakeFeedbackService((_) async {});
    await openDialog(tester, service);

    await tester.tap(find.text(strings.send));
    await tester.pumpAndSettle();

    expect(service.calls, 0);
    expect(find.text(strings.feedbackEmpty), findsOneWidget);
    expect(find.byType(FeedbackDialog), findsOneWidget);
  });

  testWidgets('2. Loading mencegah pengiriman ganda', (tester) async {
    final completer = Completer<void>();
    final service = FakeFeedbackService((_) => completer.future);
    await openDialog(tester, service);

    await tester.enterText(find.byType(TextField), 'Saran saya');
    await tester.tap(find.text(strings.send));
    await tester.pump();

    // Tombol berubah menjadi indikator loading dan tidak bisa ditekan lagi.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(ElevatedButton),
      ),
    );
    await tester.pump();
    expect(service.calls, 1);

    completer.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('3. Sukses hanya setelah service selesai, lalu menutup dialog', (
    tester,
  ) async {
    final completer = Completer<void>();
    final service = FakeFeedbackService((_) => completer.future);
    await openDialog(tester, service);

    await tester.enterText(find.byType(TextField), '  Saran saya  ');
    await tester.tap(find.text(strings.send));
    await tester.pump();

    // Belum ada konfirmasi, dialog masih terbuka.
    expect(find.byType(FeedbackDialog), findsOneWidget);
    expect(service.lastPesan, 'Saran saya');

    completer.complete();
    await tester.pumpAndSettle();

    expect(find.byType(FeedbackDialog), findsNothing);
    expect(find.text(strings.feedbackSent), findsOneWidget);
  });

  testWidgets('4. Offline menampilkan error dan dialog tetap terbuka', (
    tester,
  ) async {
    final service = FakeFeedbackService(
      (_) async => throw const FeedbackException(FeedbackFailure.offline),
    );
    await openDialog(tester, service);

    await tester.enterText(find.byType(TextField), 'Saran saya');
    await tester.tap(find.text(strings.send));
    await tester.pumpAndSettle();

    expect(find.byType(FeedbackDialog), findsOneWidget);
    expect(find.text(strings.feedbackOffline), findsOneWidget);
    expect(find.text(strings.feedbackSent), findsNothing);
  });

  testWidgets('5. Error server tidak menampilkan pesan sukses', (tester) async {
    final service = FakeFeedbackService(
      (_) async => throw const FeedbackException(FeedbackFailure.server),
    );
    await openDialog(tester, service);

    await tester.enterText(find.byType(TextField), 'Saran saya');
    await tester.tap(find.text(strings.send));
    await tester.pumpAndSettle();

    expect(find.text(strings.feedbackFailed), findsOneWidget);
    expect(find.text(strings.feedbackSent), findsNothing);
  });
}
