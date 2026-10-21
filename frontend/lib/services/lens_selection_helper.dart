import 'dart:math';
import 'package:flutter/material.dart';

import '../models/text_formatter_models.dart';
import 'ocr_noise_filter.dart';
import 'ocr_text_validator.dart';
import 'text_formatter.dart';

/// Posisi titik pegangan (handle) untuk mengubah ukuran bingkai seleksi.
enum LensHandlePosition {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  top,
  bottom,
  left,
  right,
  none,
}

/// Hasil evaluasi pemilihan teks dalam bingkai potongan gambar.
@immutable
class LensSelectionResult {
  final String text;
  final FormattedTextResult? formattedResult;
  final List<OcrLineData> acceptedLines;
  final Rect imageCropRect;
  final OcrTextValidationResult validation;
  final bool hasText;

  const LensSelectionResult({
    required this.text,
    this.formattedResult,
    required this.acceptedLines,
    required this.imageCropRect,
    required this.validation,
    required this.hasText,
  });

  static const LensSelectionResult empty = LensSelectionResult(
    text: '',
    formattedResult: null,
    acceptedLines: [],
    imageCropRect: Rect.zero,
    validation: OcrTextValidationResult(
      hasText: false,
      reason: NoTextReason.rawOcrEmpty,
      alphanumericCount: 0,
      text: '',
    ),
    hasText: false,
  );
}

/// Layanan murni untuk mengelola matematika koordinat, seleksi kata,
/// dan pembacaan teks dalam bingkai Google Lens.
class LensSelectionHelper {
  /// Ukuran minimum bingkai agar tidak mengecil sampai tidak terlihat.
  static const double minFrameSize = 64.0;

  /// Area sentuh minimum untuk aksesibilitas titik pegangan (48dp).
  static const double minTouchTarget = 48.0;

  /// Mengonversi persegi bingkai dari koordinat layar ke koordinat piksel citra asli.
  /// Langkah:
  /// 1. Layar ke scene melalui kebalikan (invers) matriks transformasi.
  /// 2. Scene ke piksel gambar melalui skala dan offset BoxFit.contain.
  static Rect screenToImageCoordinates({
    required Rect screenRect,
    required Matrix4 transformMatrix,
    required Size viewportSize,
    required Size originalImageSize,
  }) {
    if (viewportSize.width <= 0 ||
        viewportSize.height <= 0 ||
        originalImageSize.width <= 0 ||
        originalImageSize.height <= 0) {
      return Rect.zero;
    }

    // 1. Invers matriks transformasi untuk memetakan dari layar ke scene
    final Matrix4 inverse = Matrix4.identity();
    final double det = inverse.copyInverse(transformMatrix);
    if (det == 0.0) {
      return Rect.zero;
    }

    final Offset sceneTopLeft = MatrixUtils.transformPoint(
      inverse,
      screenRect.topLeft,
    );
    final Offset sceneBottomRight = MatrixUtils.transformPoint(
      inverse,
      screenRect.bottomRight,
    );

    final double sceneLeft = min(sceneTopLeft.dx, sceneBottomRight.dx);
    final double sceneTop = min(sceneTopLeft.dy, sceneBottomRight.dy);
    final double sceneRight = max(sceneTopLeft.dx, sceneBottomRight.dx);
    final double sceneBottom = max(sceneTopLeft.dy, sceneBottomRight.dy);

    // 2. Hitung skala dan offset BoxFit.contain di scene
    final double scale = min(
      viewportSize.width / originalImageSize.width,
      viewportSize.height / originalImageSize.height,
    );
    if (scale <= 0) return Rect.zero;

    final double renderedWidth = originalImageSize.width * scale;
    final double renderedHeight = originalImageSize.height * scale;
    final double offsetX = (viewportSize.width - renderedWidth) / 2.0;
    final double offsetY = (viewportSize.height - renderedHeight) / 2.0;

    // 3. Konversi dari scene ke piksel gambar
    final double imgLeft = (sceneLeft - offsetX) / scale;
    final double imgTop = (sceneTop - offsetY) / scale;
    final double imgRight = (sceneRight - offsetX) / scale;
    final double imgBottom = (sceneBottom - offsetY) / scale;

    // 4. Batasi dalam batas ukuran gambar asli [0, width] x [0, height]
    final double clampLeft = imgLeft.clamp(0.0, originalImageSize.width);
    final double clampTop = imgTop.clamp(0.0, originalImageSize.height);
    final double clampRight = imgRight.clamp(0.0, originalImageSize.width);
    final double clampBottom = imgBottom.clamp(0.0, originalImageSize.height);

    final double finalLeft = min(clampLeft, clampRight);
    final double finalTop = min(clampTop, clampBottom);
    final double finalRight = max(clampLeft, clampRight);
    final double finalBottom = max(clampTop, clampBottom);

    return Rect.fromLTRB(finalLeft, finalTop, finalRight, finalBottom);
  }

