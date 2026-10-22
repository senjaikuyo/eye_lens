import 'package:eye_lens/models/text_formatter_models.dart';
import 'package:eye_lens/services/text_cluster_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TextClusterHelper Unit Tests', () {
    const imageSize = Size(1000, 2000);

    test('1. Mengelompokkan baris paragraf yang berdekatan ke dalam satu cluster', () {
      // Dua baris paragraf dengan tinggi 40px, berjarak 20px vertikal
      const line1 = OcrLineData(
        text: 'Baris pertama dari paragraf dokumen',
        boundingBox: Rect.fromLTRB(100, 200, 500, 240), // H = 40
      );
      const line2 = OcrLineData(
        text: 'Baris kedua dari paragraf dokumen',
        boundingBox: Rect.fromLTRB(100, 260, 520, 300), // H = 40, gap = 20 <= 1.2*40
      );

      final clusters = TextClusterHelper.detectClusters(
        filteredLines: [line1, line2],
        imageSize: imageSize,
      );

      expect(clusters.length, equals(1));
      expect(clusters.first.lines.length, equals(2));
      expect(clusters.first.fullText, contains('Baris pertama'));
      expect(clusters.first.fullText, contains('Baris kedua'));
    });

    test('2. Memisahkan dua paragraf yang terpisah jarak vertikal jauh', () {
      const lineTop = OcrLineData(
        text: 'Judul Atas Dokumen',
        boundingBox: Rect.fromLTRB(100, 100, 500, 150), // H = 50
      );
      const lineBottom = OcrLineData(
        text: 'Teks Footer di Bawah Sekali',
        boundingBox: Rect.fromLTRB(100, 1500, 500, 1550), // Jauh
      );

      final clusters = TextClusterHelper.detectClusters(
        filteredLines: [lineTop, lineBottom],
        imageSize: imageSize,
      );

      expect(clusters.length, equals(2));
    });

    test('3. Bounding box cluster diberi padding 0.5 H dan di-clamp ke batas citra', () {
      // Baris sangat mepet ke tepi kiri dan atas (left: 10, top: 10, height: 40)
      const edgeLine = OcrLineData(
        text: 'Teks Dekat Tepi',
        boundingBox: Rect.fromLTRB(10, 10, 200, 50), // H = 40, pad = 20
      );

      final clusters = TextClusterHelper.detectClusters(
        filteredLines: [edgeLine],
        imageSize: imageSize,
      );

      expect(clusters.length, equals(1));
      final box = clusters.first.boundingBox;

      // Seharusnya 10 - 20 = -10, tapi di-clamp menjadi 0.0
      expect(box.left, equals(0.0));
      expect(box.top, equals(0.0));
      expect(box.right, equals(200 + 20));
      expect(box.bottom, equals(50 + 20));
    });

    test('4. Hit-test memilih cluster terdekat pusatnya jika terjadi overlap kotak berpadding', () {
      const dummyLineA = OcrLineData(
        text: 'Cluster A',
        boundingBox: Rect.fromLTRB(110, 210, 290, 390),
      );
      const dummyLineB = OcrLineData(
        text: 'Cluster B',
        boundingBox: Rect.fromLTRB(260, 210, 440, 390),
      );

      // Cluster A: center sekitar (200, 300)
      final clusterA = TextCluster(
        id: 0,
        lines: const [dummyLineA],
        boundingBox: const Rect.fromLTRB(100, 200, 300, 400),
        score: 1.0,
      );

      // Cluster B: center sekitar (350, 300)
      // Overlap pada rentang X 250 - 300
      final clusterB = TextCluster(
        id: 1,
        lines: const [dummyLineB],
        boundingBox: const Rect.fromLTRB(250, 200, 450, 400),
        score: 1.0,
      );

      // Titik ketuk di (260, 300):
      // Jarak ke center A (200, 300) = 60
      // Jarak ke center B (350, 300) = 90
      // Maka harus memilih Cluster A!
      final hitA = TextClusterHelper.findClusterAtPoint(
        imagePoint: const Offset(260, 300),
        clusters: [clusterA, clusterB],
      );
      expect(hitA?.id, equals(0));

      // Titik ketuk di (295, 300):
      // Jarak ke center A (200, 300) = 95
      // Jarak ke center B (350, 300) = 55
      // Maka harus memilih Cluster B!
      final hitB = TextClusterHelper.findClusterAtPoint(
        imagePoint: const Offset(295, 300),
        clusters: [clusterA, clusterB],
      );
      expect(hitB?.id, equals(1));
    });

    test('5. Daftar baris kosong menghasilkan cluster kosong', () {
      final clusters = TextClusterHelper.detectClusters(
        filteredLines: const [],
        imageSize: imageSize,
      );
      expect(clusters, isEmpty);
    });

    test('6. Kelompok kecil di dalam kelompok besar (nested): pilih yang terkecil', () {
      // Cluster Besar (misal sebuah kontainer pesan utuh): 100, 100 -> 500, 500 (luas = 160.000)
      final outerCluster = TextCluster(
        id: 0,
        lines: const [],
        boundingBox: const Rect.fromLTRB(100, 100, 500, 500),
        score: 1.0,
      );

      // Cluster Kecil di dalam Cluster Besar: 200, 200 -> 300, 300 (luas = 10.000)
      final innerCluster = TextCluster(
        id: 1,
        lines: const [],
        boundingBox: const Rect.fromLTRB(200, 200, 300, 300),
        score: 1.0,
      );

      // Titik ketuk di dalam cluster kecil (250, 250)
      final hit = TextClusterHelper.findClusterAtPoint(
        imagePoint: const Offset(250, 250),
        clusters: [outerCluster, innerCluster],
      );

      expect(hit?.id, equals(1)); // innerCluster yang luasnya terkecil harus dipilih
    });

    test('7. evaluateTapDecision memindahkan bingkai saat mode Full image aktif', () {
      final fullImageRect = const Rect.fromLTWH(0, 0, 1080, 1920);
      final targetCluster = TextCluster(
        id: 1,
        lines: const [],
        boundingBox: const Rect.fromLTWH(100, 300, 400, 150),
        score: 1.0,
      );

      // Ketukan jatuh di dalam targetCluster (misal 200, 350)
      final decision = TextClusterHelper.evaluateTapDecision(
        imagePoint: const Offset(200, 350),
        clusters: [targetCluster],
        activeFrameRect: fullImageRect,
      );

      expect(decision.action, equals(TapDecisionAction.animateToCluster));
      expect(decision.shouldAnimate, isTrue);
      expect(decision.targetRect, equals(targetCluster.boundingBox));
    });

    test('8. evaluateTapDecision mengabaikan ketukan jika kelompok sudah sama dengan bingkai aktif', () {
      final activeRect = const Rect.fromLTWH(100, 300, 400, 150);
      final targetCluster = TextCluster(
        id: 1,
        lines: const [],
        boundingBox: const Rect.fromLTWH(100, 300, 400, 150),
        score: 1.0,
      );

      final decision = TextClusterHelper.evaluateTapDecision(
        imagePoint: const Offset(200, 350),
        clusters: [targetCluster],
        activeFrameRect: activeRect,
      );

      expect(decision.action, equals(TapDecisionAction.ignoreAlreadyActive));
      expect(decision.shouldAnimate, isFalse);
    });

    test('9. evaluateTapDecision mengabaikan ketukan pada area kosong di luar semua kelompok', () {
      final fullImageRect = const Rect.fromLTWH(0, 0, 1080, 1920);
      final targetCluster = TextCluster(
        id: 1,
        lines: const [],
        boundingBox: const Rect.fromLTWH(100, 300, 400, 150),
        score: 1.0,
      );

      // Ketuk di titik kosong (50, 50)
      final decision = TextClusterHelper.evaluateTapDecision(
        imagePoint: const Offset(50, 50),
        clusters: [targetCluster],
        activeFrameRect: fullImageRect,
      );

      expect(decision.action, equals(TapDecisionAction.ignoreEmptySpace));
      expect(decision.shouldAnimate, isFalse);
      expect(decision.targetCluster, isNull);
    });
  });
}
