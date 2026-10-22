import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'providers/history_provider.dart';
import 'providers/language_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/splash/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: const EyeLensApp(),
    ),
  );
}

class EyeLensApp extends StatelessWidget {
  const EyeLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final languageProvider = context.watch<LanguageProvider>();

    return MaterialApp(
      title: 'Eye Lens',
      debugShowCheckedModeBanner: false,
      locale: languageProvider.locale,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      builder: (context, child) {
        // Mendukung pembesar sistem ponsel (Big Font) hingga 2.5x (250%)
        // dengan batas minimum 1.0x agar layout tetap proporsional dan tidak overflow
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: mediaQuery.textScaler.clamp(
              minScaleFactor: 1.0,
              maxScaleFactor: 2.5,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const SplashScreen(),
    );
  }
}
