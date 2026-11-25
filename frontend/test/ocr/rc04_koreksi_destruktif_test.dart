import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:eye_lens/features/ocr/services/ocr_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final text in [
    'Rizky Fatimah Nabila',
    'Prednison Parasetamol',
    'INDONES1A d1ter1ma k0mputer',
    'Rp 5O.OOO 14:OO O8123456789O',
    'terirna clalam welcom',
    'A4 USB3 50kg',
  ]) {
    test('service preserves ML Kit characters: $text', () async {
      const box = Rect.fromLTWH(10, 10, 300, 20);
      final recognized = RecognizedText(
        text: text,
        blocks: [
          TextBlock(
            text: text,
            boundingBox: box,
            recognizedLanguages: [],
            cornerPoints: [],
            lines: [
              TextLine(
                text: text,
                elements: [],
                boundingBox: box,
                recognizedLanguages: [],
                cornerPoints: [],
                confidence: .9,
                angle: 0,
              ),
            ],
          ),
        ],
      );
      final result = await OcrService.buildOcrResult(
        recognizedText: recognized,
        imageSize: const Size(1000, 1000),
      );
      expect(result.fullText, text);
      expect(result.elements.single.text, text);
      expect(result.documentData!.rawText, text);
      expect(result.rawLines.single.text, text);
    });
  }
}
