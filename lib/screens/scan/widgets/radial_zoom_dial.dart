import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Radial Zoom Dial terinspirasi dari kamera profesional / iOS:
/// - Terletak di tengah bawah, tepat di atas shutter button.
/// - Skala melengkung halus dengan indikator panah segitiga kuning & teks kuning aktif.
/// - Menampilkan titik henti zoom (1x, 1.5x, 2x) dan garis tick presisi.
/// - Responsif terhadap sentuhan geser horizontal halus dan animasi mulus.
class RadialZoomDial extends StatelessWidget {
  final double currentZoom;
  final double minZoom;
  final double maxZoom;
  final ValueChanged<double> onZoomChanged;

  const RadialZoomDial({
    super.key,
    required this.currentZoom,
    this.minZoom = 1.0,
    this.maxZoom = 2.0,
    required this.onZoomChanged,
  });

  @override
  Widget build(BuildContext context) {
    final displayZoomText = '${currentZoom.toStringAsFixed(1)}x';

    return SizedBox(
      width: 260,
      height: 72,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) {
          // Geser jari ke kanan = zoom in, geser ke kiri = zoom out
          final delta = details.primaryDelta ?? 0.0;
          final sensitivity = (maxZoom - minZoom) / 180.0;
          final newZoom = (currentZoom + delta * sensitivity).clamp(minZoom, maxZoom);
          if ((newZoom - currentZoom).abs() > 0.005) {
            onZoomChanged(newZoom);
          }
        },
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // Latar busur radial semi-transparan kaca gelap
            Positioned(
              top: 14,
              child: Container(
                width: 250,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 0.8,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  child: CustomPaint(
                    painter: _RadialDialPainter(
                      currentZoom: currentZoom,
                      minZoom: minZoom,
                      maxZoom: maxZoom,
                    ),
                  ),
                ),
              ),
            ),

            // Indikator Titik Tengah Atas: Segitiga Kuning + Angka Kuning
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Segitiga penunjuk kuning
                CustomPaint(
                  size: const Size(10, 6),
                  painter: _TrianglePointerPainter(color: const Color(0xFFFACC15)),
                ),
                const SizedBox(height: 1),
                // Nilai zoom aktif warna kuning
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    displayZoomText,
                    style: const TextStyle(
                      color: Color(0xFFFACC15),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrianglePointerPainter extends CustomPainter {
  final Color color;

  _TrianglePointerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePointerPainter oldDelegate) =>
      color != oldDelegate.color;
}

class _RadialDialPainter extends CustomPainter {
  final double currentZoom;
  final double minZoom;
  final double maxZoom;

  _RadialDialPainter({
    required this.currentZoom,
    required this.minZoom,
    required this.maxZoom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height + 90);
    final radius = 130.0;

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    final majorPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    // Normalisasi posisi zoom saat ini ke sudut
    final totalSteps = 20;
    final zoomRange = maxZoom - minZoom;
    final normalized = (currentZoom - minZoom) / (zoomRange == 0 ? 1 : zoomRange);

    // Rentang sudut busur yang ditampilkan (-0.55 rad sampai +0.55 rad)
    final arcSpan = 0.95;
    final startAngle = -math.pi / 2 - (arcSpan / 2);

    for (int i = 0; i <= totalSteps; i++) {
      final t = i / totalSteps;
      final angle = startAngle + (t * arcSpan) - ((normalized - 0.5) * arcSpan * 0.9);

      // Hanya gambar jika berada di dalam area tampak
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      if (x < 10 || x > size.width - 10 || y < 10 || y > size.height + 20) {
        continue;
      }

      final isMajor = i % 5 == 0;
      final tickLength = isMajor ? 12.0 : 6.0;

      final innerX = center.dx + (radius - tickLength) * math.cos(angle);
      final innerY = center.dy + (radius - tickLength) * math.sin(angle);

      canvas.drawLine(
        Offset(innerX, innerY),
        Offset(x, y),
        isMajor ? majorPaint : linePaint,
      );

      // Teks label untuk titik henti 1x, 1.5x, 2x
      if (isMajor && y > 28) {
        final zoomVal = minZoom + (t * zoomRange);
        final labelText = zoomVal.toStringAsFixed(1);
        final textPainter = TextPainter(
          text: TextSpan(
            text: labelText,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(
          canvas,
          Offset(innerX - textPainter.width / 2, innerY - textPainter.height - 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RadialDialPainter oldDelegate) =>
      currentZoom != oldDelegate.currentZoom ||
      minZoom != oldDelegate.minZoom ||
      maxZoom != oldDelegate.maxZoom;
}
