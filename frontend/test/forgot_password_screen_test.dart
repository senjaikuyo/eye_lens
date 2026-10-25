import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eye_lens/providers/display_preferences_provider.dart';
import 'package:eye_lens/providers/language_provider.dart';
import 'package:eye_lens/screens/auth/forgot_password_screen.dart';
import 'package:eye_lens/services/auth/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createTestWidget(AuthService authService) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DisplayPreferencesProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: MaterialApp(
        home: ForgotPasswordScreen(authService: authService),
      ),
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ForgotPasswordScreen Widget Tests', () {
    testWidgets('Langkah 1: Menampilkan field email dan tombol kirim kode', (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Kode verifikasi terkirim.'}),
          200,
        );
      });
      final authService = AuthService(client: mockClient);

      await tester.pumpWidget(createTestWidget(authService));
      await tester.pumpAndSettle();

      expect(find.text('Lupa Kata Sandi'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Kirim Kode'), findsOneWidget);
    });

    testWidgets('Langkah 1 ke Langkah 2: Berpindah langkah setelah email dikirim sukses', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/api/forgot-password')) {
          return http.Response(
            jsonEncode({'message': 'Kode terkirim'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });
      final authService = AuthService(client: mockClient);

      await tester.pumpWidget(createTestWidget(authService));
      await tester.pumpAndSettle();

      // Isi email
      await tester.enterText(find.byType(TextField).first, 'user@example.com');
      await tester.pump();

      // Klik tombol Kirim Kode
      await tester.tap(find.text('Kirim Kode'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verifikasi layar berpindah ke Langkah 2
      expect(find.text('Verifikasi'), findsAtLeastNWidgets(1));
      expect(find.textContaining('user@example.com'), findsOneWidget);
    });
  });
}