  /// Menghitung persegi tampilan citra di viewport pada skala 1x (BoxFit.contain).
  static Rect getRenderedImageRect({
    required Size viewportSize,
    required Size originalImageSize,
  }) {
    if (viewportSize.width <= 0 ||
        viewportSize.height <= 0 ||
        originalImageSize.width <= 0 ||
        originalImageSize.height <= 0) {
      return Rect.zero;
    }

    final double scale = min(
      viewportSize.width / originalImageSize.width,
      viewportSize.height / originalImageSize.height,
    );
    final double renderedWidth = originalImageSize.width * scale;
    final double renderedHeight = originalImageSize.height * scale;
    final double offsetX = (viewportSize.width - renderedWidth) / 2.0;
    final double offsetY = (viewportSize.height - renderedHeight) / 2.0;

    return Rect.fromLTWH(offsetX, offsetY, renderedWidth, renderedHeight);
  }

  /// Menghitung posisi awal bingkai di tengah dengan lebar 80% lebar gambar.
  static Rect calculateInitialFrame({
    required Size viewportSize,
    required Size originalImageSize,
  }) {
    final renderedRect = getRenderedImageRect(
      viewportSize: viewportSize,
      originalImageSize: originalImageSize,
    );
    if (renderedRect.width <= 0 || renderedRect.height <= 0) {
      final w = viewportSize.width * 0.8;
      final h = viewportSize.height * 0.6;
      return Rect.fromCenter(
        center: Offset(viewportSize.width / 2, viewportSize.height / 2),
        width: max(minFrameSize, w),
        height: max(minFrameSize, h),
      );
    }

    final frameWidth = max(minFrameSize, renderedRect.width * 0.80);
    final frameHeight = max(
      minFrameSize,
      min(renderedRect.height * 0.65, renderedRect.height),
    );

    return Rect.fromCenter(
      center: renderedRect.center,
      width: frameWidth,
      height: frameHeight,
    );
  }

  /// Menghitung bingkai untuk tombol "Seluruh gambar" yang menutupi seluruh gambar.
  static Rect calculateFullImageFrame({
    required Size viewportSize,
    required Size originalImageSize,
  }) {
    final renderedRect = getRenderedImageRect(
      viewportSize: viewportSize,
      originalImageSize: originalImageSize,
    );
    if (renderedRect.width <= 0 || renderedRect.height <= 0) {
      return Rect.fromLTWH(0, 0, viewportSize.width, viewportSize.height);
    }
    return renderedRect;
  }

  /// Menyesuaikan ukuran bingkai saat pengguna menyeret salah satu pegangan (handle).
  static Rect resizeFrame({
    required Rect currentRect,
    required LensHandlePosition handle,
    required Offset delta,
    required Size boundarySize,
    double minWidth = minFrameSize,
    double minHeight = minFrameSize,
  }) {
    double left = currentRect.left;
    double top = currentRect.top;
    double right = currentRect.right;
    double bottom = currentRect.bottom;

    switch (handle) {
      case LensHandlePosition.topLeft:
        left = min(left + delta.dx, right - minWidth);
        top = min(top + delta.dy, bottom - minHeight);
        break;
      case LensHandlePosition.topRight:
        right = max(right + delta.dx, left + minWidth);
        top = min(top + delta.dy, bottom - minHeight);
        break;
      case LensHandlePosition.bottomLeft:
        left = min(left + delta.dx, right - minWidth);
        bottom = max(bottom + delta.dy, top + minHeight);
        break;
      case LensHandlePosition.bottomRight:
        right = max(right + delta.dx, left + minWidth);
        bottom = max(bottom + delta.dy, top + minHeight);
        break;
      case LensHandlePosition.top:
        top = min(top + delta.dy, bottom - minHeight);
        break;
      case LensHandlePosition.bottom:
        bottom = max(bottom + delta.dy, top + minHeight);
        break;
      case LensHandlePosition.left:
        left = min(left + delta.dx, right - minWidth);
        break;
      case LensHandlePosition.right:
        right = max(right + delta.dx, left + minWidth);
        break;
      case LensHandlePosition.none:
        break;
    }

    // Batasi di dalam boundarySize layar
    left = left.clamp(0.0, boundarySize.width - minWidth);
    top = top.clamp(0.0, boundarySize.height - minHeight);
    right = right.clamp(left + minWidth, boundarySize.width);
    bottom = bottom.clamp(top + minHeight, boundarySize.height);

    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// Memilih kata (TextElement / OcrWordData) yang titik tengahnya berada di dalam bingkai potongan.
  /// Baris dikelompokkan kembali lalu disaring oleh OcrNoiseFilter dan TextFormatter.
  /// Jika data kata tidak tersedia, digunakan titik tengah baris (OcrLineData).
  ///
  /// CATATAN: OcrNoiseFilter tetap menggunakan [originalImageSize] penuh sebagai acuan
  /// aturan ukuran relatif, zona tepi, dan keterpencilan, bukan ukuran bingkai crop.
  static LensSelectionResult selectTextInCrop({
    required List<OcrLineData> rawLines,
    required Rect imageCropRect,
    required Size originalImageSize,
    OcrNoiseFilterConfig filterConfig = const OcrNoiseFilterConfig(),
  }) {
    if (rawLines.isEmpty || imageCropRect.width <= 0 || imageCropRect.height <= 0) {
      return LensSelectionResult.empty;
    }

    final List<OcrLineData> selectedLines = [];

    for (final line in rawLines) {
      if (line.elements.isNotEmpty) {
        // Pilih kata yang titik tengah bounding box-nya berada di dalam bingkai
        final selectedWords = line.elements.where((w) {
          return imageCropRect.contains(w.boundingBox.center);
        }).toList();

        if (selectedWords.isNotEmpty) {
          // Urutkan kata dari kiri ke kanan
          selectedWords.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));

          // Hitung gabungan bounding box baris baru
          double minL = selectedWords.first.boundingBox.left;
          double minT = selectedWords.first.boundingBox.top;
          double maxR = selectedWords.first.boundingBox.right;
          double maxB = selectedWords.first.boundingBox.bottom;
          for (final w in selectedWords.skip(1)) {
            minL = min(minL, w.boundingBox.left);
            minT = min(minT, w.boundingBox.top);
            maxR = max(maxR, w.boundingBox.right);
            maxB = max(maxB, w.boundingBox.bottom);
          }

          final newBoundingBox = Rect.fromLTRB(minL, minT, maxR, maxB);
          final newLineText = selectedWords.map((w) => w.text).join(' ');

          selectedLines.add(
            OcrLineData(
              text: newLineText,
              boundingBox: newBoundingBox,
              confidence: line.confidence,
              blockIndex: line.blockIndex,
              elements: selectedWords,
            ),
          );
        }
      } else {
        // Fallback per-baris jika TextElement tidak tersedia
        if (imageCropRect.contains(line.boundingBox.center)) {
          selectedLines.add(line);
        }
      }
    }

