import 'dart:io';
import 'dart:ui' as ui;

import 'package:eye_lens/services/ocr_preprocessor.dart';
import 'package:eye_lens/services/ocr_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';

Future<Uint8List> createSampleImageBytes({
  int width = 100,
  int height = 100,
  Color bgColor = Colors.white,
  Color textColor = Colors.black,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
    recorder,
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
  );
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = bgColor,
  );

  final textPainter = TextPainter(
    text: TextSpan(
      text: 'EyeLens',
      style: TextStyle(
        color: textColor,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
    ),
    textDirection: TextDirection.ltr,
  );
  textPainter.layout();
  textPainter.paint(canvas, const Offset(10, 10));

  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return byteData!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    const MethodChannel channel = MethodChannel(
      'plugins.flutter.io/path_provider',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'getTemporaryDirectory') {
            return Directory.systemTemp.path;
          }
          return null;
        });
  });

  group('OcrPreprocessor Unit Tests', () {
    test(
      '1. calculateOtsuThreshold memisahkan distribusi bimodal secara akurat',
      () {
        // Buat 100 piksel gelap (lum ~30) dan 100 piksel terang (lum ~220)
        const int numDark = 100;
        const int numLight = 100;
        final pixels = Uint8List((numDark + numLight) * 4);

        for (int i = 0; i < numDark; i++) {
          final offset = i * 4;
          pixels[offset] = 30; // R
          pixels[offset + 1] = 30; // G
          pixels[offset + 2] = 30; // B
          pixels[offset + 3] = 255; // A
        }
        for (int i = 0; i < numLight; i++) {
          final offset = (numDark + i) * 4;
          pixels[offset] = 220;
          pixels[offset + 1] = 220;
          pixels[offset + 2] = 220;
          pixels[offset + 3] = 255;
        }

        final threshold = OcrPreprocessor.calculateOtsuThreshold(
          pixels,
          numDark + numLight,
        );
        expect(threshold, greaterThanOrEqualTo(30.0));
        expect(threshold, lessThanOrEqualTo(220.0));
      },
    );

    test(
      '2. enhanceContrast menghasilkan byte PNG valid dengan dimensi yang sama',
      () async {
        final inputBytes = await createSampleImageBytes(width: 80, height: 60);
        final enhancedBytes = await OcrPreprocessor.enhanceContrast(
          inputBytes,
          contrast: 1.8,
        );

        expect(enhancedBytes.isNotEmpty, isTrue);
        final ui.Image decoded = await decodeImageFromList(enhancedBytes);
        expect(decoded.width, equals(80));
        expect(decoded.height, equals(60));
        decoded.dispose();
      },
    );

    test(
      '3. binarizeOtsu menghasilkan citra terbinarisasi dengan piksel murni',
      () async {
        final inputBytes = await createSampleImageBytes(width: 50, height: 50);
        final binarizedBytes = await OcrPreprocessor.binarizeOtsu(inputBytes);

        expect(binarizedBytes.isNotEmpty, isTrue);
        final ui.Image decoded = await decodeImageFromList(binarizedBytes);
        expect(decoded.width, equals(50));
        expect(decoded.height, equals(50));

        final rawData = await decoded.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        decoded.dispose();
        final pixels = rawData!.buffer.asUint8List();

        // Setiap piksel RGB harus bernilai 0 atau 255 setelah binarisasi
        for (int i = 0; i < pixels.length; i += 4) {
          final r = pixels[i];
          final g = pixels[i + 1];
          final b = pixels[i + 2];
          expect(r == 0 || r == 255, isTrue);
          expect(g == 0 || g == 255, isTrue);
          expect(b == 0 || b == 255, isTrue);
        }
      },
    );

    test('4. purgeOrphanedCache membersihkan file ocr_ephemeral_* tanpa menyentuh file lain', () async {
      final tempDir = await getTemporaryDirectory();
      final ephemeralFile = File(
        '${tempDir.path}/ocr_ephemeral_test_orphan.jpg',
      );
      final normalFile = File('${tempDir.path}/safe_keep_file.txt');

      await ephemeralFile.writeAsString('cache data');
      await normalFile.writeAsString('permanent data');

      expect(await ephemeralFile.exists(), isTrue);
      expect(await normalFile.exists(), isTrue);

      await OcrService.purgeOrphanedCache();

      expect(
        await ephemeralFile.exists(),
        isFalse,
        reason: 'ocr_ephemeral_* harus terhapus',
      );
      expect(
        await normalFile.exists(),
        isTrue,
        reason: 'file lain tidak boleh terhapus',
      );

      await normalFile.delete();
    });
  });
}
