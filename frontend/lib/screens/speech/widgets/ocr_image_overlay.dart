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
import '../../../services/text_cluster_helper.dart';

/// Menentukan apakah overlay visual debug OCR (kotak hijau/merah) diaktifkan.
/// Default bernilai false: citra tampil bersih ala Google Lens tanpa kotak pada teks.
const bool kDebugOcrOverlay = false;

/// Widget untuk menampilkan citra hasil scan dengan deteksi kelompok teks otomatis
/// dan bingkai pemilih area ala Google Lens.
///
/// Fitur utama:
/// - Satu bingkai membungkus kelompok teks utama (terbesar dan terdekat ke tengah).
/// - Bingkai disimpan dalam koordinat piksel citra asli dan menempel pada citra
///   saat di-zoom (pinch) atau digeser (pan satu jari di dalam/luar bingkai).
/// - Mengetuk kelompok teks lain memindahkan bingkai dengan animasi 200 ms.
/// - Menyeret salah satu dari 8 titik pegangan mengubah ukuran bingkai (resize manual).
/// - Ukuran minimum 64 dp ditegakkan sesuai skala transformasi aktif.
/// - Tombol "Seluruh gambar" mengembalikan zoom ke 1x dan membentangkan bingkai ke seluruh citra.
/// - Jika tidak ada kelompok teks terdeteksi, bingkai disembunyikan dan memicu alert tanpa teks.
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

