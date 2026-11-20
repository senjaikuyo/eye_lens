import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'package:eye_lens/features/speech/models/text_formatter_models.dart';

// Kept until K2 removes the manual mode UI and its callers.
enum OcrScanMode { document, smallText, screenText, handwriting }

enum NoiseRejectionReason {
  lowConfidence,
  tooSmall,
  edgeBoundary,
  isolated,
  lowAlphaNumericRatio,
  symbolOnly,
  emptyOrWhitespace,
  clockPattern,
  statusBarPattern,
  combinedSuspicion,
  shortText,
}

@immutable
class RejectedLineInfo {
  final OcrLineData line;
  final NoiseRejectionReason reason;
  final String explanation;
  final double suspicionScore;
  final List<NoiseRejectionReason> signals;

  const RejectedLineInfo({
    required this.line,
    required this.reason,
    required this.explanation,
    this.suspicionScore = 0,
    this.signals = const [],
  });
}

/// All K3 thresholds and weights live here. Initial values are conservative,
/// not calibrated accuracy claims. One weak signal cannot quarantine a line.
@immutable
class OcrNoiseFilterConfig {
  final double minConfidence;
  final double minLineHeightRatio;
  final double edgeTolerance;
  final double isolationDistanceFactor;
  final int isolationShortCharCount;
  final double minAlphaNumericRatio;
  final int shortLength;
  final double confidenceWeight;
  final double sizeWeight;
  final double edgeWeight;
  final double isolationWeight;
  final double shortWeight;
  final double alphaRatioWeight;
  final double uiPatternWeight;
  final double doubtfulThreshold;
  final int minSuspiciousSignals;
  final double edgeZoneHeightRatio;
  final double screenshotSensitivity;
  final double screenshotShortLinesRatio;
  final int screenshotShortLineCharLimit;
  final int screenshotMinLines;
  final bool isScreenTextMode;
  final bool enableAutoScreenshotDetection;
  final Set<String> validShortWords;
  final Set<String> knownCarriers;

  const OcrNoiseFilterConfig({
    this.minConfidence = .5,
    this.minLineHeightRatio = .1,
    this.edgeTolerance = 4,
    this.isolationDistanceFactor = 5,
    this.isolationShortCharCount = 15,
    this.minAlphaNumericRatio = .5,
    this.shortLength = 3,
    this.confidenceWeight = 1,
    this.sizeWeight = 1,
    this.edgeWeight = .5,
    this.isolationWeight = 1,
    this.shortWeight = .5,
    this.alphaRatioWeight = 1.5,
    this.uiPatternWeight = 1,
    this.doubtfulThreshold = 2.5,
    this.minSuspiciousSignals = 2,
    this.edgeZoneHeightRatio = .08,
    this.screenshotSensitivity = 1.5,
    this.screenshotShortLinesRatio = .5,
    this.screenshotShortLineCharLimit = 20,
    this.screenshotMinLines = 4,
    this.isScreenTextMode = false,
    this.enableAutoScreenshotDetection = true,
    this.validShortWords = const {
      'a',
      'i',
      'u',
      'e',
      'o',
      'di',
      'ke',
      'ya',
      'no',
      'dan',
      'ini',
      'itu',
      'atau',
      'the',
      'an',
      'in',
      'on',
      'at',
      'to',
      'of',
      'by',
      'is',
      'it',
      'as',
    },
    this.knownCarriers = const {
      'telkomsel',
      'xl',
      'xl axiata',
      'smartfren',
      'axis',
      'tri',
      'three',
      'indosat',
      'indosat ooredoo',
      'no sim',
      'emergency calls only',
      'panggilan darurat',
    },
  });

  /// Modes no longer relax confidence/size rules; K3 uses shared scoring.
  factory OcrNoiseFilterConfig.fromMode(OcrScanMode mode) =>
      OcrNoiseFilterConfig(isScreenTextMode: mode == OcrScanMode.screenText);
}

