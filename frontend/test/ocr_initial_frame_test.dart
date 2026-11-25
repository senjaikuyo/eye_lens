import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eye_lens/core/services/language_provider.dart';
import 'package:eye_lens/features/image_area/logic/lens_selection_controller.dart';
import 'package:eye_lens/features/image_area/screen/ocr_image_overlay.dart';
import 'package:eye_lens/features/speech/models/text_formatter_models.dart';

void main() {
  const imageSize = Size(1000, 1000);
  const manualCrop = Rect.fromLTWH(100, 100, 300, 300);

  for (final restore in [false, true]) {
    testWidgets(
      restore ? 'restores existing manual frame' : 'starts with entire image',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final language = LanguageProvider();
        final controller = LensSelectionController();
        if (restore) controller.setCropRect(manualCrop);
        final bytes = base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
        );
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: language,
            child: MaterialApp(
              home: Scaffold(
                body: OcrImageOverlay(
                  imageBytes: bytes,
                  imageSize: imageSize,
                  controller: controller,
                  rawLines: const [
                    OcrLineData(
                      text: 'Kelompok teks pertama',
                      boundingBox: Rect.fromLTWH(100, 100, 300, 30),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(controller.isInitialized, isTrue);
        expect(
          controller.imageCropRect,
          restore ? manualCrop : Offset.zero & imageSize,
        );
        expect(controller.isManual, restore);
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
        language.dispose();
      },
    );
  }
}
