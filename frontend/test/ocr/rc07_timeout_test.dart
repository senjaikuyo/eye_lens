import 'dart:async';

import 'package:eye_lens/features/ocr/services/ocr_timeout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RC-07 PF-01/KP-03 OCR timeout', () {
    test('operasi cepat selesai normal', () async {
      final result = await OcrTimeout.run(
        Future.value('selesai'),
        timeout: const Duration(milliseconds: 100),
      );

      expect(result, 'selesai');
    });

    test('operasi menggantung melempar TimeoutException', () async {
      await expectLater(
        OcrTimeout.run(
          Future<String>.delayed(
            const Duration(milliseconds: 200),
            () => 'terlambat',
          ),
          timeout: const Duration(milliseconds: 20),
        ),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('batas waktu pass lebih pendek dari total', () {
      expect(
        OcrTimeout.passTimeout,
        lessThan(Duration(seconds: 60)),
      );
      expect(OcrTimeout.totalTimeout, Duration(seconds: 60));
    });
  });
}
