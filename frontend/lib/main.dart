import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:eye_lens/app/app.dart';
import 'package:eye_lens/core/services/auth_provider.dart';
import 'package:eye_lens/core/services/display_preferences_provider.dart';
import 'package:eye_lens/core/services/image_cache_cleanup.dart';
import 'package:eye_lens/core/services/language_provider.dart';
import 'package:eye_lens/core/services/sync_coordinator.dart';
import 'package:eye_lens/features/history/logic/history_provider.dart';
import 'package:eye_lens/features/settings/logic/pengaturan_service.dart';
import 'package:eye_lens/features/settings/logic/settings_provider.dart';
import 'package:eye_lens/features/ocr/services/ocr_service.dart';

export 'package:eye_lens/app/routes/app_routes.dart' show routeObserver;
export 'package:eye_lens/app/app.dart' show EyeLensApp;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(_runStartupCleanup());
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Sesi pengguna dimuat lebih dulu agar scope data lokal (user_id) benar
  // sebelum provider lain membaca database.
  final authProvider = AuthProvider();
  await authProvider.load();

  // Migrasi pengaturan lama dari SharedPreferences sebelum provider membaca
  // SQLite. Kegagalan migrasi tidak boleh mencegah aplikasi dibuka.
  try {
    await PengaturanService.instance.migrateLegacyPreferences();
  } catch (e) {
    debugPrint('Legacy preference migration failed: ${e.runtimeType}');
  }

  // Validasi token tersimpan saat online; saat offline sesi lokal dipertahankan.
  unawaited(authProvider.validateSession());

  final syncCoordinator = SyncCoordinator(
    onConnectivityRestored: authProvider.validateSession,
  );
  syncCoordinator.start();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => DisplayPreferencesProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: const EyeLensApp(),
    ),
  );
}

Future<void> _runStartupCleanup() async {
  try {
    await OcrService.purgeOrphanedCache();
  } catch (e) {
    debugPrint('OCR cache cleanup error: $e');
  }
  try {
    await ImageCacheCleanup.purgeOrphans();
  } catch (e) {
    debugPrint('Image cache cleanup error: $e');
  }
}
