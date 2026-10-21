import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_strings.dart';
import '../../../models/ocr_element.dart';
import '../../../models/text_formatter_models.dart';
import '../../../services/lens_selection_helper.dart';
import '../../../services/ocr_noise_filter.dart';

/// Menentukan apakah overlay visual debug OCR (kotak hijau/merah) diaktifkan.
/// Default bernilai false: citra tampil bersih ala Google Lens tanpa kotak pada teks.
const bool kDebugOcrOverlay = false;

/// Widget untuk menampilkan citra hasil scan dengan bingkai pemilih area ala Google Lens.
/// Fitur utama:
/// - Citra tampil bersih beresolusi penuh (FilterQuality.high) tanpa kotak sorotan teks.
/// - Zoom interaktif (1x - 6x) dengan cubit dua jari, ketuk dua kali untuk zoom masuk/keluar, dan geser satu jari.
/// - Bingkai pemilih area tetap di layar; gambar bergerak di bawah bingkai.
/// - Pengguna dapat mengubah ukuran bingkai melalui titik pegangan sudut atau sisi (touch target >= 48dp).
/// - Area di luar bingkai digelapkan (dimmed scrim); area di dalam bingkai tetap terang.
/// - Tombol "Seluruh gambar" untuk mengembalikan zoom ke 1x dan memperluas bingkai ke seluruh gambar.
/// - Debounce 300 ms untuk menghentikan TTS dan menghitung ulang seleksi teks di dalam bingkai.
class OcrImageOverlay extends StatefulWidget {
  final Uint8List imageBytes;
  final Size imageSize;
  final List<OcrLineData> rawLines;
  final List<OcrElement> elements;
  final List<RejectedLineInfo> rejectedLines;
  final VoidCallback? onFrameChanging;
  final ValueChanged<LensSelectionResult>? onSelectionComputed;
  final bool isDark;
  final bool isHighContrast;

  const OcrImageOverlay({
    super.key,
    required this.imageBytes,
    required this.imageSize,
    this.rawLines = const [],
    this.elements = const [],
    this.rejectedLines = const [],
    this.onFrameChanging,
    this.onSelectionComputed,
    this.isDark = true,
    this.isHighContrast = false,
  });

  @override
  State<OcrImageOverlay> createState() => _OcrImageOverlayState();
}

class _OcrImageOverlayState extends State<OcrImageOverlay> {
  late final TransformationController _transformationController;
  final ValueNotifier<Rect> _frameRectNotifier = ValueNotifier<Rect>(Rect.zero);

  Size _viewportSize = Size.zero;
  Timer? _debounceTimer;
  LensHandlePosition _activeHandle = LensHandlePosition.none;
  Offset _dragStartGlobal = Offset.zero;
  Rect _dragStartRect = Rect.zero;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _transformationController.addListener(_onTransformationChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    _frameRectNotifier.dispose();
    super.dispose();
  }

  void _onTransformationChanged() {
    widget.onFrameChanging?.call();
    _scheduleSelectionCompute();
  }

