import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../models/text_formatter_models.dart';

/// Komponen visualisasi teks bacaan yang otomatis menyorot kata/paragraf aktif
/// dan melakukan auto-scroll halus mengikuti posisi bacaan yang sedang aktif.
class HighlightedTextView extends StatefulWidget {
  final String text;
  final FormattedTextResult? formattedResult;
  final int currentCharIndex;
  final double fontSize;
  final bool cursorColorEnabled;
  final Color highlightColor;
  final bool isDark;
  final bool isHighContrast;
  final double progress;
  final ValueChanged<double> onProgressChanged;
  final ValueChanged<int>? onCharIndexChanged;

  const HighlightedTextView({
    super.key,
    required this.text,
    this.formattedResult,
    this.currentCharIndex = 0,
    required this.fontSize,
    required this.cursorColorEnabled,
    required this.highlightColor,
    required this.isDark,
    required this.isHighContrast,
    required this.progress,
    required this.onProgressChanged,
    this.onCharIndexChanged,
  });

  @override
  State<HighlightedTextView> createState() => _HighlightedTextViewState();
}

class _HighlightedTextViewState extends State<HighlightedTextView> {
  // Mode paragraf terformat
  List<GlobalKey> _paragraphKeys = [];
  int _lastActiveParagraphIndex = -1;

  // Fallback mode baris
  List<String> _fallbackLines = [];
  List<GlobalKey> _fallbackLineKeys = [];
  int _lastActiveLineIndex = -1;

  @override
  void initState() {
    super.initState();
    _initStructure();
  }

  @override
  void didUpdateWidget(covariant HighlightedTextView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.text != widget.text ||
        oldWidget.formattedResult != widget.formattedResult) {
      _initStructure();
    }

