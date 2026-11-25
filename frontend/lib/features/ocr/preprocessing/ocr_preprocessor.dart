import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Quarter-turn image rotation for OCR recovery and display.
class OcrPreprocessor {
  const OcrPreprocessor._();

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
}
