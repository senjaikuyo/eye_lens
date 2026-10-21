import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../models/text_formatter_models.dart';

/// Alasan penolakan baris OCR oleh [OcrNoiseFilter].
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
}

/// Informasi baris yang ditolak beserta alasan penolakannya untuk kemudahan inspeksi debug.
@immutable
class RejectedLineInfo {
  final OcrLineData line;
  final NoiseRejectionReason reason;
  final String explanation;

  const RejectedLineInfo({
    required this.line,
    required this.reason,
    required this.explanation,
  });

  @override
  String toString() =>
      'RejectedLineInfo(${reason.name}: "${line.text}" - $explanation)';
}

/// Konfigurasi ambang batas terpusat untuk penyaring noise OCR.
@immutable
class OcrNoiseFilterConfig {
  /// Ambang batas keyakinan (confidence) minimal (0.0 s.d. 1.0).
  final double minConfidence;

  /// Ambang batas tinggi baris terhadap median (0.4 = 40% dari median).
  final double minLineHeightRatio;

  /// Toleransi jarak batas tepi citra dalam piksel.
  final double edgeTolerance;

  /// Faktor pengali median tinggi baris untuk mengukur keterpencilan.
  final double isolationDistanceFactor;

  /// Batas panjang karakter untuk kategori baris pendek yang rentan noise keterpencilan.
  final int isolationShortCharCount;

  /// Jumlah minimal baris dalam dokumen agar aturan keterpencilan aktif.
  final int isolationMinLineCount;

  /// Rasio minimal karakter huruf dan angka terhadap karakter non-spasi (0.5 = 50%).
  final double minAlphaNumericRatio;

  /// Rasio tinggi citra untuk zona tepi atas dan bawah (0.08 = 8%).
  final double edgeZoneHeightRatio;

  /// Pengatur sensitivitas zona tepi jika terdeteksi tangkapan layar UI antarmuka (default 1.5).
  final double screenshotSensitivity;

  /// Rasio minimal baris pendek untuk mendeteksi tata letak UI antarmuka (0.50 = 50%).
  final double screenshotShortLinesRatio;

  /// Batas karakter baris pendek untuk deteksi tangkapan layar antarmuka.
  final int screenshotShortLineCharLimit;

  /// Minimal jumlah baris untuk menjalankan deteksi tangkapan layar antarmuka.
  final int screenshotMinLines;

  /// Daftar kata pendek sah yang tidak boleh dibuang (case-insensitive).
  final Set<String> validShortWords;

  /// Daftar nama operator telekomunikasi populer (case-insensitive).
  final Set<String> knownCarriers;

  const OcrNoiseFilterConfig({
    this.minConfidence = 0.5,
    this.minLineHeightRatio = 0.4,
    this.edgeTolerance = 4.0,
    this.isolationDistanceFactor = 5.0,
    this.isolationShortCharCount = 15,
    this.isolationMinLineCount = 3,
    this.minAlphaNumericRatio = 0.5,
    this.edgeZoneHeightRatio = 0.08,
    this.screenshotSensitivity = 1.5,
    this.screenshotShortLinesRatio = 0.50,
    this.screenshotShortLineCharLimit = 20,
    this.screenshotMinLines = 4,
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
      'indosat',
      'indosat ooredoo',
      'xl',
      'xl axiata',
      'smartfren',
      'axis',
      'tri',
      'three',
      '3',
      'verizon',
      'at&t',
      't-mobile',
      'sprint',
      'vodafone',
      'orange',
      'o2',
      'claro',
      'movistar',
      'jio',
      'airtel',
      'no sim',
      'emergency calls only',
      'panggilan darurat',
      'darurat',
    },
  });
}

/// Hasil penyaringan noise OCR.
@immutable
class NoiseFilterResult {
  final List<OcrLineData> acceptedLines;
  final List<RejectedLineInfo> rejectedLines;
  final bool fallbackUsed;
  final bool hasLowQualityWarning;

  const NoiseFilterResult({
    required this.acceptedLines,
    required this.rejectedLines,
    this.fallbackUsed = false,
    this.hasLowQualityWarning = false,
  });