    _handleAutoScroll();
  }

  void _initStructure() {
    final result = widget.formattedResult;
    if (result != null && result.paragraphs.isNotEmpty) {
      _paragraphKeys = List.generate(
        result.paragraphs.length,
        (_) => GlobalKey(),
      );
      _lastActiveParagraphIndex = -1;
    } else {
      _processFallbackLines();
    }
  }

  void _processFallbackLines() {
    final raw = widget.text.trim();
    if (raw.contains('\n')) {
      _fallbackLines = raw
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } else {
      _fallbackLines = raw
          .split(RegExp(r'(?<=[.!?])\s+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }

    if (_fallbackLines.isEmpty) {
      _fallbackLines = [raw.isNotEmpty ? raw : 'yesterday\ntoday\ntomorrow'];
    }

    _fallbackLineKeys = List.generate(_fallbackLines.length, (_) => GlobalKey());
    _lastActiveLineIndex = -1;
  }

  void _handleAutoScroll() {
    final result = widget.formattedResult;
    if (result != null && result.paragraphs.isNotEmpty) {
      final activeParaIndex = _findActiveParagraphIndex(result);
      if (activeParaIndex != -1 &&
          activeParaIndex != _lastActiveParagraphIndex) {
        _lastActiveParagraphIndex = activeParaIndex;
        _scrollToKey(_paragraphKeys, activeParaIndex);
      }
    } else if (_fallbackLines.isNotEmpty) {
      final activeIndex = (widget.progress * _fallbackLines.length)
          .clamp(0, _fallbackLines.length - 1)
          .toInt();
      if (activeIndex != _lastActiveLineIndex) {
        _lastActiveLineIndex = activeIndex;
        _scrollToKey(_fallbackLineKeys, activeIndex);
      }
    }
  }

  int _findActiveParagraphIndex(FormattedTextResult result) {
    final charIndex = widget.currentCharIndex;
    if (charIndex > 0) {
      for (int i = 0; i < result.paragraphs.length; i++) {
        final p = result.paragraphs[i];
        if (charIndex >= p.startIndex && charIndex <= p.endIndex) {
          return i;
        }
      }
    }

    final fullLen = result.fullText.length;
    if (fullLen > 0) {
      final estimatedIndex = (widget.progress * fullLen).round();
      for (int i = 0; i < result.paragraphs.length; i++) {
        final p = result.paragraphs[i];
        if (estimatedIndex >= p.startIndex && estimatedIndex <= p.endIndex) {
          return i;
        }
      }
    }
    return 0;
  }

  void _scrollToKey(List<GlobalKey> keys, int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || index < 0 || index >= keys.length) return;
      final keyContext = keys[index].currentContext;
      if (keyContext != null) {
        Scrollable.ensureVisible(
          keyContext,
          alignment: 0.35,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.formattedResult;
    if (result != null && result.paragraphs.isNotEmpty) {
      return _buildFormattedParagraphsView(result);
    }
    return _buildFallbackLinesView();
  }

  Widget _buildFormattedParagraphsView(FormattedTextResult result) {
    final activeParaIndex = _findActiveParagraphIndex(result);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int pIdx = 0; pIdx < result.paragraphs.length; pIdx++) ...[
          _buildParagraphWidget(
            paragraph: result.paragraphs[pIdx],
            paragraphIndex: pIdx,
            isActiveParagraph: pIdx == activeParaIndex,
            totalChars: result.fullText.length,
          ),
          const SizedBox(height: 18),
        ],
        const SizedBox(height: 160),
      ],
    );
  }

  Widget _buildParagraphWidget({
    required FormattedParagraph paragraph,
    required int paragraphIndex,
    required bool isActiveParagraph,
    required int totalChars,
  }) {
    final baseTextColor = widget.isDark ? Colors.white : AppColors.black;
    final activeChar = widget.currentCharIndex;

    return Semantics(
      label: paragraph.text,
      child: Container(
        key: _paragraphKeys[paragraphIndex],
        padding: EdgeInsets.symmetric(
          horizontal: paragraph.isListItem ? 8.0 : 4.0,
          vertical: 4.0,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isActiveParagraph && widget.cursorColorEnabled
              ? widget.highlightColor.withValues(alpha: 0.08)
              : Colors.transparent,
        ),
        child: RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: widget.fontSize,
              height: 1.5,
              color: baseTextColor,
              fontWeight: widget.isHighContrast
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
            children: [
              for (int wIdx = 0; wIdx < paragraph.words.length; wIdx++) ...[
                if (wIdx > 0) const TextSpan(text: ' '),
                _buildWordSpan(
                  word: paragraph.words[wIdx],
                  isActive: widget.cursorColorEnabled &&
                      isActiveParagraph &&
                      activeChar >= paragraph.words[wIdx].startIndex &&
                      activeChar <= paragraph.words[wIdx].endIndex,
                  totalChars: totalChars,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  InlineSpan _buildWordSpan({
    required FormattedWord word,
    required bool isActive,
    required int totalChars,
  }) {
    final baseTextColor = widget.isDark ? Colors.white : AppColors.black;

    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: GestureDetector(
        onTap: () {
          if (widget.onCharIndexChanged != null) {
            widget.onCharIndexChanged!(word.startIndex);
          }
          if (totalChars > 0) {
            widget.onProgressChanged(word.startIndex / totalChars);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: isActive ? 4.0 : 1.0,
            vertical: isActive ? 2.0 : 0.0,
          ),
          decoration: BoxDecoration(
            color: isActive ? widget.highlightColor : Colors.transparent,
            borderRadius: BorderRadius.circular(4.0),
            border: isActive && widget.isHighContrast
                ? Border.all(
                    color: widget.isDark ? Colors.white : Colors.black,
                    width: 1.5,
                  )
                : null,
          ),
          child: Text(
            word.text,
            style: TextStyle(
              fontSize: widget.fontSize,
              height: 1.5,
              color: isActive ? Colors.white : baseTextColor,
              fontWeight: widget.isHighContrast
                  ? FontWeight.w800
                  : (isActive ? FontWeight.w700 : FontWeight.w500),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackLinesView() {
    final activeIndex = _fallbackLines.isNotEmpty
        ? (widget.progress * _fallbackLines.length)
            .clamp(0, _fallbackLines.length - 1)
            .toInt()
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...List.generate(_fallbackLines.length, (index) {
          final line = _fallbackLines[index];
          final isActive = index == activeIndex;

          if (!widget.cursorColorEnabled) {
            return Container(
              key: _fallbackLineKeys[index],
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                style: TextStyle(
                  color: widget.isDark ? Colors.white : AppColors.black,
                  fontSize: widget.fontSize,
                  height: 1.35,
                  fontWeight: widget.isHighContrast
                      ? FontWeight.w800
                      : FontWeight.w600,
                ),
                child: Text(line),
              ),
            );
          }

          return GestureDetector(
            key: _fallbackLineKeys[index],
            onTap: () {
              widget.onProgressChanged(index / _fallbackLines.length);
              _scrollToKey(_fallbackLineKeys, index);
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
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
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
                child: Text(line),
              ),
            ),
          );
        }),
        const SizedBox(height: 160),
      ],
    );
  }
}
