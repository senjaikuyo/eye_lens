import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:eye_lens/core/services/auth_provider.dart';
import 'package:eye_lens/features/auth/logic/auth_service.dart';
import 'package:eye_lens/core/services/database_helper.dart';

class FakeClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest request) handler;
  final List<http.BaseRequest> requests = [];

  FakeClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    final response = await handler(request);
    return http.StreamedResponse(
      Stream.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    final tempDir = await Directory.systemTemp.createTemp('eyelens_auth_test');
    await databaseFactoryFfi.setDatabasesPath(tempDir.path);
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DatabaseHelper.instance.clearCurrentUser();
  });

  tearDownAll(() async {
    await DatabaseHelper.instance.close();
  });

  void storeSession({
    int id = 7,
    String token = 'token-lama',
    String email = 'lama@example.com',
    String name = 'Lama',
  }) {
    SharedPreferences.setMockInitialValues({
      AuthService.tokenKey: token,
      AuthService.userKey: jsonEncode({'id': id, 'email': email, 'name': name}),
    });
  }

  void storeCombinedSession({
    int id = 20,
    String token = 'token-baru',
    String email = 'baru@example.com',
  }) {
    SharedPreferences.setMockInitialValues({
      AuthService.sessionKey: jsonEncode({
        'token': token,
        'user': {'id': id, 'email': email, 'name': 'Baru'},
      }),
      AuthService.tokenKey: 'token-lama',
      AuthService.userKey: jsonEncode({
        'id': 7,
        'email': 'lama@example.com',
        'name': 'Lama',
      }),
    });
  }

  group('AuthService.validateSession', () {
    test('1. 200 berarti sesi sah dan data pengguna diperbarui', () async {
      storeSession();
      final client = FakeClient((request) async {
        expect(request.url.path.endsWith('/me'), isTrue);
        expect(request.headers['Authorization'], 'Bearer token-lama');
        return http.Response(
          jsonEncode({
            'user': {'id': 7, 'email': 'baru@example.com', 'name': 'Baru'},
          }),
          200,
          headers: {'Content-Type': 'application/json'},
        );
      });
      final service = AuthService(client: client);

      final result = await service.validateSession();

      expect(result, SessionValidation.valid);
      final user = await service.getUser();
      expect(user!['email'], 'baru@example.com');
      expect(user['name'], 'Baru');
    });

    test('2. 401 menghapus sesi lokal', () async {
      storeSession();
      final service = AuthService(
        client: FakeClient((_) async => http.Response('{}', 401)),
      );

      final result = await service.validateSession();

      expect(result, SessionValidation.invalid);
      expect(await service.getToken(), isNull);
      expect(await service.getUser(), isNull);
    });

    test('3. Offline mempertahankan sesi lokal', () async {
      storeSession();
      final service = AuthService(
        client: FakeClient((_) async => throw http.ClientException('offline')),
      );

      final result = await service.validateSession();

      expect(result, SessionValidation.offline);
      expect(await service.getToken(), 'token-lama');
      expect(await service.getUser(), isNotNull);
    });

    test('4. 5xx dianggap offline, bukan token tidak sah', () async {
      storeSession();
      final service = AuthService(
        client: FakeClient((_) async => http.Response('{}', 503)),
      );

      final result = await service.validateSession();

      expect(result, SessionValidation.offline);
      expect(await service.getToken(), 'token-lama');
    });

    test('5. Tanpa token berarti noSession', () async {
      final service = AuthService(
        client: FakeClient((_) async => http.Response('{}', 200)),
      );

      final result = await service.validateSession();

      expect(result, SessionValidation.noSession);
    });
  });

  group('AuthProvider offline', () {
    test('6. load memulihkan sesi tersimpan dan scope database', () async {
      storeSession(id: 11);
      final provider = AuthProvider(
        authService: AuthService(
          client: FakeClient((_) async => http.Response('{}', 200)),
        ),
      );

      await provider.load();

      expect(provider.isAuthenticated, isTrue);
      expect(provider.userId, 11);
      expect(provider.email, 'lama@example.com');
      expect(provider.name, 'Lama');
      expect(DatabaseHelper.instance.currentUserId, 11);
    });

    test('7. validateSession offline tetap mengizinkan akses', () async {
      storeSession(id: 12);
      final provider = AuthProvider(
        authService: AuthService(
          client: FakeClient(
            (_) async => throw http.ClientException('offline'),
          ),
        ),
      );
      await provider.load();

      await provider.validateSession();

      expect(provider.isAuthenticated, isTrue);
      expect(provider.isOfflineSession, isTrue);
      expect(provider.userId, 12);
    });

    test('8. validateSession 401 membersihkan sesi dan scope', () async {
      storeSession(id: 13);
      final provider = AuthProvider(
        authService: AuthService(
          client: FakeClient((_) async => http.Response('{}', 401)),
        ),
      );
      await provider.load();
      expect(provider.isAuthenticated, isTrue);

      await provider.validateSession();

      expect(provider.isAuthenticated, isFalse);
      expect(provider.isOfflineSession, isFalse);
      expect(
        DatabaseHelper.instance.currentUserId,
        DatabaseHelper.legacyUserId,
      );
      expect(await AuthService().getToken(), isNull);
    });
  });

  group('AuthService.getSession', () {
    test('9. Sesi gabungan diprioritaskan atas kunci lama', () async {
      storeCombinedSession(id: 20, token: 'token-baru');
      final service = AuthService(
        client: FakeClient((_) async => http.Response('{}', 200)),
      );

      final session = await service.getSession();

      expect(session, isNotNull);
      expect(session!.token, 'token-baru');
      expect(session.userId, 20);
    });

    test('10. Sesi lama dimigrasikan dan tidak tercampur', () async {
      storeSession(id: 7, token: 'token-lama');
      final service = AuthService(
        client: FakeClient((_) async => http.Response('{}', 200)),
      );

      final first = await service.getSession();
      expect(first, isNotNull);
      expect(first!.token, 'token-lama');
      expect(first.userId, 7);

      // Kunci lama diubah terpisah: sesi gabungan harus tetap konsisten.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AuthService.tokenKey, 'token-baru');
      await prefs.setString(AuthService.userKey, jsonEncode({'id': 99}));

      final second = await service.getSession();
      expect(second, isNotNull);
      expect(second!.token, 'token-lama');
      expect(second.userId, 7);
    });
  });
}
