import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:eye_lens/features/ocr/services/ocr_service.dart';
import 'package:eye_lens/features/ocr/orientation/orientation_transform.dart';
import 'package:eye_lens/features/image_area/logic/lens_selection_helper.dart';
import 'package:eye_lens/features/ocr/preprocessing/ocr_preprocessor.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('DEBUG real vertical images', (tester) async {
    const paths = [
      '/data/local/tmp/eye_lens_a.jpeg',
      '/data/local/tmp/eye_lens_b.jpeg',
    ];
    final service = OcrService();
    for (final path in paths) {
      final file = File(path);
      expect(await file.exists(), isTrue, reason: 'Image missing: $path');
      final bytes = await file.readAsBytes();
      final result = await service.processImageWithCoordinates(bytes);
      // ignore: avoid_print
      print('=== FIXTURE: $path ===');
      for (final degrees in [90, 180, 270]) {
        final rotated = await OcrPreprocessor.rotate(bytes, degrees);
        final rotatedResult = await service.processImageWithCoordinates(
          rotated,
        );
        // ignore: avoid_print
        print('=== FIXTURE ROTATED $degrees ===');
        // ignore: avoid_print
        print(rotatedResult.fullText);
        for (final line in rotatedResult.rawLines) {
          // ignore: avoid_print
          print('ROTATED_$degrees=${line.text} | ${line.boundingBox}');
        }
      }

      // ignore: avoid_print
      print('=== BEFORE CORRECTION / PASS1 LINES ===');
      for (final line in result.rawLines) {
        // ignore: avoid_print
        print(
          'TEXT=${line.text} | ANGLE=${line.angle} | CONF=${line.confidence} '
          '| ORIENT=${line.orientation?.orientation.name} '
          '| EVIDENCE=${line.orientation?.evidence} '
          '| SKEW=${line.orientation?.skewDegrees} '
          '| BOX=${line.boundingBox} | WORDS=${line.elements.length}',
        );
      }
      // ignore: avoid_print
      print('=== FULL TEXT ===');
      // ignore: avoid_print
      print(result.fullText);
      final displayResult = OrientationTransform.rotateResultForDisplay(
        result,
        result.appliedOrientationRotation,
      );
      final selection = LensSelectionHelper.selectTextInCrop(
        rawLines: displayResult.rawLines,
        imageCropRect: Rect.fromLTWH(
          0,
          0,
          displayResult.imageSize.width,
          displayResult.imageSize.height,
        ),
        originalImageSize: displayResult.imageSize,
      );
      // ignore: avoid_print
      print('=== DISPLAY / FULL-FRAME SELECTION ===');
      // ignore: avoid_print
      print(
        'ROTATION=${result.appliedOrientationRotation} '
        'SIZE=${displayResult.imageSize} TEXT=${selection.text}',
      );
      for (final line in selection.acceptedLines) {
        // ignore: avoid_print
        print('DISPLAY_LINE=${line.text} | BOX=${line.boundingBox}');
      }
      // Fixture nyata dapat menampilkan teks UI tambahan; log digunakan untuk
      // membandingkan setiap pass tanpa mengasumsikan seluruh teks identik.
      // ignore: avoid_print
      print('=== FORMATTED PARAGRAPHS ===');
      for (final paragraph in result.formattedResult?.paragraphs ?? const []) {
        // ignore: avoid_print
        print(
          'PARA=${paragraph.text} | RANGE=${paragraph.startIndex}-${paragraph.endIndex}',
        );
        for (final word in paragraph.words) {
          // ignore: avoid_print
          print(
            'WORD=${word.text} | RANGE=${word.startIndex}-${word.endIndex}',
          );
        }
      }
      // ignore: avoid_print
      print('=== DIAGNOSTICS ===');
      if (result.diagnosticJson != null) {
        final json = jsonDecode(result.diagnosticJson!) as Map<String, dynamic>;
        // ignore: avoid_print
        print(const JsonEncoder.withIndent('  ').convert(json));
      } else {
        // ignore: avoid_print
        print('NO DIAGNOSTICS');
      }
    }
    await service.dispose();
  });
}
