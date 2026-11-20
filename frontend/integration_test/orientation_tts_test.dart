import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:eye_lens/features/ocr/models/ocr_element.dart';
import 'package:eye_lens/features/ocr/preprocessing/ocr_preprocessor.dart';
import 'package:eye_lens/features/ocr/services/ocr_service.dart';
import 'package:eye_lens/features/speech/logic/tts_text_chunker.dart';

class _Label {
  final String text;
  final double x;
  final double y;
  final double size;

  const _Label(this.text, this.x, this.y, this.size);
}

Future<Uint8List> _render(
  List<_Label> labels, {
  required int width,
  required int height,
  double skewDegrees = 0,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = Colors.white,
  );
  if (skewDegrees != 0) {
    canvas.save();
    canvas.translate(width / 2, height / 2);
    canvas.rotate(skewDegrees * math.pi / 180);
    canvas.translate(-width / 2, -height / 2);
  }

  for (final label in labels) {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(fontSize: label.size, textAlign: TextAlign.left),
    )..pushStyle(
      ui.TextStyle(color: Colors.black, fontSize: label.size),
    );
    builder.addText(label.text);
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: width - label.x - 10));
    canvas.drawParagraph(paragraph, ui.Offset(label.x, label.y));
  }

  if (skewDegrees != 0) canvas.restore();

  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return byteData!.buffer.asUint8List();
}

Future<Uint8List> _compose(ui.Image first, ui.Image second) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder)
    ..drawRect(
      const ui.Rect.fromLTWH(0, 0, 700, 600),
      ui.Paint()..color = Colors.white,
    )
    ..drawImage(first, ui.Offset.zero, ui.Paint())
    ..drawImage(second, const ui.Offset(340, 160), ui.Paint());
  final picture = recorder.endRecording();
  final image = await picture.toImage(700, 600);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return byteData!.buffer.asUint8List();
}

