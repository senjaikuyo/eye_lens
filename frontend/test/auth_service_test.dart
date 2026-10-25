import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eye_lens/services/auth/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService Tests', () {
    test('1. getToken dan getUser membaca dari SharedPreferences dengan benar', () async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'sample_sanctum_token_123',
        'auth_user': jsonEncode({'id': 1, 'name': 'Budi', 'email': 'budi@example.com'}),
      });

      final authService = AuthService();
      final token = await authService.getToken();
      final user = await authService.getUser();

      expect(token, 'sample_sanctum_token_123');
      expect(user, isNotNull);
      expect(user!['name'], 'Budi');
      expect(user['email'], 'budi@example.com');
    });

    test('2. logout menghapus auth_token dan auth_user dari local storage', () async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'sample_token_to_remove',
        'auth_user': jsonEncode({'id': 2, 'name': 'Siti'}),
      });

      final authService = AuthService();
      await authService.logout();

      final tokenAfter = await authService.getToken();
      final userAfter = await authService.getUser();

      expect(tokenAfter, isNull);
      expect(userAfter, isNull);
    });

    test('3. baseUrl mengembalikan fallback host yang valid', () {
      final url = AuthService.baseUrl;
      expect(url.startsWith('http://'), isTrue);
      expect(url.endsWith('/api'), isTrue);
    });
  });
}
