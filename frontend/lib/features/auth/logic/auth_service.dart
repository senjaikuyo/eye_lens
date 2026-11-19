import "dart:convert";

import "package:flutter/foundation.dart";
import "package:http/http.dart" as http;
import "package:shared_preferences/shared_preferences.dart";

class AuthService {
  static const String _serverUrlKey = 'custom_server_base_url';
  static String? _cachedBaseUrl;
  final http.Client _client;

  AuthService({http.Client? client}) : _client = client ?? http.Client();

  static Future<String> getBaseUrl() async {
    if (_cachedBaseUrl != null && _cachedBaseUrl!.isNotEmpty) {
      return _cachedBaseUrl!;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_serverUrlKey);
      if (saved != null && saved.trim().isNotEmpty) {
        _cachedBaseUrl = saved.trim();
        return _cachedBaseUrl!;
      }
    } catch (_) {}

    const customUrl = String.fromEnvironment('API_BASE_URL');
    if (customUrl.isNotEmpty) {
      _cachedBaseUrl = customUrl;
      return customUrl;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      _cachedBaseUrl = "http://10.0.2.2:8000/api";
      return _cachedBaseUrl!;
    }
    _cachedBaseUrl = "http://127.0.0.1:8000/api";
    return _cachedBaseUrl!;
  }

  static Future<void> setBaseUrl(String url) async {
    String cleanUrl = url.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    if (!cleanUrl.endsWith('/api')) {
      cleanUrl = '$cleanUrl/api';
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_serverUrlKey, cleanUrl);
    } catch (_) {}
    _cachedBaseUrl = cleanUrl;
  }

  static String get baseUrl {
    if (_cachedBaseUrl != null && _cachedBaseUrl!.isNotEmpty) {
      return _cachedBaseUrl!;
    }
    const customUrl = String.fromEnvironment('API_BASE_URL');
    if (customUrl.isNotEmpty) return customUrl;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return "http://10.0.2.2:8000/api";
    }
    return "http://127.0.0.1:8000/api";
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final currentBaseUrl = await AuthService.getBaseUrl();
    final response = await _client.post(
      Uri.parse("$currentBaseUrl/register"),
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "name": name,
        "email": email,
        "password": password,
        "password_confirmation": passwordConfirmation,
      }),
    );

    final data = _decodeResponse(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      await _saveToken(data["access_token"]);
      await _saveUser(data["user"]);
      return data;
    }

    throw Exception(_extractErrorMessage(data, "Registration failed"));
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final currentBaseUrl = await AuthService.getBaseUrl();
    final response = await _client.post(
      Uri.parse("$currentBaseUrl/login"),
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
      },
      body: jsonEncode({"email": email, "password": password}),
    );

    final data = _decodeResponse(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      await _saveToken(data["access_token"]);
      await _saveUser(data["user"]);
      return data;
    }

    throw Exception(_extractErrorMessage(data, "Login failed"));
  }

  /// Meminta kode OTP 6-digit untuk lupa kata sandi
  Future<String> requestPasswordReset(String email) async {
    final currentBaseUrl = await AuthService.getBaseUrl();
    final response = await _client.post(
      Uri.parse("$currentBaseUrl/forgot-password"),
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
      },
      body: jsonEncode({"email": email.trim()}),
    );

    final data = _decodeResponse(response);

    if (response.statusCode == 429) {
      throw Exception(_rateLimitMessage(data));
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data["message"] ?? "Kode verifikasi telah dikirim.";
    }

    throw Exception(
      _extractErrorMessage(data, "Gagal mengirim kode verifikasi."),
    );
  }

  /// Verifikasi kode OTP 6-digit dan mengembalikan reset token
  Future<String> verifyResetCode({
    required String email,
    required String code,
  }) async {
    final currentBaseUrl = await AuthService.getBaseUrl();
    final response = await _client.post(
      Uri.parse("$currentBaseUrl/verify-reset-code"),
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
      },
      body: jsonEncode({"email": email.trim(), "code": code.trim()}),
    );

    final data = _decodeResponse(response);

    if (response.statusCode == 429) {
      throw Exception(_rateLimitMessage(data));
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final resetToken = data["reset_token"];
      if (resetToken is String && resetToken.isNotEmpty) {
        return resetToken;
      }

      throw Exception("Reset token tidak ditemukan pada respons server.");
    }

    throw Exception(_extractErrorMessage(data, "Kode verifikasi tidak valid."));
  }

  /// Simpan password baru menggunakan reset token
  Future<String> resetPassword({
    required String email,
    required String resetToken,
    required String password,
    required String passwordConfirmation,
  }) async {
    final currentBaseUrl = await AuthService.getBaseUrl();
    final response = await _client.post(
      Uri.parse("$currentBaseUrl/reset-password"),
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "email": email.trim(),
        "reset_token": resetToken,
        "password": password,
        "password_confirmation": passwordConfirmation,
      }),
    );

    final data = _decodeResponse(response);

    if (response.statusCode == 429) {
      throw Exception(_rateLimitMessage(data));
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data["message"] ?? "Kata sandi berhasil diperbarui.";
    }

    throw Exception(
      _extractErrorMessage(data, "Gagal memperbarui kata sandi."),
    );
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("auth_token");

    if (token != null) {
      final currentBaseUrl = await AuthService.getBaseUrl();
      try {
        await _client.post(
          Uri.parse("$currentBaseUrl/logout"),
          headers: {
            "Accept": "application/json",
            "Authorization": "Bearer $token",
          },
        );
      } catch (_) {
        // Biarkan lolos jika jaringan offline agar pembersihan sesi lokal tetap berjalan
      }
    }

    await prefs.remove("auth_token");
    await prefs.remove("auth_user");
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("auth_token");
  }

  Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString("auth_user");
    if (userJson == null) return null;
    return jsonDecode(userJson);
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final rawBody = utf8.decode(response.bodyBytes).trim();
    if (rawBody.isEmpty) return <String, dynamic>{};

    try {
      final decoded = jsonDecode(rawBody);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } on FormatException {
      return <String, dynamic>{};
    }
  }

  String _extractErrorMessage(Map<String, dynamic> data, String fallback) {
    final errors = data["errors"];
    if (errors is Map && errors.isNotEmpty) {
      final firstError = errors.values.first;
      if (firstError is List && firstError.isNotEmpty) {
        return firstError.first.toString();
      }
    }

    final message = data["message"];
    if (message is String && message.trim().isNotEmpty) {
      return message;
    }

    return fallback;
  }

  String _rateLimitMessage(Map<String, dynamic> data) {
    final message = data["message"];
    if (message is String &&
        message.trim().isNotEmpty &&
        message != "Too Many Requests") {
      return message;
    }

    final retryAfter = data["retry_after"];
    if (retryAfter is num && retryAfter > 0) {
      return "Terlalu banyak permintaan. Coba lagi dalam ${retryAfter.toInt()} detik.";
    }

    return "Terlalu banyak permintaan. Silakan coba lagi nanti.";
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("auth_token", token);
  }

  Future<void> _saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("auth_user", jsonEncode(user));
  }
}
