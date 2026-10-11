import 'package:flutter/material.dart';

class ZoomRuler extends StatelessWidget {
  final double currentZoom;
  final double minZoom;
  final double maxZoom;
  final ValueChanged<double>? onZoomChanged;

  const ZoomRuler({
    super.key,
    required this.currentZoom,
    this.minZoom = 1.0,
    this.maxZoom = 10.0,
    this.onZoomChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) {
        // Drag ke atas = zoom in, drag ke bawah = zoom out
        final dy = details.delta.dy;
        final sensitivity = (maxZoom - minZoom) / 180.0;
        final newZoom = (currentZoom - dy * sensitivity).clamp(minZoom, maxZoom);
        onZoomChanged?.call(newZoom);
      },
      child: Container(
        width: 36,
        height: 190,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(16),
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
            width: 0.8,
          ),
        ),
        child: CustomPaint(
          painter: _RulerPainter(
            zoom: currentZoom,
            minZoom: minZoom,
            maxZoom: maxZoom,
          ),
        ),
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  final double zoom;
  final double minZoom;
  final double maxZoom;

  _RulerPainter({
    required this.zoom,
    required this.minZoom,
    required this.maxZoom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    final majorTickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final activePaint = Paint()
      ..color = const Color(0xFFFACC15) // Kuning aksen
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    const totalTicks = 19;
    final spacing = size.height / (totalTicks - 1);

    for (int i = 0; i < totalTicks; i++) {
      final y = i * spacing;
      final isMajor = i % 3 == 0;
      final tickLength = isMajor ? 18.0 : 9.0;

      canvas.drawLine(
        Offset(size.width - tickLength, y),
        Offset(size.width - 2, y),
        isMajor ? majorTickPaint : tickPaint,
      );
    }

    // Active marker garis kuning berdasarkan zoom (minZoom s.d maxZoom)
    final range = maxZoom - minZoom;
    final progress = range > 0 ? ((zoom - minZoom) / range).clamp(0.0, 1.0) : 0.0;
    final markerY = size.height - (progress * size.height);

    canvas.drawLine(
      Offset(4, markerY),
      Offset(size.width - 2, markerY),
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RulerPainter oldDelegate) =>
      zoom != oldDelegate.zoom ||
      minZoom != oldDelegate.minZoom ||
      maxZoom != oldDelegate.maxZoom;
}
