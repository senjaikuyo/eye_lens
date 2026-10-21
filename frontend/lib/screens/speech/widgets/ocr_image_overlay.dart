import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/ocr_element.dart';
import '../../../services/ocr_noise_filter.dart';

/// Widget untuk menampilkan citra hasil scan dengan overlay kotak teks interaktif mirip Google Lens.
/// Mendukung:
/// - Ketuk (tap) untuk memilih/membatalkan satu kotak teks.
/// - Seret jari (pan/drag) untuk memilih banyak kotak teks sekaligus dalam satu usapan.
/// - Kotak terpilih otomatis diurutkan dari atas-ke-bawah dan kiri-ke-kanan.
/// - Mode Debug (hanya aktif pada build debug): kotak hijau untuk baris yang lolos dan kotak merah untuk baris yang dibuang.
class OcrImageOverlay extends StatefulWidget {
  final Uint8List imageBytes;
  final Size imageSize;
  final List<OcrElement> elements;
  final List<RejectedLineInfo> rejectedLines;
  final Set<String> selectedIds;
  final ValueChanged<List<OcrElement>> onSelectionChanged;
  final VoidCallback onClearSelection;
  final Color highlightColor;
  final bool isDark;
  final bool isHighContrast;

  const OcrImageOverlay({
    super.key,
    required this.imageBytes,
    required this.imageSize,
    required this.elements,
    this.rejectedLines = const [],
    required this.selectedIds,
    required this.onSelectionChanged,
    required this.onClearSelection,
    this.highlightColor = const Color(0xFFE58E1B),
    this.isDark = true,
    this.isHighContrast = false,
  });

  @override
  State<OcrImageOverlay> createState() => _OcrImageOverlayState();
}

class _OcrImageOverlayState extends State<OcrImageOverlay> {
  // Simpan bounding box di layar untuk deteksi sentuhan cepat
  final Map<String, Rect> _screenRects = {};
  final Map<String, Rect> _rejectedScreenRects = {};

  void _calculateScreenRects(Size containerSize) {
    if (widget.imageSize.width <= 0 || widget.imageSize.height <= 0) return;

    final scale = min(
      containerSize.width / widget.imageSize.width,
      containerSize.height / widget.imageSize.height,
    );
    final renderedWidth = widget.imageSize.width * scale;
    final renderedHeight = widget.imageSize.height * scale;
    final offsetX = (containerSize.width - renderedWidth) / 2;
    final offsetY = (containerSize.height - renderedHeight) / 2;

    _screenRects.clear();
    for (final elem in widget.elements) {
      final rect = Rect.fromLTWH(
        offsetX + elem.boundingBox.left * scale,
        offsetY + elem.boundingBox.top * scale,
        elem.boundingBox.width * scale,
        elem.boundingBox.height * scale,
      );
      _screenRects[elem.id] = rect;
    }

    _rejectedScreenRects.clear();
    for (int i = 0; i < widget.rejectedLines.length; i++) {
      final rej = widget.rejectedLines[i];
      final rect = Rect.fromLTWH(
        offsetX + rej.line.boundingBox.left * scale,
        offsetY + rej.line.boundingBox.top * scale,
        rej.line.boundingBox.width * scale,
        rej.line.boundingBox.height * scale,
      );
      _rejectedScreenRects['rej_$i'] = rect;
    }
  }

  void _handleTapAt(Offset localPosition) {
    for (final elem in widget.elements) {
      final rect = _screenRects[elem.id];
      if (rect != null && rect.inflate(4.0).contains(localPosition)) {
        HapticFeedback.selectionClick();
        final newSelectedIds = Set<String>.from(widget.selectedIds);
        if (newSelectedIds.contains(elem.id)) {
          newSelectedIds.remove(elem.id);
        } else {
          newSelectedIds.add(elem.id);
        }
        _notifySelection(newSelectedIds);
        return;
      }
    }
  }

  void _handlePanAt(Offset localPosition) {
    final newSelectedIds = Set<String>.from(widget.selectedIds);
    bool changed = false;

    for (final elem in widget.elements) {
      final rect = _screenRects[elem.id];
      if (rect != null && rect.inflate(6.0).contains(localPosition)) {
        if (!newSelectedIds.contains(elem.id)) {
          newSelectedIds.add(elem.id);
          changed = true;
        }
      }
    }

    if (changed) {
      HapticFeedback.selectionClick();
      _notifySelection(newSelectedIds);
    }
  }