@immutable
class NoiseFilterResult {
  final List<OcrLineData> acceptedLines;
  final List<RejectedLineInfo> rejectedLines;
  final List<RejectedLineInfo> doubtfulLines;
  final bool fallbackUsed;
  final bool hasLowQualityWarning;
  final bool allLinesFilteredOut;

  const NoiseFilterResult({
    required this.acceptedLines,
    required this.rejectedLines,
    this.doubtfulLines = const [],
    this.fallbackUsed = false,
    this.hasLowQualityWarning = false,
    this.allLinesFilteredOut = false,
  });

  static const empty = NoiseFilterResult(acceptedLines: [], rejectedLines: []);
}

@immutable
class OcrNoiseFilterInput {
  final List<OcrLineData> lines;
  final Size imageSize;
  final OcrNoiseFilterConfig config;

  const OcrNoiseFilterInput({
    required this.lines,
    required this.imageSize,
    this.config = const OcrNoiseFilterConfig(),
  });
}

class OcrNoiseFilter {
  static final _alphaNumeric = RegExp(r'[\p{L}\p{N}]', unicode: true);
  static final _clock = RegExp(
    r'^\d{1,2}[:.][0-5]\d(?::[0-5]\d)?(?:\s*(?:AM|PM))?$',
    caseSensitive: false,
  );
  static final _network = RegExp(
    r'^(?:[2345]G\+?|LTE|VoLTE|VoWiFi|Wi-?Fi|H\+?|EDGE|GPRS|\d{1,3}\s*%)$',
    caseSensitive: false,
  );

  static bool isClockPattern(String text) => _clock.hasMatch(text.trim());

