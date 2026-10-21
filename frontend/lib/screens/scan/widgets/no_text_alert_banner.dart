import 'package:flutter/material.dart';

/// Floating alert banner di atas tombol rana untuk menginformasikan kondisi tanpa teks.
///
/// Karakteristik desain:
/// - Tidak menghalangi tombol rana kamera (terletak di atas tombol rana).
/// - Tidak menutupi area tengah pratinjau kamera (viewfinder).
/// - Menyediakan tombol tutup dengan target sentuh aksesibilitas minimal 48dp.
/// - Menghilang dengan animasi transisi yang halus.
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

    return Positioned(
      left: 20,
      right: 20,
      bottom: bottomPadding + 130,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: isVisible ? 1.0 : 0.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFF59E0B),
                size: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
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