void expectOrder(OcrResult result, List<String> tokens) {
  final text = result.fullText.toLowerCase();
  final indexes = <int>[];
  for (final token in tokens) {
    final index = text.indexOf(token.toLowerCase());
    expect(
      index,
      isNonNegative,
      reason: 'Teks "$token" tidak terbaca. Hasil: ${result.fullText}',
    );
    indexes.add(index);
  }
  for (var i = 1; i < indexes.length; i++) {
    expect(
      indexes[i - 1],
      lessThan(indexes[i]),
      reason: 'Urutan salah untuk $tokens. Hasil: ${result.fullText}',
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('OCR Orientasi & Urutan Baca (offline, device)', () {
    late OcrService service;

    setUp(() {
      service = OcrService();
    });

    tearDown(() async {
      await service.dispose();
    });

    Future<OcrResult> recognize(Uint8List bytes) =>
        service.processImageWithCoordinates(bytes);

    testWidgets('T01 portrait normal', (tester) async {
      final bytes = await _render(
        const [
          _Label('TISU', 40, 40, 56),
          _Label('KERTAS', 40, 160, 48),
          _Label('LAPIS', 40, 280, 44),
        ],
        width: 480,
        height: 420,
      );
      expectOrder(await recognize(bytes), ['TISU', 'KERTAS', 'LAPIS']);
    });

    testWidgets('T02 landscape normal tidak salah rotasi', (tester) async {
      final bytes = await _render(
        const [
          _Label('TISU', 60, 40, 56),
          _Label('KERTAS', 60, 150, 48),
        ],
        width: 900,
        height: 300,
      );
      final result = await recognize(bytes);
      expect(result.imageSize.width, greaterThan(result.imageSize.height));
      expectOrder(result, ['TISU', 'KERTAS']);
    });

    testWidgets('T03 rotasi 90 dikoreksi', (tester) async {
      final upright = await _render(
        const [
          _Label('TISU', 40, 40, 56),
          _Label('KERTAS', 40, 160, 48),
        ],
        width: 600,
        height: 300,
      );
      final rotated = await OcrPreprocessor.rotate(upright, 90);
      expectOrder(await recognize(rotated), ['TISU', 'KERTAS']);
    });

    testWidgets('T04 rotasi 180 dikoreksi', (tester) async {
      final upright = await _render(
        const [
          _Label('TISU', 40, 40, 56),
          _Label('KERTAS', 40, 160, 48),
        ],
        width: 600,
        height: 300,
      );
      final rotated = await OcrPreprocessor.rotate(upright, 180);
      expectOrder(await recognize(rotated), ['TISU', 'KERTAS']);
    });

    testWidgets('T05 rotasi 270 dikoreksi', (tester) async {
      final upright = await _render(
        const [
          _Label('TISU', 40, 40, 56),
          _Label('KERTAS', 40, 160, 48),
        ],
        width: 600,
        height: 300,
      );
      final rotated = await OcrPreprocessor.rotate(upright, 270);
      expectOrder(await recognize(rotated), ['TISU', 'KERTAS']);
    });

    testWidgets('T06 landscape terbalik dikenali', (tester) async {
      final upright = await _render(
        const [
          _Label('TISU', 60, 40, 56),
          _Label('KERTAS', 60, 150, 48),
        ],
        width: 900,
        height: 300,
      );
      final rotated = await OcrPreprocessor.rotate(upright, 180);
      expectOrder(await recognize(rotated), ['TISU', 'KERTAS']);
    });

    testWidgets('T07 banyak blok urutannya benar', (tester) async {
      final bytes = await _render(
        const [
          _Label('TISU', 40, 30, 48),
          _Label('KERTAS', 40, 120, 44),
          _Label('LAPIS', 40, 210, 42),
          _Label('BAGUS', 40, 300, 40),
        ],
        width: 500,
        height: 420,
      );
      expectOrder(
        await recognize(bytes),
        ['TISU', 'KERTAS', 'LAPIS', 'BAGUS'],
      );
    });

    testWidgets('T08 ukuran teks berbeda tetap terurut', (tester) async {
      final bytes = await _render(
        const [
          _Label('TISU', 40, 80, 28),
          _Label('KERTAS', 160, 60, 60),
        ],
        width: 700,
        height: 220,
      );
      expectOrder(await recognize(bytes), ['TISU', 'KERTAS']);
    });

    testWidgets('T09 blok orientasi berbeda dianalisis per blok', (tester) async {
      final uprightBytes = await _render(
        const [_Label('TISU', 20, 40, 52)],
        width: 320,
        height: 140,
      );
      final rotatedBytes = await OcrPreprocessor.rotate(
        await _render(
          const [_Label('KERTAS', 20, 30, 48)],
          width: 300,
          height: 140,
        ),
        90,
      );
      final first = await decodeImageFromList(uprightBytes);
      final second = await decodeImageFromList(rotatedBytes);
      final composed = await _compose(first, second);
      first.dispose();
      second.dispose();

      final result = await recognize(composed);
      expect(result.fullText.trim(), isNotEmpty);
      expect(
        result.rawLines.any(
          (line) =>
              line.orientation != null &&
              line.orientation!.orientation.name != 'up',
        ),
        isTrue,
        reason: 'Blok dengan orientasi berbeda tidak terdeteksi: '
            '${result.rawLines.map((l) => l.orientation?.orientation.name).toList()}',
      );
    });

    testWidgets('T10 foto miring tetap terbaca', (tester) async {
      final bytes = await _render(
        const [
          _Label('TISU', 50, 60, 52),
          _Label('KERTAS', 50, 160, 46),
        ],
        width: 600,
        height: 320,
        skewDegrees: 12,
      );
      final result = await recognize(bytes);
      expect(result.fullText.trim(), isNotEmpty);
      expectOrder(result, ['TISU', 'KERTAS']);
    });

    testWidgets('T11 kemasan produk: utama sebelum pendukung', (tester) async {
      final bytes = await _render(
        const [
          _Label('TISU', 40, 30, 72),
          _Label('KERTAS', 40, 140, 34),
          _Label('LAPIS', 40, 210, 32),
        ],
        width: 620,
        height: 320,
      );
      expectOrder(await recognize(bytes), ['TISU', 'KERTAS', 'LAPIS']);
    });

    testWidgets('T12 urutan hasil OCR menjadi urutan chunk TTS', (tester) async {
      final rotated = await OcrPreprocessor.rotate(
        await _render(
          const [
            _Label('TISU', 40, 40, 56),
            _Label('KERTAS', 40, 160, 48),
          ],
          width: 600,
          height: 300,
        ),
        180,
      );
      final result = await recognize(rotated);
      final formatted = result.formattedResult;
      expect(formatted, isNotNull);

      final chunkText = TtsTextChunker.split(formatted!.fullText).join(' ');
      expectOrder(
        OcrResult(
          fullText: chunkText,
          elements: const [],
          imageSize: result.imageSize,
        ),
        ['TISU', 'KERTAS'],
      );
      expect(
        formatted.paragraphs.map((p) => p.text).join(' ').toLowerCase(),
        contains('tisu'),
      );
    });
  });
}
