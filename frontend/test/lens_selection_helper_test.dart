import 'package:eye_lens/models/text_formatter_models.dart';
import 'package:eye_lens/services/lens_selection_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LensSelectionHelper Unit Tests', () {
    const originalImageSize = Size(1000, 2000); // Rasio 1:2
    const viewportSize = Size(500, 1000); // Rasio pas 1:2, skala contain = 0.5

    test('1. Konversi koordinat layar ke citra asli pada Zoom 1x', () {
      final transformMatrix = Matrix4.identity();

      // Bingkai di tengah layar: (100, 200) hingga (400, 800)
      const screenRect = Rect.fromLTRB(100, 200, 400, 800);

      final imageRect = LensSelectionHelper.screenToImageCoordinates(
        screenRect: screenRect,
        transformMatrix: transformMatrix,
        viewportSize: viewportSize,
        originalImageSize: originalImageSize,
      );

      // Skala BoxFit.contain = 500 / 1000 = 0.5. offsetX = 0, offsetY = 0.
      // img = screen / 0.5 = screen * 2
      expect(imageRect.left, closeTo(200.0, 0.1));
      expect(imageRect.top, closeTo(400.0, 0.1));
      expect(imageRect.right, closeTo(800.0, 0.1));
      expect(imageRect.bottom, closeTo(1600.0, 0.1));

      // Konversi balik citra -> layar harus kembali persis
      final roundTripScreen = LensSelectionHelper.imageToScreenCoordinates(
        imageRect: imageRect,
        transformMatrix: transformMatrix,
        viewportSize: viewportSize,
        originalImageSize: originalImageSize,
      );
      expect(roundTripScreen.left, closeTo(screenRect.left, 0.1));
      expect(roundTripScreen.top, closeTo(screenRect.top, 0.1));
      expect(roundTripScreen.right, closeTo(screenRect.right, 0.1));
      expect(roundTripScreen.bottom, closeTo(screenRect.bottom, 0.1));
    });

    test('2. Konversi koordinat layar ke citra asli pada Zoom 3x', () {
      // Matriks transformasi zoom 3x
      final transformMatrix = Matrix4.diagonal3Values(3.0, 3.0, 1.0);

      const screenRect = Rect.fromLTRB(150, 300, 300, 600);

      final imageRect = LensSelectionHelper.screenToImageCoordinates(
        screenRect: screenRect,
        transformMatrix: transformMatrix,
        viewportSize: viewportSize,
        originalImageSize: originalImageSize,
      );

      // Scene = screen / 3.0 -> L=50, T=100, R=100, B=200
      // Image = scene / 0.5 = scene * 2 -> L=100, T=200, R=200, B=400
      expect(imageRect.left, closeTo(100.0, 0.1));
      expect(imageRect.top, closeTo(200.0, 0.1));
      expect(imageRect.right, closeTo(200.0, 0.1));
      expect(imageRect.bottom, closeTo(400.0, 0.1));

      // Konversi balik citra -> layar pada zoom 3x
      final roundTripScreen = LensSelectionHelper.imageToScreenCoordinates(
        imageRect: imageRect,
        transformMatrix: transformMatrix,
        viewportSize: viewportSize,
        originalImageSize: originalImageSize,
      );
      expect(roundTripScreen.left, closeTo(screenRect.left, 0.1));
      expect(roundTripScreen.top, closeTo(screenRect.top, 0.1));
      expect(roundTripScreen.right, closeTo(screenRect.right, 0.1));
      expect(roundTripScreen.bottom, closeTo(screenRect.bottom, 0.1));
    });

    test('3. Konversi koordinat layar ke citra asli setelah digeser (Pan / Translate)', () {
      // Zoom 2x lalu digeser ke kiri 100dp dan ke atas 200dp
      final transformMatrix = Matrix4.diagonal3Values(2.0, 2.0, 1.0)
        ..setTranslationRaw(-100.0, -200.0, 0.0);

      const screenRect = Rect.fromLTRB(100, 200, 300, 400);

      final imageRect = LensSelectionHelper.screenToImageCoordinates(
        screenRect: screenRect,
        transformMatrix: transformMatrix,
        viewportSize: viewportSize,
        originalImageSize: originalImageSize,
      );

      // L=200, T=400, R=400, B=600
      expect(imageRect.left, closeTo(200.0, 0.1));
      expect(imageRect.top, closeTo(400.0, 0.1));
      expect(imageRect.right, closeTo(400.0, 0.1));
      expect(imageRect.bottom, closeTo(600.0, 0.1));

      // Konversi balik citra -> layar setelah digeser
      final roundTripScreen = LensSelectionHelper.imageToScreenCoordinates(
        imageRect: imageRect,
        transformMatrix: transformMatrix,
        viewportSize: viewportSize,
        originalImageSize: originalImageSize,
      );
      expect(roundTripScreen.left, closeTo(screenRect.left, 0.1));
      expect(roundTripScreen.top, closeTo(screenRect.top, 0.1));
      expect(roundTripScreen.right, closeTo(screenRect.right, 0.1));
      expect(roundTripScreen.bottom, closeTo(screenRect.bottom, 0.1));
    });

    test('4. resizeImageFrame memastikan bingkai tidak pernah keluar dari batas gambar', () {
      final transformMatrix = Matrix4.identity();
      const initialImageRect = Rect.fromLTRB(100, 100, 500, 500);

      // Coba seret sudut kanan bawah jauh melewati batas gambar (misal delta layar sangat besar)
      final expandedOut = LensSelectionHelper.resizeImageFrame(
        currentImageRect: initialImageRect,
        handle: LensHandlePosition.bottomRight,
        deltaScreen: const Offset(5000, 5000),
        transformMatrix: transformMatrix,
        viewportSize: viewportSize,
        originalImageSize: originalImageSize,
      );

      // Batas kanan citra asli adalah 1000, batas bawah 2000
      expect(expandedOut.right, lessThanOrEqualTo(originalImageSize.width));
      expect(expandedOut.bottom, lessThanOrEqualTo(originalImageSize.height));
      expect(expandedOut.left, greaterThanOrEqualTo(0.0));
      expect(expandedOut.top, greaterThanOrEqualTo(0.0));

      // Coba seret sudut kiri atas jauh ke negatif
      final expandedNeg = LensSelectionHelper.resizeImageFrame(
        currentImageRect: initialImageRect,
        handle: LensHandlePosition.topLeft,
        deltaScreen: const Offset(-5000, -5000),
        transformMatrix: transformMatrix,
        viewportSize: viewportSize,
        originalImageSize: originalImageSize,
      );
      expect(expandedNeg.left, equals(0.0));
      expect(expandedNeg.top, equals(0.0));
    });

    test('5. kMinFrameSize 64 dp ditegakkan sesuai skala transformasi zoom', () {
      final zoom1x = Matrix4.identity();
      final zoom3x = Matrix4.diagonal3Values(3.0, 3.0, 1.0);

      const initialImageRect = Rect.fromLTRB(200, 200, 600, 600);

      // Pada zoom 1x: skala total = 0.5 (contain). 64 dp di layar = 64 / 0.5 = 128 px di citra.
      final shrunk1x = LensSelectionHelper.resizeImageFrame(
        currentImageRect: initialImageRect,
        handle: LensHandlePosition.bottomRight,
        deltaScreen: const Offset(-800, -800), // coba ciutkan sekecil mungkin
        transformMatrix: zoom1x,
        viewportSize: viewportSize,
        originalImageSize: originalImageSize,
        minFrameSizeDp: 64.0,
      );
      expect(shrunk1x.width, closeTo(128.0, 0.1));
      expect(shrunk1x.height, closeTo(128.0, 0.1));

      // Pada zoom 3x: skala total = 0.5 * 3 = 1.5. 64 dp di layar = 64 / 1.5 = 42.67 px di citra.
      final shrunk3x = LensSelectionHelper.resizeImageFrame(
        currentImageRect: initialImageRect,
        handle: LensHandlePosition.bottomRight,
        deltaScreen: const Offset(-800, -800), // coba ciutkan sekecil mungkin
        transformMatrix: zoom3x,
        viewportSize: viewportSize,
        originalImageSize: originalImageSize,
        minFrameSizeDp: 64.0,
      );
      expect(shrunk3x.width, closeTo(64.0 / 1.5, 0.1));
      expect(shrunk3x.height, closeTo(64.0 / 1.5, 0.1));
    });

    test('6. Pemilihan kata: kata di dalam, di luar, dan di tepi bingkai', () {
      final line1 = OcrLineData(
        text: 'Pertama Kedua Ketiga',
        boundingBox: const Rect.fromLTRB(100, 500, 440, 550),
        elements: const [
          OcrWordData(
            text: 'Pertama',
            boundingBox: Rect.fromLTRB(100, 500, 200, 550),
          ),
          OcrWordData(
            text: 'Kedua',
            boundingBox: Rect.fromLTRB(220, 500, 320, 550),
          ),
          OcrWordData(
            text: 'Ketiga',
            boundingBox: Rect.fromLTRB(340, 500, 440, 550),
          ),
        ],
      );

      final line2 = OcrLineData(
        text: 'Teks Luar Jauh',
        boundingBox: const Rect.fromLTRB(100, 900, 300, 950),
        elements: const [
          OcrWordData(
            text: 'Teks',
            boundingBox: Rect.fromLTRB(100, 900, 160, 950),
          ),
          OcrWordData(
            text: 'Luar',
            boundingBox: Rect.fromLTRB(170, 900, 230, 950),
          ),
          OcrWordData(
            text: 'Jauh',
            boundingBox: Rect.fromLTRB(240, 900, 300, 950),
          ),
        ],
      );

      // Area crop hanya mencakup "Kedua" (center: 270)
      const cropRect = Rect.fromLTRB(210, 480, 350, 580);

      final result = LensSelectionHelper.selectTextInCrop(
        rawLines: [line1, line2],
        imageCropRect: cropRect,
        originalImageSize: originalImageSize,
      );

      expect(result.hasText, isTrue);
      expect(result.text, equals('Kedua'));
      expect(result.text.contains('Pertama'), isFalse);
      expect(result.text.contains('Ketiga'), isFalse);
      expect(result.text.contains('Luar'), isFalse);
    });

    test('7. Area kosong atau < 2 huruf/angka menghasilkan hasText false', () {
      final lineSymbol = const OcrLineData(
        text: '!',
        boundingBox: Rect.fromLTRB(100, 100, 150, 150),
        elements: [
          OcrWordData(
            text: '!',
            boundingBox: Rect.fromLTRB(100, 100, 150, 150),
          ),
        ],
      );

      const symbolCrop = Rect.fromLTRB(50, 50, 200, 200);

      final result = LensSelectionHelper.selectTextInCrop(
        rawLines: [lineSymbol],
        imageCropRect: symbolCrop,
        originalImageSize: originalImageSize,
      );

      // Kurang dari 2 huruf/angka -> hasText false
      expect(result.hasText, isFalse);
      expect(result.validation.alphanumericCount, equals(0));
    });
  });
}
