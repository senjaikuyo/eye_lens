import 'dart:ui';

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
    final originalQuarter = (estimate.quarterTurns - degrees ~/ 90 + 4) % 4;
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

  /// Memetakan kotak dari citra asli ke citra yang diputar searah jarum jam.
  static Rect rotateBox(Rect box, Size original, int degrees) {
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
          original.height - box.bottom,
          box.left,
          original.height - box.top,
          box.right,
        );
      case 270:
        return Rect.fromLTRB(
          box.top,
          original.width - box.right,
          box.bottom,
          original.width - box.left,
        );
      default:
        throw ArgumentError.value(degrees, 'degrees');
    }
  }

  /// Menyiapkan salinan hasil untuk overlay pada citra yang telah diputar.
  /// Teks terformat dipertahankan karena urutan bacanya sudah benar.
  static OcrResult rotateResultForDisplay(OcrResult result, int degrees) {
    if (degrees == 0) return result;
    final original = result.imageSize;
    Rect box(Rect value) => rotateBox(value, original, degrees);
    OcrLineData line(OcrLineData value) => OcrLineData(
      text: value.text,
      boundingBox: box(value.boundingBox),
      confidence: value.confidence,
      angle: value.angle == null
          ? null
          : ((value.angle! + degrees + 180) % 360) - 180,
      orientation: value.orientation == null
          ? null
          : TextOrientationEstimate(
              orientation: TextOrientation.fromQuarterTurns(
                value.orientation!.quarterTurns + degrees ~/ 90,
              ),
              skewDegrees: value.orientation!.skewDegrees,
              confidence: value.orientation!.confidence,
              evidence: value.orientation!.evidence,
            ),
      blockIndex: value.blockIndex,
      elements: value.elements
          .map(
            (word) => OcrWordData(
              text: word.text,
              boundingBox: box(word.boundingBox),
              confidence: word.confidence,
            ),
          )
          .toList(),
    );
    final displaySize = degrees == 180
        ? original
        : Size(original.height, original.width);
    return OcrResult(
      fullText: result.fullText,
      elements: result.elements
          .map(
            (element) => OcrElement(
              id: element.id,
              text: element.text,
              boundingBox: box(element.boundingBox),
            ),
          )
          .toList(),
      imageSize: displaySize,
      documentData: result.documentData == null
          ? null
          : OcrDocumentData(
              blocks: result.documentData!.blocks
                  .map(
                    (block) => OcrBlockData(
                      text: block.text,
                      boundingBox: box(block.boundingBox),
                      lines: block.lines.map(line).toList(),
                    ),
                  )
                  .toList(),
              rawText: result.documentData!.rawText,
              allRawLines: result.documentData!.allRawLines.map(line).toList(),
            ),
      formattedResult: result.formattedResult,
      hasLowQualityWarning: result.hasLowQualityWarning,
      rawLinesCount: result.rawLinesCount,
      rawLines: result.rawLines.map(line).toList(),
      diagnosticJson: result.diagnosticJson,
      failureType: result.failureType,
      appliedOrientationRotation: 0,
    );
  }

  /// Memetakan geometry kembali ke citra asli lalu menyusun ulang urutan baca
  /// memakai orientasi yang ikut dipetakan. Teks tidak dibalik atau diubah.
  static OcrResult mapResultBack(OcrResult result, Size original, int degrees) {
    OcrLineData line(OcrLineData l) => mapLineBack(l, original, degrees);

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
          : mappedDoc.blocks
                .expand((b) => b.lines)
                .map((l) => l.text)
                .join('\n');
    }

    return OcrResult(
      fullText: fullText,
      elements: mappedElements,
      imageSize: original,
      documentData: mappedDoc,
      formattedResult: formatted,
      hasLowQualityWarning: result.hasLowQualityWarning,
      rawLinesCount: result.rawLinesCount,
      rawLines: mappedLines,
      appliedOrientationRotation: degrees,
      diagnosticJson: result.diagnosticJson,
      failureType: result.failureType,
    );
  }
}
