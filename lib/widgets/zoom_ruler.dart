import 'package:flutter/material.dart';

class ZoomRuler extends StatefulWidget {
  final double currentZoom;
  final ValueChanged<double>? onZoomChanged;

  const ZoomRuler({
    super.key,
    this.currentZoom = 1.0,
    this.onZoomChanged,
  });

  @override
  State<ZoomRuler> createState() => _ZoomRulerState();
}

class _ZoomRulerState extends State<ZoomRuler> {
  late double _zoom;

  @override
  void initState() {
    super.initState();
    _zoom = widget.currentZoom;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        setState(() {
          _zoom = (_zoom - details.delta.dy * 0.02).clamp(1.0, 5.0);
        });
        widget.onZoomChanged?.call(_zoom);
      },
      child: Container(
        width: 32,
        height: 180,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(10),
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 0.8,
          ),
        ),
        child: CustomPaint(
          painter: _RulerPainter(zoom: _zoom),
        ),
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  final double zoom;

  _RulerPainter({required this.zoom});

  @override
  void paint(Canvas canvas, Size size) {
    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 1.0;

    final activePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0;

    const totalTicks = 20;
    final spacing = size.height / (totalTicks - 1);

    for (int i = 0; i < totalTicks; i++) {
      final y = i * spacing;
      final isMajor = i % 5 == 0;
      final tickLength = isMajor ? 18.0 : 10.0;

      canvas.drawLine(
        Offset(size.width - tickLength, y),
        Offset(size.width, y),
        tickPaint,
      );
    }

    // Active marker based on zoom (1.0 to 5.0)
    final progress = (zoom - 1.0) / 4.0;
    final markerY = size.height - (progress * size.height);
    canvas.drawLine(
      Offset(4, markerY),
      Offset(size.width, markerY),
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RulerPainter oldDelegate) =>
      zoom != oldDelegate.zoom;
}
