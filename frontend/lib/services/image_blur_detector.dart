import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'package:eye_lens/services/camera_input_policy.dart';

/// Native bounded thumbnail decode, followed by grayscale/Laplacian in compute.
/// Measurements only: no uncalibrated blur/darkness thresholds or warnings.
class ImageBlurDetector {
  const ImageBlurDetector._();

  static Future<Map<String, Object?>> measure(Uint8List bytes) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final scale = math.min(
        1.0,
        CameraInputPolicy.analysisLongestSide /
            math.max(descriptor.width, descriptor.height),
      );
      codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * scale).round()),
        targetHeight: math.max(1, (descriptor.height * scale).round()),
      );
      image = (await codec.getNextFrame()).image;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) throw StateError('Cannot read thumbnail pixels');
      final metrics = await compute(measureRgba, {
        'rgba': data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        'width': image.width,
        'height': image.height,
      });
      return {
        ...metrics,
        'encodedPixelWidth': descriptor.width,
        'encodedPixelHeight': descriptor.height,
      };
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }

  @visibleForTesting
  static Map<String, Object?> measureRgba(Map<String, Object> input) {
    final rgba = input['rgba']! as Uint8List;
    final width = input['width']! as int;
    final height = input['height']! as int;
    if (width < 3 || height < 3 || rgba.length != width * height * 4) {
      throw ArgumentError('Expected RGBA image at least 3x3');
    }
    final gray = Float64List(width * height);
    var luminance = 0.0;
    for (var i = 0; i < gray.length; i++) {
      final p = i * 4;
      gray[i] = .2126 * rgba[p] + .7152 * rgba[p + 1] + .0722 * rgba[p + 2];
      luminance += gray[i];
    }
    // Welford variance avoids subtracting two large, nearly equal sums.
    var count = 0;
    var mean = 0.0;
    var m2 = 0.0;
    for (var y = 1; y < height - 1; y++) {
      for (var x = 1; x < width - 1; x++) {
        final p = y * width + x;
        final lap =
            gray[p - 1] +
            gray[p + 1] +
            gray[p - width] +
            gray[p + width] -
            4 * gray[p];
        count++;
        final delta = lap - mean;
        mean += delta / count;
        m2 += delta * (lap - mean);
      }
    }
    return {
      'laplacianVariance': m2 / count,
      'meanLuminance': luminance / gray.length,
      'analysisWidth': width,
      'analysisHeight': height,
      'warningThreshold': null,
    };
  }

  /// Preserve original gallery bytes unless one decoded raster exceeds budget.
  static Future<Uint8List> boundGalleryImage(Uint8List bytes) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (descriptor.width * descriptor.height <=
          CameraInputPolicy.galleryMaxPixels) {
        return bytes;
      }
      final target = CameraInputPolicy.boundedSize(
        ui.Size(descriptor.width.toDouble(), descriptor.height.toDouble()),
        CameraInputPolicy.galleryMaxPixels,
      );
      codec = await descriptor.instantiateCodec(
        targetWidth: target.width.toInt(),
        targetHeight: target.height.toInt(),
      );
      image = (await codec.getNextFrame()).image;
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('Cannot resize gallery image');
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }
}
