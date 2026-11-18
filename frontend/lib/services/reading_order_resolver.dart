import 'dart:math';

import '../models/text_formatter_models.dart';

/// Menentukan urutan baca dokumen OCR tanpa mencampurkan baris dari blok
/// ML Kit yang berbeda. Untuk tata letak multi-kolom, satu kolom diselesaikan
/// dahulu sebelum berpindah ke kolom di sebelah kanan.
class ReadingOrderResolver {
  static const double _columnOverlapTolerance = 0.2;

  /// Mengembalikan salinan blok dalam urutan baca, dengan baris tiap blok
  /// terurut atas-ke-bawah dan kiri-ke-kanan pada baseline yang sama.
  static List<OcrBlockData> resolve(List<OcrBlockData> blocks) {
    final validBlocks = blocks
        .where((block) => block.lines.isNotEmpty)
        .toList();
    if (validBlocks.length < 2) {
      return validBlocks.map(_withOrderedLines).toList(growable: false);
    }

    final columns = <_Column>[];
    final byLeft = [...validBlocks]
      ..sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));

    for (final block in byLeft) {
      _Column? match;
      for (final column in columns) {
        final overlap =
            min(column.right, block.boundingBox.right) -
            max(column.left, block.boundingBox.left);
        final smallerWidth = min(
          max(1.0, column.right - column.left),
          max(1.0, block.boundingBox.width),
        );
        if (overlap > smallerWidth * _columnOverlapTolerance) {
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
    final ordered = <OcrBlockData>[];
    for (final column in columns) {
      column.blocks.sort((a, b) {
        final top = a.boundingBox.top.compareTo(b.boundingBox.top);
        return top != 0
            ? top
            : a.boundingBox.left.compareTo(b.boundingBox.left);
      });
      ordered.addAll(column.blocks.map(_withOrderedLines));
    }
    return List.unmodifiable(ordered);
  }

  static OcrBlockData _withOrderedLines(OcrBlockData block) {
    final lines = [...block.lines];
    final medianHeight = _medianHeight(lines);
    lines.sort((a, b) {
      final topDifference = a.boundingBox.top - b.boundingBox.top;
      if (topDifference.abs() < medianHeight * 0.5) {
        return a.boundingBox.left.compareTo(b.boundingBox.left);
      }
      return topDifference.compareTo(0);
    });
    return OcrBlockData(
      text: block.text,
      boundingBox: block.boundingBox,
      lines: List.unmodifiable(lines),
    );
  }

  static double _medianHeight(List<OcrLineData> lines) {
    final heights =
        lines
            .map((line) => line.boundingBox.height)
            .where((height) => height > 0)
            .toList()
          ..sort();
    if (heights.isEmpty) return 12.0;
    final middle = heights.length ~/ 2;
    return max(
      1.0,
      heights.length.isOdd
          ? heights[middle]
          : (heights[middle - 1] + heights[middle]) / 2,
    );
  }
}

class _Column {
  double left;
  double right;
  final List<OcrBlockData> blocks;

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