  static const NoiseFilterResult empty = NoiseFilterResult(
    acceptedLines: [],
    rejectedLines: [],
  );
}

/// DTO masukan untuk menjalankan filter pada isolate compute.
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

/// Penyaring noise OCR murni (pure function) untuk membersihkan teks latar belakang,
/// teks terpotong di tepi foto, simbol acak, dan bayangan sebelum dirapikan oleh [TextFormatter].
class OcrNoiseFilter {
  static final RegExp _listItemRegex = RegExp(
    r'^(\d+[\.\)]|[a-zA-Z][\.\)]|[\u2022\u2023\u25E6\u2043\u2219\*\-\+])\s*',
  );

  static final RegExp _numberRegex = RegExp(r'^\d+(\.\d+)?$');
  static final RegExp _alphaNumericRegex = RegExp(r'[a-zA-Z0-9]');

  /// Pola jam: 1-2 digit, titik dua atau titik, 2 digit menit, opsional detik atau AM/PM.
  /// Contoh: 5:51, 05.51, 17:30, 5:51 PM, 05:51:30 AM
  static final RegExp _clockRegex = RegExp(
    r'^\s*\d{1,2}[:.][0-5]\d(?::[0-5]\d)?(?:\s*(?:AM|PM|am|pm))?\s*$',
    caseSensitive: false,
  );

  /// Pola persen status bar: 85%, 100 %, dsb.
  static final RegExp _statusBarPercentRegex = RegExp(
    r'^\s*\d{1,3}\s*%\s*$',
  );

  /// Pola indikator sinyal/jaringan: 4G, 5G, LTE, Wi-Fi, WiFi, VoLTE, dsb.
  static final RegExp _statusBarNetworkRegex = RegExp(
    r'^\s*(?:[2345]G\+?|LTE|VoLTE\d?|VoWiFi|Wi-?Fi|H\+?|EDGE|GPRS)\s*$',
    caseSensitive: false,
  );

  /// Pola pemisah token pada baris status bar (spasi, bullet, garis tegak, slash).
  static final RegExp _statusBarPunctuationRegex = RegExp(r'[\s|•·/\\,]+');

  /// Memeriksa apakah teks cocok dengan pola jam/waktu murni.
  static bool isClockPattern(String text) {
    return _clockRegex.hasMatch(text.trim());
  }

  /// Memeriksa apakah teks cocok dengan pola elemen status bar
  /// (persen baterai, nama operator, atau kombinasi 4G, 5G, LTE, Wi-Fi).
  static bool isStatusBarPattern(String text, OcrNoiseFilterConfig config) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    // 1. Persen baterai tunggal
    if (_statusBarPercentRegex.hasMatch(trimmed)) return true;

    // 2. Sinyal / konektivitas tunggal
    if (_statusBarNetworkRegex.hasMatch(trimmed)) return true;

    // 3. Nama operator tunggal
    if (config.knownCarriers.contains(trimmed.toLowerCase())) return true;

