import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:eye_lens/app/app.dart';
import 'package:eye_lens/core/services/display_preferences_provider.dart';
import 'package:eye_lens/core/services/image_cache_cleanup.dart';
import 'package:eye_lens/core/services/language_provider.dart';
import 'package:eye_lens/providers/history_provider.dart';
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
  runApp(
    MultiProvider(
      providers: [
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
