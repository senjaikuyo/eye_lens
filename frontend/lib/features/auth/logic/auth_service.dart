import "dart:async";
import "dart:convert";

import "package:flutter/foundation.dart";
import "package:http/http.dart" as http;
import "package:shared_preferences/shared_preferences.dart";

/// Status validasi sesi tersimpan.
///
/// Token Sanctum bersifat opaque, sehingga validitasnya tidak dapat
/// diverifikasi secara kriptografis saat offline. [offline] berarti sesi
/// lokal dipertahankan sampai backend dapat dihubungi kembali.
enum SessionValidation { valid, invalid, offline, noSession }

/// Snapshot token dan identitas pengguna yang dibaca sebagai satu kesatuan.
///
/// Dipakai oleh sinkronisasi agar data lokal tidak pernah dikirim dengan token
/// milik akun lain ketika pengguna berganti akun di tengah proses.
class AuthSession {
  final String token;
  final Map<String, dynamic> user;

  const AuthSession({required this.token, required this.user});

  int? get userId => (user['id'] as num?)?.toInt();
}

class AuthService {
  static const String tokenKey = "auth_token";
  static const String userKey = "auth_user";
  static const String sessionKey = "auth_session";
  static const Duration requestTimeout = Duration(seconds: 15);

  static const String _serverUrlKey = 'custom_server_base_url';
  static String? _cachedBaseUrl;

  final http.Client _client;

  AuthService({http.Client? client}) : _client = client ?? http.Client();

  /// Base URL efektif (dari preferensi server kustom bila ada).
  ///
  /// Dipakai untuk semua request agar konfigurasi server kustom tetap
  /// berlaku pada alur autentikasi maupun sinkronisasi.
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

    _cachedBaseUrl = _defaultBaseUrl;
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

  /// Nilai sinkron untuk pemanggil non-async. Tidak membaca preferensi.
  static String get baseUrl {
    if (_cachedBaseUrl != null && _cachedBaseUrl!.isNotEmpty) {
      return _cachedBaseUrl!;
    }
    return _defaultBaseUrl;
  }

  static String get _defaultBaseUrl {
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
    final currentBaseUrl = await getBaseUrl();
    final response = await _client
        .post(
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
        )
        .timeout(requestTimeout);

    final data = _decodeResponse(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      await _saveSessionFromResponse(data);
      return data;
    }

    throw Exception(_extractErrorMessage(data, "Registration failed"));
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final currentBaseUrl = await getBaseUrl();
    final response = await _client
        .post(
          Uri.parse("$currentBaseUrl/login"),
          headers: {
            "Accept": "application/json",
            "Content-Type": "application/json",
          },
          body: jsonEncode({"email": email, "password": password}),
        )
        .timeout(requestTimeout);

    final data = _decodeResponse(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      await _saveSessionFromResponse(data);
      return data;
    }

    throw Exception(_extractErrorMessage(data, "Login failed"));
  }

  /// Meminta kode OTP 6-digit untuk lupa kata sandi
  Future<String> requestPasswordReset(String email) async {
    final currentBaseUrl = await getBaseUrl();
    final response = await _client
        .post(
          Uri.parse("$currentBaseUrl/forgot-password"),
          headers: {
            "Accept": "application/json",
            "Content-Type": "application/json",
          },
          body: jsonEncode({"email": email.trim()}),
        )
        .timeout(requestTimeout);

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
    final currentBaseUrl = await getBaseUrl();
    final response = await _client
        .post(
          Uri.parse("$currentBaseUrl/verify-reset-code"),
          headers: {
            "Accept": "application/json",
            "Content-Type": "application/json",
          },
          body: jsonEncode({"email": email.trim(), "code": code.trim()}),
        )
        .timeout(requestTimeout);

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
    final currentBaseUrl = await getBaseUrl();
    final response = await _client
        .post(
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
        )
        .timeout(requestTimeout);

    final data = _decodeResponse(response);

    if (response.statusCode == 429) {
      throw Exception(_rateLimitMessage(data));
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Backend mencabut semua token Sanctum setelah reset password.
      await clearSession();
      return data["message"] ?? "Kata sandi berhasil diperbarui.";
    }

    throw Exception(
      _extractErrorMessage(data, "Gagal memperbarui kata sandi."),
    );
  }