    if (selectedLines.isEmpty) {
      final validation = OcrTextValidator.evaluate(
        rawOcrText: '',
        rawLinesCount: 0,
        filteredText: '',
        acceptedLinesCount: 0,
        allLinesFiltered: true,
      );
      return LensSelectionResult(
        text: '',
        formattedResult: null,
        acceptedLines: const [],
        imageCropRect: imageCropRect,
        validation: validation,
        hasText: false,
      );
    }

    // Saring noise dengan OcrNoiseFilter menggunakan ukuran gambar penuh sebagai acuan
    final filterResult = OcrNoiseFilter.filter(
      lines: selectedLines,
      imageSize: originalImageSize,
      config: filterConfig,
    );

    // Kelompokkan baris yang lolos ke dalam blok
    final Map<int, List<OcrLineData>> blockMap = {};
    for (final line in filterResult.acceptedLines) {
      blockMap.putIfAbsent(line.blockIndex, () => []).add(line);
    }

    final List<OcrBlockData> blocks = [];
    for (final entry in blockMap.entries) {
      final lines = entry.value;
      Rect? blockRect;
      for (final l in lines) {
        blockRect = blockRect == null
            ? l.boundingBox
            : Rect.fromLTRB(
                min(blockRect.left, l.boundingBox.left),
                min(blockRect.top, l.boundingBox.top),
                max(blockRect.right, l.boundingBox.right),
                max(blockRect.bottom, l.boundingBox.bottom),
              );
      }

      blocks.add(
        OcrBlockData(
          text: lines.map((l) => l.text).join('\n'),
          boundingBox: blockRect ?? Rect.zero,
          lines: lines,
        ),
      );
    }

    final docData = OcrDocumentData(
      blocks: blocks,
      rawText: filterResult.acceptedLines.map((l) => l.text).join('\n'),
      allRawLines: selectedLines,
    );

    // Format dokumen teks
    final formatted = TextFormatter.format(docData);
    final String finalText = formatted.fullText.isNotEmpty
        ? formatted.fullText
        : filterResult.acceptedLines.map((l) => l.text).join('\n');

    // Validasi apakah hasil seleksi berisi teks yang sah
    final validation = OcrTextValidator.evaluate(
      rawOcrText: selectedLines.map((l) => l.text).join('\n'),
      rawLinesCount: selectedLines.length,
      filteredText: finalText,
      acceptedLinesCount: filterResult.acceptedLines.length,
      allLinesFiltered: filterResult.allLinesFilteredOut,
    );

    return LensSelectionResult(
      text: finalText,
      formattedResult: formatted,
      acceptedLines: filterResult.acceptedLines,
      imageCropRect: imageCropRect,
      validation: validation,
      hasText: validation.hasText,
    );
  }
}
