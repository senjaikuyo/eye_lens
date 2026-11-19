import 'dart:math' as math;
import 'dart:ui';

/// Pure input geometry; mirrors the existing BoxFit.cover camera preview.
class CameraInputPolicy {
  const CameraInputPolicy._();

  // Bound one decoded gallery raster to 48 MiB (not total process memory).
  static const galleryMaxPixels = 12 * 1024 * 1024;
  static const analysisLongestSide = 640;

  static Size boundedSize(Size source, int maxPixels) {
    if (source.width <= 0 || source.height <= 0 || maxPixels <= 0) {
      throw ArgumentError('Invalid image dimensions or pixel budget');
    }
    final ratio = math.min(
      1.0,
      math.sqrt(maxPixels / (source.width * source.height)),
    );
    return Size(
      math.max(1, (source.width * ratio).floor()).toDouble(),
      math.max(1, (source.height * ratio).floor()).toDouble(),
    );
  }

  static Offset focusPoint(Offset tap, Size viewport, Size preview) {
    if (viewport.isEmpty ||
        preview.isEmpty ||
        !tap.dx.isFinite ||
        !tap.dy.isFinite) {
      throw ArgumentError('Invalid preview geometry');
    }
    final scale = math.max(
      viewport.width / preview.width,
      viewport.height / preview.height,
    );
    final displayed = Size(preview.width * scale, preview.height * scale);
    return Offset(
      ((tap.dx + (displayed.width - viewport.width) / 2) / displayed.width)
          .clamp(0.0, 1.0),
      ((tap.dy + (displayed.height - viewport.height) / 2) / displayed.height)
          .clamp(0.0, 1.0),
    );
  }
}