  Future<void> logout() async {
    final token = await getToken();

    if (token != null && token.isNotEmpty) {
      final currentBaseUrl = await getBaseUrl();
      try {
        await _client
            .post(
              Uri.parse("$currentBaseUrl/logout"),
              headers: {
                "Accept": "application/json",
                "Authorization": "Bearer $token",
              },
            )
            .timeout(const Duration(seconds: 10));
      } catch (_) {
        // Biarkan lolos jika jaringan offline agar pembersihan sesi lokal tetap berjalan
      }
    }

    await clearSession();
  }

  Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(tokenKey);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(userKey);
      if (userJson == null) return null;
      final decoded = jsonDecode(userJson);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Membaca token dan pengguna sebagai satu snapshot yang konsisten.
  ///
  /// Sejak versi ini keduanya disimpan dalam satu nilai `auth_session` agar
  /// tidak mungkin tercampur antar-akun. Sesi lama (dua kunci terpisah)
  /// dimigrasikan otomatis ke bentuk gabungan saat pertama kali dibaca.
  Future<AuthSession?> getSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final raw = prefs.getString(sessionKey);
      if (raw != null && raw.isNotEmpty) {
        final session = _decodeSession(raw);
        if (session != null) return session;
      }

      final token = prefs.getString(tokenKey);
      final userJson = prefs.getString(userKey);
      if (token == null || token.isEmpty || userJson == null) return null;

      final decodedUser = jsonDecode(userJson);
      if (decodedUser is! Map<String, dynamic> || decodedUser['id'] == null) {
        return null;
      }

      final session = AuthSession(token: token, user: decodedUser);
      // Self-healing: setelah ini token dan pengguna selalu dibaca bersama.
      await prefs.setString(sessionKey, _encodeSession(session));
      return session;
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasStoredSession() async {
    final session = await getSession();
    return session != null && session.userId != null;
  }

  /// Validasi token ke `GET /api/me` bila perangkat online.
  ///
  /// Token Sanctum tidak dapat diverifikasi offline. Karena itu:
  /// - 200: sesi sah dan data pengguna diperbarui.
  /// - 401/403: token dicabut/kedaluwarsa, sesi lokal dihapus.
  /// - gangguan jaringan/5xx: sesi lokal dipertahankan sebagai offline.
  Future<SessionValidation> validateSession() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return SessionValidation.noSession;

    try {
      final currentBaseUrl = await getBaseUrl();
      final response = await _client
          .get(
            Uri.parse("$currentBaseUrl/me"),
            headers: {
              "Accept": "application/json",
              "Authorization": "Bearer $token",
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = _decodeResponse(response);
        final user = data["user"];
        if (user is Map<String, dynamic>) {
          await _saveSession(token, user);
        }
        return SessionValidation.valid;
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        await clearSession();
        return SessionValidation.invalid;
      }

      return SessionValidation.offline;
    } on TimeoutException {
      return SessionValidation.offline;
    } on http.ClientException {
      return SessionValidation.offline;
    } catch (_) {
      return SessionValidation.offline;
    }
  }

  Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(sessionKey);
      await prefs.remove(tokenKey);
      await prefs.remove(userKey);
    } catch (_) {
      // Penyimpanan lokal tidak tersedia (mis. unit test tanpa mock).
    }
  }

  Future<void> _saveSessionFromResponse(Map<String, dynamic> data) async {
    final token = data["access_token"];
    final user = data["user"];
    if (token is! String ||
        token.isEmpty ||
        user is! Map<String, dynamic> ||
        user['id'] == null) {
      throw Exception("Respons autentikasi tidak valid.");
    }
    await _saveSession(token, user);
  }

  /// Menyimpan token dan pengguna dalam satu nilai agar atomik.
  Future<void> _saveSession(String token, Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    final session = AuthSession(token: token, user: user);
    await prefs.setString(sessionKey, _encodeSession(session));
    // Kunci lama tetap dipertahankan untuk kompatibilitas pembaca lain.
    await prefs.setString(tokenKey, token);
    await prefs.setString(userKey, jsonEncode(user));
  }

  String _encodeSession(AuthSession session) {
    return jsonEncode({'token': session.token, 'user': session.user});
  }

  AuthSession? _decodeSession(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final token = decoded['token'];
      final user = decoded['user'];
      if (token is String &&
          token.isNotEmpty &&
          user is Map<String, dynamic> &&
          user['id'] != null) {
        return AuthSession(token: token, user: user);
      }
    } catch (_) {
      // Format lama/rusak; pembaca akan mencoba kunci terpisah.
    }
    return null;
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
      if (firstError is String && firstError.isNotEmpty) {
        return firstError;
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
}
