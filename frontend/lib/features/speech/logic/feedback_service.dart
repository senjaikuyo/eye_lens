import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:eye_lens/features/auth/logic/auth_service.dart';

enum FeedbackFailure {
  empty,
  unauthorized,
  offline,
  timeout,
  validation,
  server,
}

class FeedbackException implements Exception {
  final FeedbackFailure failure;
  final String? serverMessage;

  const FeedbackException(this.failure, {this.serverMessage});

  @override
  String toString() => 'FeedbackException($failure)';
}

/// Mengirim masukan pengguna ke `POST /api/masukan`.
///
/// Sukses hanya dikembalikan setelah backend menjawab 2xx. Tidak ada
/// penyimpanan antrean lokal karena masukan bukan data offline-first.
class FeedbackService {
  final AuthService _authService;
  final http.Client _client;

  FeedbackService({AuthService? authService, http.Client? client})
    : _authService = authService ?? AuthService(),
      _client = client ?? http.Client();

  Future<void> submit(String pesan) async {
    final trimmed = pesan.trim();
    if (trimmed.isEmpty) {
      throw const FeedbackException(FeedbackFailure.empty);
    }

    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw const FeedbackException(FeedbackFailure.unauthorized);
    }

    try {
      final response = await _client
          .post(
            Uri.parse('${AuthService.baseUrl}/masukan'),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'pesan': trimmed}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const FeedbackException(FeedbackFailure.unauthorized);
      }

      if (response.statusCode == 422) {
        throw FeedbackException(
          FeedbackFailure.validation,
          serverMessage: _firstError(response.body),
        );
      }

      throw const FeedbackException(FeedbackFailure.server);
    } on FeedbackException {
      rethrow;
    } on TimeoutException {
      throw const FeedbackException(FeedbackFailure.timeout);
    } on http.ClientException {
      throw const FeedbackException(FeedbackFailure.offline);
    } catch (_) {
      throw const FeedbackException(FeedbackFailure.server);
    }
  }

  String? _firstError(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['errors'] is Map) {
        final errors = decoded['errors'] as Map;
        for (final value in errors.values) {
          if (value is List && value.isNotEmpty) return value.first.toString();
          if (value is String && value.isNotEmpty) return value;
        }
      }
      if (decoded is Map && decoded['message'] is String) {
        return decoded['message'] as String;
      }
    } catch (_) {}
    return null;
  }
}
