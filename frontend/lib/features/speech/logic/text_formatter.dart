import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:eye_lens/features/speech/models/text_formatter_models.dart';
import 'package:eye_lens/features/ocr/orientation/orientation_aware_reading_order.dart';

/// Konfigurasi dan ambang batas aturan perapian teks OCR.
class TextFormatterConfig {
  /// Ambang faktor vertikal antar baris untuk memicu paragraf baru (0.8x tinggi median).
  static const double verticalGapFactor = 0.8;

  /// Ambang faktor indentasi baris berikutnya untuk memicu paragraf baru (1.0x tinggi median).
  static const double indentFactor = 1.0;

  /// Rasio lebar baris terhadap lebar kolom untuk mendeteksi penutup paragraf (< 70% lebar kolom).
  static const double paragraphEndWidthRatio = 0.7;

  /// Jeda antar paragraf saat pembacaan TTS dalam milidetik.
  static const int paragraphPauseMs = 300;

  /// Regex deteksi penanda item daftar (misal: "1.", "1)", "a.", "a)", "•", "-", "*").
  static final RegExp listPrefixRegex = RegExp(
    r'^(\d+[\.\)]|[a-zA-Z][\.\)]|[\u2022\u2023\u25E6\u2043\u2219\*\-\–\—])\s+',
  );
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
    // Karakter dari ML Kit tidak dikoreksi memakai kamus.
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

    // 3. Pertahankan blok ML Kit sebagai unit baca. Resolver mengurutkan
    // kolom dan blok, tetapi tidak pernah mencampurkan baris lintas blok.
    final orderedBlocks = OrientationAwareReadingOrder.resolve(data.blocks);

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
      return formatRawText(data.rawText);
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
      final lineText = rawLine.text;

      final isCurrentListItem = TextFormatterConfig.listPrefixRegex.hasMatch(
        lineText,
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
        currentPara.appendLine(lineText, isFirstLine: true);
      } else {
        currentPara!.appendLine(lineText, isFirstLine: false);
      }

      prevLine = rawLine;
    }

    if (currentPara != null && currentPara.hasContent) {
      outputParagraphs.add(currentPara);
    }
  }

  /// Fallback untuk memformat teks mentah jika tidak ada data posisi/koordinat.
  static FormattedTextResult formatRawText(String rawText) {
    if (rawText.isEmpty) return FormattedTextResult.empty;
    return _buildFormattedResult([
      for (final line in rawText.split('\n'))
        _RawParagraphAccumulator(
          isListItem: TextFormatterConfig.listPrefixRegex.hasMatch(line),
        )..appendLine(line, isFirstLine: true),
    ], paragraphSeparator: '\n');
  }

  /// Membangun FormattedTextResult dengan pemetaan indeks karakter yang persis.
  static FormattedTextResult _buildFormattedResult(
    List<_RawParagraphAccumulator> rawParagraphs, {
    String paragraphSeparator = '\n\n',
  }) {
    final StringBuffer fullTextBuffer = StringBuffer();
    final List<FormattedParagraph> paragraphs = [];
    final List<FormattedWord> allWords = [];

    for (int pIdx = 0; pIdx < rawParagraphs.length; pIdx++) {
      final paraAcc = rawParagraphs[pIdx];
      final paraString = paraAcc.toString();
      if (pIdx > 0) {
        fullTextBuffer.write(paragraphSeparator);
      }

      final int paraStartIndex = fullTextBuffer.length;
      final List<FormattedWord> paraWords = [];

      // Pecah paragraf menjadi kata-kata
      fullTextBuffer.write(paraString);
      for (final match in RegExp(r'\S+').allMatches(paraString)) {
        final word = FormattedWord(
          text: match.group(0)!,
          startIndex: paraStartIndex + match.start,
          endIndex: paraStartIndex + match.end,
          paragraphIndex: paragraphs.length,
          wordIndexInParagraph: paraWords.length,
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

  _RawParagraphAccumulator({required this.isListItem});

  bool get hasContent => _buffer.isNotEmpty;

  void appendLine(String line, {required bool isFirstLine}) {
    if (isFirstLine) {
      _buffer.write(line);
      return;
    }

    // Preserve line boundaries and hyphens instead of guessing word joins.
    _buffer.write('\n');
    _buffer.write(line);
  }

  @override
  String toString() => _buffer.toString();
}
