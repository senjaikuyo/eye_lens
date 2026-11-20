import 'dart:math' as math;
import 'dart:ui';

import 'package:eye_lens/features/ocr/orientation/text_orientation.dart';
import 'package:eye_lens/features/ocr/orientation/text_orientation_analyzer.dart';
import 'package:eye_lens/features/speech/models/text_formatter_models.dart';

/// Menyusun urutan baca memakai arah baseline dan orientasi teks.
///
/// Koordinat atas/kiri tidak pernah dipakai sebagai penentu tunggal. Untuk
/// teks 180°, 90°, dan 270°, sumbu baca diputar mengikuti orientasi baris.
class OrientationAwareReadingOrder {
  const OrientationAwareReadingOrder._();

  static List<OcrBlockData> resolve(List<OcrBlockData> blocks) {
    final valid = blocks.where((b) => b.lines.isNotEmpty).toList();
    if (valid.isEmpty) return List.unmodifiable(<OcrBlockData>[]);

    final allLines = valid.expand((b) => b.lines).toList();
    final analysis = TextOrientationAnalyzer.analyze(allLines);
    final documentOrientation = analysis.dominantOrientation;
    final documentAxis = readingAxisFor(documentOrientation);
    final documentCross = crossAxisFor(documentAxis);

    final ordered = [
      for (final block in valid)
        _orderBlock(block, fallbackOrientation: documentOrientation),
    ];

    final columnsAllowed = valid.every(
      (block) =>
          _blockOrientation(block, documentOrientation) == documentOrientation,
    );
    final columnOrdered = columnsAllowed
        ? _tryColumns(ordered, documentOrientation, documentAxis, documentCross)
        : null;
    if (columnOrdered == null) {
      ordered.sort(
        (a, b) => _compareBlocks(
          a,
          b,
          documentOrientation,
          documentAxis,
          documentCross,
        ),
      );
    }
    return List.unmodifiable(columnOrdered ?? ordered);
  }

  /// Kolom lintas blok hanya diterima bila ada gutter nyata dan baris berulang.
  /// Pendekatan ini menggantikan pengurutan top/left lama.
  static List<OcrBlockData>? _tryColumns(
    List<OcrBlockData> blocks,
    TextOrientation documentOrientation,
    Offset axis,
    Offset cross,
  ) {
    if (blocks.length < 2) return null;
    final items = [
      for (final block in blocks) _BlockGeometry.from(block, axis, cross),
    ];
    if (items.any((item) => item.orientation != documentOrientation)) {
      return null;
    }

    final byRead = [...items]..sort((a, b) => a.readMin.compareTo(b.readMin));
    final columns = <_ColumnGeometry>[];
    for (final item in byRead) {
      _ColumnGeometry? match;
      for (final column in columns) {
        final overlap =
            math.min(column.readMax, item.readMax) -
            math.max(column.readMin, item.readMin);
        if (overlap > 0) {
          match = column;
          break;
        }
      }
      if (match == null) {
        columns.add(_ColumnGeometry([item]));
      } else {
        match.items.add(item);
      }
    }
    if (columns.length < 2) return null;

    columns.sort((a, b) => a.readMin.compareTo(b.readMin));
    var repeatedColumn = false;
    for (var i = 0; i < columns.length; i++) {
      final column = columns[i];
      final lineCount = column.items.fold<int>(
        0,
        (sum, item) => sum + item.block.lines.length,
      );
      if (lineCount >= 2) repeatedColumn = true;
      if (i == 0) continue;
      final previous = columns[i - 1];
      final gap = column.readMin - previous.readMax;
      final smallerWidth = math.min(column.readWidth, previous.readWidth);
      final overlap =
          math.min(column.crossMax, previous.crossMax) -
          math.max(column.crossMin, previous.crossMin);
      final smallerHeight = math.min(column.crossHeight, previous.crossHeight);
      if (smallerWidth <= 0 ||
          smallerHeight <= 0 ||
          gap < smallerWidth * 0.1 ||
          overlap < smallerHeight * 0.25) {
        return null;
      }
    }
    if (!repeatedColumn) return null;

    final ordered = <OcrBlockData>[];
    for (final column in columns) {
      column.items.sort((a, b) => a.crossMin.compareTo(b.crossMin));
      ordered.addAll(column.items.map((item) => item.block));
    }
    return ordered;
  }

