import 'dart:math';
import 'package:flutter/material.dart';
import '../models/text_formatter_models.dart';

/// Model representasi kelompok teks (paragraph / text cluster) pada citra.
@immutable
class TextCluster {
  final int id;
  final Rect boundingBox;
  final List<OcrLineData> lines;
  final double score;

  const TextCluster({
    required this.id,
    required this.boundingBox,
    required this.lines,
    required this.score,
  });

  /// Menggabungkan teks dari seluruh baris dalam cluster.
  String get fullText => lines.map((l) => l.text).join('\n');
}

/// Struktur data Disjoint Set (Union-Find) untuk pengelompokan baris teks.
class _UnionFind {
  final List<int> _parent;
  final List<int> _rank;

  _UnionFind(int size)
      : _parent = List<int>.generate(size, (i) => i),
        _rank = List<int>.filled(size, 0);

  int find(int i) {
    if (_parent[i] == i) return i;
    _parent[i] = find(_parent[i]);
    return _parent[i];
  }

  void union(int i, int j) {
    final rootI = find(i);
    final rootJ = find(j);
    if (rootI == rootJ) return;

    if (_rank[rootI] < _rank[rootJ]) {
      _parent[rootI] = rootJ;
    } else if (_rank[rootI] > _rank[rootJ]) {
      _parent[rootJ] = rootI;
    } else {
      _parent[rootJ] = rootI;
      _rank[rootI]++;
    }
  }
}

/// Layanan murni untuk mendeteksi kelompok teks otomatis (clustering)
/// menggunakan algoritma union-find berbasis kedekatan baris.
class TextClusterHelper {
  /// Rasio jarak vertikal maksimum terhadap tinggi median baris (H).
  static const double verticalDistanceRatio = 1.2;

  /// Rasio jarak horizontal maksimum terhadap tinggi median baris (H) jika tidak bertumpuk.
  static const double horizontalDistanceRatio = 2.0;

  /// Rasio padding batas luar kelompok terhadap tinggi median baris (H).
  static const double paddingRatio = 0.5;

  /// Durasi animasi perpindahan bingkai saat mengetuk kelompok lain.
  static const Duration switchAnimationDuration = Duration(milliseconds: 200);

  /// Jeda debouncing sebelum memproses teks seleksi.
  static const Duration selectionDebounceDuration = Duration(milliseconds: 300);

