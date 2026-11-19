import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'package:eye_lens/features/speech/models/text_formatter_models.dart';

/// Utilitas pemrosesan citra on-device untuk multi-pass OCR:
/// - Mengatur kontras & grayscale via ColorFilter shader hardware (cepat, < 5 ms).
/// - Binarisasi adaptif Otsu murni untuk dokumen kontras rendah atau pencahayaan tidak merata.
/// - Menjaga memori: setiap ui.Image dan buffer raster segera dimusnahkan.
class OcrPreprocessor {
  const OcrPreprocessor._();

  /// Quarter-turn fallback only. Original JPEG remains untouched for pass 1.
  static Future<Uint8List> rotate(Uint8List bytes, int degrees) async {
    if (![90, 180, 270].contains(degrees)) {
      throw ArgumentError.value(degrees, 'degrees');
    }
    final base = await decodeImageFromList(bytes);
    ui.Picture? picture;
    ui.Image? rotated;
    try {
      final width = degrees == 180 ? base.width : base.height;
      final height = degrees == 180 ? base.height : base.width;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      switch (degrees) {
        case 90:
          canvas.translate(width.toDouble(), 0);
        case 180:
          canvas.translate(width.toDouble(), height.toDouble());
        case 270:
          canvas.translate(0, height.toDouble());
      }
      canvas.rotate(degrees * math.pi / 180);
      canvas.drawImage(base, ui.Offset.zero, ui.Paint());
      picture = recorder.endRecording();
      rotated = await picture.toImage(width, height);
      final data = await rotated.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('Cannot encode rotated image');
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      rotated?.dispose();
      picture?.dispose();
      base.dispose();
    }
  }

  /// Meningkatkan kontras dan mengonversi ke grayscale menggunakan matrix ColorFilter.
  static Future<Uint8List> enhanceContrast(
    Uint8List imageBytes, {
    double contrast = 1.6,
  }) async {
    final ui.Image baseImage = await decodeImageFromList(imageBytes);
    final int width = baseImage.width;
    final int height = baseImage.height;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );

    final double c = contrast;
    final double offset = 128.0 * (1.0 - c);

    // Matrix grayscale luminance (0.2126 R, 0.7152 G, 0.0722 B) + ekspansi kontras c
    final paint = Paint()
      ..colorFilter = ColorFilter.matrix(<double>[
        0.2126 * c,
        0.7152 * c,
        0.0722 * c,
        0,
        offset,
        0.2126 * c,
        0.7152 * c,
        0.0722 * c,
        0,
        offset,
        0.2126 * c,
        0.7152 * c,
        0.0722 * c,
        0,
        offset,
        0,
        0,
        0,
        1,
        0,
      ]);

    canvas.drawImage(baseImage, Offset.zero, paint);
    baseImage.dispose();

    final picture = recorder.endRecording();
    final enhancedImage = await picture.toImage(width, height);
    picture.dispose();

    final byteData = await enhancedImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    enhancedImage.dispose();

