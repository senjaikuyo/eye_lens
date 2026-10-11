import 'package:flutter/material.dart';
import '../../../core/app_colors.dart';

/// Komponen visualisasi teks bacaan yang otomatis menyorot kata/baris
/// dan melakukan auto-scroll halus mengikuti posisi bacaan yang sedang aktif,
/// sehingga teks yang sedang dibacakan selalu berada di area pandang layar.
class HighlightedTextView extends StatefulWidget {
  final String text;
  final double fontSize;
  final bool cursorColorEnabled;
  final Color highlightColor;
  final bool isDark;
  final bool isHighContrast;
  final double progress;
  final ValueChanged<double> onProgressChanged;

  const HighlightedTextView({
    super.key,
    required this.text,
    required this.fontSize,
    required this.cursorColorEnabled,
    required this.highlightColor,
    required this.isDark,
    required this.isHighContrast,
    required this.progress,
    required this.onProgressChanged,
  });

  @override
  State<HighlightedTextView> createState() => _HighlightedTextViewState();
}

class _HighlightedTextViewState extends State<HighlightedTextView> {
  List<String> _lines = [];
  List<GlobalKey> _lineKeys = [];
  int _lastActiveIndex = -1;

  @override
  void initState() {
    super.initState();
    _processText();
  }

  @override
  void didUpdateWidget(covariant HighlightedTextView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.text != widget.text) {
      _processText();
    }

    if (_lines.isNotEmpty) {
      final activeIndex =
          (widget.progress * _lines.length).clamp(0, _lines.length - 1).toInt();

      if (activeIndex != _lastActiveIndex) {
        _lastActiveIndex = activeIndex;
        _scrollToActiveIndex(activeIndex);
      }
    }
  }

  void _processText() {
    final raw = widget.text.trim();
    if (raw.contains('\n')) {
      _lines = raw
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } else {
      // Jika hasil OCR adalah paragraf panjang tanpa newline, pecah per kalimat
      _lines = raw
          .split(RegExp(r'(?<=[.!?])\s+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }

    if (_lines.isEmpty) {
      _lines = [raw.isNotEmpty ? raw : 'yesterday\ntoday\ntomorrow'];
    }

    _lineKeys = List.generate(_lines.length, (_) => GlobalKey());
    _lastActiveIndex = -1;
  }

  void _scrollToActiveIndex(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || index < 0 || index >= _lineKeys.length) return;
      final keyContext = _lineKeys[index].currentContext;
      if (keyContext != null) {
        Scrollable.ensureVisible(
          keyContext,
          alignment: 0.35, // Posisikan teks aktif di sepertiga atas area pandang layar
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeIndex = _lines.isNotEmpty
        ? (widget.progress * _lines.length).clamp(0, _lines.length - 1).toInt()
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...List.generate(_lines.length, (index) {
          final line = _lines[index];
          final isActive = index == activeIndex;

          if (!widget.cursorColorEnabled) {
            return Container(
              key: _lineKeys[index],
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                line,
                style: TextStyle(
                  color: widget.isDark ? Colors.white : AppColors.black,
                  fontSize: widget.fontSize,
                  height: 1.35,
                  fontWeight: widget.isHighContrast
                      ? FontWeight.w800
                      : FontWeight.w600,
                ),
              ),
            );
          }

          return GestureDetector(
            key: _lineKeys[index],
            onTap: () {
              widget.onProgressChanged(index / _lines.length);
              _scrollToActiveIndex(index);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: EdgeInsets.symmetric(
                horizontal: isActive ? 12 : 4,
                vertical: isActive ? 8 : 4,
              ),
              decoration: BoxDecoration(
                color: isActive ? widget.highlightColor : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: isActive && widget.isHighContrast
                    ? Border.all(
                        color: widget.isDark ? Colors.white : Colors.black,
                        width: 2.0,
                      )
                    : null,
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: widget.highlightColor.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                line,
                style: TextStyle(
                  color: isActive
                      ? Colors.white
                      : (widget.isDark ? Colors.white : AppColors.black),
                  fontSize: widget.fontSize,
                  height: 1.35,
                  fontWeight: widget.isHighContrast
                      ? FontWeight.w900
                      : (isActive ? FontWeight.w700 : FontWeight.w600),
                ),
              ),
            ),
          );
        }),
        // Ruang kosong di bawah agar baris terakhir bisa di-scroll ke tengah tanpa tertutup audio bar
        const SizedBox(height: 160),
      ],
    );
  }
}
