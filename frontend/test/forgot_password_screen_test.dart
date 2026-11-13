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
import 'package:eye_lens/screens/auth/login_screen.dart';
import 'package:eye_lens/services/auth/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createTestWidget(AuthService authService) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DisplayPreferencesProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: MaterialApp(home: ForgotPasswordScreen(authService: authService)),
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ForgotPasswordScreen Widget Tests', () {
    testWidgets('Langkah 1: Menampilkan field email dan tombol kirim kode', (
      tester,
    ) async {
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

    testWidgets(
      'Langkah 1 ke Langkah 2: Berpindah langkah setelah email dikirim sukses',
      (tester) async {
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
        await tester.enterText(
          find.byType(TextField).first,
          'user@example.com',
        );
        await tester.pump();

        // Klik tombol Kirim Kode
        await tester.tap(find.text('Kirim Kode'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Verifikasi layar berpindah ke Langkah 2
        expect(find.text('Verifikasi'), findsAtLeastNWidgets(1));
        expect(find.textContaining('user@example.com'), findsOneWidget);
        expect(find.textContaining('5 menit'), findsOneWidget);

        // Lepas screen agar timer hitung mundur ikut dibatalkan.
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets('Alur lengkap: OTP valid, simpan password, kembali ke Login', (
      tester,
    ) async {
      final mockClient = MockClient((request) async {
        switch (request.url.path) {
          case '/api/forgot-password':
            return http.Response(
              jsonEncode({'message': 'Kode verifikasi terkirim.'}),
              200,
              headers: {'content-type': 'application/json'},
            );
          case '/api/verify-reset-code':
            return http.Response(
              jsonEncode({
                'message': 'Kode valid.',
                'reset_token':
                    'dummy_reset_token_64_characters_long_abcdef123456',
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          case '/api/reset-password':
            return http.Response(
              jsonEncode({
                'message':
                    'Kata sandi berhasil diperbarui. Silakan masuk kembali.',
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          case '/api/logout':
            return http.Response(
              jsonEncode({'message': 'Logged out successfully'}),
              200,
              headers: {'content-type': 'application/json'},
            );
          default:
            return http.Response('{}', 404);
        }
      });
      final authService = AuthService(client: mockClient);

      await tester.pumpWidget(createTestWidget(authService));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'user@example.com');
      await tester.tap(find.text('Kirim Kode'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Isi 6 digit OTP; digit terakhir otomatis memicu verifikasi.
      final otpFields = find.byType(TextField);
      for (var i = 0; i < 6; i++) {
        await tester.enterText(otpFields.at(i), '${i + 1}');
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Buat Kata Sandi Baru'), findsOneWidget);

      final passwordFields = find.byType(TextField);
      await tester.enterText(passwordFields.at(0), 'NewPassword123!');
      await tester.enterText(passwordFields.at(1), 'NewPassword123!');
      await tester.ensureVisible(find.text('Simpan Kata Sandi'));
      await tester.tap(find.text('Simpan Kata Sandi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Kata Sandi Diperbarui'), findsOneWidget);
      await tester.tap(find.byKey(const Key('backToLoginButton')));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });
}
