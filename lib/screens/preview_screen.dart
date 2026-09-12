import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../providers/camera_provider.dart';
import '../providers/reader_provider.dart';
import '../providers/settings_provider.dart';
import 'result_screen.dart';
import 'widgets/glass_button.dart';
import 'widgets/glass_container.dart';

class PreviewScreen extends StatefulWidget {
  final String imagePath;

  const PreviewScreen({super.key, required this.imagePath});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  bool _isLoading = false;

  Future<void> _handleConfirm() async {
    setState(() => _isLoading = true);

    final readerProvider = Provider.of<ReaderProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

    final success = await readerProvider.processAndRead(
      imagePath: widget.imagePath,
      speechRate: settingsProvider.settings.kecepatanSuara,
      language: settingsProvider.settings.bahasaSuara,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResultScreen(imagePath: widget.imagePath),
        ),
      );
    } else {
      // Tampilkan notifikasi ramah jika gagal membaca
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Tulisan belum terbaca jelas. Mohon foto ulang dengan lebih tenang.',
            style: TextStyle(
              fontSize: 16 * settingsProvider.settings.fontSizeMultiplier,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: AppColors.accentRed,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _handleRetake() {
    final cameraProvider = Provider.of<CameraProvider>(context, listen: false);
    cameraProvider.clearCapturedPhoto();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isDark = settingsProvider.isDarkMode;
    final fontMultiplier = settingsProvider.settings.fontSizeMultiplier;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Tampilan Foto Pratinjau
          Image.file(
            File(widget.imagePath),
            fit: BoxFit.contain,
          ),

          // 2. Banner Informasi Atas Kaca
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: GlassContainer(
                  borderRadius: 22,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline, color: AppColors.accentBlue, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Pratinjau Foto',
                        style: TextStyle(
                          fontSize: 18 * fontMultiplier,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. Bilah Tombol Konfirmasi Bawah (2 Tombol Besar)
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                child: Row(
                  children: [
                    // Tombol Kiri: Foto Ulang
                    Expanded(
                      child: GlassButton(
                        minSize: 62,
                        borderRadius: 22,
                        onTap: _isLoading ? null : _handleRetake,
                        icon: const Icon(Icons.refresh_rounded, size: 26, color: AppColors.accentRed),
                        label: 'Foto Ulang',
                        textColor: AppColors.accentRed,
                        backgroundColor: isDark
                            ? AppColors.darkCardBg.withOpacity(0.9)
                            : Colors.white.withOpacity(0.92),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Tombol Kanan: Baca Teks (Primary)
                    Expanded(
                      child: _isLoading
                          ? GlassContainer(
                              borderRadius: 22,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.accentBlue,
                                  strokeWidth: 3,
                                ),
                              ),
                            )
                          : GlassButton(
                              minSize: 62,
                              borderRadius: 22,
                              isPrimary: true,
                              onTap: _handleConfirm,
                              icon: const Icon(Icons.volume_up_rounded, size: 26, color: Colors.white),
                              label: 'Baca Teks',
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
