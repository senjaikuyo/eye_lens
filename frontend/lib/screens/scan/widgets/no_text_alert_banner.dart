import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';

/// Floating alert banner di atas tombol rana atau player bar untuk menginformasikan kondisi tanpa teks.
///
/// Karakteristik desain:
/// - Mengikuti tema EyeLens (permukaan gelap konsisten, border halus, bayangan lembut).
/// - Menyediakan tombol tutup dengan target sentuh aksesibilitas minimal 48dp.
/// - Menghilang otomatis dan mendukung animasi transisi halus.
/// - Menggunakan token tipografi bodyMedium (minimal 16 sp) agar teks terbaca jelas.
class NoTextAlertBanner extends StatelessWidget {
  final bool isVisible;
  final double bottomPadding;
  final String message;
  final VoidCallback onClose;
  final String closeLabel;

  const NoTextAlertBanner({
    super.key,
    required this.isVisible,
    required this.bottomPadding,
    required this.message,
    required this.onClose,
    this.closeLabel = 'Tutup',
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;

    return Positioned(
      left: 20,
      right: 20,
      bottom: bottomPadding + 130,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        opacity: isVisible ? 1.0 : 0.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E).withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.greyDarkBorder, width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
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
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
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
