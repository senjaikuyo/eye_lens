import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:eye_lens/services/auth/auth_service.dart';
import 'package:eye_lens/services/feedback_service.dart';

class FakeAuthService extends AuthService {
  final String? token;

  FakeAuthService({this.token});

  @override
  Future<String?> getToken() async => token;
}

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
  group('FeedbackService', () {
    test('1. Pesan kosong ditolak tanpa memanggil jaringan', () async {
      var called = false;
      final client = FakeClient((_) async {
        called = true;
        return http.Response('{}', 201);
      });
      final service = FeedbackService(
        authService: FakeAuthService(token: 'token'),
        client: client,
      );

      await expectLater(
        service.submit('   '),
        throwsA(
          isA<FeedbackException>().having(
            (e) => e.failure,
            'failure',
            FeedbackFailure.empty,
          ),
        ),
      );
      expect(called, isFalse);
    });

    test('2. Tanpa token tidak mengirim dan melaporkan unauthorized', () async {
      var called = false;
      final client = FakeClient((_) async {
        called = true;
        return http.Response('{}', 201);
      });
      final service = FeedbackService(
        authService: FakeAuthService(token: null),
        client: client,
      );

      await expectLater(
        service.submit('Saran'),
        throwsA(
          isA<FeedbackException>().having(
            (e) => e.failure,
            'failure',
            FeedbackFailure.unauthorized,
          ),
        ),
      );
      expect(called, isFalse);
    });

    test('3. Sukses hanya setelah backend 2xx dan body benar', () async {
      final client = FakeClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path.endsWith('/masukan'), isTrue);
        expect(request.headers['Authorization'], 'Bearer rahasia');
        final body = jsonDecode((request as http.Request).body);
        expect(body['pesan'], 'Tolong tambah mode gelap');
        return http.Response(
          jsonEncode({'status': 'success'}),
          201,
          headers: {'Content-Type': 'application/json'},
        );
      });
      final service = FeedbackService(
        authService: FakeAuthService(token: 'rahasia'),
        client: client,
      );

      await service.submit('  Tolong tambah mode gelap  ');
      expect(client.requests.length, 1);
    });

    test('4. 401 dilaporkan sebagai unauthorized', () async {
      final service = FeedbackService(
        authService: FakeAuthService(token: 'token'),
        client: FakeClient((_) async => http.Response('{}', 401)),
      );

      await expectLater(
        service.submit('Saran'),
        throwsA(
          isA<FeedbackException>().having(
            (e) => e.failure,
            'failure',
            FeedbackFailure.unauthorized,
          ),
        ),
      );
    });

    test('5. 422 membawa pesan validasi server', () async {
      final service = FeedbackService(
        authService: FakeAuthService(token: 'token'),
        client: FakeClient(
          (_) async => http.Response(
            jsonEncode({
              'message': 'Invalid',
              'errors': {
                'pesan': ['Pesan terlalu panjang.'],
              },
            }),
            422,
          ),
        ),
      );

      await expectLater(
        service.submit('Saran'),
        throwsA(
          isA<FeedbackException>()
              .having((e) => e.failure, 'failure', FeedbackFailure.validation)
              .having(
                (e) => e.serverMessage,
                'serverMessage',
                'Pesan terlalu panjang.',
              ),
        ),
      );
    });

    test('6. Timeout dilaporkan sebagai timeout', () async {
      final service = FeedbackService(
        authService: FakeAuthService(token: 'token'),
        client: FakeClient((_) async => throw TimeoutException('timeout')),
      );

      await expectLater(
        service.submit('Saran'),
        throwsA(
          isA<FeedbackException>().having(
            (e) => e.failure,
            'failure',
            FeedbackFailure.timeout,
          ),
        ),
      );
    });

    test('7. Gangguan koneksi dilaporkan sebagai offline', () async {
      final service = FeedbackService(
        authService: FakeAuthService(token: 'token'),
        client: FakeClient((_) async => throw http.ClientException('offline')),
      );

      await expectLater(
        service.submit('Saran'),
        throwsA(
          isA<FeedbackException>().having(
            (e) => e.failure,
            'failure',
            FeedbackFailure.offline,
          ),
        ),
      );
    });

    test('8. 500 dilaporkan sebagai kegagalan server', () async {
      final service = FeedbackService(
        authService: FakeAuthService(token: 'token'),
        client: FakeClient((_) async => http.Response('{}', 500)),
      );

      await expectLater(
        service.submit('Saran'),
        throwsA(
          isA<FeedbackException>().having(
            (e) => e.failure,
            'failure',
            FeedbackFailure.server,
          ),
        ),
      );
    });
  });
}
