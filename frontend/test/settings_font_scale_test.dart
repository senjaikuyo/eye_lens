import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eye_lens/providers/language_provider.dart';
import 'package:eye_lens/providers/settings_provider.dart';
import 'package:eye_lens/providers/theme_provider.dart';
import 'package:eye_lens/screens/settings/settings_screen.dart';

Widget createTestSettingsApp({required double textScaleFactor}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ChangeNotifierProvider(create: (_) => SettingsProvider()),
    ],
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(textScaleFactor),
          size: const Size(400, 800),
        ),
        child: const SettingsScreen(),
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SettingsScreen Font Scale & Switch Tests', () {
    testWidgets('1. Skala font 1.0x merender sakelar tanpa overflow dan dapat ditekan', (tester) async {
      await tester.pumpWidget(createTestSettingsApp(textScaleFactor: 1.0));
      await tester.pumpAndSettle();

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      final switchWidget = tester.widget<Switch>(switchFinder);
      expect(switchWidget.value, isTrue);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      final updatedSwitch = tester.widget<Switch>(switchFinder);
      expect(updatedSwitch.value, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('2. Skala font 1.5x merender sakelar tanpa overflow dan dapat ditekan', (tester) async {
      await tester.pumpWidget(createTestSettingsApp(textScaleFactor: 1.5));
      await tester.pumpAndSettle();

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      final switchWidget = tester.widget<Switch>(switchFinder);
      expect(switchWidget.value, isTrue);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      final updatedSwitch = tester.widget<Switch>(switchFinder);
      expect(updatedSwitch.value, isFalse);
      expect(tester.takeException(), isNull);
    });
  });
}
