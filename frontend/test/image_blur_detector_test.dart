import 'package:flutter/foundation.dart';

import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:eye_lens/services/image_blur_detector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Map<String, Object> raster({required bool edges}) {
    const width = 32;
    const height = 32;
    final rgba = Uint8List(width * height * 4);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final i = (y * width + x) * 4;
        final value = edges ? ((x ~/ 4).isEven ? 0 : 255) : 128;
        rgba[i] = rgba[i + 1] = rgba[i + 2] = value;
        rgba[i + 3] = 255;
      }
    }
    return {'rgba': rgba, 'width': width, 'height': height};
  }

  test(
    'flat raster has zero variance; synthetic edges have higher variance',
    () async {
      final flat = await compute(
        ImageBlurDetector.measureRgba,
        raster(edges: false),
      );
      final sharp = await compute(
        ImageBlurDetector.measureRgba,
        raster(edges: true),
      );
      expect(flat['laplacianVariance'], 0);
      expect(sharp['laplacianVariance'] as double, greaterThan(0));
      expect(flat['meanLuminance'] as double, closeTo(128, .001));
      expect(sharp['warningThreshold'], isNull);
      expect(sharp['analysisWidth'], 32);
    },
  );

  test('invalid raster is rejected', () {
    expect(
      () => ImageBlurDetector.measureRgba({
        'rgba': Uint8List(4),
        'width': 3,
        'height': 3,
      }),
      throwsArgumentError,
    );
  });

  testWidgets(
    'bounded native decode measures image without changing input bytes',
    (tester) async {
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.drawColor(const ui.Color(0xFF808080), ui.BlendMode.src);
        final picture = recorder.endRecording();
        final image = await picture.toImage(800, 400);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final bytes = data!.buffer.asUint8List();
        try {
          final original = Uint8List.fromList(bytes);
          final metrics = await ImageBlurDetector.measure(bytes);
          expect(metrics['analysisWidth'], 640);
          expect(metrics['analysisHeight'], 320);
          expect(metrics['encodedPixelWidth'], 800);
          expect(metrics['encodedPixelHeight'], 400);
          expect(metrics['laplacianVariance'], 0);
          expect(await ImageBlurDetector.boundGalleryImage(bytes), same(bytes));
          expect(bytes, original);
        } finally {
          image.dispose();
          picture.dispose();
        }
      });
    },
  );
}
