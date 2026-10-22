import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../controllers/lens_selection_controller.dart';
import '../../../core/app_strings.dart';
import '../../../models/ocr_element.dart';
import '../../../models/text_formatter_models.dart';
import '../../../services/lens_selection_helper.dart';
import '../../../services/ocr_noise_filter.dart';
import '../../../services/text_cluster_helper.dart';
import '../../../widgets/scanner_corner_painter.dart';

/// Menentukan apakah overlay visual debug OCR (kotak hijau/merah) diaktifkan.
/// Default bernilai false: citra tampil bersih ala Google Lens tanpa kotak pada teks.
const bool kDebugOcrOverlay = false;

/// Widget untuk menampilkan citra hasil scan dengan deteksi kelompok teks otomatis
/// dan bingkai pemilih area ala Google Lens.
///
/// Fitur utama:
/// - Satu bingkai membungkus kelompok teks utama (terbesar dan terdekat ke tengah).
/// - 4 sudut putih tipis berbentuk huruf L melengkung tanpa garis penuh, tanpa glow,
///   dan area di luar bingkai digelapkan tipis lewat scrim transparan.
/// - Menempel pada citra saat di-zoom (pinch) atau digeser (pan satu jari di dalam/luar bingkai).
/// - Mengetuk kelompok teks lain memindahkan bingkai dengan animasi 200 ms (bahkan saat Full image).
/// - Menyeret salah satu dari 8 titik pegangan mengubah ukuran bingkai (resize manual),
///   dengan area sentuh 48dp yang tetap bisa disentuh saat menempel di tepi layar.
/// - State bingkai dan zoom disimpan di LensSelectionController sehingga bertahan saat
///   berpindah ke mode teks dan kembali.
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
  final LensSelectionController? controller;

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
    this.controller,
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
  bool _isInteractivePanEnabled = true;

  @override
  void initState() {
    super.initState();
    final ctrl = widget.controller;
    _transformationController = TransformationController(
      ctrl != null && ctrl.isInitialized
          ? ctrl.transformMatrix
          : Matrix4.identity(),
    );
    _transformationController.addListener(_onTransformationChanged);

    _switchAnimationController = AnimationController(
      vsync: this,
      duration: TextClusterHelper.switchAnimationDuration,
    );
    _switchAnimationController.addListener(() {
      if (_switchAnimation?.value != null) {
        _imageCropRectNotifier.value = _switchAnimation!.value!;
        widget.controller?.setCropRect(
          _switchAnimation!.value!,
          isManual: false,
        );
      }
    });
    _switchAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _scheduleSelectionCompute();
      }
    });

    _initOrRestoreClusters();
  }

  void _initOrRestoreClusters() {
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

    final ctrl = widget.controller;
    if (ctrl != null && ctrl.isInitialized && ctrl.imageCropRect != Rect.zero) {
      // Pulihkan state yang tersimpan tanpa mengulang deteksi awal
      _imageCropRectNotifier.value = ctrl.imageCropRect;
    } else {
      // Deteksi awal pertama kali
      if (_clusters.isNotEmpty) {
        final initialRect = _clusters.first.boundingBox;
        _imageCropRectNotifier.value = initialRect;
        ctrl?.markInitialized(initialRect);
      } else {
        _imageCropRectNotifier.value = Rect.zero;
      }
    }
  }

  @override
  void didUpdateWidget(covariant OcrImageOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rawLines != oldWidget.rawLines ||
        widget.elements != oldWidget.elements ||
        widget.imageSize != oldWidget.imageSize) {
      _initOrRestoreClusters();
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

  void _onTransformationChanged() {
    widget.controller?.setTransformMatrix(_transformationController.value);
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

    final ctrl = widget.controller;
    if (ctrl != null && !ctrl.shouldRecompute(imageCropRect) && ctrl.cachedResult != null) {
      // Lewati komputasi ulang jika bingkai tidak berubah sejak teks terakhir disiapkan
      widget.onSelectionComputed?.call(ctrl.cachedResult!);
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

    ctrl?.cacheResult(result, imageCropRect);
    widget.onSelectionComputed?.call(result);
  }

  /// Mereset zoom ke 1x dan membentangkan bingkai ke seluruh citra.
  void _resetZoomAndFitImage() {
    HapticFeedback.mediumImpact();
    widget.onFrameChanging?.call();

    // Kembalikan zoom ke 1x
    _transformationController.value = Matrix4.identity();
    widget.controller?.setTransformMatrix(Matrix4.identity());

    // Rentangkan bingkai ke seluruh citra asli
    final fullRect = Rect.fromLTWH(
      0.0,
      0.0,
      widget.imageSize.width,
      widget.imageSize.height,
    );
    _imageCropRectNotifier.value = fullRect;
    widget.controller?.resetToFullImage(widget.imageSize);

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

    // 1. Cek apakah ketukan mengenai salah satu kelompok teks
    final targetCluster = TextClusterHelper.findClusterAtPoint(
      imagePoint: imagePoint,
      clusters: _clusters,
    );

    final currentCropRect = _imageCropRectNotifier.value;

    // Jika mengenai kelompok teks dan posisinya berbeda dari bingkai aktif,
    // langsung pindahkan bingkai ke kelompok tersebut (berfungsi juga saat Full image)
    if (targetCluster != null && targetCluster.boundingBox != currentCropRect) {
      _animateToCluster(targetCluster.boundingBox);
      return;
    }

    // 2. Ketukan di dalam bingkai aktif saat ini (di luar teks lain) diabaikan
    if (currentCropRect != Rect.zero && currentCropRect.contains(imagePoint)) {
      return;
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

    widget.controller?.animateToCluster(targetBoundingBox);
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
    widget.controller?.setCropRect(newRect, isManual: true);
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
    final touchRect = LensSelectionHelper.computeHandleTouchRect(
      position: position,
      screenFrameRect: screenFrameRect,
      viewportSize: _viewportSize,
    );

    if (touchRect.width <= 0 || touchRect.height <= 0) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: touchRect.left,
      top: touchRect.top,
      width: touchRect.width,
      height: touchRect.height,
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
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final containerSize = Size(constraints.maxWidth, constraints.maxHeight);
        if (_viewportSize != containerSize) {
          _viewportSize = containerSize;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final ctrl = widget.controller;
            if (ctrl != null && ctrl.isInitialized && ctrl.imageCropRect != Rect.zero) {
              _imageCropRectNotifier.value = ctrl.imageCropRect;
            } else if (_imageCropRectNotifier.value == Rect.zero &&
                _clusters.isNotEmpty) {
              final initialRect = _clusters.first.boundingBox;
              _imageCropRectNotifier.value = initialRect;
              ctrl?.markInitialized(initialRect);
            }
            _computeAndNotifySelection();
          });
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            // 1. InteractiveViewer: zoom cubit & seret di luar bingkai
            InteractiveViewer(
              transformationController: _transformationController,
              panEnabled: _isInteractivePanEnabled,
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
                    // Scrim gelap tipis & 4 sudut putih tipis ala Google Lens
                    IgnorePointer(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _GoogleLensFramePainter(
                          frameRect: screenFrameRect,
                        ),
                      ),
                    ),

                    // Lapisan gestur seret satu jari di dalam bingkai
                    Positioned(
                      left: screenFrameRect.left,
                      top: screenFrameRect.top,
                      width: screenFrameRect.width,
                      height: screenFrameRect.height,
                      child: Semantics(
                        label: strings.isIndonesian
                            ? '${strings.googleLensFrame}. Geser dengan satu jari untuk memindahkan bingkai.'
                            : '${strings.googleLensFrame}. Drag with one finger to move frame.',
                        container: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanStart: (details) {
                            setState(() {
                              _isInteractivePanEnabled = false;
                            });
                            _dragStartGlobal = details.globalPosition;
                            _dragStartImageRect = _imageCropRectNotifier.value;
                            HapticFeedback.selectionClick();
                            widget.onFrameChanging?.call();
                          },
                          onPanUpdate: (details) {
                            final totalDelta =
                                details.globalPosition - _dragStartGlobal;
                            final newRect = LensSelectionHelper.dragImageFrame(
                              currentImageRect: _dragStartImageRect,
                              deltaScreen: totalDelta,
                              transformMatrix: _transformationController.value,
                              viewportSize: _viewportSize,
                              originalImageSize: widget.imageSize,
                            );
                            _imageCropRectNotifier.value = newRect;
                            widget.controller
                                ?.setCropRect(newRect, isManual: true);
                            _scheduleSelectionCompute();
                          },
                          onPanEnd: (details) {
                            setState(() {
                              _isInteractivePanEnabled = true;
                            });
                            HapticFeedback.lightImpact();
                            _computeAndNotifySelection();
                          },
                          onPanCancel: () {
                            setState(() {
                              _isInteractivePanEnabled = true;
                            });
                          },
                          child: const SizedBox.expand(),
                        ),
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

                    // Tombol "Seluruh gambar" (Full image) di posisi aman yang tidak menutupi bingkai atau teks
                    Builder(
                      builder: (context) {
                        final bool hasSpaceBelow = (screenFrameRect.bottom +
                                60) <
                            (_viewportSize.height - 110);
                        final double buttonTop = hasSpaceBelow
                            ? screenFrameRect.bottom + 12
                            : max(16.0, screenFrameRect.top - 54);
                        final double buttonLeft =
                            (screenFrameRect.center.dx - 70).clamp(
                          16.0,
                          max(16.0, _viewportSize.width - 156),
                        );

                        return Positioned(
                          top: buttonTop,
                          left: buttonLeft,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _resetZoomAndFitImage,
                              borderRadius: BorderRadius.circular(24),
                              child: Container(
                                constraints: const BoxConstraints(
                                  minHeight: 48,
                                  minWidth: 48,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.75),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: Colors.white70,
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
                                    const Icon(
                                      Icons.fullscreen_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      strings.fullImage,
                                      style: textTheme.labelMedium?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
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
                    style: textTheme.labelSmall?.copyWith(
                      color: Colors.white,
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

/// Painter untuk menggambar scrim gelap tipis di luar bingkai serta empat sudut putih
/// melengkung halus khas Google Lens, tanpa garis sisi penuh dan tanpa glow/bayangan tebal.
class _GoogleLensFramePainter extends CustomPainter {
  final Rect frameRect;

  const _GoogleLensFramePainter({
    required this.frameRect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (frameRect.width <= 0 || frameRect.height <= 0) return;

    // 1. Scrim gelap tipis di luar bingkai (cutout tengah 100% transparan dengan radius sudut Google Lens)
    final scrimPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.38)
      ..style = PaintingStyle.fill;

    final fullPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final framePath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        frameRect,
        const Radius.circular(LensSelectionHelper.lensCornerRadius),
      ));

    final cutOutPath = Path.combine(
      PathOperation.difference,
      fullPath,
      framePath,
    );
    canvas.drawPath(cutOutPath, scrimPaint);

    // 2. Empat sudut berbentuk huruf L melengkung putih tipis ala Google Lens
    // Diberi inset setengah stroke agar tidak pernah terpotong di tepi layar maupun tepi citra
    final halfStroke = LensSelectionHelper.lensStrokeWidth / 2.0;
    final insetRect = Rect.fromLTRB(
      max(halfStroke, frameRect.left + halfStroke),
      max(halfStroke, frameRect.top + halfStroke),
      min(size.width - halfStroke, frameRect.right - halfStroke),
      min(size.height - halfStroke, frameRect.bottom - halfStroke),
    );

    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = LensSelectionHelper.lensStrokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    ScannerCornerPainter.drawGoogleLensCorners(
      canvas: canvas,
      rect: insetRect,
      paint: cornerPaint,
      cornerLength: LensSelectionHelper.lensCornerLength,
      cornerRadius: LensSelectionHelper.lensCornerRadius,
    );
  }

  @override
  bool shouldRepaint(covariant _GoogleLensFramePainter oldDelegate) {
    return oldDelegate.frameRect != frameRect;
  }
}