  static OcrBlockData _orderBlock(
    OcrBlockData block, {
    required TextOrientation fallbackOrientation,
  }) {
    final geoms = [for (final line in block.lines) _LineGeometry.from(line)];
    if (geoms.length < 2) {
      return OcrBlockData(
        text: block.text,
        boundingBox: block.boundingBox,
        lines: List.unmodifiable(block.lines),
      );
    }

    final blockOrientation = _dominantOrientation(
      geoms,
      fallback: fallbackOrientation,
    );
    final blockAxis = readingAxisFor(blockOrientation);
    final blockExtent = _extent(block.boundingBox, blockAxis);

    final split = _detectColumnSplit(geoms, blockExtent);
    final orderedLines = <OcrLineData>[];
    if (split != null) {
      final left = <_LineGeometry>[];
      final right = <_LineGeometry>[];
      for (final geom in geoms) {
        (geom.readPosition < split ? left : right).add(geom);
      }
      if (left.length >= 2 && right.length >= 2) {
        left.sort(_compareWithinBand);
        right.sort(_compareWithinBand);
        orderedLines.addAll(left.map((g) => g.line));
        orderedLines.addAll(right.map((g) => g.line));
      }
    }
    if (orderedLines.isEmpty) {
      orderedLines.addAll(_orderByBands(geoms));
    }

    return OcrBlockData(
      text: block.text,
      boundingBox: block.boundingBox,
      lines: List.unmodifiable(orderedLines),
    );
  }

  static List<OcrLineData> _orderByBands(List<_LineGeometry> geoms) {
    final sorted = [...geoms]
      ..sort((a, b) {
        final cross = a.crossPosition.compareTo(b.crossPosition);
        return cross != 0 ? cross : a.readPosition.compareTo(b.readPosition);
      });

    final crossSizes =
        sorted
            .map((g) => g.crossExtent)
            .where((v) => v.isFinite && v > 0)
            .toList()
          ..sort();
    final medianCross = crossSizes.isEmpty
        ? 12.0
        : crossSizes.length.isOdd
        ? crossSizes[crossSizes.length ~/ 2]
        : (crossSizes[crossSizes.length ~/ 2 - 1] +
                  crossSizes[crossSizes.length ~/ 2]) /
              2;
    final threshold = math.max(8.0, medianCross * 0.8);

    final bands = <List<_LineGeometry>>[];
    for (final geom in sorted) {
      if (bands.isEmpty ||
          geom.crossPosition - bands.last.first.crossPosition > threshold) {
        bands.add([geom]);
      } else {
        bands.last.add(geom);
      }
    }

    final result = <OcrLineData>[];
    for (final band in bands) {
      band.sort(_compareWithinBand);
      result.addAll(band.map((g) => g.line));
    }
    return result;
  }

  static int _compareWithinBand(_LineGeometry a, _LineGeometry b) {
    final along = a.readPosition.compareTo(b.readPosition);
    if (along != 0) return along;
    final cross = a.crossPosition.compareTo(b.crossPosition);
    return cross != 0
        ? cross
        : a.line.boundingBox.top.compareTo(b.line.boundingBox.top);
  }

  static int _compareBlocks(
    OcrBlockData a,
    OcrBlockData b,
    TextOrientation documentOrientation,
    Offset documentAxis,
    Offset documentCross,
  ) {
    final aOrientation = _blockOrientation(a, documentOrientation);
    final bOrientation = _blockOrientation(b, documentOrientation);
    final top = a.boundingBox.top.compareTo(b.boundingBox.top);
    if (top != 0) return top;
    final left = a.boundingBox.left.compareTo(b.boundingBox.left);
    if (left != 0) return left;

    // Equal visual origin: keep document-orientation preference only as a
    // deterministic tie-breaker, never to hide a vertical block.
    final aPriority = aOrientation == documentOrientation ? 0 : 1;
    final bPriority = bOrientation == documentOrientation ? 0 : 1;
    return aPriority.compareTo(bPriority);
  }

  static TextOrientation _blockOrientation(
    OcrBlockData block,
    TextOrientation fallback,
  ) {
    return _dominantOrientation([
      for (final line in block.lines) _LineGeometry.from(line),
    ], fallback: fallback);
  }

  static TextOrientation _dominantOrientation(
    List<_LineGeometry> geoms, {
    required TextOrientation fallback,
  }) {
    final votes = <TextOrientation, double>{
      for (final value in TextOrientation.values) value: 0,
    };
    for (final geom in geoms) {
      final estimate = geom.estimate;
      votes[estimate.orientation] =
          votes[estimate.orientation]! + math.max(0.2, estimate.confidence);
    }
    var winner = fallback;
    for (final entry in votes.entries) {
      if (entry.value > votes[winner]! ||
          (entry.value == votes[winner]! &&
              entry.key.quarterTurns < winner.quarterTurns)) {
        winner = entry.key;
      }
    }
    return winner;
  }