  /// Mengelompokkan baris-baris OCR yang telah disaring (filteredLines) ke dalam TextCluster.
  /// Baris yang dimasukkan harus sudah lolos OcrNoiseFilter agar status bar, jam, dan noise
  /// tidak membentuk kelompok teks.
  static List<TextCluster> detectClusters({
    required List<OcrLineData> filteredLines,
    required Size imageSize,
  }) {
    if (filteredLines.isEmpty ||
        imageSize.width <= 0 ||
        imageSize.height <= 0) {
      return const [];
    }

    // 1. Hitung tinggi median baris (H)
    final heights = filteredLines
        .map((line) => line.boundingBox.height)
        .where((h) => h > 0)
        .toList()
      ..sort();

    if (heights.isEmpty) return const [];

    final double medianH;
    final int mid = heights.length ~/ 2;
    if (heights.length.isOdd) {
      medianH = heights[mid];
    } else {
      medianH = (heights[mid - 1] + heights[mid]) / 2.0;
    }

    if (medianH <= 0) return const [];

    final double maxVerticalDist = medianH * verticalDistanceRatio;
    final double maxHorizontalDist = medianH * horizontalDistanceRatio;
    final double clusterPadding = medianH * paddingRatio;

    // 2. Hubungkan baris yang berdekatan menggunakan Union-Find
    final n = filteredLines.length;
    final uf = _UnionFind(n);

    for (int i = 0; i < n; i++) {
      final rectA = filteredLines[i].boundingBox;
      for (int j = i + 1; j < n; j++) {
        final rectB = filteredLines[j].boundingBox;

        // Jarak vertikal: jarak antara tepi terdekat
        final double dy = max(
          0.0,
          max(rectA.top, rectB.top) - min(rectA.bottom, rectB.bottom),
        );

        if (dy > maxVerticalDist) continue;

        // Cek apakah rentang horizontal bertumpuk atau berjarak <= maxHorizontalDist
        final bool horizontalOverlap =
            max(rectA.left, rectB.left) <= min(rectA.right, rectB.right);
        final double dx = horizontalOverlap
            ? 0.0
            : max(
                0.0,
                max(rectA.left, rectB.left) - min(rectA.right, rectB.right),
              );

        if (dx <= maxHorizontalDist) {
          uf.union(i, j);
        }
      }
    }

    // 3. Kumpulkan baris per komponen kelompok
    final Map<int, List<OcrLineData>> groups = {};
    for (int i = 0; i < n; i++) {
      final root = uf.find(i);
      groups.putIfAbsent(root, () => []).add(filteredLines[i]);
    }

    // 4. Hitung bounding box, padding, dan skor untuk setiap kelompok
    final Offset imageCenter = Offset(
      imageSize.width / 2.0,
      imageSize.height / 2.0,
    );
    final double maxCenterDist = sqrt(
      pow(imageSize.width / 2.0, 2) + pow(imageSize.height / 2.0, 2),
    );

    final List<TextCluster> clusters = [];
    int clusterId = 0;

    for (final entry in groups.entries) {
      final linesInGroup = entry.value;

      double minLeft = double.infinity;
      double minTop = double.infinity;
      double maxRight = double.negativeInfinity;
      double maxBottom = double.negativeInfinity;
      double totalArea = 0.0;

      for (final line in linesInGroup) {
        final r = line.boundingBox;
        if (r.left < minLeft) minLeft = r.left;
        if (r.top < minTop) minTop = r.top;
        if (r.right > maxRight) maxRight = r.right;
        if (r.bottom > maxBottom) maxBottom = r.bottom;

        totalArea += (r.width * r.height);
      }

      // Tambahkan padding dan batasi ke dimensi citra
      final paddedLeft = (minLeft - clusterPadding).clamp(0.0, imageSize.width);
      final paddedTop = (minTop - clusterPadding).clamp(0.0, imageSize.height);
      final paddedRight =
          (maxRight + clusterPadding).clamp(0.0, imageSize.width);
      final paddedBottom =
          (maxBottom + clusterPadding).clamp(0.0, imageSize.height);

      final boundingBox = Rect.fromLTRB(
        min(paddedLeft, paddedRight),
        min(paddedTop, paddedBottom),
        max(paddedLeft, paddedRight),
        max(paddedTop, paddedBottom),
      );

      // Hitung faktor kedekatan ke tengah citra (0.5 sampai 1.0)
      final clusterCenter = boundingBox.center;
      final double distToCenter = (clusterCenter - imageCenter).distance;
      final double centerFactor = maxCenterDist > 0
          ? (1.0 - 0.5 * (distToCenter / maxCenterDist)).clamp(0.5, 1.0)
          : 1.0;

      final double score = totalArea * centerFactor;

      clusters.add(TextCluster(
        id: clusterId++,
        boundingBox: boundingBox,
        lines: linesInGroup,
        score: score,
      ));
    }

    // 5. Urutkan kelompok berdasarkan skor tertinggi. Jika seri, pilih yang paling dekat ke tengah.
    clusters.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;

      final distA = (a.boundingBox.center - imageCenter).distance;
      final distB = (b.boundingBox.center - imageCenter).distance;
      return distA.compareTo(distB);
    });

    return clusters;
  }

  /// Menemukan kelompok teks yang terkena titik ketuk (imagePoint dalam piksel citra).
  /// Jika titik ketuk berada di dalam beberapa kelompok berpadding yang saling bertumpuk,
  /// pilih kelompok yang pusatnya paling dekat dengan titik ketuk.
  /// Jika ada kelompok kecil yang berada di dalam kelompok lain, pilih yang luasnya terkecil.
  static TextCluster? findClusterAtPoint({
    required Offset imagePoint,
    required List<TextCluster> clusters,
  }) {
    if (clusters.isEmpty) return null;

    final matchingClusters = clusters
        .where((c) => c.boundingBox.contains(imagePoint))
        .toList();

    if (matchingClusters.isEmpty) return null;
    if (matchingClusters.length == 1) return matchingClusters.first;

    // Jika tumpang tindih:
    // 1. Cek apakah ada kelompok yang berada di dalam kelompok lain (nested), prioritaskan yang terkecil
    // 2. Jika tidak nested, pilih yang pusat boundingBox-nya paling dekat ke titik ketuk
    matchingClusters.sort((a, b) {
      final areaA = a.boundingBox.width * a.boundingBox.height;
      final areaB = b.boundingBox.width * b.boundingBox.height;

      final aInsideB = b.boundingBox.contains(a.boundingBox.topLeft) &&
          b.boundingBox.contains(a.boundingBox.bottomRight);
      final bInsideA = a.boundingBox.contains(b.boundingBox.topLeft) &&
          a.boundingBox.contains(b.boundingBox.bottomRight);

      if (aInsideB && !bInsideA) return -1;
      if (bInsideA && !aInsideB) return 1;

      final distA = (a.boundingBox.center - imagePoint).distance;
      final distB = (b.boundingBox.center - imagePoint).distance;
      final distDiff = (distA - distB).abs();

      if (distDiff < 2.0) {
        return areaA.compareTo(areaB);
      }
      return distA.compareTo(distB);
    });

    return matchingClusters.first;
  }

  /// Evaluasi keputusan ketukan pada citra:
  /// 1. Temukan kelompok teks pada titik ketuk (imagePoint).
  /// 2. Jika tidak ada kelompok yang terkena (area kosong), kembalikan [TapDecisionAction.ignoreEmptySpace].
  /// 3. Jika kelompok yang terkena sudah sama dengan bingkai aktif (selisih di bawah [tolerancePx]),
  ///    kembalikan [TapDecisionAction.ignoreAlreadyActive].
  /// 4. Jika berbeda (termasuk saat bingkai aktif adalah Full image),
  ///    kembalikan [TapDecisionAction.animateToCluster].
  static TapDecision evaluateTapDecision({
    required Offset imagePoint,
    required List<TextCluster> clusters,
    required Rect activeFrameRect,
    double tolerancePx = 4.0,
  }) {
    final cluster = findClusterAtPoint(
      imagePoint: imagePoint,
      clusters: clusters,
    );

    if (cluster == null) {
      return const TapDecision(action: TapDecisionAction.ignoreEmptySpace);
    }

    // Cek apakah kotak kelompok sudah sama dengan bingkai aktif dalam batas toleransi
    final isSameRect = (cluster.boundingBox.left - activeFrameRect.left).abs() <= tolerancePx &&
        (cluster.boundingBox.top - activeFrameRect.top).abs() <= tolerancePx &&
        (cluster.boundingBox.right - activeFrameRect.right).abs() <= tolerancePx &&
        (cluster.boundingBox.bottom - activeFrameRect.bottom).abs() <= tolerancePx;

    if (isSameRect) {
      return TapDecision(
        action: TapDecisionAction.ignoreAlreadyActive,
        targetCluster: cluster,
        targetRect: cluster.boundingBox,
      );
    }

    return TapDecision(
      action: TapDecisionAction.animateToCluster,
      targetCluster: cluster,
      targetRect: cluster.boundingBox,
    );
  }
}

/// Aksi hasil evaluasi ketukan pada citra
enum TapDecisionAction {
  /// Pindahkan atau kecilkan bingkai ke kelompok teks target
  animateToCluster,

  /// Ketukan diabaikan karena kelompok sudah sama dengan bingkai aktif
  ignoreAlreadyActive,

  /// Ketukan diabaikan karena jatuh di area kosong di luar semua kelompok
  ignoreEmptySpace,
}

/// Hasil keputusan evaluasi ketukan pada citra
class TapDecision {
  final TapDecisionAction action;
  final TextCluster? targetCluster;
  final Rect? targetRect;

  const TapDecision({
    required this.action,
    this.targetCluster,
    this.targetRect,
  });

  bool get shouldAnimate => action == TapDecisionAction.animateToCluster;
}
