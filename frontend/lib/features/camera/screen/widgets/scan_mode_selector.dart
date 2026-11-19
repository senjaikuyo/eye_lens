import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:eye_lens/app/theme/app_colors.dart';
import 'package:eye_lens/core/constants/app_strings.dart';
import 'package:eye_lens/features/ocr/correction/ocr_noise_filter.dart';

/// Widget pemilih mode pemindaian OCR manual yang dapat diakses (WCAG AA).
/// Menempatkan 4 mode: Dokumen, Teliti (Teks Kecil), Layar, dan Tulis Tangan.
class ScanModeSelector extends StatelessWidget {
  final OcrScanMode selectedMode;
  final ValueChanged<OcrScanMode> onModeChanged;
  final double bottomPadding;

  const ScanModeSelector({
    super.key,
    required this.selectedMode,
    required this.onModeChanged,
    required this.bottomPadding,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    final List<_ModeItem> items = [
      _ModeItem(
        mode: OcrScanMode.document,
        label: strings.modeDocument,
        icon: Icons.description_outlined,
      ),
      _ModeItem(
        mode: OcrScanMode.smallText,
        label: strings.modeSmallText,
        icon: Icons.zoom_in_outlined,
      ),
      _ModeItem(
        mode: OcrScanMode.screenText,
        label: strings.modeScreenText,
        icon: Icons.smartphone_outlined,
      ),
      _ModeItem(
        mode: OcrScanMode.handwriting,
        label: strings.modeHandwriting,
        icon: Icons.draw_outlined,
      ),
    ];

    return Positioned(
      left: 0,
      right: 0,
      bottom: bottomPadding + 124,
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: items.map((item) {
              final isSelected = item.mode == selectedMode;
              final accessibilityStatus = isSelected
                  ? (strings.isIndonesian ? 'terpilih' : 'selected')
                  : (strings.isIndonesian
                        ? 'ketuk untuk memilih'
                        : 'tap to select');

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Semantics(
                  button: true,
                  selected: isSelected,
                  label: '${item.label}, $accessibilityStatus',
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          if (!isSelected) {
                            HapticFeedback.selectionClick();
                            onModeChanged(item.mode);
                          }
                        },
                        borderRadius: BorderRadius.circular(24),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.white
                                : Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.white
                                  : Colors.white.withValues(alpha: 0.35),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item.icon,
                                size: 16,
                                color: isSelected
                                    ? AppColors.black
                                    : AppColors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                item.label,
                                style: TextStyle(
                                  color: isSelected
                                      ? AppColors.black
                                      : AppColors.white,
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _ModeItem {
  final OcrScanMode mode;
  final String label;
  final IconData icon;

  const _ModeItem({
    required this.mode,
    required this.label,
    required this.icon,
  });
}
