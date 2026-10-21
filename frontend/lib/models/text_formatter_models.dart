import 'dart:ui';
import 'package:flutter/foundation.dart';

/// DTO untuk satu kata terformat lengkap dengan indeks karakter pada teks akhir.
@immutable
class FormattedWord {
  final String text;
  final int startIndex;
  final int endIndex;
  final int paragraphIndex;
  final int wordIndexInParagraph;

  const FormattedWord({
    required this.text,
    required this.startIndex,
    required this.endIndex,
    required this.paragraphIndex,
    required this.wordIndexInParagraph,
  });

  @override
  String toString() => 'FormattedWord($text, $startIndex-$endIndex)';
}

/// DTO untuk satu paragraf terformat.
@immutable
class FormattedParagraph {
  final String text;
  final int startIndex;
  final int endIndex;
  final int index;
  final List<FormattedWord> words;
  final bool isListItem;

  const FormattedParagraph({
    required this.text,
    required this.startIndex,
    required this.endIndex,
    required this.index,
    required this.words,
    this.isListItem = false,
  });

  @override
  String toString() => 'FormattedParagraph($index, $startIndex-$endIndex: $text)';
}

/// DTO hasil keluaran pemformatan teks lengkap.
@immutable
class FormattedTextResult {
  final String fullText;
  final List<FormattedParagraph> paragraphs;
  final List<FormattedWord> allWords;

  const FormattedTextResult({
    required this.fullText,
    required this.paragraphs,
    required this.allWords,
  });

  static const FormattedTextResult empty = FormattedTextResult(
    fullText: '',
    paragraphs: [],
    allWords: [],
  );

  /// Mencari kata yang mencakup indeks karakter yang diberikan.
  FormattedWord? findWordAt(int charIndex) {
    if (charIndex < 0 || allWords.isEmpty) return null;
    for (final w in allWords) {
      if (charIndex >= w.startIndex && charIndex < w.endIndex) {
        return w;
      }
    }
    // Jika berada di antara kata (spasi/jeda), cari kata terdekat sebelum indeks
    for (int i = allWords.length - 1; i >= 0; i--) {
      if (allWords[i].startIndex <= charIndex) {
        return allWords[i];
      }
    }
    return allWords.first;
  }

  /// Mencari paragraf yang mencakup indeks karakter yang diberikan.
  FormattedParagraph? findParagraphAt(int charIndex) {
    if (charIndex < 0 || paragraphs.isEmpty) return null;
    for (final p in paragraphs) {
      if (charIndex >= p.startIndex && charIndex <= p.endIndex) {
        return p;
      }
    }
    return paragraphs.last;
  }
}

/// DTO baris OCR murni dengan koordinat bounding box, opsional confidence, dan indeks blok.
@immutable
class OcrLineData {
  final String text;
  final Rect boundingBox;
  final double? confidence;
  final int blockIndex;

  const OcrLineData({
    required this.text,
    required this.boundingBox,
    this.confidence,
    this.blockIndex = 0,
  });
}

/// DTO blok OCR murni dengan baris-baris di dalamnya.
@immutable
class OcrBlockData {
  final String text;
  final Rect boundingBox;
  final List<OcrLineData> lines;

  const OcrBlockData({
    required this.text,
    required this.boundingBox,
    required this.lines,
  });
}

/// DTO dokumen OCR mentah sebelum dirapikan.
@immutable
class OcrDocumentData {
  final List<OcrBlockData> blocks;
  final String rawText;

  const OcrDocumentData({
    required this.blocks,
    required this.rawText,
  });

  static const OcrDocumentData empty = OcrDocumentData(
    blocks: [],
    rawText: '',
  );
}
