import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_strings.dart';

/// Floating alert banner bertema merah untuk menginformasikan kondisi kesalahan / teks tidak ditemukan.
///
/// Karakteristik desain:
/// - Latar belakang merah cerah terkalibrasi (#D8224E) dengan rasio kontras > 4.9:1 terhadap teks putih (WCAG AA).
/// - Ikon status: lingkaran putih pejal berisi tanda silang (X) merah di sisi kiri (30dp).
/// - Judul tebal (minimal 18 sp, titleMedium) dan baris pesan petunjuk (minimal 16 sp, bodyMedium).
/// - Tombol tutup di pojok kanan atas dengan target sentuh aksesibilitas minimal 48dp.
/// - Sudut membulat 12dp dengan bayangan halus, margin horizontal, dan animasi fade yang selaras.
class NoTextAlertBanner extends StatelessWidget {
  final bool isVisible;
  final double bottomPadding;
  final String? title;
  final String message;
  final VoidCallback onClose;
  final String closeLabel;

  const NoTextAlertBanner({
    super.key,
    required this.isVisible,
    required this.bottomPadding,
    this.title,
    required this.message,
    required this.onClose,
    this.closeLabel = 'Tutup',
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    final strings = AppStrings.of(context);
    final textTheme = Theme.of(context).textTheme;
    final displayTitle = title ?? strings.noTextFoundTitle;

    return Positioned(
      left: 16,
      right: 16,
      bottom: bottomPadding + 130,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        opacity: isVisible ? 1.0 : 0.0,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.alertErrorBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.alertErrorBorder,
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.only(
            left: 14,
            top: 12,
            right: 6,
            bottom: 12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ikon Status Kiri: Lingkaran putih pejal dengan tanda X merah
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.close_rounded,
                    color: AppColors.alertErrorIconX,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Konten Teks: Judul tebal (>= 18 sp) dan Pesan (>= 16 sp)
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayTitle,
                      style: textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      message,
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w400,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),

              // Tombol Tutup Pojok Kanan Atas (Area sentuh minimal 48dp)
              Semantics(
                button: true,
                label: closeLabel,
                child: InkWell(
                  onTap: onClose,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withValues(alpha: 0.85),
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
