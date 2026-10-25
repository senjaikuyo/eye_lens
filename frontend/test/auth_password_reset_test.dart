import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:eye_lens/services/auth/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService Password Reset API Tests', () {
    test('requestPasswordReset sukses mengirim email', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/forgot-password');
        final body = jsonDecode(request.body);
        expect(body['email'], 'user@example.com');
        return http.Response(
          jsonEncode({'message': 'Kode verifikasi telah dikirim.'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final authService = AuthService(client: mockClient);
      final msg = await authService.requestPasswordReset('user@example.com');
      expect(msg, 'Kode verifikasi telah dikirim.');
    });

    test('requestPasswordReset melempar exception saat rate limited (429)', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Too Many Requests'}),
          429,
          headers: {'content-type': 'application/json'},
        );
      });

      final authService = AuthService(client: mockClient);
      expect(
        () => authService.requestPasswordReset('user@example.com'),
        throwsA(isA<Exception>()),
      );
    });

    test('verifyResetCode sukses dan mengembalikan reset token', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/verify-reset-code');
        final body = jsonDecode(request.body);
        expect(body['email'], 'user@example.com');
        expect(body['code'], '123456');
        return http.Response(
          jsonEncode({
            'message': 'Kode valid.',
            'reset_token': 'dummy_reset_token_64_characters_long_abcdef123456',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final authService = AuthService(client: mockClient);
      final token = await authService.verifyResetCode(
        email: 'user@example.com',
        code: '123456',
      );
      expect(token, 'dummy_reset_token_64_characters_long_abcdef123456');
    });

    test('verifyResetCode melempar pesan error saat kode salah', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'message': 'Validation error',
            'errors': {
              'code': ['Kode verifikasi salah. Sisa percobaan: 4.'],
            },
          }),
          422,
          headers: {'content-type': 'application/json'},
        );
      });

      final authService = AuthService(client: mockClient);
      expect(
        () => authService.verifyResetCode(
          email: 'user@example.com',
          code: '000000',
        ),
        throwsA(predicate((e) => e.toString().contains('Kode verifikasi salah'))),
      );
    });

    test('resetPassword sukses memperbarui password', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/reset-password');
        final body = jsonDecode(request.body);
        expect(body['email'], 'user@example.com');
        expect(body['password'], 'NewPassword123!');
        return http.Response(
          jsonEncode({'message': 'Kata sandi berhasil diperbarui.'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final authService = AuthService(client: mockClient);
      final msg = await authService.resetPassword(
        email: 'user@example.com',
        resetToken: 'token123',
        password: 'NewPassword123!',
        passwordConfirmation: 'NewPassword123!',
      );
      expect(msg, 'Kata sandi berhasil diperbarui.');
    });
  });
}
