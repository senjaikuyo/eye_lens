import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:eye_lens/services/auto_play_helper.dart';
import 'package:eye_lens/services/lens_selection_helper.dart';
import 'package:eye_lens/services/ocr_text_validator.dart';

void main() {
  group('AutoPlayHelper Unit Tests', () {
    const validResult = LensSelectionResult(
      text: 'Halo Dunia',
      acceptedLines: [],
      imageCropRect: Rect.fromLTWH(10, 10, 100, 100),
      hasText: true,
      validation: OcrTextValidationResult(
        hasText: true,
        text: 'Halo Dunia',
        reason: NoTextReason.none,
        alphanumericCount: 9,
      ),
    );

    const emptyResult = LensSelectionResult(
      text: '',
      acceptedLines: [],
      imageCropRect: Rect.fromLTWH(10, 10, 100, 100),
      hasText: false,
      validation: OcrTextValidationResult(
        hasText: false,
        text: '',
        reason: NoTextReason.rawOcrEmpty,
        alphanumericCount: 0,
      ),
    );

    test('1. Ketuk kelompok dengan sakelar aktif memicu pembacaan otomatis (speak)', () {
      final decision = AutoPlayHelper.shouldAutoPlay(
        trigger: FrameChangeTrigger.tapCluster,
        autoPlayEnabled: true,
        selectionResult: validResult,
      );
      expect(decision, equals(AutoPlayDecision.speak));
    });

    test('2. Ketuk kelompok dengan sakelar mati hanya menyiapkan teks (prepareOnly)', () {
      final decision = AutoPlayHelper.shouldAutoPlay(
        trigger: FrameChangeTrigger.tapCluster,
        autoPlayEnabled: false,
        selectionResult: validResult,
      );
      expect(decision, equals(AutoPlayDecision.prepareOnly));
    });

    test('3. Seret titik pegangan (dragHandle) dengan sakelar aktif hanya menyiapkan teks', () {
      final decision = AutoPlayHelper.shouldAutoPlay(
        trigger: FrameChangeTrigger.dragHandle,
        autoPlayEnabled: true,
        selectionResult: validResult,
      );
      expect(decision, equals(AutoPlayDecision.prepareOnly));
    });

    test('4. Menggeser bingkai (moveFrame) dengan sakelar aktif hanya menyiapkan teks', () {
      final decision = AutoPlayHelper.shouldAutoPlay(
        trigger: FrameChangeTrigger.moveFrame,
        autoPlayEnabled: true,
        selectionResult: validResult,
      );
      expect(decision, equals(AutoPlayDecision.prepareOnly));
    });

    test('5. Tombol Full image dengan sakelar aktif hanya menyiapkan teks', () {
      final decision = AutoPlayHelper.shouldAutoPlay(
        trigger: FrameChangeTrigger.fullImage,
        autoPlayEnabled: true,
        selectionResult: validResult,
      );
      expect(decision, equals(AutoPlayDecision.prepareOnly));
    });

    test('6. Muat awal gambar (initialLoad) dengan sakelar aktif hanya menyiapkan teks', () {
      final decision = AutoPlayHelper.shouldAutoPlay(
        trigger: FrameChangeTrigger.initialLoad,
        autoPlayEnabled: true,
        selectionResult: validResult,
      );
      expect(decision, equals(AutoPlayDecision.prepareOnly));
    });

    test('7. Zoom dan pan (zoomPan) dengan sakelar aktif hanya menyiapkan teks', () {
      final decision = AutoPlayHelper.shouldAutoPlay(
        trigger: FrameChangeTrigger.zoomPan,
        autoPlayEnabled: true,
        selectionResult: validResult,
      );
      expect(decision, equals(AutoPlayDecision.prepareOnly));
    });

    test('8. Ketuk kelompok saat tidak ada teks valid memicu alert teks tidak ditemukan (alertNoText)', () {
      final decision = AutoPlayHelper.shouldAutoPlay(
        trigger: FrameChangeTrigger.tapCluster,
        autoPlayEnabled: true,
        selectionResult: emptyResult,
      );
      expect(decision, equals(AutoPlayDecision.alertNoText));
    });
  });
}
