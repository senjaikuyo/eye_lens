import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:eye_lens/app/theme/app_colors.dart';
import 'package:eye_lens/features/image_area/logic/lens_selection_controller.dart';

import 'package:eye_lens/features/image_area/screen/ocr_image_overlay.dart';
import 'package:eye_lens/features/ocr/models/ocr_element.dart';
import 'package:eye_lens/features/speech/models/text_formatter_models.dart';
import 'package:eye_lens/features/speech/screen/widgets/highlighted_text_view.dart';

class SpeechBodyView extends StatelessWidget {
  final bool isTextView;
  final bool isDark;
  final bool isHighContrast;
  final bool cursorColorEnabled;
  final Color highlightColor;
  final double topPadding;
  final double bottomPadding;
  final Uint8List? imageBytes;
  final OcrResult? ocrResult;
  final LensSelectionController lensSelectionController;
  final VoidCallback onFrameChanging;
  final OnSelectionComputedCallback onSelectionComputed;
  final String activeText;
  final FormattedTextResult? formattedResult;
  final ValueNotifier<double> fontSizeNotifier;
  final ValueNotifier<double> progressNotifier;
  final ValueNotifier<int> currentCharIndexNotifier;
  final ValueChanged<double> onProgressChanged;
  final ValueChanged<int> onCharIndexChanged;

  const SpeechBodyView({
    super.key,
    required this.isTextView,
    required this.isDark,
    required this.isHighContrast,
    required this.cursorColorEnabled,
    required this.highlightColor,
    required this.topPadding,
    required this.bottomPadding,
    required this.imageBytes,
    required this.ocrResult,
    required this.lensSelectionController,
    required this.onFrameChanging,
    required this.onSelectionComputed,
    required this.activeText,
    required this.formattedResult,
    required this.fontSizeNotifier,
    required this.progressNotifier,
    required this.currentCharIndexNotifier,
    required this.onProgressChanged,
    required this.onCharIndexChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (!isTextView) {
      final bytes = imageBytes;
      if (bytes != null) {
        return Padding(
          padding: EdgeInsets.only(
            top: topPadding + 64,
            bottom: bottomPadding + 140,
          ),
          child: OcrImageOverlay(
            imageBytes: bytes,
            imageSize: ocrResult?.imageSize ?? Size.zero,
            rawLines: ocrResult?.rawLines ?? const [],
            elements: ocrResult?.elements ?? const [],
            isDark: isDark,
            isHighContrast: isHighContrast,
            controller: lensSelectionController,
            onFrameChanging: onFrameChanging,
            onSelectionComputed: onSelectionComputed,
          ),
        );
      }
      return Container(color: Colors.black);
    }

    return Container(
      color: isDark ? AppColors.black : Colors.white,
      padding: EdgeInsets.only(
        top: topPadding + 80,
        left: 28,
        right: 28,
        bottom: 160,
      ),
      child: SingleChildScrollView(
        child: ValueListenableBuilder<double>(
          valueListenable: fontSizeNotifier,
          builder: (context, currentFontSize, _) {
            return ValueListenableBuilder<double>(
              valueListenable: progressNotifier,
              builder: (context, progress, _) {
                return ValueListenableBuilder<int>(
                  valueListenable: currentCharIndexNotifier,
                  builder: (context, charIndex, _) {
                    return HighlightedTextView(
                      text: activeText,
                      formattedResult: formattedResult,
                      currentCharIndex: charIndex,
                      fontSize: currentFontSize,
                      cursorColorEnabled: cursorColorEnabled,
                      highlightColor: highlightColor,
                      isDark: isDark,
                      isHighContrast: isHighContrast,
                      progress: progress,
                      onProgressChanged: onProgressChanged,
                      onCharIndexChanged: onCharIndexChanged,
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
