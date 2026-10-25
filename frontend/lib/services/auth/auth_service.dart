import "dart:convert";

import "package:flutter/foundation.dart";
import "package:http/http.dart" as http;
import "package:shared_preferences/shared_preferences.dart";

class AuthService {
  final http.Client _client;

  AuthService({http.Client? client}) : _client = client ?? http.Client();

  static String get baseUrl {
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
    final response = await _client.post(
      Uri.parse("$baseUrl/register"),
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

    final data = jsonDecode(response.body.trim()) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      await _saveToken(data["access_token"]);
      await _saveUser(data["user"]);
      return data;
    }

    if (data["errors"] != null) {
      final errors = data["errors"] as Map;
      final firstError = errors.values.first;
      if (firstError is List && firstError.isNotEmpty) {
        throw Exception(firstError.first.toString());
      }
    }

    throw Exception(data["message"] ?? "Registration failed");
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse("$baseUrl/login"),
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "email": email,
        "password": password,
      }),
    );

    final data = jsonDecode(response.body.trim()) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      await _saveToken(data["access_token"]);
      await _saveUser(data["user"]);
      return data;
    }

    if (data["errors"] != null) {
      final errors = data["errors"] as Map;
      final firstError = errors.values.first;
      if (firstError is List && firstError.isNotEmpty) {
        throw Exception(firstError.first.toString());
      }
    }

    throw Exception(data["message"] ?? "Login failed");
  }

  /// Meminta kode OTP 6-digit untuk lupa kata sandi
  Future<String> requestPasswordReset(String email) async {
    final response = await _client.post(
      Uri.parse("$baseUrl/forgot-password"),
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "email": email.trim(),
      }),
    );

    final data = jsonDecode(response.body.trim()) as Map<String, dynamic>;

    if (response.statusCode == 429) {
      throw Exception("Terlalu banyak permintaan. Silakan tunggu 15 menit.");
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data["message"] ?? "Kode verifikasi telah dikirim.";
    }

    if (data["errors"] != null) {
      final errors = data["errors"] as Map;
      final firstError = errors.values.first;
      if (firstError is List && firstError.isNotEmpty) {
        throw Exception(firstError.first.toString());
      }
    }

    throw Exception(data["message"] ?? "Gagal mengirim kode verifikasi.");
  }

  /// Verifikasi kode OTP 6-digit dan mengembalikan reset token
  Future<String> verifyResetCode({
    required String email,
    required String code,
  }) async {
    final response = await _client.post(
      Uri.parse("$baseUrl/verify-reset-code"),
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "email": email.trim(),
        "code": code.trim(),
      }),
    );

    final data = jsonDecode(response.body.trim()) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data["reset_token"] as String;
    }

    if (data["errors"] != null) {
      final errors = data["errors"] as Map;
      final firstError = errors.values.first;
      if (firstError is List && firstError.isNotEmpty) {
        throw Exception(firstError.first.toString());
      }
    }

    throw Exception(data["message"] ?? "Kode verifikasi tidak valid.");
  }

  /// Simpan password baru menggunakan reset token
  Future<String> resetPassword({
    required String email,
    required String resetToken,
    required String password,
    required String passwordConfirmation,
  }) async {
    final response = await _client.post(
      Uri.parse("$baseUrl/reset-password"),
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

    final data = jsonDecode(response.body.trim()) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data["message"] ?? "Kata sandi berhasil diperbarui.";
    }

    if (data["errors"] != null) {
      final errors = data["errors"] as Map;
      final firstError = errors.values.first;
      if (firstError is List && firstError.isNotEmpty) {
        throw Exception(firstError.first.toString());
      }
    }

    throw Exception(data["message"] ?? "Gagal memperbarui kata sandi.");
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("auth_token");

    if (token != null) {
      try {
        await _client.post(
          Uri.parse("$baseUrl/logout"),
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

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("auth_token", token);
  }

  Future<void> _saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("auth_user", jsonEncode(user));
  }
}
