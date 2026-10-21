import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/text_formatter_models.dart';

/// Konfigurasi dan ambang batas aturan perapian teks OCR.
class TextFormatterConfig {
  /// Ambang faktor vertikal antar baris untuk memicu paragraf baru (0.8x tinggi median).
  static const double verticalGapFactor = 0.8;

  /// Ambang faktor indentasi baris berikutnya untuk memicu paragraf baru (1.0x tinggi median).
  static const double indentFactor = 1.0;

  /// Rasio lebar baris terhadap lebar kolom untuk mendeteksi penutup paragraf (< 70% lebar kolom).
  static const double paragraphEndWidthRatio = 0.7;

  /// Toleransi tumpang-tindih sumbu-X untuk pengelompokan kolom (20%).
  static const double columnOverlapTolerance = 0.2;

  /// Jeda antar paragraf saat pembacaan TTS dalam milidetik.
  static const int paragraphPauseMs = 300;

  /// Regex deteksi penanda item daftar (misal: "1.", "1)", "a.", "a)", "•", "-", "*").
  static final RegExp listPrefixRegex = RegExp(
    r'^(\d+[\.\)]|[a-zA-Z][\.\)]|[\u2022\u2023\u25E6\u2043\u2219\*\-\–\—])\s+',
  );

  /// Karakter sampah/noise OCR di awal atau akhir baris.
  static final RegExp edgeNoiseRegex = RegExp(
    r"""^[\~\|\_\`\'\^]+|[\~\|\_\`\'\^]+$""",
  );

  /// Deteksi kata yang terpotong tanda hubung di akhir baris (misal: "revolu-").
  static final RegExp trailingHyphenRegex = RegExp(
    r'(\w+)-\s*$',
  );
}

class _ColumnCluster {
  double left;
  double right;
  final List<OcrLineData> lines;

  _ColumnCluster({
    required this.left,
    required this.right,
    required this.lines,
  });

  double get width => max(1.0, right - left);
}

/// Layanan murni untuk merapikan hasil OCR berbasis struktur spasial (bounding box) dan teks.
class TextFormatter {
  /// Memformat dokumen OCR menggunakan isolate worker (compute) agar UI tidak terblokir.
  static Future<FormattedTextResult> formatWithCompute(
    OcrDocumentData data,
  ) async {
    try {
      return await compute(_computeEntry, data);
    } catch (e) {
      debugPrint('[TextFormatter] Isolate error, fallback to synchronous: $e');
      return format(data);
    }
  }

  static FormattedTextResult _computeEntry(OcrDocumentData data) {
    return TextFormatter.format(data);
  }

  /// Fungsi murni utama: memformat dokumen OCR menjadi daftar paragraf dan kata berindeks.
  static FormattedTextResult format(OcrDocumentData data) {
    if (data.blocks.isEmpty) {
      return formatRawText(data.rawText);
    }

    // 1. Kumpulkan semua baris valid
    final List<OcrLineData> allLines = [];
    for (final block in data.blocks) {
      for (final line in block.lines) {
        if (line.text.trim().isNotEmpty) {
          allLines.add(line);
        }
      }
    }

    if (allLines.isEmpty) {
      return formatRawText(data.rawText);
    }

    // 2. Hitung tinggi baris median sebagai satuan ukuran acuan
    final heights = allLines.map((l) => l.boundingBox.height).toList()..sort();
    final double medianLineHeight = heights.length.isOdd
        ? heights[heights.length ~/ 2]
        : (heights[(heights.length ~/ 2) - 1] + heights[heights.length ~/ 2]) /
            2.0;
    final double safeMedianHeight = max(12.0, medianLineHeight);

    // 3. Kelompokkan blok ke dalam kolom berdasarkan tumpang tindih sumbu x
    final List<_ColumnCluster> columns = _clusterIntoColumns(data.blocks);

    // 4. Urutkan kolom dari kiri ke kanan
    columns.sort((a, b) => a.left.compareTo(b.left));

    final List<_RawParagraphAccumulator> rawParagraphs = [];

    // 5. Proses dokumen kolom demi kolom (bukan melintang antar kolom)
    for (final col in columns) {
      // Urutkan baris di dalam kolom dari atas ke bawah (dan kiri ke kanan jika tinggi serupa)
      col.lines.sort((a, b) {
        final topDiff = (a.boundingBox.top - b.boundingBox.top);
        if (topDiff.abs() < safeMedianHeight * 0.5) {
          return a.boundingBox.left.compareTo(b.boundingBox.left);
        }
        return topDiff.compareTo(0);
      });

      _processColumnLines(
        col: col,
        safeMedianHeight: safeMedianHeight,
        outputParagraphs: rawParagraphs,
      );
    }

    if (rawParagraphs.isEmpty) {
      return formatRawText(data.rawText);
    }

    // 6. Bangun hasil akhir terformat dengan pemetaan indeks karakter persis
    return _buildFormattedResult(rawParagraphs);
  }

