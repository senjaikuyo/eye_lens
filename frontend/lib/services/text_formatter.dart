import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:eye_lens/models/text_formatter_models.dart';
import 'package:eye_lens/features/ocr/correction/ocr_post_corrector.dart';
import 'package:eye_lens/features/ocr/reading_order/reading_order_resolver.dart';

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
  static final RegExp trailingHyphenRegex = RegExp(r'(\w+)-\s*$');
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
    // Terapkan koreksi karakter ambigu kamus & heuristik leksikal (Issue h)
    final correctedData = OcrPostCorrector.correctDocument(data);

    if (correctedData.blocks.isEmpty) {
      return formatRawText(correctedData.rawText);
    }

    // 1. Kumpulkan semua baris valid
    final List<OcrLineData> allLines = [];
    for (final block in correctedData.blocks) {
      for (final line in block.lines) {
        if (line.text.trim().isNotEmpty) {
          allLines.add(line);
        }
      }
    }

    if (allLines.isEmpty) {
      return formatRawText(correctedData.rawText);
    }

    // 3. Pertahankan blok ML Kit sebagai unit baca. Resolver mengurutkan
    // kolom dan blok, tetapi tidak pernah mencampurkan baris lintas blok.
    final orderedBlocks = ReadingOrderResolver.resolve(correctedData.blocks);

    final List<_RawParagraphAccumulator> rawParagraphs = [];

    // 4. Proses blok demi blok supaya kartu/paragraf terpisah tetap utuh.
    for (final block in orderedBlocks) {
      // Paragraph geometry belongs to this block, not a distant title/card.
      final heights =
          block.lines
              .map((l) => l.boundingBox.height)
              .where((h) => h > 0 && h.isFinite)
              .toList()
            ..sort();
      final middle = heights.length ~/ 2;
      final median = heights.isEmpty
          ? 12.0
          : heights.length.isOdd
          ? heights[middle]
          : (heights[middle - 1] + heights[middle]) / 2;
      _processBlockLines(
        block: block,
        safeMedianHeight: max(12.0, median),
        outputParagraphs: rawParagraphs,
      );
    }

    if (rawParagraphs.isEmpty) {
      return formatRawText(correctedData.rawText);
    }

    // 6. Bangun hasil akhir terformat dengan pemetaan indeks karakter persis
    return _buildFormattedResult(rawParagraphs);
  }

  /// Memproses baris-baris dalam satu blok dan membaginya ke dalam paragraf logis.
  static void _processBlockLines({
    required OcrBlockData block,
    required double safeMedianHeight,
    required List<_RawParagraphAccumulator> outputParagraphs,
  }) {
    _RawParagraphAccumulator? currentPara;
    OcrLineData? prevLine;

    for (final rawLine in block.lines) {
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
          final indentFromBlock =
              rawLine.boundingBox.left - block.boundingBox.left;
          final isIndented =
              indentFromPrev >
                  (TextFormatterConfig.indentFactor * safeMedianHeight) ||
              indentFromBlock >
                  (TextFormatterConfig.indentFactor * safeMedianHeight);

          // Aturan 4: Baris sebelumnya adalah penutup paragraf (lebar < 70% lebar kolom)
          final prevLineWidth = prevLine.boundingBox.width;
          final isPrevLineShort =
              prevLineWidth <
              (max(1.0, block.boundingBox.width) *
                  TextFormatterConfig.paragraphEndWidthRatio);

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
    final correctedRawText = OcrPostCorrector.correctText(rawText);
    final clean = correctedRawText.trim();
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

      if (currentPara == null ||
          isListItem ||
          currentPara.isListItem ||
          isShort) {
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
      final wordTokens = paraString
          .split(' ')
          .where((w) => w.isNotEmpty)
          .toList();

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
    if (hyphenMatch != null &&
        line.isNotEmpty &&
        RegExp(r'^\w').hasMatch(line)) {
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
