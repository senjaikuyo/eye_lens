import 'dart:typed_data';
import 'dart:ui';

import 'package:eye_lens/core/utils/image_dimension_helper.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List buildJpeg({
  required int width,
  required int height,
  int? orientation,
  bool littleEndian = true,
}) {
  final bb = BytesBuilder();
  // SOI
  bb.add([0xFF, 0xD8]);

  // APP1 EXIF
  if (orientation != null) {
    final tiffHeader = <int>[];
    if (littleEndian) {
      tiffHeader.addAll([0x49, 0x49, 0x2A, 0x00]); // II, 42
      tiffHeader.addAll([0x08, 0x00, 0x00, 0x00]); // Offset to IFD0 = 8
      tiffHeader.addAll([0x01, 0x00]); // 1 entry
      tiffHeader.addAll([0x12, 0x01]); // Tag 0x0112 (Orientation)
      tiffHeader.addAll([0x03, 0x00]); // Type SHORT (3)
      tiffHeader.addAll([0x01, 0x00, 0x00, 0x00]); // Count 1
      tiffHeader.addAll([
        orientation & 0xFF,
        (orientation >> 8) & 0xFF,
        0x00,
        0x00,
      ]);
      tiffHeader.addAll([0x00, 0x00, 0x00, 0x00]); // Next IFD = 0
    } else {
      tiffHeader.addAll([0x4D, 0x4D, 0x00, 0x2A]); // MM, 42
      tiffHeader.addAll([0x00, 0x00, 0x00, 0x08]); // Offset to IFD0 = 8
      tiffHeader.addAll([0x00, 0x01]); // 1 entry
      tiffHeader.addAll([0x01, 0x12]); // Tag 0x0112 (Orientation)
      tiffHeader.addAll([0x00, 0x03]); // Type SHORT (3)
      tiffHeader.addAll([0x00, 0x00, 0x00, 0x01]); // Count 1
      tiffHeader.addAll([
        (orientation >> 8) & 0xFF,
        orientation & 0xFF,
        0x00,
        0x00,
      ]);
      tiffHeader.addAll([0x00, 0x00, 0x00, 0x00]); // Next IFD = 0
    }

    final exifData = <int>[
      0x45, 0x78, 0x69, 0x66, 0x00, 0x00, // Exif\0\0
      ...tiffHeader,
    ];
    final app1Length = exifData.length + 2;
    bb.add([
      0xFF,
      0xE1,
      (app1Length >> 8) & 0xFF,
      app1Length & 0xFF,
      ...exifData,
    ]);
  }

  // SOF0 (0xFF, 0xC0)
  const sofLen = 11;
  bb.add([
    0xFF,
    0xC0,
    (sofLen >> 8) & 0xFF,
    sofLen & 0xFF,
    0x08, // precision 8 bits
    (height >> 8) & 0xFF,
    height & 0xFF,
    (width >> 8) & 0xFF,
    width & 0xFF,
    0x01, // 1 component
    0x01,
    0x11,
    0x00,
  ]);

  // EOI
  bb.add([0xFF, 0xD9]);
  return bb.toBytes();
}

Uint8List buildPng({required int width, required int height}) {
  final bb = BytesBuilder();
  // PNG signature
  bb.add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  // IHDR length 13
  bb.add([0x00, 0x00, 0x00, 0x0D]);
  // IHDR chunk type
  bb.add([0x49, 0x48, 0x44, 0x52]);
  // Width
  bb.add([
    (width >> 24) & 0xFF,
    (width >> 16) & 0xFF,
    (width >> 8) & 0xFF,
    width & 0xFF,
  ]);
  // Height
  bb.add([
    (height >> 24) & 0xFF,
    (height >> 16) & 0xFF,
    (height >> 8) & 0xFF,
    height & 0xFF,
  ]);
  // Bit depth, color type, etc. + CRC
  bb.add([0x08, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
  return bb.toBytes();
}

void main() {
  group('ImageDimensionHelper Tests', () {
    test('1. Ekstraksi ukuran PNG murni dari IHDR header', () {
      final bytes = buildPng(width: 800, height: 600);
      final size = ImageDimensionHelper.parseHeaderSize(bytes);
      expect(size, equals(const Size(800, 600)));
    });

    test('2. Ekstraksi JPEG mentah tanpa EXIF (orientasi normal)', () {
      final bytes = buildJpeg(width: 1920, height: 1080);
      final size = ImageDimensionHelper.parseHeaderSize(bytes);
      expect(size, equals(const Size(1920, 1080)));
    });

    test(
      '3. Ekstraksi JPEG dengan EXIF orientation 1 (Normal / Landscape)',
      () {
        final bytes = buildJpeg(width: 1920, height: 1080, orientation: 1);
        final size = ImageDimensionHelper.parseHeaderSize(bytes);
        expect(size, equals(const Size(1920, 1080)));
      },
    );

    test('4. Ekstraksi JPEG dengan EXIF orientation 6 (90 CW) menukar lebar dan tinggi', () {
      final bytes = buildJpeg(width: 1280, height: 720, orientation: 6);
      final size = ImageDimensionHelper.parseHeaderSize(bytes);
      expect(size, equals(const Size(720, 1280)));
    });

    test('5. Ekstraksi JPEG dengan EXIF orientation 8 (270 CW) menukar lebar dan tinggi', () {
      final bytes = buildJpeg(width: 1280, height: 720, orientation: 8);
      final size = ImageDimensionHelper.parseHeaderSize(bytes);
      expect(size, equals(const Size(720, 1280)));
    });

    test('6. Ekstraksi JPEG dengan EXIF orientation 3 (180 deg) mempertahankan sumbu', () {
      final bytes = buildJpeg(width: 1920, height: 1080, orientation: 3);
      final size = ImageDimensionHelper.parseHeaderSize(bytes);
      expect(size, equals(const Size(1920, 1080)));
    });

    test('7. Ekstraksi JPEG dengan EXIF Big-Endian MM orientation 6 menukar lebar dan tinggi', () {
      final bytes = buildJpeg(
        width: 1280,
        height: 720,
        orientation: 6,
        littleEndian: false,
      );
      final size = ImageDimensionHelper.parseHeaderSize(bytes);
      expect(size, equals(const Size(720, 1280)));
    });

    test('8. Data gambar tidak valid mengembalikan null', () {
      final bytes = Uint8List.fromList([0x00, 0x01, 0x02]);
      final size = ImageDimensionHelper.parseHeaderSize(bytes);
      expect(size, isNull);
    });
  });
}
