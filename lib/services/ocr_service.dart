import 'dart:ui';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class DetectedWord {
  final String text;
  final Rect boundingBox;

  DetectedWord({required this.text, required this.boundingBox});
}

class OcrResult {
  final String fullText;
  final List<DetectedWord> words;
  final Size imageSize;

  OcrResult({
    required this.fullText,
    required this.words,
    required this.imageSize,
  });

  bool get isEmpty => fullText.trim().isEmpty;
}

class OcrService {
  final TextRecognizer _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<OcrResult> processImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _recognizer.processImage(inputImage);

      final List<DetectedWord> words = [];
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          for (final element in line.elements) {
            words.add(DetectedWord(
              text: element.text,
              boundingBox: element.boundingBox,
            ));
          }
        }
      }

      // Default estimate if not provided
      final size = Size(
        inputImage.metadata?.size.width ?? 1080,
        inputImage.metadata?.size.height ?? 1920,
      );

      return OcrResult(
        fullText: recognizedText.text,
        words: words,
        imageSize: size,
      );
    } catch (e) {
      return OcrResult(
        fullText: '',
        words: [],
        imageSize: const Size(1080, 1920),
      );
    }
  }

  void dispose() {
    _recognizer.close();
  }
}
