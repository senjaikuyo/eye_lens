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

  /// Konstanta geometri bingkai Google Lens resmi
  static const double lensCornerLength = 28.0;
  static const double lensCornerRadius = 24.0;
  static const double lensStrokeWidth = 3.0;

  /// Menggeser posisi bingkai citra mengikuti gerakan jari di layar tanpa mengubah ukuran.
  /// Menjamin bingkai tidak pernah keluar dari batas ukuran citra asli [0, width] x [0, height].
  static Rect dragImageFrame({
    required Rect currentImageRect,
    required Offset deltaScreen,
    required Matrix4 transformMatrix,
    required Size viewportSize,
    required Size originalImageSize,
  }) {
    if (viewportSize.width <= 0 ||
        viewportSize.height <= 0 ||
        originalImageSize.width <= 0 ||
        originalImageSize.height <= 0 ||
        currentImageRect.width <= 0 ||
        currentImageRect.height <= 0) {
      return currentImageRect;
    }

    // Hitung skala BoxFit.contain
    final double containScale = min(
      viewportSize.width / originalImageSize.width,
      viewportSize.height / originalImageSize.height,
    );
    if (containScale <= 0) return currentImageRect;

    // Hitung zoom dari matriks transformasi
    final double zoomScale = transformMatrix.getMaxScaleOnAxis();
    final double totalScale = containScale * (zoomScale > 0 ? zoomScale : 1.0);
    if (totalScale <= 0) return currentImageRect;

    final double deltaImageX = deltaScreen.dx / totalScale;
    final double deltaImageY = deltaScreen.dy / totalScale;

    final double frameWidth = currentImageRect.width;
    final double frameHeight = currentImageRect.height;

    final double maxLeft = max(0.0, originalImageSize.width - frameWidth);
    final double maxTop = max(0.0, originalImageSize.height - frameHeight);

    final double newLeft =
        (currentImageRect.left + deltaImageX).clamp(0.0, maxLeft);
    final double newTop =
        (currentImageRect.top + deltaImageY).clamp(0.0, maxTop);

    return Rect.fromLTWH(newLeft, newTop, frameWidth, frameHeight);
  }

  /// Mengonversi persegi bingkai dari koordinat piksel citra asli ke koordinat layar.
  /// Langkah:
  /// 1. Piksel gambar ke scene melalui skala dan offset BoxFit.contain.
  /// 2. Scene ke layar melalui perkalian matriks transformasi.
  static Rect imageToScreenCoordinates({
    required Rect imageRect,
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

    final double scale = min(
      viewportSize.width / originalImageSize.width,
      viewportSize.height / originalImageSize.height,
    );
    if (scale <= 0) return Rect.zero;

    final double renderedWidth = originalImageSize.width * scale;
    final double renderedHeight = originalImageSize.height * scale;
    final double offsetX = (viewportSize.width - renderedWidth) / 2.0;
    final double offsetY = (viewportSize.height - renderedHeight) / 2.0;

    final double sceneLeft = imageRect.left * scale + offsetX;
    final double sceneTop = imageRect.top * scale + offsetY;
    final double sceneRight = imageRect.right * scale + offsetX;
    final double sceneBottom = imageRect.bottom * scale + offsetY;

    final Offset screenTopLeft = MatrixUtils.transformPoint(
      transformMatrix,
      Offset(sceneLeft, sceneTop),
    );
    final Offset screenBottomRight = MatrixUtils.transformPoint(
      transformMatrix,
      Offset(sceneRight, sceneBottom),
    );

    final double sLeft = min(screenTopLeft.dx, screenBottomRight.dx);
    final double sTop = min(screenTopLeft.dy, screenBottomRight.dy);
    final double sRight = max(screenTopLeft.dx, screenBottomRight.dx);
    final double sBottom = max(screenTopLeft.dy, screenBottomRight.dy);

    return Rect.fromLTRB(sLeft, sTop, sRight, sBottom);
  }

  /// Mengonversi satu titik sentuh dari koordinat layar ke koordinat piksel citra asli.
  static Offset screenToImagePoint({
    required Offset screenPoint,
    required Matrix4 transformMatrix,
    required Size viewportSize,
    required Size originalImageSize,
  }) {
    if (viewportSize.width <= 0 ||
        viewportSize.height <= 0 ||
        originalImageSize.width <= 0 ||
        originalImageSize.height <= 0) {
      return Offset.zero;
    }

    final Matrix4 inverse = Matrix4.identity();
    final double det = inverse.copyInverse(transformMatrix);
    if (det == 0.0) return Offset.zero;

    final Offset scenePoint = MatrixUtils.transformPoint(inverse, screenPoint);

    final double scale = min(
      viewportSize.width / originalImageSize.width,
      viewportSize.height / originalImageSize.height,
    );
    if (scale <= 0) return Offset.zero;

    final double renderedWidth = originalImageSize.width * scale;
    final double renderedHeight = originalImageSize.height * scale;
    final double offsetX = (viewportSize.width - renderedWidth) / 2.0;
    final double offsetY = (viewportSize.height - renderedHeight) / 2.0;

    final double imgX = (scenePoint.dx - offsetX) / scale;
    final double imgY = (scenePoint.dy - offsetY) / scale;

    return Offset(
      imgX.clamp(0.0, originalImageSize.width),
      imgY.clamp(0.0, originalImageSize.height),
    );
  }

  /// Menyesuaikan ukuran bingkai dalam koordinat citra asli saat pengguna menyeret
  /// salah satu pegangan (handle).
  ///
  /// Ukuran minimum [minFrameSizeDp] (64dp) ditegakkan dalam skala layar saat ini
  /// dengan mengonversinya ke satuan piksel citra asli sesuai tingkat zoom dan BoxFit.
  static Rect resizeImageFrame({
    required Rect currentImageRect,
    required LensHandlePosition handle,
    required Offset deltaScreen,
    required Matrix4 transformMatrix,
    required Size viewportSize,
    required Size originalImageSize,
    double minFrameSizeDp = minFrameSize,
  }) {
    if (viewportSize.width <= 0 ||
        viewportSize.height <= 0 ||
        originalImageSize.width <= 0 ||
        originalImageSize.height <= 0) {
      return currentImageRect;
    }

    final double fitScale = min(
      viewportSize.width / originalImageSize.width,
      viewportSize.height / originalImageSize.height,
    );
    final double transformScale = transformMatrix.getMaxScaleOnAxis();
    final double totalScale =
        fitScale * (transformScale > 0 ? transformScale : 1.0);
    if (totalScale <= 0) return currentImageRect;

    final double deltaImgX = deltaScreen.dx / totalScale;
    final double deltaImgY = deltaScreen.dy / totalScale;

    // Hitung ukuran minimum dalam piksel citra agar di layar tetap >= minFrameSizeDp
    final double minImgW = minFrameSizeDp / totalScale;
    final double minImgH = minFrameSizeDp / totalScale;

    final double effectiveMinW = min(minImgW, originalImageSize.width);
    final double effectiveMinH = min(minImgH, originalImageSize.height);

    double left = currentImageRect.left;
    double top = currentImageRect.top;
    double right = currentImageRect.right;
    double bottom = currentImageRect.bottom;

    switch (handle) {
      case LensHandlePosition.topLeft:
        left = min(left + deltaImgX, right - effectiveMinW);
        top = min(top + deltaImgY, bottom - effectiveMinH);
        break;
      case LensHandlePosition.topRight:
        right = max(right + deltaImgX, left + effectiveMinW);
        top = min(top + deltaImgY, bottom - effectiveMinH);
        break;
      case LensHandlePosition.bottomLeft:
        left = min(left + deltaImgX, right - effectiveMinW);
        bottom = max(bottom + deltaImgY, top + effectiveMinH);
        break;
      case LensHandlePosition.bottomRight:
        right = max(right + deltaImgX, left + effectiveMinW);
        bottom = max(bottom + deltaImgY, top + effectiveMinH);
        break;
      case LensHandlePosition.top:
        top = min(top + deltaImgY, bottom - effectiveMinH);
        break;
      case LensHandlePosition.bottom:
        bottom = max(bottom + deltaImgY, top + effectiveMinH);
        break;
      case LensHandlePosition.left:
        left = min(left + deltaImgX, right - effectiveMinW);
        break;
      case LensHandlePosition.right:
        right = max(right + deltaImgX, left + effectiveMinW);
        break;
      case LensHandlePosition.none:
        break;
    }

    // Batasi di dalam batas gambar asli
    left = left.clamp(0.0, originalImageSize.width - effectiveMinW);
    top = top.clamp(0.0, originalImageSize.height - effectiveMinH);
    right = right.clamp(left + effectiveMinW, originalImageSize.width);
    bottom = bottom.clamp(top + effectiveMinH, originalImageSize.height);

    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// Menghitung target sentuh pegangan (minimal 48dp) dengan penyesuaian agar
  /// saat bingkai menempel di tepi layar, area sentuh menjorok ke dalam bingkai
  /// sehingga tetap dapat disentuh dengan mudah tanpa terpotong tepi layar/bezel.
  static Rect computeHandleTouchRect({
    required LensHandlePosition position,
    required Rect screenFrameRect,
    required Size viewportSize,
    double touchSize = minTouchTarget,
  }) {
    double left = 0;
    double top = 0;
    double width = touchSize;
    double height = touchSize;

    switch (position) {
      case LensHandlePosition.topLeft:
        left = screenFrameRect.left < touchSize / 2
            ? screenFrameRect.left
            : screenFrameRect.left - touchSize / 2;
        top = screenFrameRect.top < touchSize / 2
            ? screenFrameRect.top
            : screenFrameRect.top - touchSize / 2;
        break;
      case LensHandlePosition.topRight:
        left = screenFrameRect.right > viewportSize.width - touchSize / 2
            ? screenFrameRect.right - touchSize
            : screenFrameRect.right - touchSize / 2;
        top = screenFrameRect.top < touchSize / 2
            ? screenFrameRect.top
            : screenFrameRect.top - touchSize / 2;
        break;
      case LensHandlePosition.bottomLeft:
        left = screenFrameRect.left < touchSize / 2
            ? screenFrameRect.left
            : screenFrameRect.left - touchSize / 2;
        top = screenFrameRect.bottom > viewportSize.height - touchSize / 2
            ? screenFrameRect.bottom - touchSize
            : screenFrameRect.bottom - touchSize / 2;
        break;
      case LensHandlePosition.bottomRight:
        left = screenFrameRect.right > viewportSize.width - touchSize / 2
            ? screenFrameRect.right - touchSize
            : screenFrameRect.right - touchSize / 2;
        top = screenFrameRect.bottom > viewportSize.height - touchSize / 2
            ? screenFrameRect.bottom - touchSize
            : screenFrameRect.bottom - touchSize / 2;
        break;
      case LensHandlePosition.top:
        left = screenFrameRect.left + touchSize / 2;
        top = screenFrameRect.top < touchSize / 2
            ? screenFrameRect.top
            : screenFrameRect.top - touchSize / 2;
        width = max(0.0, screenFrameRect.width - touchSize);
        height = touchSize;
        break;
      case LensHandlePosition.bottom:
        left = screenFrameRect.left + touchSize / 2;
        top = screenFrameRect.bottom > viewportSize.height - touchSize / 2
            ? screenFrameRect.bottom - touchSize
            : screenFrameRect.bottom - touchSize / 2;
        width = max(0.0, screenFrameRect.width - touchSize);
        height = touchSize;
        break;
      case LensHandlePosition.left:
        left = screenFrameRect.left < touchSize / 2
            ? screenFrameRect.left
            : screenFrameRect.left - touchSize / 2;
        top = screenFrameRect.top + touchSize / 2;
        width = touchSize;
        height = max(0.0, screenFrameRect.height - touchSize);
        break;
      case LensHandlePosition.right:
        left = screenFrameRect.right > viewportSize.width - touchSize / 2
            ? screenFrameRect.right - touchSize
            : screenFrameRect.right - touchSize / 2;
        top = screenFrameRect.top + touchSize / 2;
        width = touchSize;
        height = max(0.0, screenFrameRect.height - touchSize);
        break;
      case LensHandlePosition.none:
        return Rect.zero;
    }

    return Rect.fromLTWH(left, top, width, height);
  }

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
