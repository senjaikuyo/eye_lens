import 'package:eye_lens/services/lens_selection_controller.dart';
import 'package:eye_lens/services/lens_selection_helper.dart';
import 'package:eye_lens/services/ocr_text_validator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LensSelectionController Unit Tests', () {
    test('1. Inisialisasi awal controller dan update state crop rect', () {
      final controller = LensSelectionController();
      expect(controller.isInitialized, isFalse);
      expect(controller.imageCropRect, equals(Rect.zero));
      expect(controller.isManual, isFalse);

      const initialRect = Rect.fromLTWH(50, 50, 300, 200);
      controller.markInitialized(initialRect);

      expect(controller.isInitialized, isTrue);
      expect(controller.imageCropRect, equals(initialRect));
      expect(controller.isManual, isFalse);

      // Ubah manual melalui handle dragging
      const manualRect = Rect.fromLTWH(40, 40, 320, 220);
      controller.setCropRect(manualRect, isManual: true);
      expect(controller.imageCropRect, equals(manualRect));
      expect(controller.isManual, isTrue);

      // Pindah ke cluster lain mengembalikan isManual ke false
      const clusterRect = Rect.fromLTWH(100, 500, 400, 300);
      controller.animateToCluster(clusterRect);
      expect(controller.imageCropRect, equals(clusterRect));
      expect(controller.isManual, isFalse);

      controller.dispose();
    });

    test('2. Reset ke full image mempertahankan status isManual false', () {
      final controller = LensSelectionController();
      controller.resetToFullImage(const Size(1080, 1920));

      expect(controller.imageCropRect, equals(const Rect.fromLTWH(0, 0, 1080, 1920)));
      expect(controller.isManual, isFalse);
      expect(controller.transformMatrix, equals(Matrix4.identity()));

      controller.dispose();
    });

    test('3. Cache hasil seleksi teks dan evaluasi shouldRecompute', () {
      final controller = LensSelectionController();
      const rectA = Rect.fromLTWH(100, 100, 200, 200);
      const rectB = Rect.fromLTWH(105, 105, 200, 200);

      expect(controller.shouldRecompute(rectA), isTrue);

      const dummyResult = LensSelectionResult(
        text: 'Halo Dunia',
        formattedResult: null,
        acceptedLines: [],
        imageCropRect: rectA,
        validation: OcrTextValidationResult(
          hasText: true,
          reason: NoTextReason.none,
          alphanumericCount: 9,
          text: 'Halo Dunia',
        ),
        hasText: true,
      );

      controller.cacheResult(dummyResult, rectA);
      expect(controller.cachedResult, equals(dummyResult));
      expect(controller.shouldRecompute(rectA), isFalse);
      expect(controller.shouldRecompute(rectB), isTrue);

      controller.dispose();
    });
  });
}
