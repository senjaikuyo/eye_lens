import 'dart:io';
import 'dart:ui' as ui;

import 'package:eye_lens/models/text_formatter_models.dart';
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

  test('tile ROIs cover landscape in top-to-bottom, left-to-right order', () {
    final tiles = OcrPreprocessor.computeTileRois(const Size(1000, 500));
    expect(tiles, hasLength(4));
    expect(tiles.first.top, lessThan(tiles[2].top));
    expect(tiles[0].right, greaterThan(500));
    expect(tiles[0].left, lessThan(tiles[1].left));
    expect(tiles[0].bottom, greaterThan(250));
    expect(OcrPreprocessor.computeTileRois(Size.zero), isEmpty);
    expect(
      OcrPreprocessor.computeTileRois(
        const Size(100, 100),
        rows: 3,
        columns: 3,
      ),
      isEmpty,
    );
  });

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

    test('5. preprocessScreenText menghasilkan citra terfilter dengan dimensi yang persis sama', () async {
      final inputBytes = await createSampleImageBytes(width: 120, height: 90);
      final processedBytes = await OcrPreprocessor.preprocessScreenText(
        inputBytes,
        blurSigma: 0.8,
        contrast: 1.5,
      );

      expect(processedBytes.isNotEmpty, isTrue);
      final ui.Image decoded = await decodeImageFromList(processedBytes);
      expect(decoded.width, equals(120));
      expect(decoded.height, equals(90));
      decoded.dispose();
    });

    test('6. cropAndScaleRoi memotong dan memperbesar citra ke dimensi target secara akurat', () async {
      final inputBytes = await createSampleImageBytes(width: 100, height: 100);
      const cropRect = Rect.fromLTWH(20, 20, 40, 30);
      final croppedBytes = await OcrPreprocessor.cropAndScaleRoi(
        inputBytes,
        cropRect: cropRect,
        scale: 2.0,
      );

      expect(croppedBytes.isNotEmpty, isTrue);
      final ui.Image decoded = await decodeImageFromList(croppedBytes);
      expect(decoded.width, equals(80)); // 40 * 2.0
      expect(decoded.height, equals(60)); // 30 * 2.0
      decoded.dispose();
    });

    test('7. cropAndScaleRoi menangani cropRect yang melampaui batas citra dengan aman', () async {
      final inputBytes = await createSampleImageBytes(width: 100, height: 100);
      const overflowRect = Rect.fromLTWH(-20, -20, 150, 150);
      final croppedBytes = await OcrPreprocessor.cropAndScaleRoi(
        inputBytes,
        cropRect: overflowRect,
        scale: 1.0,
      );

      expect(croppedBytes.isNotEmpty, isTrue);
      final ui.Image decoded = await decodeImageFromList(croppedBytes);
      expect(decoded.width, equals(100));
      expect(decoded.height, equals(100));
      decoded.dispose();
    });

    test('8. computeTextRoi menghitung pembatas gabungan dengan padding yang benar', () {
      final lines = [
        const OcrLineData(
          text: 'Baris Pertama',
          boundingBox: Rect.fromLTWH(100, 200, 200, 30),
          confidence: 0.9,
          blockIndex: 0,
        ),
        const OcrLineData(
          text: 'Baris Kedua',
          boundingBox: Rect.fromLTWH(120, 250, 250, 40),
          confidence: 0.85,
          blockIndex: 0,
        ),
      ];

      final roi = OcrPreprocessor.computeTextRoi(
        lines,
        imageSize: const Size(1000, 1000),
        paddingRatio: 0.1,
      );

      expect(roi, isNotNull);
      // MinLeft: 100, MaxRight: 370 (120+250). Lebar: 270. padX: 27
      expect(roi!.left, closeTo(73.0, 0.1));
      expect(roi.right, closeTo(397.0, 0.1));
      // MinTop: 200, MaxBottom: 290 (250+40). Tinggi: 90. padY: 9
      expect(roi.top, closeTo(191.0, 0.1));
      expect(roi.bottom, closeTo(299.0, 0.1));
    });

    test('9. computeCenterRoi menghitung retikel tengah secara presisi', () {
      const imageSize = Size(1000, 800);
      final centerRoi = OcrPreprocessor.computeCenterRoi(
        imageSize,
        ratio: 0.70,
      );

      expect(centerRoi.width, equals(700.0));
      expect(centerRoi.height, equals(560.0));
      expect(centerRoi.left, equals(150.0)); // (1000 - 700) / 2
      expect(centerRoi.top, equals(120.0)); // (800 - 560) / 2
    });

    test('10. remapBoundingBox memetakan koordinat cropped & scaled ROI ke koordinat asli', () {
      const cropOffset = Offset(200, 300);
      const scale = 2.0;
      const boxInCropped = Rect.fromLTWH(100, 200, 200, 50);

      final remapped = OcrPreprocessor.remapBoundingBox(
        boxInCropped,
        cropOffset: cropOffset,
        scale: scale,
      );

      expect(remapped.left, equals(250.0)); // 200 + (100 / 2)
      expect(remapped.top, equals(400.0)); // 300 + (200 / 2)
      expect(remapped.width, equals(100.0)); // 200 / 2
      expect(remapped.height, equals(25.0)); // 50 / 2

      // Identity check
      final identity = OcrPreprocessor.remapBoundingBox(
        boxInCropped,
        cropOffset: Offset.zero,
        scale: 1.0,
      );
      expect(identity, equals(boxInCropped));
    });

    test('11. preprocessHandwriting menghasilkan citra PNG valid dengan dimensi yang sama (Issue i Phase I)', () async {
      final inputBytes = await createSampleImageBytes(width: 100, height: 80);
      final processedBytes = await OcrPreprocessor.preprocessHandwriting(
        inputBytes,
        contrast: 1.6,
        strokeThickening: true,
      );

      expect(processedBytes.isNotEmpty, isTrue);
      final ui.Image decoded = await decodeImageFromList(processedBytes);
      expect(decoded.width, equals(100));
      expect(decoded.height, equals(80));
      decoded.dispose();
    });

    test(
      '12. preprocessHandwriting mendukung strokeThickening false secara aman',
      () async {
        final inputBytes = await createSampleImageBytes(width: 80, height: 60);
        final processedBytes = await OcrPreprocessor.preprocessHandwriting(
          inputBytes,
          contrast: 1.5,
          strokeThickening: false,
        );

        expect(processedBytes.isNotEmpty, isTrue);
        final ui.Image decoded = await decodeImageFromList(processedBytes);
        expect(decoded.width, equals(80));
        expect(decoded.height, equals(60));
        decoded.dispose();
      },
    );
  });
}
