import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:eye_lens/models/text_formatter_models.dart';
import 'package:eye_lens/models/ocr_element.dart';
import 'package:eye_lens/services/ocr_noise_filter.dart';
import 'package:eye_lens/services/text_formatter.dart';

void main() {
  const size = Size(1000, 1000);
  OcrLineData line(
    String text, {
    double? confidence,
    double x = 100,
    double y = 100,
    double height = 30,
  }) => OcrLineData(
    text: text,
    confidence: confidence,
    boundingBox: Rect.fromLTWH(x, y, 150, height),
  );
  NoiseFilterResult filter(
    List<OcrLineData> lines, {
    OcrNoiseFilterConfig config = const OcrNoiseFilterConfig(),
  }) => OcrNoiseFilter.filter(lines: lines, imageSize: size, config: config);

  test('null and zero confidence are unavailable, not low confidence', () {
    for (final confidence in <double?>[
      null,
      0,
      .3,
      double.nan,
      double.infinity,
    ]) {
      final result = filter([
        line('Valid complete sentence', confidence: confidence),
      ]);
      expect(result.acceptedLines, hasLength(1));
      expect(result.doubtfulLines, isEmpty);
      expect(result.rejectedLines, isEmpty);
    }
  });

  test(
    'one weak confidence, size, position or distance signal preserves text',
    () {
      final lines = [
        line('Main document paragraph'),
        line('Another document paragraph', y: 140),
        line('Small but valid footnote', y: 180, height: 2),
        line('Text touching left edge', x: 0, y: 220),
        line('Text touching right edge', x: 850, y: 260),
        line('artifak', y: 850),
        line('Low confidence sentence', y: 300, confidence: .2),
      ];
      final result = filter(lines);
      expect(result.acceptedLines, orderedEquals(lines));
      expect(result.rejectedLines, isEmpty);
      expect(result.doubtfulLines, isEmpty);
    },
  );

  test('combined signals quarantine separately, never hard reject', () {
    final suspect = line('ab###', confidence: .2, x: 0, y: 850, height: 2);
    final result = filter([
      line('Main paragraph'),
      line('Another paragraph', y: 140),
      suspect,
    ]);
    expect(result.acceptedLines, hasLength(2));
    expect(result.rejectedLines, isEmpty);
    final doubtful = result.doubtfulLines.single;
    expect(doubtful.line, same(suspect));
    expect(doubtful.reason, NoiseRejectionReason.combinedSuspicion);
    expect(
      doubtful.signals,
      containsAll([
        NoiseRejectionReason.lowConfidence,
        NoiseRejectionReason.tooSmall,
        NoiseRejectionReason.lowAlphaNumericRatio,
        NoiseRejectionReason.edgeBoundary,
        NoiseRejectionReason.isolated,
      ]),
    );
    expect(doubtful.suspicionScore, greaterThanOrEqualTo(2.5));
    expect(result.hasLowQualityWarning, isTrue);
  });

  test(
    'edge plus low ratio can be doubtful, edge with normal ratio survives',
    () {
      final result = filter([
        line('ab####', x: 0),
        line('Valid edge text', x: 0, y: 140),
      ], config: const OcrNoiseFilterConfig(doubtfulThreshold: 2));
      expect(result.acceptedLines.single.text, 'Valid edge text');
      expect(
        result.doubtfulLines.single.signals,
        contains(NoiseRejectionReason.edgeBoundary),
      );
      expect(result.rejectedLines, isEmpty);
    },
  );

  test('even a high single weight cannot quarantine without corroboration', () {
    final result = filter([
      line('Complete sentence', confidence: .1),
    ], config: const OcrNoiseFilterConfig(confidenceWeight: 100));
    expect(result.acceptedLines, hasLength(1));
  });

  test('hard rules reject empty, pure symbols and isolated single letters', () {
    final result = filter([
      line('   '),
      line('~~~|---', y: 200),
      line('Z', y: 850),
    ]);
    expect(result.acceptedLines, isEmpty);
    expect(
      result.rejectedLines.map((r) => r.reason),
      orderedEquals([
        NoiseRejectionReason.emptyOrWhitespace,
        NoiseRejectionReason.symbolOnly,
        NoiseRejectionReason.isolatedLetter,
      ]),
    );
    expect(result.allLinesFilteredOut, isTrue);
    expect(result.fallbackUsed, isFalse);
  });

  test('contextual letters, list labels and serial numbers are retained', () {
    final lines = [
      line('A'),
      line('B', y: 140),
      line('C', y: 180),
      line('1. First item', y: 220),
      line('42', y: 900),
    ];
    expect(filter(lines).acceptedLines, orderedEquals(lines));
  });

  test('isolated standalone letter rejected even when short-word listed', () {
    expect(
      filter([line('I')]).rejectedLines.single.reason,
      NoiseRejectionReason.isolatedLetter,
    );
    expect(filter([line('7')]).acceptedLines, hasLength(1));
  });

  test(
    'clock, carrier, percentage and prices are not automatic hard rejections',
    () {
      final lines = [
        line('08:00', y: 10),
        line('85%', x: 850, y: 10),
        line('Telkomsel 4G', y: 50),
        line('Wi-Fi', x: 350, y: 50),
        line('Rp 50.000', y: 250),
        line('12', y: 950),
      ];
      final result = filter(lines);
      expect(result.acceptedLines, orderedEquals(lines));
      expect(result.rejectedLines, isEmpty);
    },
  );

  test('screen patterns only contribute a weak suspicion', () {
    final result = filter([
      line('09:41', y: 10),
      line('Content here', y: 200),
    ], config: OcrNoiseFilterConfig.fromMode(OcrScanMode.screenText));
    expect(result.acceptedLines, hasLength(2));
  });

  test('all legacy modes share conservative size and confidence scoring', () {
    final lines = [
      line('Main document'),
      line('Continuation', y: 140),
      line('Small text preserved', y: 180, height: 2, confidence: 0),
    ];
    for (final mode in OcrScanMode.values) {
      expect(
        filter(
          lines,
          config: OcrNoiseFilterConfig.fromMode(mode),
        ).acceptedLines,
        orderedEquals(lines),
      );
    }
  });

  test('Unicode letters are not symbol-only noise', () {
    expect(filter([line('Café naïve résumé')]).acceptedLines, hasLength(1));
  });

  test('doubtful-only result is empty for speech, without raw fallback', () {
    final result = filter([line('ab###', confidence: .1, x: 0)]);
    expect(result.doubtfulLines, hasLength(1));
    expect(result.acceptedLines, isEmpty);
    expect(result.rejectedLines, isEmpty);
    expect(result.allLinesFilteredOut, isTrue);
  });

  test('formatter and highlight receive accepted text only', () {
    final result = filter([
      line('Buku ini mengajarkan kita'),
      line('membaca dengan nyaman.', y: 140),
      line('ab###', x: 0, y: 800, confidence: .1),
    ]);
    final doc = OcrDocumentData(
      blocks: [
        OcrBlockData(
          text: result.acceptedLines.map((l) => l.text).join('\n'),
          boundingBox: const Rect.fromLTWH(100, 100, 400, 70),
          lines: result.acceptedLines,
        ),
      ],
      rawText: result.acceptedLines.map((l) => l.text).join('\n'),
    );
    final formatted = TextFormatter.format(doc);
    expect(formatted.fullText, isNot(contains('ab###')));
    for (final word in formatted.allWords) {
      expect(
        formatted.fullText.substring(word.startIndex, word.endIndex),
        word.text,
      );
    }
  });

  test('compute preserves classification and diagnostics', () async {
    final lines = [
      line('Main paragraph'),
      line('~~~', y: 200),
      line('ab###', x: 0, y: 800, confidence: .1),
    ];
    final expected = filter(lines);
    final actual = await OcrNoiseFilter.filterWithCompute(
      OcrNoiseFilterInput(lines: lines, imageSize: size),
    );
    expect(
      actual.acceptedLines.map((l) => l.text),
      expected.acceptedLines.map((l) => l.text),
    );
    expect(
      actual.doubtfulLines.single.suspicionScore,
      expected.doubtfulLines.single.suspicionScore,
    );
    expect(actual.rejectedLines.single.reason, NoiseRejectionReason.symbolOnly);
  });

  test('empty input has no warnings', () {
    final result = filter([]);
    expect(result.hasLowQualityWarning, isFalse);
    expect(result.allLinesFilteredOut, isFalse);
  });

  test('diagnostic copy retains doubtful lines outside speech elements', () {
    final result = filter([line('ab###', confidence: .1, x: 0)]);
    final ocr = OcrResult(
      fullText: '',
      elements: const [],
      imageSize: size,
      doubtfulLines: result.doubtfulLines,
      allLinesFilteredOut: result.allLinesFilteredOut,
    );
    final copied = ocr.copyWith(diagnosticJson: '{}');
    expect(copied.doubtfulLines.single.line.text, 'ab###');
    expect(copied.elements, isEmpty);
    expect(copied.fullText, isEmpty);
  });
}
