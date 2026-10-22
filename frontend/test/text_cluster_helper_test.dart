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
  });
}
