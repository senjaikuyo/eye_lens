import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:eye_lens/app/routes/app_routes.dart';
import 'package:eye_lens/app/theme/app_theme.dart';
import 'package:eye_lens/core/services/display_preferences_provider.dart';
import 'package:eye_lens/core/services/language_provider.dart';
import 'package:eye_lens/screens/splash/splash_screen.dart';

class EyeLensApp extends StatelessWidget {
  const EyeLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<DisplayPreferencesProvider>();
    final languageProvider = context.watch<LanguageProvider>();

    return MaterialApp(
      title: 'Eye Lens',
      debugShowCheckedModeBanner: false,
      locale: languageProvider.locale,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      navigatorObservers: [routeObserver],
      builder: (context, child) {
        // Support system Big Font up to 2.5x with a 1.0x floor to avoid overflow.
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
