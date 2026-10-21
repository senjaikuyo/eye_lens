import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../services/camera_service.dart';
import '../../../widgets/scanner_corner_painter.dart';

class CameraViewfinder extends StatefulWidget {
  final CameraService cameraService;
  final double currentZoom;
  final ValueChanged<double> onZoomChanged;
  final bool isBlurry;
  final Size size;

  const CameraViewfinder({
    super.key,
    required this.cameraService,
    required this.currentZoom,
    required this.onZoomChanged,
    required this.isBlurry,
    required this.size,
  });

  @override
  State<CameraViewfinder> createState() => _CameraViewfinderState();
}

class _CameraViewfinderState extends State<CameraViewfinder> {
  double _baseScaleZoom = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: (details) {
        _baseScaleZoom = widget.currentZoom;
      },
      onScaleUpdate: (details) {
        if (details.pointerCount > 1) {
          // Zoom Cubit (Pinch 2 jari)
          widget.onZoomChanged(_baseScaleZoom * details.scale);
        } else {
          // Swipe 1 Jari Vertikal: Ke atas = zoom in, ke bawah = zoom out
          final dy = details.focalPointDelta.dy;
          const sensitivity = 0.015;
          widget.onZoomChanged(widget.currentZoom - (dy * sensitivity));
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Live Camera Preview atau fallback
          if (widget.cameraService.isInitialized &&
              widget.cameraService.controller != null)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width:
                      widget
                          .cameraService
                          .controller!
                          .value
                          .previewSize
                          ?.height ??
                      widget.size.width,
                  height:
                      widget
                          .cameraService
                          .controller!
                          .value
                          .previewSize
                          ?.width ??
                      widget.size.height,
                  child: CameraPreview(widget.cameraService.controller!),
                ),
              ),
            )
          else
            Image.asset(
              'assets/images/UI Scanning Teks.png',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),

          // Subtle Vignette Gradient
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.45),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.6),
                  ],
                  stops: const [0.0, 0.2, 0.7, 1.0],
                ),
              ),
            ),
          ),

          // Central Viewfinder Frame - 4 Busur Melengkung Halus di Sudut
          Center(
            child: SizedBox(
              width: widget.size.width * 0.78,
              height: widget.size.width * 0.78,
              child: CustomPaint(
                painter: ScannerCornerPainter(
                  color: widget.isBlurry
                      ? const Color(0xFFF59E0B)
                      : Colors.white.withValues(alpha: 0.85),
                  strokeWidth: 2.0,
                  arcRadius: 40.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