  /// Deteksi dua kolom di dalam satu blok memakai proyeksi sumbu baca.
  static double? _detectColumnSplit(
    List<_LineGeometry> geoms,
    double blockExtent,
  ) {
    if (geoms.length < 4 || blockExtent <= 0) return null;
    if (geoms.any((g) => g.readExtent > blockExtent * 0.6)) return null;

    final byRead = [...geoms]
      ..sort((a, b) => a.readPosition.compareTo(b.readPosition));
    final minimumGap = math.max(20.0, blockExtent * 0.06);
    double? bestSplit;
    var bestGap = 0.0;

    for (var cut = 2; cut <= byRead.length - 2; cut++) {
      final left = byRead.sublist(0, cut);
      final right = byRead.sublist(cut);
      final maxLeftRight = left
          .map((g) => g.readPosition + g.readExtent / 2)
          .reduce(math.max);
      final minRightLeft = right
          .map((g) => g.readPosition - g.readExtent / 2)
          .reduce(math.min);
      final gap = minRightLeft - maxLeftRight;
      if (gap >= minimumGap && gap > bestGap) {
        bestGap = gap;
        bestSplit = (maxLeftRight + minRightLeft) / 2;
      }
    }
    return bestSplit;
  }

  static double _extent(Rect box, Offset axis) =>
      box.width * axis.dx.abs() + box.height * axis.dy.abs();
}

class _LineGeometry {
  final OcrLineData line;
  final TextOrientationEstimate estimate;
  final Offset axis;
  final Offset cross;
  final double readPosition;
  final double crossPosition;
  final double readExtent;
  final double crossExtent;

  const _LineGeometry({
    required this.line,
    required this.estimate,
    required this.axis,
    required this.cross,
    required this.readPosition,
    required this.crossPosition,
    required this.readExtent,
    required this.crossExtent,
  });

  factory _LineGeometry.from(OcrLineData line) {
    final estimate =
        line.orientation ?? TextOrientationAnalyzer.analyzeLine(line);
    final expected = readingAxisFor(
      estimate.orientation,
      skewDegrees: estimate.skewDegrees,
    );
    var axis = expected;

    final words = line.elements.where((w) => w.text.trim().isNotEmpty).toList();
    if (words.length >= 2) {
      final first = words.first.boundingBox.center;
      final last = words.last.boundingBox.center;
      final dx = last.dx - first.dx;
      final dy = last.dy - first.dy;
      final distance = math.sqrt(dx * dx + dy * dy);
      if (distance > 1) {
        var candidate = Offset(dx / distance, dy / distance);
        final alignment =
            candidate.dx * expected.dx + candidate.dy * expected.dy;
        if (alignment < 0) candidate = -candidate;
        axis = candidate;
      }
    }

    final cross = crossAxisFor(axis);
    final center = line.boundingBox.center;
    return _LineGeometry(
      line: line,
      estimate: estimate,
      axis: axis,
      cross: cross,
      readPosition: center.dx * axis.dx + center.dy * axis.dy,
      crossPosition: center.dx * cross.dx + center.dy * cross.dy,
      readExtent: OrientationAwareReadingOrder._extent(line.boundingBox, axis),
      crossExtent: OrientationAwareReadingOrder._extent(
        line.boundingBox,
        cross,
      ),
    );
  }
}

class _BlockGeometry {
  final OcrBlockData block;
  final TextOrientation orientation;
  final double readMin;
  final double readMax;
  final double crossMin;
  final double crossMax;

  double get readWidth => readMax - readMin;
  double get crossHeight => crossMax - crossMin;

  const _BlockGeometry({
    required this.block,
    required this.orientation,
    required this.readMin,
    required this.readMax,
    required this.crossMin,
    required this.crossMax,
  });

  factory _BlockGeometry.from(OcrBlockData block, Offset axis, Offset cross) {
    final center = block.boundingBox.center;
    final readExtent =
        OrientationAwareReadingOrder._extent(block.boundingBox, axis) / 2;
    final crossExtent =
        OrientationAwareReadingOrder._extent(block.boundingBox, cross) / 2;
    final readCenter = center.dx * axis.dx + center.dy * axis.dy;
    final crossCenter = center.dx * cross.dx + center.dy * cross.dy;
    final geoms = [for (final line in block.lines) _LineGeometry.from(line)];
    return _BlockGeometry(
      block: block,
      orientation: OrientationAwareReadingOrder._dominantOrientation(
        geoms,
        fallback: TextOrientation.up,
      ),
      readMin: readCenter - readExtent,
      readMax: readCenter + readExtent,
      crossMin: crossCenter - crossExtent,
      crossMax: crossCenter + crossExtent,
    );
  }
}

class _ColumnGeometry {
  final List<_BlockGeometry> items;

  _ColumnGeometry(this.items);

  double get readMin => items.map((i) => i.readMin).reduce(math.min);
  double get readMax => items.map((i) => i.readMax).reduce(math.max);
  double get readWidth => readMax - readMin;
  double get crossMin => items.map((i) => i.crossMin).reduce(math.min);
  double get crossMax => items.map((i) => i.crossMax).reduce(math.max);
  double get crossHeight => crossMax - crossMin;
}
