import 'dart:math';

import '../models/text_formatter_models.dart';

/// Menentukan urutan baca dokumen OCR tanpa mencampurkan baris dari blok
/// ML Kit yang berbeda. Untuk tata letak multi-kolom, satu kolom diselesaikan
/// dahulu sebelum berpindah ke kolom di sebelah kanan.
class ReadingOrderResolver {
  static const double _minimumGutterWidthRatio = 0.1;
  static const double _minimumVerticalOverlapRatio = 0.25;
  static const int _minimumLinesPerColumn = 2;

  /// Mengembalikan salinan blok dalam urutan baca, dengan baris tiap blok
  /// terurut atas-ke-bawah dan kiri-ke-kanan pada baseline yang sama.
  static List<OcrBlockData> resolve(List<OcrBlockData> blocks) {
    final validBlocks = blocks
        .where((block) => block.lines.isNotEmpty)
        .toList();
    if (validBlocks.length < 2) {
      return validBlocks.map(_withOrderedLines).toList(growable: false);
    }

    // Start with strict top/left fallback. Isolated offset cards do not prove
    // columns; require a real gutter and repeated, vertically overlapping text.
    int compareBlocks(OcrBlockData a, OcrBlockData b) {
      final top = a.boundingBox.top.compareTo(b.boundingBox.top);
      return top != 0 ? top : a.boundingBox.left.compareTo(b.boundingBox.left);
    }

    final fallback = [...validBlocks]..sort(compareBlocks);
    final columns = <_Column>[];
    final byLeft = [...validBlocks]
      ..sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));

    for (final block in byLeft) {
      _Column? match;
      for (final column in columns) {
        final overlap =
            min(column.right, block.boundingBox.right) -
            max(column.left, block.boundingBox.left);
        // Any horizontal overlap removes evidence for a separating gutter.
        if (overlap > 0) {
          match = column;
          break;
        }
      }

      if (match == null) {
        columns.add(_Column.fromBlock(block));
      } else {
        match.add(block);
      }
    }

    columns.sort((a, b) => a.left.compareTo(b.left));
    bool supported = columns.length >= 2;
    var repeatedColumn = false;
    for (var i = 0; i < columns.length; i++) {
      final column = columns[i];
      final lineCount = column.blocks.fold<int>(
        0,
        (n, b) => n + b.lines.length,
      );
      if (lineCount >= _minimumLinesPerColumn) repeatedColumn = true;
      if (i == 0) continue;
      final previous = columns[i - 1];
      final gap = column.left - previous.right;
      final smallerWidth = min(
        column.right - column.left,
        previous.right - previous.left,
      );
      final overlap =
          min(column.bottom, previous.bottom) - max(column.top, previous.top);
      final smallerHeight = min(
        column.bottom - column.top,
        previous.bottom - previous.top,
      );
      if (smallerWidth <= 0 ||
          smallerHeight <= 0 ||
          gap < smallerWidth * _minimumGutterWidthRatio ||
          overlap < smallerHeight * _minimumVerticalOverlapRatio) {
        supported = false;
      }
    }
    if (!supported || !repeatedColumn) {
      return List.unmodifiable(fallback.map(_withOrderedLines));
    }
    final ordered = <OcrBlockData>[];
    for (final column in columns) {
      column.blocks.sort(compareBlocks);
      ordered.addAll(column.blocks.map(_withOrderedLines));
    }
    return List.unmodifiable(ordered);
  }

  static OcrBlockData _withOrderedLines(OcrBlockData block) {
    final lines = [...block.lines];
    lines.sort((a, b) {
      final top = a.boundingBox.top.compareTo(b.boundingBox.top);
      return top != 0 ? top : a.boundingBox.left.compareTo(b.boundingBox.left);
    });
    return OcrBlockData(
      text: block.text,
      boundingBox: block.boundingBox,
      lines: List.unmodifiable(lines),
    );
  }
}

class _Column {
  double left;
  double right;
  final List<OcrBlockData> blocks;
  double get top => blocks.map((b) => b.boundingBox.top).reduce(min);
  double get bottom => blocks.map((b) => b.boundingBox.bottom).reduce(max);

  _Column({required this.left, required this.right, required this.blocks});

  factory _Column.fromBlock(OcrBlockData block) => _Column(
    left: block.boundingBox.left,
    right: block.boundingBox.right,
    blocks: [block],
  );

  void add(OcrBlockData block) {
    left = min(left, block.boundingBox.left);
    right = max(right, block.boundingBox.right);
    blocks.add(block);
  }
}
