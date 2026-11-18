import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Utilitas pemrosesan citra on-device untuk multi-pass OCR:
/// - Mengatur kontras & grayscale via ColorFilter shader hardware (cepat, < 5 ms).
/// - Binarisasi adaptif Otsu murni untuk dokumen kontras rendah atau pencahayaan tidak merata.
/// - Menjaga memori: setiap ui.Image dan buffer raster segera dimusnahkan.
class OcrPreprocessor {
  const OcrPreprocessor._();

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
}