  static bool isStatusBarPattern(String text, OcrNoiseFilterConfig config) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    if (config.knownCarriers.contains(trimmed.toLowerCase())) return true;
    return trimmed
        .split(RegExp(r'[\s|•·/\\,]+'))
        .every(
          (token) =>
              _network.hasMatch(token) ||
              config.knownCarriers.contains(token.toLowerCase()),
        );
  }

  static bool isLikelyScreenshot({
    required List<OcrLineData> lines,
    required Size imageSize,
    required OcrNoiseFilterConfig config,
  }) =>
      lines.length >= config.screenshotMinLines &&
      lines
                  .where(
                    (l) =>
                        l.text.trim().length <=
                        config.screenshotShortLineCharLimit,
                  )
                  .length /
              lines.length >=
          config.screenshotShortLinesRatio;

  static Future<NoiseFilterResult> filterWithCompute(
    OcrNoiseFilterInput input,
  ) => compute(_computeFilterEntry, input);

  static NoiseFilterResult _computeFilterEntry(OcrNoiseFilterInput input) =>
      filter(
        lines: input.lines,
        imageSize: input.imageSize,
        config: input.config,
      );

  static NoiseFilterResult filter({
    required List<OcrLineData> lines,
    required Size imageSize,
    OcrNoiseFilterConfig config = const OcrNoiseFilterConfig(),
  }) {
    if (lines.isEmpty) return NoiseFilterResult.empty;
    final heights =
        lines
            .where((l) => l.text.trim().isNotEmpty)
            .map((l) => l.boundingBox.height)
            .where((h) => h > 0 && h.isFinite)
            .toList()
          ..sort();
    final median = heights.isEmpty
        ? 0.0
        : heights.length.isOdd
        ? heights[heights.length ~/ 2]
        : (heights[heights.length ~/ 2 - 1] + heights[heights.length ~/ 2]) / 2;
    final accepted = <OcrLineData>[];
    final rejected = <RejectedLineInfo>[];
    final doubtful = <RejectedLineInfo>[];
    final screenshot =
        config.isScreenTextMode ||
        (config.enableAutoScreenshotDetection &&
            isLikelyScreenshot(
              lines: lines,
              imageSize: imageSize,
              config: config,
            ));

    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final text = line.text.trim();
      final compact = text.replaceAll(RegExp(r'\s+'), '');
      final length = compact.runes.length;
      final alphaCount = _alphaNumeric.allMatches(compact).length;
      NoiseRejectionReason? hardReason;
      if (length == 0) {
        hardReason = NoiseRejectionReason.emptyOrWhitespace;
      } else if (alphaCount == 0) {
        hardReason = NoiseRejectionReason.symbolOnly;
      }
      // Ignore empty/symbol-only neighbors: they cannot provide text context.
      var nearest = double.infinity;
      for (var other = 0; other < lines.length; other++) {
        if (other == index || !_alphaNumeric.hasMatch(lines[other].text)) {
          continue;
        }
        nearest = min(
          nearest,
          _distance(line.boundingBox, lines[other].boundingBox),
        );
      }
      if (hardReason != null) {
        rejected.add(
          RejectedLineInfo(
            line: line,
            reason: hardReason,
            explanation: hardReason.name,
            signals: [hardReason],
          ),
        );
        continue;
      }

      final signals = <NoiseRejectionReason>[];
      var score = 0.0;
      void add(NoiseRejectionReason signal, double weight) {
        signals.add(signal);
        score += weight;
      }

      final confidence = line.confidence;
      if (confidence != null &&
          confidence.isFinite &&
          confidence > 0 &&
          confidence <= 1 &&
          confidence < config.minConfidence) {
        add(NoiseRejectionReason.lowConfidence, config.confidenceWeight);
      }
      if (median > 0 &&
          line.boundingBox.height < median * config.minLineHeightRatio) {
        add(NoiseRejectionReason.tooSmall, config.sizeWeight);
      }
      final box = line.boundingBox;
      final edge =
          imageSize.width > 0 &&
          imageSize.height > 0 &&
          (box.left <= config.edgeTolerance ||
              box.top <= config.edgeTolerance ||
              box.right >= imageSize.width - config.edgeTolerance ||
              box.bottom >= imageSize.height - config.edgeTolerance);
      // Edge position alone is never a reason to remove or quarantine text.
      final lowRatio = alphaCount / length < config.minAlphaNumericRatio;
      if (lowRatio) {
        add(NoiseRejectionReason.lowAlphaNumericRatio, config.alphaRatioWeight);
        if (edge) add(NoiseRejectionReason.edgeBoundary, config.edgeWeight);
      }
      // Panjang, ukuran, jarak antarbaris, dan confidence bukan bukti noise.
      // Karakter tunggal dan teks kecil dapat menjadi label atau teks vertikal.
      final zone =
          config.edgeZoneHeightRatio *
          (screenshot ? config.screenshotSensitivity : 1);
      final inZone =
          imageSize.height > 0 &&
          (box.top <= imageSize.height * zone ||
              box.bottom >= imageSize.height * (1 - zone));
      // Clock/network patterns are suspicions, never unconditional rejections.
      if (screenshot && inZone) {
        if (isClockPattern(text)) {
          add(NoiseRejectionReason.clockPattern, config.uiPatternWeight);
        } else if (isStatusBarPattern(text, config)) {
          add(NoiseRejectionReason.statusBarPattern, config.uiPatternWeight);
        }
      }
      if (signals.length >= max(2, config.minSuspiciousSignals) &&
          score >= config.doubtfulThreshold) {
        doubtful.add(
          RejectedLineInfo(
            line: line,
            reason: NoiseRejectionReason.combinedSuspicion,
            explanation: signals.map((s) => s.name).join(', '),
            suspicionScore: score,
            signals: List.unmodifiable(signals),
          ),
        );
      } else {
        accepted.add(line);
      }
    }
    return NoiseFilterResult(
      acceptedLines: List.unmodifiable(accepted),
      rejectedLines: List.unmodifiable(rejected),
      doubtfulLines: List.unmodifiable(doubtful),
      hasLowQualityWarning: doubtful.isNotEmpty || accepted.isEmpty,
      allLinesFilteredOut: accepted.isEmpty,
    );
  }

  static double _distance(Rect a, Rect b) {
    final dx = max(0.0, max(a.left - b.right, b.left - a.right));
    final dy = max(0.0, max(a.top - b.bottom, b.top - a.bottom));
    return sqrt(dx * dx + dy * dy);
  }
}
