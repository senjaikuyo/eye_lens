import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:eye_lens/features/ocr/services/ocr_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('DEBUG G033 180 real image', (tester) async {
    const path = '/data/local/tmp/eye_lens_g033_180.png';
    final file = File(path);
    expect(await file.exists(), isTrue, reason: 'Image missing: $path');
    final bytes = await file.readAsBytes();

    final service = OcrService();
    final result = await service.processImageWithCoordinates(bytes);

    // ignore: avoid_print
    print('=== G033 PASS RESULT ===');
    // ignore: avoid_print
    print('FULL TEXT:\n${result.fullText}');
    // ignore: avoid_print
    print('=== RAW LINES ===');
    for (final line in result.rawLines) {
      // ignore: avoid_print
      print(
        'TEXT=${line.text} | ANGLE=${line.angle} | CONF=${line.confidence} '
        '| ORIENT=${line.orientation?.orientation.name} '
        '| BOX=${line.boundingBox}',
      );
    }
    // ignore: avoid_print
    print('=== DIAGNOSTICS ===');
    if (result.diagnosticJson != null) {
      final json = jsonDecode(result.diagnosticJson!) as Map<String, dynamic>;
      // ignore: avoid_print
      print(const JsonEncoder.withIndent('  ').convert(json));
    }

    await service.dispose();
  });
}
