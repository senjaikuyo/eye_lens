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
    });

    test('2. Konversi koordinat layar ke citra asli pada Zoom 3x', () {
      // Matriks transformasi zoom 3x
      final transformMatrix = Matrix4.diagonal3Values(3.0, 3.0, 1.0);

      // Bingkai tetap di layar (misal 150, 300 hingga 300, 600)
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
    });

    test('3. Konversi koordinat layar ke citra asli setelah digeser (Pan / Translate)', () {
      // Zoom 2x lalu digeser ke kiri 100dp dan ke atas 200dp
      final transformMatrix =
          Matrix4.diagonal3Values(2.0, 2.0, 1.0)..setTranslationRaw(-100.0, -200.0, 0.0);

      const screenRect = Rect.fromLTRB(100, 200, 300, 400);

      final imageRect = LensSelectionHelper.screenToImageCoordinates(
        screenRect: screenRect,
        transformMatrix: transformMatrix,
        viewportSize: viewportSize,
        originalImageSize: originalImageSize,
      );

      // screen = 2 * scene - 100 => scene = (screen + 100) / 2
      // sceneLeft = (100 + 100) / 2 = 100
      // sceneTop = (200 + 200) / 2 = 200
      // sceneRight = (300 + 100) / 2 = 200
      // sceneBottom = (400 + 200) / 2 = 300
      // Image = scene * 2:
      // L=200, T=400, R=400, B=600
      expect(imageRect.left, closeTo(200.0, 0.1));
      expect(imageRect.top, closeTo(400.0, 0.1));
      expect(imageRect.right, closeTo(400.0, 0.1));
      expect(imageRect.bottom, closeTo(600.0, 0.1));
    });

    test('4. Pemilihan kata: kata di dalam, di luar, dan di tepi bingkai', () {
      // Siapkan satu baris dokumen dengan 3 kata:
      // Kata 1: "Pertama" di [100, 500, 200, 550] (center: 150, 525)
      // Kata 2: "Kedua" di [220, 500, 320, 550] (center: 270, 525)
      // Kata 3: "Ketiga" di [340, 500, 440, 550] (center: 390, 525)
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

      // Baris 2 di tempat lain (di luar):
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

      // Area crop hanya mencakup "Kedua" dan sebagian "Ketiga",
      // tetapi titik tengah "Ketiga" (390) berada di luar batas kanan (350).
      // Titik tengah "Pertama" (150) berada di luar batas kiri (210).
      // Jadi HANYA "Kedua" (center: 270) yang titik tengahnya ada di dalam [210, 480, 350, 580].
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

    test('5. Fallback per-baris jika data TextElement tidak tersedia', () {
      final lineA = const OcrLineData(
        text: 'Baris Dalam',
        boundingBox: Rect.fromLTRB(100, 300, 300, 350), // center: 200, 325
        elements: [], // kosong
      );
      final lineB = const OcrLineData(
        text: 'Baris Luar',
        boundingBox: Rect.fromLTRB(100, 800, 300, 850), // center: 200, 825
        elements: [], // kosong
      );

      const crop = Rect.fromLTRB(50, 200, 400, 500);

      final result = LensSelectionHelper.selectTextInCrop(
        rawLines: [lineA, lineB],
        imageCropRect: crop,
        originalImageSize: originalImageSize,
      );

      expect(result.hasText, isTrue);
      expect(result.text, equals('Baris Dalam'));
      expect(result.text.contains('Baris Luar'), isFalse);
    });

    test('6. Area kosong menghasilkan hasText false dan penanganan tanpa teks', () {
      final line = const OcrLineData(
        text: 'Dokumen Penting',
        boundingBox: Rect.fromLTRB(100, 100, 400, 150),
        elements: [
          OcrWordData(
            text: 'Dokumen',
            boundingBox: Rect.fromLTRB(100, 100, 240, 150),
          ),
          OcrWordData(
            text: 'Penting',
            boundingBox: Rect.fromLTRB(250, 100, 400, 150),
          ),
        ],
      );

      // Area crop di bawah (kosong tanpa teks)
      const emptyCrop = Rect.fromLTRB(100, 700, 500, 900);

      final result = LensSelectionHelper.selectTextInCrop(
        rawLines: [line],
        imageCropRect: emptyCrop,
        originalImageSize: originalImageSize,
      );

      expect(result.hasText, isFalse);
      expect(result.text, isEmpty);
      expect(result.validation.hasText, isFalse);
    });

    test('7. Pengubahan ukuran bingkai (resizeFrame) mematuhi batas minimum dan viewport', () {
      const current = Rect.fromLTRB(100, 100, 300, 300);
      const bounds = Size(500, 800);

      // Seret pegangan kanan bawah sebesar (50, 50)
      final expanded = LensSelectionHelper.resizeFrame(
        currentRect: current,
        handle: LensHandlePosition.bottomRight,
        delta: const Offset(50, 50),
        boundarySize: bounds,
      );
      expect(expanded.right, equals(350));
      expect(expanded.bottom, equals(350));

      // Coba kecilkan sudut kiri atas hingga melewati batas minimum (64dp)
      final shrunk = LensSelectionHelper.resizeFrame(
        currentRect: current,
        handle: LensHandlePosition.topLeft,
        delta: const Offset(280, 280),
        boundarySize: bounds,
        minWidth: 64.0,
        minHeight: 64.0,
      );
      expect(shrunk.width, greaterThanOrEqualTo(64.0));
      expect(shrunk.height, greaterThanOrEqualTo(64.0));
    });
  });
}
