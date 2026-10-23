import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../services/camera_service.dart';
import '../../../services/lens_selection_helper.dart';
import '../../../widgets/scanner_corner_painter.dart';

class CameraViewfinder extends StatefulWidget {
  final CameraService cameraService;
  final double currentZoom;
  final ValueChanged<double> onZoomChanged;
  final bool isBlurry;
  final Size size;
  final bool isInitializing;
  final String? errorMessage;
  final String? initializingText;
  final String? retryText;
  final VoidCallback? onRetry;

  const CameraViewfinder({
    super.key,
    required this.cameraService,
    required this.currentZoom,
    required this.onZoomChanged,
    required this.isBlurry,
    required this.size,
    this.isInitializing = false,
    this.errorMessage,
    this.initializingText,
    this.retryText,
    this.onRetry,
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
          // 1. Live Camera Preview atau fallback latar belakang
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
            const ColoredBox(color: Colors.black),

          // 2. Subtle Vignette Gradient — hanya saat kamera siap
          if (widget.cameraService.isInitialized &&
              widget.cameraService.controller != null)
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

          // 3. Central Viewfinder Frame - hanya saat kamera siap dan tanpa error
          if (widget.cameraService.isInitialized &&
              widget.cameraService.controller != null &&
              widget.errorMessage == null)
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

          // 4. Indikator loading singkat saat inisialisasi / re-start kamera
          if (widget.isInitializing)
            Container(
              color: Colors.black.withValues(alpha: 0.4),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        widget.initializingText ?? 'Menyiapkan kamera...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 5. Pesan Error dan Tombol Coba Lagi jika inisialisasi gagal
          if (widget.errorMessage != null && !widget.isInitializing)
            Container(
              color: Colors.black.withValues(alpha: 0.75),
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.alertErrorBg,
                      size: 56,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (widget.onRetry != null)
                      ElevatedButton.icon(
                        onPressed: widget.onRetry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(
                          widget.retryText ?? 'Coba Lagi',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.linkBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
