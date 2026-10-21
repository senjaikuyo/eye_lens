import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Helper untuk mengekstrak dimensi citra (width & height) secara efisien:
/// - Mengutamakan inspeksi header JPEG & PNG murni (zero-allocation RAM, < 0.1 ms).
/// - Menghindari alokasi raster bitmap uncompressed (menghemat ~48 MB - 192 MB RAM per foto kamera).
/// - Fallback otomatis ke `ui.decodeImageFromList` jika format non-standar/WebP.
class ImageDimensionHelper {
  const ImageDimensionHelper._();

  static Future<Size> getImageSize(Uint8List bytes) async {
    final fastSize = parseHeaderSize(bytes);
    if (fastSize != null && fastSize.width > 0 && fastSize.height > 0) {
      return fastSize;
    }

    // Fallback aman jika header tidak terbaca / format eksotik
    try {
      final ui.Image decoded = await decodeImageFromList(bytes);
      final size = Size(decoded.width.toDouble(), decoded.height.toDouble());
      decoded.dispose();
      return size;
    } catch (e) {
      debugPrint(
        '[ImageDimensionHelper] Fallback decodeImageFromList gagal: $e',
      );
      return Size.zero;
    }
  }

  /// Membaca lebar & tinggi langsung dari bit header tanpa decode raster.
  static Size? parseHeaderSize(Uint8List bytes) {
    if (bytes.length < 24) return null;

    // 1. Cek PNG: Signature 89 50 4E 47 0D 0A 1A 0A
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      // Chunk IHDR dimulai pada byte 8, lebar di byte 16..19, tinggi di byte 20..23
      final width =
          (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
      final height =
          (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
      return Size(width.toDouble(), height.toDouble());
    }

    // 2. Cek JPEG: SOI marker FF D8
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
      int offset = 2;
      final int length = bytes.length;

      while (offset < length - 8) {
        if (bytes[offset] != 0xFF) {
          offset++;
          continue;
        }

        // Lewati padding 0xFF beruntun
        while (offset < length && bytes[offset] == 0xFF) {
          offset++;
        }

        if (offset >= length) break;
        final int marker = bytes[offset++];

        // SOS (Start of Scan) atau EOI (End of Image) -> tidak ada SOF lagi
        if (marker == 0xDA || marker == 0xD9) {
          break;
        }

        // Standar SOF markers (SOF0, SOF1, SOF2, dll.)
        final bool isSof =
            (marker >= 0xC0 && marker <= 0xC3) ||
            (marker >= 0xC5 && marker <= 0xC7) ||
            (marker >= 0xC9 && marker <= 0xCB) ||
            (marker >= 0xCD && marker <= 0xCF);

        if (offset + 1 >= length) break;
        final int segmentLength = (bytes[offset] << 8) | bytes[offset + 1];

        if (isSof && offset + 7 < length) {
          // Format SOF:
          // [0..1] segment length
          // [2] data precision (bits)
          // [3..4] image height (big-endian)
          // [5..6] image width (big-endian)
          final int height = (bytes[offset + 3] << 8) | bytes[offset + 4];
          final int width = (bytes[offset + 5] << 8) | bytes[offset + 6];
          return Size(width.toDouble(), height.toDouble());
        }

        offset += segmentLength;
      }
    }

    return null;
  }
}