  void _scheduleSelectionCompute() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _computeAndNotifySelection();
    });
  }

  void _computeAndNotifySelection() {
    final frame = _frameRectNotifier.value;
    if (frame.width <= 0 || frame.height <= 0 || _viewportSize.isEmpty) return;

    final imageCropRect = LensSelectionHelper.screenToImageCoordinates(
      screenRect: frame,
      transformMatrix: _transformationController.value,
      viewportSize: _viewportSize,
      originalImageSize: widget.imageSize,
    );

    // Ambil baris mentah (rawLines) atau bangun dari elements jika rawLines kosong
    List<OcrLineData> linesToUse = widget.rawLines;
    if (linesToUse.isEmpty && widget.elements.isNotEmpty) {
      linesToUse = widget.elements.map((e) {
        return OcrLineData(
          text: e.text,
          boundingBox: e.boundingBox,
        );
      }).toList();
    }

    final result = LensSelectionHelper.selectTextInCrop(
      rawLines: linesToUse,
      imageCropRect: imageCropRect,
      originalImageSize: widget.imageSize,
    );

    widget.onSelectionComputed?.call(result);
  }

  void _resetZoomAndFitImage() {
    HapticFeedback.mediumImpact();
    widget.onFrameChanging?.call();

    // Kembalikan zoom ke 1x
    _transformationController.value = Matrix4.identity();

    // Perbesar bingkai hingga menutupi seluruh gambar
    final fullRect = LensSelectionHelper.calculateFullImageFrame(
      viewportSize: _viewportSize,
      originalImageSize: widget.imageSize,
    );
    _frameRectNotifier.value = fullRect;

    _scheduleSelectionCompute();
  }

  void _handleDoubleTap(TapDownDetails details) {
    widget.onFrameChanging?.call();
    HapticFeedback.lightImpact();

    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    if (currentScale > 1.05) {
      // Reset kembali ke 1.0x
      _transformationController.value = Matrix4.identity();
    } else {
      // Zoom 2.5x ke titik ketukan
      final tap = details.localPosition;
      final targetScale = 2.5;
      final x = -tap.dx * (targetScale - 1.0);
      final y = -tap.dy * (targetScale - 1.0);

    final Matrix4 target =
        Matrix4.diagonal3Values(targetScale, targetScale, 1.0)
          ..setTranslationRaw(x, y, 0.0);

      _transformationController.value = target;
    }
    _scheduleSelectionCompute();
  }

  void _handleHandlePanStart(LensHandlePosition handle, DragStartDetails details) {
    _activeHandle = handle;
    _dragStartGlobal = details.globalPosition;
    _dragStartRect = _frameRectNotifier.value;
    HapticFeedback.selectionClick();
    widget.onFrameChanging?.call();
  }

  void _handleHandlePanUpdate(DragUpdateDetails details) {
    if (_activeHandle == LensHandlePosition.none) return;

    final totalDelta = details.globalPosition - _dragStartGlobal;
    final newRect = LensSelectionHelper.resizeFrame(
      currentRect: _dragStartRect,
      handle: _activeHandle,
      delta: totalDelta,
      boundarySize: _viewportSize,
    );

    _frameRectNotifier.value = newRect;
    _scheduleSelectionCompute();
  }

  void _handleHandlePanEnd(DragEndDetails details) {
    _activeHandle = LensHandlePosition.none;
    HapticFeedback.lightImpact();
    _computeAndNotifySelection();
  }

  Widget _buildHandle({
    required LensHandlePosition position,
    required Rect frameRect,
    required String semanticsLabel,
  }) {
    const touchSize = LensSelectionHelper.minTouchTarget; // 48dp
    double left = 0;
    double top = 0;
    double width = touchSize;
    double height = touchSize;

    switch (position) {
      case LensHandlePosition.topLeft:
        left = frameRect.left - touchSize / 2;
        top = frameRect.top - touchSize / 2;
        break;
      case LensHandlePosition.topRight:
        left = frameRect.right - touchSize / 2;
        top = frameRect.top - touchSize / 2;
        break;
      case LensHandlePosition.bottomLeft:
        left = frameRect.left - touchSize / 2;
        top = frameRect.bottom - touchSize / 2;
        break;
      case LensHandlePosition.bottomRight:
        left = frameRect.right - touchSize / 2;
        top = frameRect.bottom - touchSize / 2;
        break;
      case LensHandlePosition.top:
        left = frameRect.left + touchSize / 2;
        top = frameRect.top - touchSize / 2;
        width = max(0.0, frameRect.width - touchSize);
        height = touchSize;
        break;
      case LensHandlePosition.bottom:
        left = frameRect.left + touchSize / 2;
        top = frameRect.bottom - touchSize / 2;
        width = max(0.0, frameRect.width - touchSize);
        height = touchSize;
        break;
      case LensHandlePosition.left:
        left = frameRect.left - touchSize / 2;
        top = frameRect.top + touchSize / 2;
        width = touchSize;
        height = max(0.0, frameRect.height - touchSize);
        break;
      case LensHandlePosition.right:
        left = frameRect.right - touchSize / 2;
        top = frameRect.top + touchSize / 2;
        width = touchSize;
        height = max(0.0, frameRect.height - touchSize);
        break;
      case LensHandlePosition.none:
        return const SizedBox.shrink();
    }

    if (width <= 0 || height <= 0) return const SizedBox.shrink();

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Semantics(
        label: semanticsLabel,
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) => _handleHandlePanStart(position, d),
          onPanUpdate: _handleHandlePanUpdate,
          onPanEnd: _handleHandlePanEnd,
          onPanCancel: () => _activeHandle = LensHandlePosition.none,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final containerSize = Size(constraints.maxWidth, constraints.maxHeight);
        if (_viewportSize != containerSize) {
          _viewportSize = containerSize;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_frameRectNotifier.value == Rect.zero) {
              _frameRectNotifier.value = LensSelectionHelper.calculateInitialFrame(
                viewportSize: _viewportSize,
                originalImageSize: widget.imageSize,
              );
              _computeAndNotifySelection();
            }
          });
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            // 1. LAPISAN BAWAH: InteractiveViewer untuk zoom, pan, dan double tap
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTapDown: _handleDoubleTap,
              child: InteractiveViewer(
                transformationController: _transformationController,
                minScale: 1.0,
                maxScale: 6.0,
                boundaryMargin: EdgeInsets.zero,
                clipBehavior: Clip.hardEdge,
                child: Center(
                  child: Image.memory(
                    widget.imageBytes,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                  ),
                ),
              ),
            ),

            // 2. LAPISAN BINGKAI PEMILIH AREA GOOGLE LENS
            ValueListenableBuilder<Rect>(
              valueListenable: _frameRectNotifier,
              builder: (context, frameRect, _) {
                if (frameRect == Rect.zero) return const SizedBox.shrink();

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // A. CustomPainter: Scrim gelap di luar bingkai & 4 sudut putih melengkung
                    IgnorePointer(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _GoogleLensFramePainter(
                          frameRect: frameRect,
                          isHighContrast: widget.isHighContrast,
                        ),
                      ),
                    ),

                    // B. Titik pegangan 4 sudut (touch target 48dp)
                    _buildHandle(
                      position: LensHandlePosition.topLeft,
                      frameRect: frameRect,
                      semanticsLabel: 'Pegangan sudut kiri atas',
                    ),
                    _buildHandle(
                      position: LensHandlePosition.topRight,
                      frameRect: frameRect,
                      semanticsLabel: 'Pegangan sudut kanan atas',
                    ),
                    _buildHandle(
                      position: LensHandlePosition.bottomLeft,
                      frameRect: frameRect,
                      semanticsLabel: 'Pegangan sudut kiri bawah',
                    ),
                    _buildHandle(
                      position: LensHandlePosition.bottomRight,
                      frameRect: frameRect,
                      semanticsLabel: 'Pegangan sudut kanan bawah',
                    ),

                    // C. Titik pegangan 4 sisi (touch target 48dp)
                    _buildHandle(
                      position: LensHandlePosition.top,
                      frameRect: frameRect,
                      semanticsLabel: 'Pegangan sisi atas',
                    ),
                    _buildHandle(
                      position: LensHandlePosition.bottom,
                      frameRect: frameRect,
                      semanticsLabel: 'Pegangan sisi bawah',
                    ),
                    _buildHandle(
                      position: LensHandlePosition.left,
                      frameRect: frameRect,
                      semanticsLabel: 'Pegangan sisi kiri',
                    ),
                    _buildHandle(
                      position: LensHandlePosition.right,
                      frameRect: frameRect,
                      semanticsLabel: 'Pegangan sisi kanan',
                    ),

                    // D. Tombol "Seluruh gambar" (Full image)
                    Positioned(
                      top: 14,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Semantics(
                          label: 'Kembalikan zoom ke satu kali dan pilih seluruh gambar',
                          button: true,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: _resetZoomAndFitImage,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.75),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.4),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.crop_free_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      strings.isIndonesian ? 'Seluruh gambar' : 'Full image',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            // 3. LAPISAN DEBUG OCR (Hanya jika kDebugOcrOverlay dan kDebugMode aktif)
            if (kDebugMode && kDebugOcrOverlay)
              Positioned(
                bottom: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    'Debug OCR: ${widget.elements.length} lolos | ${widget.rejectedLines.length} dibuang',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Painter untuk menggambar scrim gelap di luar bingkai serta empat sudut putih
/// bersudut melengkung halus khas Google Lens.
class _GoogleLensFramePainter extends CustomPainter {
  final Rect frameRect;
  final bool isHighContrast;

  const _GoogleLensFramePainter({
    required this.frameRect,
    required this.isHighContrast,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (frameRect.width <= 0 || frameRect.height <= 0) return;

    // 1. Lapisan scrim gelap di luar bingkai (cut-out area dalam bingkai)
    final scrimPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;

    final fullPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final framePath = Path()
      ..addRRect(RRect.fromRectAndRadius(frameRect, const Radius.circular(16)));

    final cutOutPath = Path.combine(
      PathOperation.difference,
      fullPath,
      framePath,
    );
    canvas.drawPath(cutOutPath, scrimPaint);

    // 2. Empat sudut melengkung putih solid ala Google Lens (Rounded L-brackets)
    final cornerPaint = Paint()
      ..color = isHighContrast ? const Color(0xFFFFE500) : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = isHighContrast ? 5.5 : 4.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final double cornerLength = min(28.0, min(frameRect.width, frameRect.height) * 0.35);
    final double radius = min(16.0, cornerLength * 0.65);

    // Pojok Kiri Atas
    final tlPath = Path()
      ..moveTo(frameRect.left, frameRect.top + cornerLength)
      ..lineTo(frameRect.left, frameRect.top + radius)
      ..arcToPoint(
        Offset(frameRect.left + radius, frameRect.top),
        radius: Radius.circular(radius),
        clockwise: true,
      )
      ..lineTo(frameRect.left + cornerLength, frameRect.top);
    canvas.drawPath(tlPath, cornerPaint);

    // Pojok Kanan Atas
    final trPath = Path()
      ..moveTo(frameRect.right - cornerLength, frameRect.top)
      ..lineTo(frameRect.right - radius, frameRect.top)
      ..arcToPoint(
        Offset(frameRect.right, frameRect.top + radius),
        radius: Radius.circular(radius),
        clockwise: true,
      )
      ..lineTo(frameRect.right, frameRect.top + cornerLength);
    canvas.drawPath(trPath, cornerPaint);

    // Pojok Kanan Bawah
    final brPath = Path()
      ..moveTo(frameRect.right, frameRect.bottom - cornerLength)
      ..lineTo(frameRect.right, frameRect.bottom - radius)
      ..arcToPoint(
        Offset(frameRect.right - radius, frameRect.bottom),
        radius: Radius.circular(radius),
        clockwise: true,
      )
      ..lineTo(frameRect.right - cornerLength, frameRect.bottom);
    canvas.drawPath(brPath, cornerPaint);

    // Pojok Kiri Bawah
    final blPath = Path()
      ..moveTo(frameRect.left + cornerLength, frameRect.bottom)
      ..lineTo(frameRect.left + radius, frameRect.bottom)
      ..arcToPoint(
        Offset(frameRect.left, frameRect.bottom - radius),
        radius: Radius.circular(radius),
        clockwise: true,
      )
      ..lineTo(frameRect.left, frameRect.bottom - cornerLength);
    canvas.drawPath(blPath, cornerPaint);

    // 3. Garis penanda lembut pada 4 sisi tengah (subtle edge handles)
    final edgePaint = Paint()
      ..color = (isHighContrast ? const Color(0xFFFFE500) : Colors.white).withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    const edgeMarkerLen = 14.0;
    // Sisi Atas
    canvas.drawLine(
      Offset(frameRect.center.dx - edgeMarkerLen, frameRect.top),
      Offset(frameRect.center.dx + edgeMarkerLen, frameRect.top),
      edgePaint,
    );
    // Sisi Bawah
    canvas.drawLine(
      Offset(frameRect.center.dx - edgeMarkerLen, frameRect.bottom),
      Offset(frameRect.center.dx + edgeMarkerLen, frameRect.bottom),
      edgePaint,
    );
    // Sisi Kiri
    canvas.drawLine(
      Offset(frameRect.left, frameRect.center.dy - edgeMarkerLen),
      Offset(frameRect.left, frameRect.center.dy + edgeMarkerLen),
      edgePaint,
    );
    // Sisi Kanan
    canvas.drawLine(
      Offset(frameRect.right, frameRect.center.dy - edgeMarkerLen),
      Offset(frameRect.right, frameRect.center.dy + edgeMarkerLen),
      edgePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GoogleLensFramePainter oldDelegate) {
    return oldDelegate.frameRect != frameRect ||
        oldDelegate.isHighContrast != isHighContrast;
  }
}
