import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eye_lens/features/ocr/orientation/text_orientation.dart';
import 'package:eye_lens/features/speech/logic/text_formatter.dart';
import 'package:eye_lens/features/speech/logic/tts_service.dart';
import 'package:eye_lens/features/speech/models/text_formatter_models.dart';

OcrLineData upsideDownLine(String text, double y, double width) => OcrLineData(
  text: text,
  boundingBox: Rect.fromLTWH(20, y, width, 24),
  orientation: const TextOrientationEstimate(
    orientation: TextOrientation.upsideDown,
    confidence: 1,
    evidence: ['test'],
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('flutter_tts');
  final spoken = <String>[];
  final calls = <String>[];

  setUp(() async {
    spoken.clear();
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'speak') {
            final args = call.arguments;
            spoken.add(args is Map ? args['text'] as String : args as String);
            return 1;
          }
          if (call.method == 'pause') return 1;
          if (call.method == 'getEngines') return ['mock'];
          return 1;
        });
    await TtsService().stop();
  });

  tearDown(() async {
    await TtsService().stop();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('T12 TTS menerima urutan teks hasil koreksi orientasi', () async {
    final doc = OcrDocumentData(
      blocks: [
        OcrBlockData(
          text: '600 Sheets\nTISU LEMBUT',
          boundingBox: const Rect.fromLTWH(0, 0, 400, 200),
          lines: [
            upsideDownLine('600 Sheets', 30, 140),
            upsideDownLine('TISU LEMBUT', 140, 320),
          ],
        ),
      ],
      rawText: '600 Sheets\nTISU LEMBUT',
    );

    final formatted = TextFormatter.format(doc);
    expect(
      formatted.fullText.indexOf('TISU LEMBUT'),
      lessThan(formatted.fullText.indexOf('600 Sheets')),
    );

    await TtsService().speakFormattedResult(formatted);

    expect(spoken, isNotEmpty);
    expect(spoken.join(' ').contains('TISU LEMBUT'), isTrue);
    expect(
      spoken.join(' ').indexOf('TISU LEMBUT'),
      lessThan(spoken.join(' ').indexOf('600 Sheets')),
    );
  });

  test('play, pause, resume, dan navigasi tetap berfungsi', () async {
    final formatted = TextFormatter.format(
      OcrDocumentData(
        blocks: [
          OcrBlockData(
            text: 'TISU LEMBUT\n600 Sheets\n2 PLY',
            boundingBox: const Rect.fromLTWH(0, 0, 400, 200),
            lines: [
              upsideDownLine('TISU LEMBUT', 140, 320),
              upsideDownLine('600 Sheets', 70, 140),
              upsideDownLine('2 PLY', 10, 100),
            ],
          ),
        ],
        rawText: 'TISU LEMBUT\n600 Sheets\n2 PLY',
      ),
    );

    final tts = TtsService();
    await tts.speakFormattedResult(formatted);
    expect(tts.isPlaying, isTrue);
    expect(calls, contains('speak'));

    await tts.pause();
    expect(tts.isPaused, isTrue);
    expect(calls, contains('pause'));

    await tts.resume();
    expect(tts.isPlaying, isTrue);

    spoken.clear();
    await tts.seekTo(0.0);
    expect(spoken, isNotEmpty);
    expect(spoken.first, contains('TISU'));
  });
}
