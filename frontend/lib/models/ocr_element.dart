import 'dart:ui';

/// Representasi elemen teks dengan posisi koordinat pada citra asli.
class OcrElement {
  final String id;
  final String text;
  final Rect boundingBox;

  const OcrElement({
    required this.id,
    required this.text,
    required this.boundingBox,
  });
}

/// Hasil lengkap ekstraksi OCR: teks penuh, daftar elemen berkoordinat, dan ukuran citra.
class OcrResult {
  final String fullText;
  final List<OcrElement> elements;
  final Size imageSize;

  const OcrResult({
    required this.fullText,
    required this.elements,
    required this.imageSize,
  });

  static const OcrResult empty = OcrResult(
    fullText: '',
    elements: [],
    imageSize: Size.zero,
  );
}