class _OcrImageOverlayState extends State<OcrImageOverlay>
    with SingleTickerProviderStateMixin {
  late final TransformationController _transformationController;
  late final AnimationController _switchAnimationController;
  Animation<Rect?>? _switchAnimation;

  /// Posisi bingkai seleksi dalam koordinat piksel citra asli [0, width] x [0, height].
  final ValueNotifier<Rect> _imageCropRectNotifier =
      ValueNotifier<Rect>(Rect.zero);

  List<TextCluster> _clusters = const [];
  Size _viewportSize = Size.zero;
  Timer? _debounceTimer;

  LensHandlePosition _activeHandle = LensHandlePosition.none;
  Offset _dragStartGlobal = Offset.zero;
  Rect _dragStartImageRect = Rect.zero;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _transformationController.addListener(_onTransformationChanged);

    _switchAnimationController = AnimationController(
      vsync: this,
      duration: TextClusterHelper.switchAnimationDuration,
    );
    _switchAnimationController.addListener(() {
      if (_switchAnimation?.value != null) {
        _imageCropRectNotifier.value = _switchAnimation!.value!;
      }
    });
    _switchAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _scheduleSelectionCompute();
      }
    });

    _detectInitialClusters();
  }

  @override
  void didUpdateWidget(covariant OcrImageOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rawLines != oldWidget.rawLines ||
        widget.elements != oldWidget.elements ||
        widget.imageSize != oldWidget.imageSize) {
      _detectInitialClusters();
      _scheduleSelectionCompute();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _switchAnimationController.dispose();
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    _imageCropRectNotifier.dispose();
    super.dispose();
  }

  /// Menjalankan deteksi awal kelompok teks dengan OcrNoiseFilter dan TextClusterHelper.
  void _detectInitialClusters() {
    List<OcrLineData> linesToUse = widget.rawLines;
    if (linesToUse.isEmpty && widget.elements.isNotEmpty) {
      linesToUse = widget.elements.map((e) {
        return OcrLineData(
          text: e.text,
          boundingBox: e.boundingBox,
        );
      }).toList();
    }

    if (linesToUse.isEmpty ||
        widget.imageSize.width <= 0 ||
        widget.imageSize.height <= 0) {
      _clusters = const [];
      _imageCropRectNotifier.value = Rect.zero;
      return;
    }

    final filterResult = OcrNoiseFilter.filter(
      lines: linesToUse,
      imageSize: widget.imageSize,
    );

    _clusters = TextClusterHelper.detectClusters(
      filteredLines: filterResult.acceptedLines,
      imageSize: widget.imageSize,
    );

    if (_clusters.isNotEmpty) {
      _imageCropRectNotifier.value = _clusters.first.boundingBox;
    } else {
      _imageCropRectNotifier.value = Rect.zero;
    }
  }

  void _onTransformationChanged() {
    widget.onFrameChanging?.call();
    _scheduleSelectionCompute();
  }

  void _scheduleSelectionCompute() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      TextClusterHelper.selectionDebounceDuration,
      () {
        if (!mounted) return;
        _computeAndNotifySelection();
      },
    );
  }

  void _computeAndNotifySelection() {
    final imageCropRect = _imageCropRectNotifier.value;
    if (_viewportSize.isEmpty) return;

    if (imageCropRect == Rect.zero ||
        imageCropRect.width <= 0 ||
        imageCropRect.height <= 0) {
      widget.onSelectionComputed?.call(LensSelectionResult.empty);
      return;
    }

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

  /// Mereset zoom ke 1x dan membentangkan bingkai ke seluruh citra.
  void _resetZoomAndFitImage() {
    HapticFeedback.mediumImpact();
    widget.onFrameChanging?.call();

    // Kembalikan zoom ke 1x
    _transformationController.value = Matrix4.identity();

    // Rentangkan bingkai ke seluruh citra asli
    _imageCropRectNotifier.value = Rect.fromLTWH(
      0.0,
      0.0,
      widget.imageSize.width,
      widget.imageSize.height,
    );

    _scheduleSelectionCompute();
  }

  void _handleTapUp(TapUpDetails details) {
    if (_viewportSize.isEmpty ||
        widget.imageSize.width <= 0 ||
        widget.imageSize.height <= 0) {
      return;
    }

    final imagePoint = LensSelectionHelper.screenToImagePoint(
      screenPoint: details.localPosition,
      transformMatrix: _transformationController.value,
      viewportSize: _viewportSize,
      originalImageSize: widget.imageSize,
    );

    final currentCropRect = _imageCropRectNotifier.value;

    // 1. Ketukan di dalam bingkai aktif diabaikan
    if (currentCropRect != Rect.zero && currentCropRect.contains(imagePoint)) {
      return;
    }

    // 2. Cek apakah ketukan mengenai kelompok teks lain
    final targetCluster = TextClusterHelper.findClusterAtPoint(
      imagePoint: imagePoint,
      clusters: _clusters,
    );

    if (targetCluster != null) {
      _animateToCluster(targetCluster.boundingBox);
    }
  }

  void _animateToCluster(Rect targetBoundingBox) {
    widget.onFrameChanging?.call();
    HapticFeedback.selectionClick();

    _switchAnimationController.stop();

    final startRect = _imageCropRectNotifier.value == Rect.zero
        ? targetBoundingBox
        : _imageCropRectNotifier.value;

    _switchAnimation = RectTween(
      begin: startRect,
      end: targetBoundingBox,
    ).animate(
      CurvedAnimation(
        parent: _switchAnimationController,
        curve: Curves.easeInOutCubic,
      ),
    );

    _switchAnimationController.forward(from: 0.0);
  }

  void _handleHandlePanStart(
    LensHandlePosition handle,
    DragStartDetails details,
  ) {
    _activeHandle = handle;
    _dragStartGlobal = details.globalPosition;
    _dragStartImageRect = _imageCropRectNotifier.value;

    HapticFeedback.selectionClick();
    widget.onFrameChanging?.call();
  }

  void _handleHandlePanUpdate(DragUpdateDetails details) {
    if (_activeHandle == LensHandlePosition.none) return;

    final totalDelta = details.globalPosition - _dragStartGlobal;
    final newRect = LensSelectionHelper.resizeImageFrame(
      currentImageRect: _dragStartImageRect,
      handle: _activeHandle,
      deltaScreen: totalDelta,
      transformMatrix: _transformationController.value,
      viewportSize: _viewportSize,
      originalImageSize: widget.imageSize,
      minFrameSizeDp: LensSelectionHelper.minFrameSize,
    );

    _imageCropRectNotifier.value = newRect;
    _scheduleSelectionCompute();
  }

  void _handleHandlePanEnd(DragEndDetails details) {
    _activeHandle = LensHandlePosition.none;
    HapticFeedback.lightImpact();
    _computeAndNotifySelection();
  }

  Widget _buildHandle({
    required LensHandlePosition position,
    required Rect screenFrameRect,
    required String semanticsLabel,
  }) {
    const touchSize = LensSelectionHelper.minTouchTarget; // 48dp
    double left = 0;
    double top = 0;
    double width = touchSize;
    double height = touchSize;

    switch (position) {
      case LensHandlePosition.topLeft:
        left = screenFrameRect.left - touchSize / 2;
        top = screenFrameRect.top - touchSize / 2;
        break;
      case LensHandlePosition.topRight:
        left = screenFrameRect.right - touchSize / 2;
        top = screenFrameRect.top - touchSize / 2;
        break;
      case LensHandlePosition.bottomLeft:
        left = screenFrameRect.left - touchSize / 2;
        top = screenFrameRect.bottom - touchSize / 2;
        break;
      case LensHandlePosition.bottomRight:
        left = screenFrameRect.right - touchSize / 2;
        top = screenFrameRect.bottom - touchSize / 2;
        break;
      case LensHandlePosition.top:
        left = screenFrameRect.left + touchSize / 2;
        top = screenFrameRect.top - touchSize / 2;
        width = max(0.0, screenFrameRect.width - touchSize);
        height = touchSize;
        break;
      case LensHandlePosition.bottom:
        left = screenFrameRect.left + touchSize / 2;
        top = screenFrameRect.bottom - touchSize / 2;
        width = max(0.0, screenFrameRect.width - touchSize);
        height = touchSize;
        break;
      case LensHandlePosition.left:
        left = screenFrameRect.left - touchSize / 2;
        top = screenFrameRect.top + touchSize / 2;
        width = touchSize;
        height = max(0.0, screenFrameRect.height - touchSize);
        break;
      case LensHandlePosition.right:
        left = screenFrameRect.right - touchSize / 2;
        top = screenFrameRect.top + touchSize / 2;
        width = touchSize;
        height = max(0.0, screenFrameRect.height - touchSize);
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
            if (_imageCropRectNotifier.value == Rect.zero &&
                _clusters.isNotEmpty) {
              _imageCropRectNotifier.value = _clusters.first.boundingBox;
            }
            _computeAndNotifySelection();
          });
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            // 1. InteractiveViewer: zoom cubit & seret satu jari di dalam/luar bingkai
            InteractiveViewer(
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

            // 2. Lapisan tap detector transparan untuk deteksi perpindahan kelompok teks
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: _handleTapUp,
              ),
            ),

            // 3. Bingkai pemilih area Google Lens
            AnimatedBuilder(
              animation: Listenable.merge([
                _transformationController,
                _imageCropRectNotifier,
              ]),
              builder: (context, _) {
                final imageCropRect = _imageCropRectNotifier.value;
                if (imageCropRect == Rect.zero ||
                    imageCropRect.width <= 0 ||
                    imageCropRect.height <= 0 ||
                    _viewportSize.isEmpty) {
                  return const SizedBox.shrink();
                }

                final screenFrameRect =
                    LensSelectionHelper.imageToScreenCoordinates(
                  imageRect: imageCropRect,
                  transformMatrix: _transformationController.value,
                  viewportSize: _viewportSize,
                  originalImageSize: widget.imageSize,
                );

                if (screenFrameRect.width <= 0 || screenFrameRect.height <= 0) {
                  return const SizedBox.shrink();
                }

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Scrim gelap & 4 sudut rounded L-bracket
                    IgnorePointer(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _GoogleLensFramePainter(
                          frameRect: screenFrameRect,
                          isHighContrast: widget.isHighContrast,
                        ),
                      ),
                    ),

                    // Semantics label untuk bingkai utama
                    Positioned(
                      left: screenFrameRect.left,
                      top: screenFrameRect.top,
                      width: screenFrameRect.width,
                      height: screenFrameRect.height,
                      child: Semantics(
                        label: strings.isIndonesian
                            ? 'Bingkai seleksi teks Google Lens'
                            : 'Google Lens text selection frame',
                        container: true,
                        child: const SizedBox.expand(),
                      ),
                    ),

                    // 4 titik pegangan sudut
                    _buildHandle(
                      position: LensHandlePosition.topLeft,
                      screenFrameRect: screenFrameRect,
                      semanticsLabel: strings.isIndonesian
                          ? 'Pegangan sudut kiri atas'
                          : 'Top left corner handle',
                    ),
                    _buildHandle(
                      position: LensHandlePosition.topRight,
                      screenFrameRect: screenFrameRect,
                      semanticsLabel: strings.isIndonesian
                          ? 'Pegangan sudut kanan atas'
                          : 'Top right corner handle',
                    ),
                    _buildHandle(
                      position: LensHandlePosition.bottomLeft,
                      screenFrameRect: screenFrameRect,
                      semanticsLabel: strings.isIndonesian
                          ? 'Pegangan sudut kiri bawah'
                          : 'Bottom left corner handle',
                    ),
                    _buildHandle(
                      position: LensHandlePosition.bottomRight,
                      screenFrameRect: screenFrameRect,
                      semanticsLabel: strings.isIndonesian
                          ? 'Pegangan sudut kanan bawah'
                          : 'Bottom right corner handle',
                    ),

                    // 4 titik pegangan sisi
                    _buildHandle(
                      position: LensHandlePosition.top,
                      screenFrameRect: screenFrameRect,
                      semanticsLabel: strings.isIndonesian
                          ? 'Pegangan sisi atas'
                          : 'Top edge handle',
                    ),
                    _buildHandle(
                      position: LensHandlePosition.bottom,
                      screenFrameRect: screenFrameRect,
                      semanticsLabel: strings.isIndonesian
                          ? 'Pegangan sisi bawah'
                          : 'Bottom edge handle',
                    ),
                    _buildHandle(
                      position: LensHandlePosition.left,
                      screenFrameRect: screenFrameRect,
                      semanticsLabel: strings.isIndonesian
                          ? 'Pegangan sisi kiri'
                          : 'Left edge handle',
                    ),
                    _buildHandle(
                      position: LensHandlePosition.right,
                      screenFrameRect: screenFrameRect,
                      semanticsLabel: strings.isIndonesian
                          ? 'Pegangan sisi kanan'
                          : 'Right edge handle',
                    ),

                    // Tombol "Seluruh gambar" (Full image)
                    Positioned(
                      top: max(8.0, screenFrameRect.top - 46),
                      left: screenFrameRect.left,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _resetZoomAndFitImage,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: widget.isHighContrast
                                    ? const Color(0xFFFFE500)
                                    : Colors.white70,
                                width: 1.2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black45,
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.fullscreen_rounded,
                                  color: widget.isHighContrast
                                      ? const Color(0xFFFFE500)
                                      : Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  strings.isIndonesian
                                      ? 'Seluruh gambar'
                                      : 'Full image',
                                  style: TextStyle(
                                    color: widget.isHighContrast
                                        ? const Color(0xFFFFE500)
                                        : Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            // 4. Bilah Debug OCR
            if (kDebugOcrOverlay)
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

    final cornerPaint = Paint()
      ..color = isHighContrast ? const Color(0xFFFFE500) : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = isHighContrast ? 5.5 : 4.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final double cornerLength =
        min(28.0, min(frameRect.width, frameRect.height) * 0.35);
    final double radius = min(16.0, cornerLength * 0.65);

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

    final brPath = Path()
      ..moveTo(frameRect.right, frameRect.bottom - cornerLength)
      ..lineTo(frameRect.right - radius, frameRect.bottom)
      ..arcToPoint(
        Offset(frameRect.right - radius, frameRect.bottom),
        radius: Radius.circular(radius),
        clockwise: true,
      )
      ..lineTo(frameRect.right - cornerLength, frameRect.bottom);
    canvas.drawPath(brPath, cornerPaint);

    final blPath = Path()
      ..moveTo(frameRect.left + cornerLength, frameRect.bottom)
      ..lineTo(frameRect.left + radius, frameRect.bottom)
      ..arcToPoint(
        Offset(frameRect.left + radius, frameRect.bottom),
        radius: Radius.circular(radius),
        clockwise: true,
      )
      ..lineTo(frameRect.left, frameRect.bottom - cornerLength);
    canvas.drawPath(blPath, cornerPaint);

    final edgePaint = Paint()
      ..color = (isHighContrast ? const Color(0xFFFFE500) : Colors.white)
          .withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    const edgeMarkerLen = 14.0;
    canvas.drawLine(
      Offset(frameRect.center.dx - edgeMarkerLen, frameRect.top),
      Offset(frameRect.center.dx + edgeMarkerLen, frameRect.top),
      edgePaint,
    );
    canvas.drawLine(
      Offset(frameRect.center.dx - edgeMarkerLen, frameRect.bottom),
      Offset(frameRect.center.dx + edgeMarkerLen, frameRect.bottom),
      edgePaint,
    );
    canvas.drawLine(
      Offset(frameRect.left, frameRect.center.dy - edgeMarkerLen),
      Offset(frameRect.left, frameRect.center.dy + edgeMarkerLen),
      edgePaint,
    );
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
