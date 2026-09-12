import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'providers/camera_provider.dart';
import 'providers/history_provider.dart';
import 'providers/reader_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/camera_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set default system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const EyeLensApp());
}

class EyeLensApp extends StatelessWidget {
  const EyeLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => CameraProvider()),
        ChangeNotifierProvider(create: (_) => ReaderProvider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {
          final fontMultiplier = settingsProvider.settings.fontSizeMultiplier;
          final isDark = settingsProvider.isDarkMode;

          return MaterialApp(
            title: 'EyeLens',
            debugShowCheckedModeBanner: false,
            themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
            theme: AppTheme.lightTheme(fontMultiplier),
            darkTheme: AppTheme.darkTheme(fontMultiplier),
            home: const CameraScreen(),
          );
        },
      ),
    );
  }
}
