import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/auth/auth_service.dart';
import '../services/database_helper.dart';
import '../services/sync_service.dart';

/// State autentikasi yang bersumber dari [AuthService].
///
/// Token disimpan di penyimpanan lokal yang tersedia (saat ini
/// SharedPreferences). Validitas token tidak diasumsikan dari keberadaannya:
/// [validateSession] memeriksa ke backend saat online dan mempertahankan sesi
/// lokal saat offline.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  int? _userId;
  String? _token;
  String? _email;
  String? _name;
  bool _loaded = false;
  bool _isOfflineSession = false;

  AuthProvider({AuthService? authService})
    : _authService = authService ?? AuthService();

  int? get userId => _userId;
  String? get token => _token;
  String? get email => _email;
  String? get name => _name;
  bool get isLoaded => _loaded;
  bool get isOfflineSession => _isOfflineSession;
  bool get isAuthenticated => _token != null && _userId != null;

  /// Memuat identitas dari sesi tersimpan dan menyelaraskan scope data lokal.
  Future<void> load() async {
    final session = await _authService.getSession();

    _applyUser(session?.user);
    _token = session?.token;
    _loaded = true;

    final dbHelper = DatabaseHelper.instance;
    if (_userId != null) {
      await dbHelper.setCurrentUserId(_userId!);
    } else {
      dbHelper.clearCurrentUser();
    }

    notifyListeners();
  }

  /// Dipanggil setelah login/register berhasil.
  Future<void> refresh() async {
    await load();
    if (isAuthenticated) {
      unawaited(SyncService().syncPending());
    }
  }

  /// Validasi sesi tersimpan ke backend.
  ///
  /// Saat offline, sesi lokal tetap dipakai agar pengguna tidak perlu login
  /// ulang hanya karena koneksi sementara terputus. Saat backend menyatakan
  /// token tidak sah (401/403), sesi lokal dibersihkan.
  Future<void> validateSession() async {
    if (!isAuthenticated) return;

    final result = await _authService.validateSession();
    switch (result) {
      case SessionValidation.valid:
        _isOfflineSession = false;
        final session = await _authService.getSession();
        _applyUser(session?.user);
        if (_userId != null) {
          await DatabaseHelper.instance.setCurrentUserId(_userId!);
        }
        notifyListeners();
        break;
      case SessionValidation.invalid:
      case SessionValidation.noSession:
        _userId = null;
        _token = null;
        _email = null;
        _name = null;
        _isOfflineSession = false;
        DatabaseHelper.instance.clearCurrentUser();
        notifyListeners();
        break;
      case SessionValidation.offline:
        _isOfflineSession = true;
        notifyListeners();
        break;
    }
  }

  void _applyUser(Map<String, dynamic>? user) {
    _userId = (user?['id'] as num?)?.toInt();
    _email = user?['email'] as String?;
    _name = user?['name'] as String?;
  }

  /// Kompatibilitas dengan pemanggil lama.
  void setAuth({required int userId, required String token}) {
    _userId = userId;
    _token = token;
    _loaded = true;
    notifyListeners();
  }

  Future<void> clear() async {
    _userId = null;
    _token = null;
    _email = null;
    _name = null;
    _isOfflineSession = false;
    _loaded = true;
    DatabaseHelper.instance.clearCurrentUser();
    notifyListeners();
  }
}
