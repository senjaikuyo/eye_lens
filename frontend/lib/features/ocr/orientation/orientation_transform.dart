import 'dart:ui';

import 'package:eye_lens/features/ocr/correction/ocr_noise_filter.dart';
import 'package:eye_lens/features/ocr/models/ocr_element.dart';
import 'package:eye_lens/features/ocr/orientation/text_orientation.dart';
import 'package:eye_lens/features/speech/logic/text_formatter.dart';
import 'package:eye_lens/features/speech/models/text_formatter_models.dart';

/// Transformasi koordinat untuk rotasi kuartal dan pemetaan balik hasil OCR.
class OrientationTransform {
  const OrientationTransform._();

  /// Kebalikan dari rotasi searah jarum jam [degrees] pada citra asli.
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

  static TextOrientationEstimate? mapOrientationBack(
    TextOrientationEstimate? estimate,
    int degrees,
  ) {
    if (estimate == null) return null;
    final originalQuarter =
        (estimate.quarterTurns - degrees ~/ 90 + 4) % 4;
    return TextOrientationEstimate(
      orientation: TextOrientation.fromQuarterTurns(originalQuarter),
      skewDegrees: estimate.skewDegrees,
      confidence: estimate.confidence,
      evidence: [...estimate.evidence, 'mappedFromRotation_$degrees'],
    );
  }

  static OcrLineData mapLineBack(OcrLineData line, Size original, int degrees) {
    Rect box(Rect r) => inverseBox(r, original, degrees);
    return OcrLineData(
      text: line.text,
      boundingBox: box(line.boundingBox),
      confidence: line.confidence,
      angle: line.angle == null
          ? null
          : ((line.angle! - degrees + 180) % 360) - 180,
      orientation: mapOrientationBack(line.orientation, degrees),
      blockIndex: line.blockIndex,
      elements: line.elements
          .map(
            (w) => OcrWordData(
              text: w.text,
              boundingBox: box(w.boundingBox),
              confidence: w.confidence,
            ),
          )
          .toList(),
    );
  }

  /// Memetakan geometry kembali ke citra asli lalu menyusun ulang urutan baca
  /// memakai orientasi yang ikut dipetakan. Teks tidak dibalik atau diubah.
  static OcrResult mapResultBack(OcrResult result, Size original, int degrees) {
    OcrLineData line(OcrLineData l) => mapLineBack(l, original, degrees);
    RejectedLineInfo info(RejectedLineInfo r) => RejectedLineInfo(
      line: line(r.line),
      reason: r.reason,
      explanation: r.explanation,
      suspicionScore: r.suspicionScore,
      signals: r.signals,
    );

    final mappedElements = result.elements
        .map(
          (e) => OcrElement(
            id: e.id,
            text: e.text,
            boundingBox: inverseBox(e.boundingBox, original, degrees),
          ),
        )
        .toList();

    final sourceDoc = result.documentData;
    OcrDocumentData? mappedDoc;
    if (sourceDoc != null) {
      mappedDoc = OcrDocumentData(
        blocks: sourceDoc.blocks
            .map(
              (b) => OcrBlockData(
                text: b.text,
                boundingBox: inverseBox(b.boundingBox, original, degrees),
                lines: b.lines.map(line).toList(),
              ),
            )
            .toList(),
        rawText: sourceDoc.rawText,
        allRawLines: sourceDoc.allRawLines.map(line).toList(),
      );
    }

    final mappedLines = result.rawLines.map(line).toList();
    FormattedTextResult? formatted = result.formattedResult;
    var fullText = result.fullText;
    if (mappedDoc != null && mappedDoc.blocks.isNotEmpty) {
      formatted = TextFormatter.format(mappedDoc);
      fullText = formatted.fullText.isNotEmpty
          ? formatted.fullText
          : mappedDoc.blocks.expand((b) => b.lines).map((l) => l.text).join('\n');
    }

    return OcrResult(
      fullText: fullText,
      elements: mappedElements,
      imageSize: original,
      documentData: mappedDoc,
      formattedResult: formatted,
      rejectedLines: result.rejectedLines.map(info).toList(),
      doubtfulLines: result.doubtfulLines.map(info).toList(),
      fallbackUsed: result.fallbackUsed,
      hasLowQualityWarning: result.hasLowQualityWarning,
      allLinesFilteredOut: result.allLinesFilteredOut,
      rawLinesCount: result.rawLinesCount,
      rawLines: mappedLines,
      diagnosticJson: result.diagnosticJson,
      failureType: result.failureType,
    );
  }
}
