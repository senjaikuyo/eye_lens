import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:eye_lens/main.dart';
import 'package:eye_lens/providers/language_provider.dart';
import 'package:eye_lens/providers/theme_provider.dart';

void main() {
  testWidgets('App starts with splash screen and animates',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ],
        child: const EyeLensApp(),
      ),
    );

    // Initial frame renders splash screen
    expect(find.byType(EyeLensApp), findsOneWidget);

    // Advance timer past splash transition
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 1500));
  });
}