  /// Memproses baris-baris dalam satu kolom dan membaginya ke dalam paragraf logis.
  static void _processColumnLines({
    required _ColumnCluster col,
    required double safeMedianHeight,
    required List<_RawParagraphAccumulator> outputParagraphs,
  }) {
    _RawParagraphAccumulator? currentPara;
    OcrLineData? prevLine;

    for (final rawLine in col.lines) {
      final sanitizedText = _sanitizeLine(rawLine.text);
      if (sanitizedText.isEmpty) continue;

      final isCurrentListItem = TextFormatterConfig.listPrefixRegex.hasMatch(
        sanitizedText,
      );

      bool startNewParagraph = false;

      if (currentPara == null || prevLine == null) {
        startNewParagraph = true;
      } else {
        final prevLineIsListItem = currentPara.isListItem;

        // Aturan 1: Item daftar selalu berdiri sendiri
        if (isCurrentListItem || prevLineIsListItem) {
          startNewParagraph = true;
        } else {
          // Aturan 2: Jarak vertikal antar baris > 0.8x tinggi median
          final verticalGap =
              rawLine.boundingBox.top - prevLine.boundingBox.bottom;
          final isLargeVerticalGap =
              verticalGap >
              (TextFormatterConfig.verticalGapFactor * safeMedianHeight);

          // Aturan 3: Baris berikutnya menjorok ke dalam (indentasi) > 1.0x tinggi baris
          final indentFromPrev =
              rawLine.boundingBox.left - prevLine.boundingBox.left;
          final indentFromCol = rawLine.boundingBox.left - col.left;
          final isIndented =
              indentFromPrev >
                  (TextFormatterConfig.indentFactor * safeMedianHeight) ||
              indentFromCol >
                  (TextFormatterConfig.indentFactor * safeMedianHeight);

          // Aturan 4: Baris sebelumnya adalah penutup paragraf (lebar < 70% lebar kolom)
          final prevLineWidth = prevLine.boundingBox.width;
          final isPrevLineShort =
              prevLineWidth <
              (col.width * TextFormatterConfig.paragraphEndWidthRatio);

          if (isLargeVerticalGap || isIndented || isPrevLineShort) {
            startNewParagraph = true;
          }
        }
      }

      if (startNewParagraph) {
        if (currentPara != null && currentPara.hasContent) {
          outputParagraphs.add(currentPara);
        }
        currentPara = _RawParagraphAccumulator(isListItem: isCurrentListItem);
        currentPara.appendLine(sanitizedText, isFirstLine: true);
      } else {
        currentPara!.appendLine(sanitizedText, isFirstLine: false);
      }

      prevLine = rawLine;
    }

    if (currentPara != null && currentPara.hasContent) {
      outputParagraphs.add(currentPara);
    }
  }

