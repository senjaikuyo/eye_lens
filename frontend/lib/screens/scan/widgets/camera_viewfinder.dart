import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../services/camera_service.dart';
import '../../../services/lens_selection_helper.dart';
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
          // Zoom Cubit (Pinch 2 jari): kurva responsif halus tanpa lompatan
          final scaleRatio = details.scale;
          final double effectiveScale = scaleRatio >= 1.0
              ? 1.0 + ((scaleRatio - 1.0) * 1.8)
              : math.max(0.1, 1.0 - ((1.0 - scaleRatio) * 1.8));
          widget.onZoomChanged(_baseScaleZoom * effectiveScale);
        } else {
          // Swipe 1 Jari Vertikal: Ke atas = zoom in, ke bawah = zoom out
          final dy = details.focalPointDelta.dy;
          final absDy = dy.abs();
          final double speedMultiplier = (1.0 + (absDy * 0.08)).clamp(1.0, 2.5);
          const double baseSensitivity = 0.035;
          widget.onZoomChanged(
            widget.currentZoom - (dy * baseSensitivity * speedMultiplier),
          );
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

          // Central Viewfinder Frame - 4 Sudut L Google Lens identik dengan SpeechScreen
          Center(
            child: SizedBox(
              width: widget.size.width * 0.78,
              height: widget.size.width * 0.78,
              child: CustomPaint(
                painter: ScannerCornerPainter(
                  color: widget.isBlurry
                      ? const Color(0xFFF59E0B)
                      : Colors.white.withValues(alpha: 0.9),
                  strokeWidth: LensSelectionHelper.lensStrokeWidth,
                  cornerLength: LensSelectionHelper.lensCornerLength,
                  cornerRadius: LensSelectionHelper.lensCornerRadius,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
