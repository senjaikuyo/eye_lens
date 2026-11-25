import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eye_lens/features/ocr/preprocessing/ocr_preprocessor.dart';
import 'package:eye_lens/features/ocr/services/ocr_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final degrees in [90, 180, 270]) {
    test(
      'rotation $degrees preserves image dimensions and pixel positions',
      () async {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.drawRect(
          const ui.Rect.fromLTWH(0, 0, 20, 10),
          ui.Paint()..color = const ui.Color(0xFFFFFFFF),
        );
        canvas.drawRect(
          const ui.Rect.fromLTWH(0, 0, 5, 5),
          ui.Paint()..color = const ui.Color(0xFF000000),
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(20, 10);
        final encoded = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        picture.dispose();
        final result = await OcrPreprocessor.rotate(
          encoded!.buffer.asUint8List(),
          degrees,
        );
        final decoded = await decodeImageFromList(result);
        try {
          expect(decoded.width, degrees == 180 ? 20 : 10);
          expect(decoded.height, degrees == 180 ? 10 : 20);
          final data = await decoded.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          final x = degrees == 270 ? 2 : decoded.width - 3;
          final y = degrees == 90 ? 2 : decoded.height - 3;
          expect(data!.getUint8((y * decoded.width + x) * 4), 0);
        } finally {
          decoded.dispose();
        }
      },
    );
  }

  test('orphan cleanup removes only OCR-prefixed files', () async {
    final directory = await Directory.systemTemp.createTemp('eyelens_cleanup_');
    // The fallback system temp directory is searched by the service.
    final orphan = File(
      '${Directory.systemTemp.path}/ocr_ephemeral_stage6.jpg',
    );
    final keep = File('${directory.path}/keep.txt');
    try {
      await orphan.writeAsString('temporary');
      await keep.writeAsString('keep');
      await OcrService.purgeOrphanedCache();
      expect(await orphan.exists(), isFalse);
      expect(await keep.exists(), isTrue);
    } finally {
      if (await orphan.exists()) await orphan.delete();
      if (await keep.exists()) await keep.delete();
      await directory.delete();
    }
  });
}
