import "dart:convert";

import "package:http/http.dart" as http;
import "package:shared_preferences/shared_preferences.dart";

class AuthService {
  static const String baseUrl = "http://127.0.0.1:8000/api";

  String _cleanJson(String body) {
    String cleaned = body.replaceAll("\ufeff", "").trim();
    final objStart = cleaned.indexOf("{");
    final arrStart = cleaned.indexOf("[");
    int start = -1;
    if (objStart >= 0 && arrStart >= 0) {
      start = objStart < arrStart ? objStart : arrStart;
    } else if (objStart >= 0) {
      start = objStart;
    } else if (arrStart >= 0) {
      start = arrStart;
    }
    if (start > 0) {
      cleaned = cleaned.substring(start);
    }
    final objEnd = cleaned.lastIndexOf("}");
    final arrEnd = cleaned.lastIndexOf("]");
    int end = -1;
    if (objEnd >= 0 && arrEnd >= 0) {
      end = objEnd > arrEnd ? objEnd : arrEnd;
    } else if (objEnd >= 0) {
      end = objEnd;
    } else if (arrEnd >= 0) {
      end = arrEnd;
    }
    if (end >= 0 && end + 1 < cleaned.length) {
      cleaned = cleaned.substring(0, end + 1);
    }
    return cleaned;
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final response = await http.post(
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

    final data = jsonDecode(_cleanJson(response.body));

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
    final response = await http.post(
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

    final data = jsonDecode(_cleanJson(response.body));

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

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
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
