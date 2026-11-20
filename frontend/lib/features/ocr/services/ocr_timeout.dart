import 'dart:async';

/// Batas waktu OCR. Nilai awal adalah ASUMSI konservatif, bukan hasil
/// kalibrasi perangkat.
class OcrTimeout {
  static const Duration passTimeout = Duration(seconds: 20);
  static const Duration totalTimeout = Duration(seconds: 60);

  static Future<T> run<T>(
    Future<T> operation, {
    Duration timeout = passTimeout,
  }) {
    return operation.timeout(timeout);
  }
}