  void _notifySelection(Set<String> newSelectedIds) {
    final selectedList = widget.elements
        .where((elem) => newSelectedIds.contains(elem.id))
        .toList();

    // Urutkan geometris: atas ke bawah (toleransi baris 10dp), lalu kiri ke kanan
    selectedList.sort((a, b) {
      final topDiff = a.boundingBox.top - b.boundingBox.top;
      if (topDiff.abs() < 12.0) {
        return a.boundingBox.left.compareTo(b.boundingBox.left);
      }
      return topDiff.compareTo(0);
    });

    widget.onSelectionChanged(selectedList);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final containerSize = Size(constraints.maxWidth, constraints.maxHeight);
        _calculateScreenRects(containerSize);

        return Stack(
          fit: StackFit.expand,
          children: [
            // Gambar dokumen (BoxFit.contain agar seluruh foto terlihat presisi)
            Center(
              child: Image.memory(
                widget.imageBytes,
                fit: BoxFit.contain,
                width: constraints.maxWidth,
                height: constraints.maxHeight,
              ),
            ),

            // Lapisan Gesture Detector untuk Tap dan Pan (Drag Multi-Select)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => _handleTapAt(details.localPosition),
              onPanStart: (details) => _handlePanAt(details.localPosition),
              onPanUpdate: (details) => _handlePanAt(details.localPosition),
              child: CustomPaint(
                painter: _OcrBoxesPainter(
                  screenRects: _screenRects,
                  rejectedScreenRects: _rejectedScreenRects,
                  selectedIds: widget.selectedIds,
                  highlightColor: widget.highlightColor,
                  isHighContrast: widget.isHighContrast,
                ),
                size: Size.infinite,
              ),
            ),

            // Mode Debug: Indikator informasi jumlah baris lolos vs dibuang
            if (kDebugMode &&
                (widget.elements.isNotEmpty ||
                    widget.rejectedLines.isNotEmpty))
              Positioned(
                bottom: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    'Debug OCR: ${widget.elements.length} lolos (hijau) | ${widget.rejectedLines.length} dibuang (merah)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

            // Floating Badge Counter & Reset Button jika ada yang terpilih
            if (widget.selectedIds.isNotEmpty)
              Positioned(
                top: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: widget.isHighContrast
                            ? Colors.white
                            : widget.highlightColor,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${widget.selectedIds.length} teks terpilih',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            widget.onClearSelection();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Reset',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OcrBoxesPainter extends CustomPainter {
  final Map<String, Rect> screenRects;
  final Map<String, Rect> rejectedScreenRects;
  final Set<String> selectedIds;
  final Color highlightColor;
  final bool isHighContrast;

  _OcrBoxesPainter({
    required this.screenRects,
    required this.rejectedScreenRects,
    required this.selectedIds,
    required this.highlightColor,
    required this.isHighContrast,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (kDebugMode) {
      // 1. Gambar kotak merah untuk baris yang dibuang (noise)
      final rejectedFill = Paint()
        ..color = const Color(0xFFEF4444).withValues(alpha: 0.22)
        ..style = PaintingStyle.fill;
      final rejectedBorder = Paint()
        ..color = const Color(0xFFEF4444)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      for (final rect in rejectedScreenRects.values) {
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
        canvas.drawRRect(rrect, rejectedFill);
        canvas.drawRRect(rrect, rejectedBorder);
      }

      // 2. Gambar kotak hijau untuk baris yang lolos seleksi
      final acceptedBorder = Paint()
        ..color = const Color(0xFF22C55E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      final acceptedFill = Paint()
        ..color = const Color(0xFF22C55E).withValues(alpha: 0.16)
        ..style = PaintingStyle.fill;

      final selectedFill = Paint()
        ..color = isHighContrast
            ? const Color(0xFFFFE500).withValues(alpha: 0.65)
            : highlightColor.withValues(alpha: 0.45)
        ..style = PaintingStyle.fill;

      final selectedBorder = Paint()
        ..color = isHighContrast ? Colors.white : highlightColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHighContrast ? 2.5 : 2.5;

      for (final entry in screenRects.entries) {
        final id = entry.key;
        final rect = entry.value;
        final isSelected = selectedIds.contains(id);
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(5));

        if (isSelected) {
          canvas.drawRRect(rrect, selectedFill);
          canvas.drawRRect(rrect, selectedBorder);
        } else {
          canvas.drawRRect(rrect, acceptedFill);
          canvas.drawRRect(rrect, acceptedBorder);
        }
      }
      return;
    }

    // Mode Produksi: Gambar kotak netral putih dan kotak terpilih
    final unselectedFill = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;

    final unselectedBorder = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final selectedFill = Paint()
      ..color = isHighContrast
          ? const Color(0xFFFFE500).withValues(alpha: 0.65)
          : highlightColor.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;

    final selectedBorder = Paint()
      ..color = isHighContrast ? Colors.white : highlightColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isHighContrast ? 2.5 : 2.0;

    for (final entry in screenRects.entries) {
      final id = entry.key;
      final rect = entry.value;
      final isSelected = selectedIds.contains(id);

      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(5));

      if (isSelected) {
        canvas.drawRRect(rrect, selectedFill);
        canvas.drawRRect(rrect, selectedBorder);
      } else {
        canvas.drawRRect(rrect, unselectedFill);
        canvas.drawRRect(rrect, unselectedBorder);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _OcrBoxesPainter oldDelegate) {
    return oldDelegate.selectedIds != selectedIds ||
        oldDelegate.screenRects != screenRects ||
        oldDelegate.rejectedScreenRects != rejectedScreenRects ||
        oldDelegate.highlightColor != highlightColor;
  }
}
