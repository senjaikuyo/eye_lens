import 'package:flutter_test/flutter_test.dart';
import 'package:eye_lens/main.dart';

void main() {
  testWidgets('EyeLens smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const EyeLensApp());
    expect(find.byType(EyeLensApp), findsOneWidget);
  });
}