    return byteData != null ? byteData.buffer.asUint8List() : imageBytes;
  }

  /// Memproses citra tangkapan layar (layar monitor/laptop/ponsel):
  /// - Meredam interferensi kisi piksel frekuensi tinggi (efek moiré) via blur Gaussian halus (sigma ~0.8).
  /// - Meningkatkan kontras teks terhadap backlight (contrast ~1.5x) dalam ruang grayscale.
  /// - Mengeliminasi noise grid LCD/OLED agar karakter teks kembali solid dan mudah dibaca OCR.
  static Future<Uint8List> preprocessScreenText(
    Uint8List imageBytes, {
    double blurSigma = 0.8,
    double contrast = 1.5,
  }) async {
    final ui.Image baseImage = await decodeImageFromList(imageBytes);
    final int width = baseImage.width;
    final int height = baseImage.height;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );

    final double c = contrast;
    final double offset = 128.0 * (1.0 - c);

    final paint = Paint()
      ..imageFilter = ui.ImageFilter.blur(
        sigmaX: blurSigma,
        sigmaY: blurSigma,
        tileMode: TileMode.clamp,
      )
      ..colorFilter = ColorFilter.matrix(<double>[
        0.2126 * c,
        0.7152 * c,
        0.0722 * c,
        0,
        offset,
        0.2126 * c,
        0.7152 * c,
        0.0722 * c,
        0,
        offset,
        0.2126 * c,
        0.7152 * c,
        0.0722 * c,
        0,
        offset,
        0,
        0,
        0,
        1,
        0,
      ]);

    canvas.drawImage(baseImage, Offset.zero, paint);
    baseImage.dispose();

    final picture = recorder.endRecording();
    final processedImage = await picture.toImage(width, height);
    picture.dispose();

    final byteData = await processedImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    processedImage.dispose();

    return byteData != null ? byteData.buffer.asUint8List() : imageBytes;
  }

  /// Memproses citra tulisan tangan (handwriting) di atas kertas:
  /// - Mengonversi ke grayscale dan meningkatkan kontras tinta terhadap kertas (contrast ~1.6x).
  /// - Mempertebal goresan pena / pensil tipis (stroke thickening) via hardware BlendMode.darken
  ///   agar karakter bersambung dan tidak terputus saat dianalisis ML Kit (Issue i Phase I).
  /// - Menjaga memori: setiap ui.Image dan Canvas recorder segera dimusnahkan.
  static Future<Uint8List> preprocessHandwriting(
    Uint8List imageBytes, {
    double contrast = 1.6,
    bool strokeThickening = true,
  }) async {
    final ui.Image baseImage = await decodeImageFromList(imageBytes);
    final int width = baseImage.width;
    final int height = baseImage.height;

    // Tahap 1: Grayscale + Contrast Shader
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );

    final double c = contrast.clamp(0.5, 3.0);
    final double offset = (1.0 - c) * 128.0;

    final contrastPaint = Paint()
      ..colorFilter = ui.ColorFilter.matrix([
        0.2126 * c,
        0.7152 * c,
        0.0722 * c,
        0,
        offset,
        0.2126 * c,
        0.7152 * c,
        0.0722 * c,
        0,
        offset,
        0.2126 * c,
        0.7152 * c,
        0.0722 * c,
        0,
        offset,
        0,
        0,
        0,
        1,
        0,
      ]);

    canvas.drawImage(baseImage, Offset.zero, contrastPaint);
    baseImage.dispose();

    final contrastPicture = recorder.endRecording();
    final contrastImage = await contrastPicture.toImage(width, height);
    contrastPicture.dispose();

    if (!strokeThickening) {
      final byteData = await contrastImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      contrastImage.dispose();
      return byteData != null ? byteData.buffer.asUint8List() : imageBytes;
    }

    // Tahap 2: Stroke Thickening via BlendMode.darken (min-filter 4-arah)
    final thickenRecorder = ui.PictureRecorder();
    final thickenCanvas = Canvas(
      thickenRecorder,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );

    // Gambar citra dasar
    thickenCanvas.drawImage(contrastImage, Offset.zero, Paint());

    // Blend citra dengan geseran 1 piksel di 4 arah mata angin menggunakan BlendMode.darken
    final darkenPaint = Paint()..blendMode = ui.BlendMode.darken;
    thickenCanvas.drawImage(contrastImage, const Offset(1, 0), darkenPaint);
    thickenCanvas.drawImage(contrastImage, const Offset(-1, 0), darkenPaint);
    thickenCanvas.drawImage(contrastImage, const Offset(0, 1), darkenPaint);
    thickenCanvas.drawImage(contrastImage, const Offset(0, -1), darkenPaint);

    contrastImage.dispose();

    final thickenPicture = thickenRecorder.endRecording();
    final thickenedImage = await thickenPicture.toImage(width, height);
    thickenPicture.dispose();

    final byteData = await thickenedImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    thickenedImage.dispose();

    return byteData != null ? byteData.buffer.asUint8List() : imageBytes;
  }

  /// Menghitung ambang batas (threshold) binarisasi optimal menggunakan metode Otsu.
  static double calculateOtsuThreshold(Uint8List rgbaPixels, int totalPixels) {
    if (totalPixels <= 0) return 128.0;

    final histogram = Int32List(256);
    for (int i = 0; i < totalPixels; i++) {
      final int offset = i * 4;
      final int lum =
          ((0.2126 * rgbaPixels[offset]) +
                  (0.7152 * rgbaPixels[offset + 1]) +
                  (0.0722 * rgbaPixels[offset + 2]))
              .round()
              .clamp(0, 255);
      histogram[lum]++;
    }

    double sum = 0;
    for (int t = 0; t < 256; t++) {
      sum += t * histogram[t];
    }

    double sumB = 0;
    int wB = 0;
    int wF = 0;
    double varMax = 0;
    double threshold = 128.0;

    for (int t = 0; t < 256; t++) {
      wB += histogram[t];
      if (wB == 0) continue;
      wF = totalPixels - wB;
      if (wF == 0) break;

      sumB += t * histogram[t];
      final double mB = sumB / wB;
      final double mF = (sum - sumB) / wF;
      final double varBetween = wB * wF * (mB - mF) * (mB - mF);

      if (varBetween > varMax) {
        varMax = varBetween;
        threshold = t.toDouble();
      }
    }

    return threshold;
  }

  /// Menerapkan binarisasi adaptif Otsu pada citra.
  static Future<Uint8List> binarizeOtsu(Uint8List imageBytes) async {
    final ui.Image baseImage = await decodeImageFromList(imageBytes);
    final int width = baseImage.width;
    final int height = baseImage.height;

    final byteData = await baseImage.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    baseImage.dispose();
    if (byteData == null) return imageBytes;

    final Uint8List pixels = byteData.buffer.asUint8List();
    final int totalPixels = width * height;
    final double threshold = calculateOtsuThreshold(pixels, totalPixels);

    final Uint8List binarizedPixels = Uint8List(pixels.length);
    for (int i = 0; i < totalPixels; i++) {
      final int offset = i * 4;
      final int r = pixels[offset];
      final int g = pixels[offset + 1];
      final int b = pixels[offset + 2];
      final double lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;
      final int val = lum >= threshold ? 255 : 0;

      binarizedPixels[offset] = val;
      binarizedPixels[offset + 1] = val;
      binarizedPixels[offset + 2] = val;
      binarizedPixels[offset + 3] = 255;
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      binarizedPixels,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    final binarizedImage = await completer.future;
    final pngData = await binarizedImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    binarizedImage.dispose();

    return pngData != null ? pngData.buffer.asUint8List() : imageBytes;
  }

  /// Memotong citra pada area ROI (Region of Interest) dan melakukan upscaling (pembesaran)
  /// untuk meningkatkan densitas piksel teks kecil / padat (Issue c).
  ///
  /// Menjaga memori: Setiap ui.Image dan Canvas recorder segera dimusnahkan.
  static Future<Uint8List> cropAndScaleRoi(
    Uint8List imageBytes, {
    required Rect cropRect,
    double scale = 1.0,
  }) async {
    final ui.Image baseImage = await decodeImageFromList(imageBytes);
    final int origWidth = baseImage.width;
    final int origHeight = baseImage.height;

    // Batasi cropRect agar tidak keluar dari dimensi citra asli
    final double safeLeft = cropRect.left.clamp(0.0, origWidth.toDouble());
    final double safeTop = cropRect.top.clamp(0.0, origHeight.toDouble());
    final double safeRight = cropRect.right.clamp(
      safeLeft,
      origWidth.toDouble(),
    );
    final double safeBottom = cropRect.bottom.clamp(
      safeTop,
      origHeight.toDouble(),
    );

    final double cropW = math.max(1.0, safeRight - safeLeft);
    final double cropH = math.max(1.0, safeBottom - safeTop);
    final safeCropRect = Rect.fromLTWH(safeLeft, safeTop, cropW, cropH);

    final int targetW = math.max(1, (cropW * scale).round());
    final int targetH = math.max(1, (cropH * scale).round());

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, targetW.toDouble(), targetH.toDouble()),
    );

    final paint = Paint()..filterQuality = ui.FilterQuality.high;
    canvas.drawImageRect(
      baseImage,
      safeCropRect,
      Rect.fromLTWH(0, 0, targetW.toDouble(), targetH.toDouble()),
      paint,
    );
    baseImage.dispose();

    final picture = recorder.endRecording();
    final processedImage = await picture.toImage(targetW, targetH);
    picture.dispose();

    final byteData = await processedImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    processedImage.dispose();

    return byteData != null ? byteData.buffer.asUint8List() : imageBytes;
  }

  /// Menghitung area pembatas gabungan (ROI) dari kumpulan baris teks dengan margin/padding tambahan.
  static Rect? computeTextRoi(
    List<OcrLineData> lines, {
    required Size imageSize,
    double paddingRatio = 0.15,
  }) {
    if (lines.isEmpty) return null;

    double minLeft = double.infinity;
    double minTop = double.infinity;
    double maxRight = double.negativeInfinity;
    double maxBottom = double.negativeInfinity;
    int validCount = 0;

    for (final line in lines) {
      if (line.text.trim().isEmpty) continue;
      final box = line.boundingBox;
      if (box.left < minLeft) minLeft = box.left;
      if (box.top < minTop) minTop = box.top;
      if (box.right > maxRight) maxRight = box.right;
      if (box.bottom > maxBottom) maxBottom = box.bottom;
      validCount++;
    }

    if (validCount == 0 || minLeft >= maxRight || minTop >= maxBottom) {
      return null;
    }

    final width = maxRight - minLeft;
    final height = maxBottom - minTop;
    final padX = width * paddingRatio;
    final padY = height * paddingRatio;

    final safeLeft = math.max(0.0, minLeft - padX);
    final safeTop = math.max(0.0, minTop - padY);
    final safeRight = math.min(imageSize.width, maxRight + padX);
    final safeBottom = math.min(imageSize.height, maxBottom + padY);

    return Rect.fromLTRB(safeLeft, safeTop, safeRight, safeBottom);
  }

  /// Menghitung area ROI tengah (central viewfinder reticle ~70%) saat teks belum terdeteksi.
  static Rect computeCenterRoi(Size imageSize, {double ratio = 0.70}) {
    final double effectiveRatio = ratio.clamp(0.1, 1.0);
    final double roiW = math.max(1.0, imageSize.width * effectiveRatio);
    final double roiH = math.max(1.0, imageSize.height * effectiveRatio);
    final double left = (imageSize.width - roiW) / 2.0;
    final double top = (imageSize.height - roiH) / 2.0;
    return Rect.fromLTWH(left, top, roiW, roiH);
  }

  /// Returns bounded overlapping tiles in visual row-major order.
  static List<Rect> computeTileRois(
    Size imageSize, {
    int rows = 2,
    int columns = 2,
    double overlap = 0.12,
  }) {
    if (!imageSize.width.isFinite ||
        !imageSize.height.isFinite ||
        imageSize.width <= 0 ||
        imageSize.height <= 0 ||
        rows < 1 ||
        columns < 1 ||
        rows * columns > 4) {
      return const [];
    }
    final safeOverlap = overlap.clamp(0.0, 0.4);
    final tileWidth = imageSize.width / columns;
    final tileHeight = imageSize.height / rows;
    return List.generate(rows * columns, (index) {
      final row = index ~/ columns;
      final column = index % columns;
      final left = (column * tileWidth - tileWidth * safeOverlap).clamp(
        0.0,
        imageSize.width,
      );
      final top = (row * tileHeight - tileHeight * safeOverlap).clamp(
        0.0,
        imageSize.height,
      );
      final right = ((column + 1) * tileWidth + tileWidth * safeOverlap).clamp(
        left,
        imageSize.width,
      );
      final bottom = ((row + 1) * tileHeight + tileHeight * safeOverlap).clamp(
        top,
        imageSize.height,
      );
      return Rect.fromLTRB(left, top, right, bottom);
    }, growable: false);
  }

  /// Memetakan kembali koordinat bounding box dari citra ROI (yang di-crop dan di-scale)
  /// ke ruang koordinat citra asli secara presisi.
  static Rect remapBoundingBox(
    Rect box, {
    required Offset cropOffset,
    required double scale,
  }) {
    final double effectiveScale = scale > 0 ? scale : 1.0;
    if (effectiveScale == 1.0 && cropOffset == Offset.zero) {
      return box;
    }
    return Rect.fromLTWH(
      cropOffset.dx + (box.left / effectiveScale),
      cropOffset.dy + (box.top / effectiveScale),
      box.width / effectiveScale,
      box.height / effectiveScale,
    );
  }
}