    // 4. Kombinasi elemen status bar (misal "Telkomsel 4G", "4G 85%", "Wi-Fi | 5G")
    return _isCompoundStatusBar(trimmed, config);
  }

  static bool _isCompoundStatusBar(String text, OcrNoiseFilterConfig config) {
    final tokens = text
        .split(_statusBarPunctuationRegex)
        .where((t) => t.isNotEmpty)
        .toList();

    if (tokens.isEmpty) return false;

    for (final token in tokens) {
      final isPercent = _statusBarPercentRegex.hasMatch(token);
      final isNetwork = _statusBarNetworkRegex.hasMatch(token);
      final isCarrier = config.knownCarriers.contains(token.toLowerCase());

      if (!isPercent && !isNetwork && !isCarrier) {
        return false;
      }
    }

    return true;
  }

  /// Mendeteksi apakah tata letak teks menyerupai antarmuka aplikasi / tangkapan layar (screenshot).
  /// Ditandai dengan banyaknya komponen/baris teks pendek khas antarmuka.
  static bool isLikelyScreenshot({
    required List<OcrLineData> lines,
    required Size imageSize,
    required OcrNoiseFilterConfig config,
  }) {
    if (lines.length < config.screenshotMinLines) return false;

    int shortCount = 0;
    for (final line in lines) {
      if (line.text.trim().length <= config.screenshotShortLineCharLimit) {
        shortCount++;
      }
    }

    final ratio = shortCount / lines.length;
    return ratio >= config.screenshotShortLinesRatio;
  }

  /// Menjalankan filter secara asynchronous pada background isolate via [compute].
  static Future<NoiseFilterResult> filterWithCompute(
    OcrNoiseFilterInput input,
  ) async {
    try {
      return await compute(_computeFilterEntry, input);
    } catch (e) {
      debugPrint('[OcrNoiseFilter] Isolate error, fallback ke sinkron: $e');
      return filter(
        lines: input.lines,
        imageSize: input.imageSize,
        config: input.config,
      );
    }
  }

  static NoiseFilterResult _computeFilterEntry(OcrNoiseFilterInput input) {
    return filter(
      lines: input.lines,
      imageSize: input.imageSize,
      config: input.config,
    );
  }

  /// Fungsi murni utama: memfilter daftar baris OCR berdasarkan aturan sekuensial.
  static NoiseFilterResult filter({
    required List<OcrLineData> lines,
    required Size imageSize,
    OcrNoiseFilterConfig config = const OcrNoiseFilterConfig(),
  }) {
    if (lines.isEmpty) {
      return NoiseFilterResult.empty;
    }

    // 1. Hitung tinggi baris median untuk evaluasi ukuran
    final validHeights = lines
        .map((l) => l.boundingBox.height)
        .where((h) => h > 0)
        .toList()
      ..sort();

    final double medianHeight = validHeights.isNotEmpty
        ? (validHeights.length.isOdd
            ? validHeights[validHeights.length ~/ 2]
            : (validHeights[(validHeights.length ~/ 2) - 1] +
                    validHeights[validHeights.length ~/ 2]) /
                2.0)
        : 0.0;

    // Deteksi apakah citra bertipe tangkapan layar antarmuka aplikasi
    final bool isScreenshot = isLikelyScreenshot(
      lines: lines,
      imageSize: imageSize,
      config: config,
    );

    // Sensitivitas zona tepi lebih ketat untuk tangkapan layar UI
    final double effectiveEdgeZoneRatio = isScreenshot
        ? (config.edgeZoneHeightRatio * config.screenshotSensitivity)
            .clamp(0.0, 0.4)
        : config.edgeZoneHeightRatio;

    final double topEdgeBoundary = imageSize.height > 0
        ? imageSize.height * effectiveEdgeZoneRatio
        : 0.0;
    final double bottomEdgeBoundary = imageSize.height > 0
        ? imageSize.height * (1.0 - effectiveEdgeZoneRatio)
        : double.infinity;

    bool isInEdgeZone(Rect box) {
      if (imageSize.height <= 0) return false;
      final inTop = box.top <= topEdgeBoundary || box.center.dy <= topEdgeBoundary;
      final inBottom = box.bottom >= bottomEdgeBoundary || box.center.dy >= bottomEdgeBoundary;
      return inTop || inBottom;
    }

    final List<OcrLineData> accepted = [];
    final List<RejectedLineInfo> rejected = [];

    for (final line in lines) {
      final trimmed = line.text.trim();
      final nonWhitespace = trimmed.replaceAll(RegExp(r'\s+'), '');

      // Aturan 0: Teks kosong atau hanya spasi
      if (nonWhitespace.isEmpty) {
        rejected.add(
          RejectedLineInfo(
            line: line,
            reason: NoiseRejectionReason.emptyOrWhitespace,
            explanation: 'Baris kosong atau hanya whitespace.',
          ),
        );
        continue;
      }

      // Aturan 1: Keyakinan (Confidence)
      // Jika bernilai null (misal iOS atau tidak didukung), lewati dan jangan gagal.
      if (line.confidence != null && line.confidence! < config.minConfidence) {
        rejected.add(
          RejectedLineInfo(
            line: line,
            reason: NoiseRejectionReason.lowConfidence,
            explanation:
                'Confidence ${line.confidence} < batas minimal ${config.minConfidence}.',
          ),
        );
        continue;
      }

      // Aturan 2: Ukuran (Size)
      // Buang baris yang tingginya < 40% median (tulisan kecil di background)
      if (medianHeight > 0 &&
          line.boundingBox.height < (medianHeight * config.minLineHeightRatio)) {
        rejected.add(
          RejectedLineInfo(
            line: line,
            reason: NoiseRejectionReason.tooSmall,
            explanation:
                'Tinggi baris ${line.boundingBox.height} < ${(medianHeight * config.minLineHeightRatio).toStringAsFixed(1)} (40% dari median ${medianHeight.toStringAsFixed(1)}).',
          ),
        );
        continue;
      }

      // Aturan 3: Posisi (Position)
      // Buang baris yang boundingBox-nya menyentuh atau melewati tepi foto (teks terpotong)
      if (imageSize.width > 0 && imageSize.height > 0) {
        final tol = config.edgeTolerance;
        final leftTouch = line.boundingBox.left <= tol;
        final topTouch = line.boundingBox.top <= tol;
        final rightTouch = line.boundingBox.right >= (imageSize.width - tol);
        final bottomTouch =
            line.boundingBox.bottom >= (imageSize.height - tol);

        if (leftTouch || topTouch || rightTouch || bottomTouch) {
          rejected.add(
            RejectedLineInfo(
              line: line,
              reason: NoiseRejectionReason.edgeBoundary,
              explanation:
                  'Menyentuh atau melewati batas tepi citra ${imageSize.width.toInt()}x${imageSize.height.toInt()} (rect: ${line.boundingBox}).',
            ),
          );
          continue;
        }
      }

      // Aturan 4: Keterpencilan (Isolation)
      // Buang baris pendek yang jauh dari kelompok teks utama (> 5x tinggi median).
      // Catatan:
      // - Angka sah (seperti nomor halaman di bawah/atas) dikecualikan agar tidak terbuang.
      // - Pola jam dan elemen status bar didelegasikan ke Aturan 6 agar tercatat dengan
      //   NoiseRejectionReason.clockPattern / statusBarPattern yang tepat untuk mode debug.
      final isNumber = _numberRegex.hasMatch(trimmed);
      final isClock = isClockPattern(trimmed);
      final isStatusBar = isStatusBarPattern(trimmed, config);

      final isShort = trimmed.length <= config.isolationShortCharCount;
      if (!isNumber &&
          !isClock &&
          !isStatusBar &&
          lines.length >= config.isolationMinLineCount &&
          isShort &&
          medianHeight > 0) {
        double minDistance = double.infinity;
        for (final other in lines) {
          if (identical(line, other)) continue;
          final d = _calculateRectDistance(line.boundingBox, other.boundingBox);
          if (d < minDistance) {
            minDistance = d;
          }
        }

        final maxAllowedDistance = config.isolationDistanceFactor * medianHeight;
        if (minDistance > maxAllowedDistance) {
          rejected.add(
            RejectedLineInfo(
              line: line,
              reason: NoiseRejectionReason.isolated,
              explanation:
                  'Baris pendek terpencil (jarak terdekat ${minDistance.toStringAsFixed(1)} > batas ${maxAllowedDistance.toStringAsFixed(1)}).',
            ),
          );
          continue;
        }
      }

      // Aturan 5: Isi Karakter (Character Content) & Simbol
      final alphaNumericCount =
          _alphaNumericRegex.allMatches(nonWhitespace).length;

      // Buang baris yang hanya berisi simbol
      if (alphaNumericCount == 0) {
        rejected.add(
          RejectedLineInfo(
            line: line,
            reason: NoiseRejectionReason.symbolOnly,
            explanation: 'Baris hanya berisi karakter simbol atau non-alfanumerik.',
          ),
        );
        continue;
      }

      // Evaluasi rasio alfanumerik (pengecualian untuk kata pendek sah, angka, dan item daftar)
      final lowerTrimmed = trimmed.toLowerCase();
      final isShortValidWord = config.validShortWords.contains(lowerTrimmed);
      final isListItem = _listItemRegex.hasMatch(trimmed);

      if (!isShortValidWord && !isNumber && !isListItem) {
        final ratio = alphaNumericCount / nonWhitespace.length;
        if (ratio < config.minAlphaNumericRatio) {
          rejected.add(
            RejectedLineInfo(
              line: line,
              reason: NoiseRejectionReason.lowAlphaNumericRatio,
              explanation:
                  'Rasio alfanumerik ${(ratio * 100).toStringAsFixed(1)}% < batas minimal ${(config.minAlphaNumericRatio * 100).toStringAsFixed(0)}%.',
            ),
          );
          continue;
        }
      }

      // Aturan 6: Elemen Antarmuka dan Jam (Status Bar & Clock Filter)
      final inEdge = isInEdgeZone(line.boundingBox);

      if (inEdge) {
        // Pada zona tepi (atas/bawah): buang baris jika cocok pola jam atau status bar
        if (isClockPattern(trimmed)) {
          rejected.add(
            RejectedLineInfo(
              line: line,
              reason: NoiseRejectionReason.clockPattern,
              explanation:
                  'Pola jam pada zona tepi citra ($trimmed, y: ${line.boundingBox.top.toStringAsFixed(1)}).',
            ),
          );
          continue;
        }

        if (isStatusBarPattern(trimmed, config)) {
          rejected.add(
            RejectedLineInfo(
              line: line,
              reason: NoiseRejectionReason.statusBarPattern,
              explanation:
                  'Pola elemen status bar pada zona tepi citra ($trimmed).',
            ),
          );
          continue;
        }
      } else {
        // Di luar zona tepi: buang baris berpola jam HANYA jika baris itu pendek, berdiri sendiri,
        // dan jauh dari kelompok teks utama. Jam di dalam tabel jadwal atau kalimat tetap lolos.
        if (isClockPattern(trimmed)) {
          final isShort = trimmed.length <= config.isolationShortCharCount;
          if (lines.length >= config.isolationMinLineCount &&
              isShort &&
              medianHeight > 0) {
            double minDistance = double.infinity;
            for (final other in lines) {
              if (identical(line, other)) continue;
              final d =
                  _calculateRectDistance(line.boundingBox, other.boundingBox);
              if (d < minDistance) {
                minDistance = d;
              }
            }

            final maxAllowedDistance =
                config.isolationDistanceFactor * medianHeight;
            if (minDistance > maxAllowedDistance) {
              rejected.add(
                RejectedLineInfo(
                  line: line,
                  reason: NoiseRejectionReason.clockPattern,
                  explanation:
                      'Pola jam berdiri sendiri terpencil di luar kelompok teks utama ($trimmed, jarak: ${minDistance.toStringAsFixed(1)} > batas ${maxAllowedDistance.toStringAsFixed(1)}).',
                ),
              );
              continue;
            }
          }
        }
      }

      // Lolos semua kriteria penyaringan
      accepted.add(line);
    }

    // Fallback: Jika seluruh baris tersaring habis, kembalikan seluruh baris asli tanpa filter ketat
    // dan beri penanda peringatan gambar kurang jelas.
    if (accepted.isEmpty && lines.isNotEmpty) {
      return NoiseFilterResult(
        acceptedLines: List.unmodifiable(lines),
        rejectedLines: List.unmodifiable(rejected),
        fallbackUsed: true,
        hasLowQualityWarning: true,
      );
    }

    return NoiseFilterResult(
      acceptedLines: List.unmodifiable(accepted),
      rejectedLines: List.unmodifiable(rejected),
      fallbackUsed: false,
      hasLowQualityWarning: false,
    );
  }

  /// Menghitung jarak Euclidean terpendek antara dua [Rect].
  static double _calculateRectDistance(Rect a, Rect b) {
    final double dx;
    if (a.right < b.left) {
      dx = b.left - a.right;
    } else if (b.right < a.left) {
      dx = a.left - b.right;
    } else {
      dx = 0.0;
    }

    final double dy;
    if (a.bottom < b.top) {
      dy = b.top - a.bottom;
    } else if (b.bottom < a.top) {
      dy = a.top - b.bottom;
    } else {
      dy = 0.0;
    }

    return sqrt(dx * dx + dy * dy);
  }
}
