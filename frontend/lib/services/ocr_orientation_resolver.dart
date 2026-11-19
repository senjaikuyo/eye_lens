import 'dart:ui';

import '../models/ocr_element.dart';
import '../models/text_formatter_models.dart';
import 'ocr_dictionary.dart';
import 'ocr_noise_filter.dart';

/// Deterministic orientation policy; no EXIF normalization or arbitrary deskew.
class OcrOrientationResolver {
  const OcrOrientationResolver._();
  static const sufficientScore = 35.0;
  static const maxRetries = 3;

  static List<int> retryAngles(Size size) =>
      size.width > size.height ? const [180, 90, 270] : const [180];

  static double score(Iterable<OcrLineData> lines) {
    var characters = 0;
    var singles = 0;
    var words = 0;
    var valid = 0;
    var confidenceSum = 0.0;
    var confidenceCount = 0;
    for (final line in lines) {
      characters += RegExp(r'[A-Za-z0-9]').allMatches(line.text).length;
      for (final match in RegExp(r'[A-Za-z]+').allMatches(line.text)) {
        words++;
        final word = match.group(0)!;
        if (word.length == 1) singles++;
        // Existing dictionary only; replacement with FrequencyWords belongs to K8.
        if (OcrDictionary.isValidWord(word)) valid++;
      }
      final c = line.confidence;
      if (c != null && c.isFinite && c > 0 && c <= 1) {
        confidenceSum += c;
        confidenceCount++;
      }
    }
    return characters +
        (words == 0 ? 0 : 10 * valid / words) -
        singles * 1.5 +
        (confidenceCount == 0 ? 0 : 5 * confidenceSum / confidenceCount);
  }

  static bool angleSuggestsUpsideDown(OcrResult result) {
    final angles = result.rawLines
        .map((l) => l.angle)
        .whereType<double>()
        .where((a) => a.isFinite)
        .toList();
    return angles.isNotEmpty &&
        angles.where((a) => a.abs() > 90).length > angles.length / 2;
  }

  static bool sufficient(OcrResult result) {
    return result.fullText.trim().isNotEmpty &&
        !result.hasLowQualityWarning &&
        score(result.rawLines) >= sufficientScore;
  }

  /// Inverse of a clockwise rotation, mapping image-edge coordinates exactly.
  static Rect inverseBox(Rect box, Size original, int degrees) {
    switch (degrees) {
      case 180:
        return Rect.fromLTRB(
          original.width - box.right,
          original.height - box.bottom,
          original.width - box.left,
          original.height - box.top,
        );
      case 90:
        return Rect.fromLTRB(
          box.top,
          original.height - box.right,
          box.bottom,
          original.height - box.left,
        );
      case 270:
        return Rect.fromLTRB(
          original.width - box.bottom,
          box.left,
          original.width - box.top,
          box.right,
        );
      default:
        throw ArgumentError.value(degrees, 'degrees');
    }
  }

  /// Preserve reading order and formatted offsets from the upright pass.
  static OcrResult mapResult(OcrResult result, Size original, int degrees) {
    Rect box(Rect r) => inverseBox(r, original, degrees);
    OcrLineData line(OcrLineData l) => OcrLineData(
      text: l.text,
      boundingBox: box(l.boundingBox),
      confidence: l.confidence,
      angle: l.angle == null ? null : ((l.angle! - degrees + 180) % 360) - 180,
      blockIndex: l.blockIndex,
      elements: l.elements
          .map(
            (w) => OcrWordData(
              text: w.text,
              boundingBox: box(w.boundingBox),
              confidence: w.confidence,
            ),
          )
          .toList(),
    );
    RejectedLineInfo info(RejectedLineInfo r) => RejectedLineInfo(
      line: line(r.line),
      reason: r.reason,
      explanation: r.explanation,
      suspicionScore: r.suspicionScore,
      signals: r.signals,
    );
    final doc = result.documentData;
    return OcrResult(
      fullText: result.fullText,
      imageSize: original,
      elements: result.elements
          .map(
            (e) => OcrElement(
              id: e.id,
              text: e.text,
              boundingBox: box(e.boundingBox),
            ),
          )
          .toList(),
      documentData: doc == null
          ? null
          : OcrDocumentData(
              blocks: doc.blocks
                  .map(
                    (b) => OcrBlockData(
                      text: b.text,
                      boundingBox: box(b.boundingBox),
                      lines: b.lines.map(line).toList(),
                    ),
                  )
                  .toList(),
              rawText: doc.rawText,
              allRawLines: doc.allRawLines.map(line).toList(),
            ),
      formattedResult: result.formattedResult,
      rawLines: result.rawLines.map(line).toList(),
      rawLinesCount: result.rawLinesCount,
      rejectedLines: result.rejectedLines.map(info).toList(),
      doubtfulLines: result.doubtfulLines.map(info).toList(),
      hasLowQualityWarning: result.hasLowQualityWarning,
      allLinesFilteredOut: result.allLinesFilteredOut,
      fallbackUsed: result.fallbackUsed,
    );
  }
}