  /// Mengelompokkan blok-blok teks ke dalam kolom-kolom spasial sumbu X.
  static List<_ColumnCluster> _clusterIntoColumns(List<OcrBlockData> blocks) {
    final List<_ColumnCluster> clusters = [];

    final validBlocks =
        blocks.where((b) => b.lines.isNotEmpty).toList()
          ..sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));

    for (final block in validBlocks) {
      final bRect = block.boundingBox;
      _ColumnCluster? matchedCol;

      for (final col in clusters) {
        final overlap = min(col.right, bRect.right) - max(col.left, bRect.left);
        final minWidth = min(col.width, max(1.0, bRect.width));
        if (overlap > minWidth * TextFormatterConfig.columnOverlapTolerance) {
          matchedCol = col;
          break;
        }
      }

      if (matchedCol != null) {
        matchedCol.left = min(matchedCol.left, bRect.left);
        matchedCol.right = max(matchedCol.right, bRect.right);
        for (final line in block.lines) {
          if (line.text.trim().isNotEmpty) {
            matchedCol.lines.add(line);
          }
        }
      } else {
        final colLines =
            block.lines.where((l) => l.text.trim().isNotEmpty).toList();
        clusters.add(
          _ColumnCluster(
            left: bRect.left,
            right: bRect.right,
            lines: colLines,
          ),
        );
      }
    }

    return clusters;
  }

  /// Membersihkan noise batas dan normalisasi spasi.
  static String _sanitizeLine(String line) {
    var text = line.trim();
    // Bersihkan karakter sampah OCR di batas baris
    text = text.replaceAll(TextFormatterConfig.edgeNoiseRegex, '').trim();
    // Bersihkan spasi ganda / tab internal
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    return text;
  }

  /// Fallback untuk memformat teks mentah jika tidak ada data posisi/koordinat.
  static FormattedTextResult formatRawText(String rawText) {
    final clean = rawText.trim();
    if (clean.isEmpty) return FormattedTextResult.empty;

    final rawLines = clean.split('\n');
    final List<_RawParagraphAccumulator> rawParagraphs = [];
    _RawParagraphAccumulator? currentPara;

    for (var rawLine in rawLines) {
      final line = _sanitizeLine(rawLine);
      if (line.isEmpty) {
        if (currentPara != null && currentPara.hasContent) {
          rawParagraphs.add(currentPara);
          currentPara = null;
        }
        continue;
      }

      final isListItem = TextFormatterConfig.listPrefixRegex.hasMatch(line);
      final isShort = line.length < 35;

      if (currentPara == null || isListItem || currentPara.isListItem || isShort) {
        if (currentPara != null && currentPara.hasContent) {
          rawParagraphs.add(currentPara);
        }
        currentPara = _RawParagraphAccumulator(isListItem: isListItem);
        currentPara.appendLine(line, isFirstLine: true);
      } else {
        currentPara.appendLine(line, isFirstLine: false);
      }
    }

    if (currentPara != null && currentPara.hasContent) {
      rawParagraphs.add(currentPara);
    }

    if (rawParagraphs.isEmpty) {
      return FormattedTextResult.empty;
    }

    return _buildFormattedResult(rawParagraphs);
  }

  /// Membangun FormattedTextResult dengan pemetaan indeks karakter yang persis.
  static FormattedTextResult _buildFormattedResult(
    List<_RawParagraphAccumulator> rawParagraphs,
  ) {
    final StringBuffer fullTextBuffer = StringBuffer();
    final List<FormattedParagraph> paragraphs = [];
    final List<FormattedWord> allWords = [];

    for (int pIdx = 0; pIdx < rawParagraphs.length; pIdx++) {
      final paraAcc = rawParagraphs[pIdx];
      final paraString = paraAcc.toString();
      if (paraString.trim().isEmpty) continue;

      if (fullTextBuffer.isNotEmpty) {
        fullTextBuffer.write('\n\n'); // Pemisah antar paragraf
      }

      final int paraStartIndex = fullTextBuffer.length;
      final List<FormattedWord> paraWords = [];

      // Pecah paragraf menjadi kata-kata
      final wordTokens = paraString.split(' ').where((w) => w.isNotEmpty).toList();

      for (int wIdx = 0; wIdx < wordTokens.length; wIdx++) {
        if (wIdx > 0) {
          fullTextBuffer.write(' ');
        }
        final int wordStart = fullTextBuffer.length;
        fullTextBuffer.write(wordTokens[wIdx]);
        final int wordEnd = fullTextBuffer.length;

        final word = FormattedWord(
          text: wordTokens[wIdx],
          startIndex: wordStart,
          endIndex: wordEnd,
          paragraphIndex: paragraphs.length,
          wordIndexInParagraph: wIdx,
        );
        paraWords.add(word);
        allWords.add(word);
      }

      final int paraEndIndex = fullTextBuffer.length;
      final formattedParagraph = FormattedParagraph(
        text: paraString,
        startIndex: paraStartIndex,
        endIndex: paraEndIndex,
        index: paragraphs.length,
        words: paraWords,
        isListItem: paraAcc.isListItem,
      );

      paragraphs.add(formattedParagraph);
    }

    return FormattedTextResult(
      fullText: fullTextBuffer.toString(),
      paragraphs: paragraphs,
      allWords: allWords,
    );
  }
}

/// Akumulator pembentuk satu paragraf dari baris-baris berurutan.
class _RawParagraphAccumulator {
  final bool isListItem;
  final StringBuffer _buffer = StringBuffer();
  String _lastAppendedLine = '';

  _RawParagraphAccumulator({required this.isListItem});

  bool get hasContent => _buffer.isNotEmpty;

  void appendLine(String line, {required bool isFirstLine}) {
    if (isFirstLine || _buffer.isEmpty) {
      _buffer.write(line);
      _lastAppendedLine = line;
      return;
    }

    // Periksa apakah baris sebelumnya terpotong tanda hubung (hyphen) di akhir
    final hyphenMatch = TextFormatterConfig.trailingHyphenRegex.firstMatch(
      _lastAppendedLine,
    );
    if (hyphenMatch != null && line.isNotEmpty && RegExp(r'^\w').hasMatch(line)) {
      // Hapus tanda hubung dari buffer dan sambung tanpa spasi
      final currentStr = _buffer.toString();
      final lastHyphenIndex = currentStr.lastIndexOf('-');
      if (lastHyphenIndex != -1) {
        _buffer.clear();
        _buffer.write(currentStr.substring(0, lastHyphenIndex));
        _buffer.write(line);
        _lastAppendedLine = line;
        return;
      }
    }

    // Sambung dengan satu spasi tunggal
    _buffer.write(' ');
    _buffer.write(line);
    _lastAppendedLine = line;
  }

  @override
  String toString() => _buffer.toString();
}
