import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../providers/reader_provider.dart';
import '../providers/settings_provider.dart';
import 'widgets/glass_button.dart';
import 'widgets/glass_container.dart';
import 'widgets/google_lens_overlay.dart';
import 'widgets/word_highlight_text.dart';

class ResultScreen extends StatefulWidget {
  final String? imagePath;

  const ResultScreen({super.key, this.imagePath});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final DraggableScrollableController _sheetController = DraggableScrollableController();

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reader = Provider.of<ReaderProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isDark = settingsProvider.isDarkMode;
    final fontMultiplier = settingsProvider.settings.fontSizeMultiplier;
    final fullText = reader.ocrResult?.fullText ?? '';

    final hasImage = widget.imagePath != null && widget.imagePath!.isNotEmpty && File(widget.imagePath!).existsSync();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: Stack(
        children: [
          // 1. Tampilan Foto Asli dengan Google Lens Overlay Bounding Boxes
          if (hasImage)
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(
                      File(widget.imagePath!),
                      fit: BoxFit.contain,
                    ),
                    if (reader.ocrResult != null)
                      CustomPaint(
                        painter: GoogleLensOverlayPainter(
                          words: reader.ocrResult!.words,
                          originalImageSize: reader.ocrResult!.imageSize,
                          activeWord: reader.highlightWord,
                        ),
                      ),
                  ],
                ),
              ),
            )
          else
            // Jika dipanggil dari riwayat (tanpa foto)
            Positioned.fill(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 80, bottom: 140),
                  child: SingleChildScrollView(
                    child: GlassContainer(
                      padding: const EdgeInsets.all(22),
                      child: WordHighlightText(
                        fullText: fullText,
                        highlightStart: reader.highlightStart,
                        highlightEnd: reader.highlightEnd,
                        fontSize: 22 * fontMultiplier,
                        textColor: isDark ? Colors.white : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 2. Header Atas Kaca (Tombol Kembali & Judul)
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    GlassButton(
                      minSize: 52,
                      borderRadius: 18,
                      onTap: () {
                        reader.stop();
                        Navigator.of(context).pop();
                      },
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: isDark ? Colors.white : AppColors.lightTextPrimary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GlassContainer(
                        borderRadius: 18,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Text(
                          'Hasil Pemindaian',
                          style: TextStyle(
                            fontSize: 18 * fontMultiplier,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.lightTextPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Bilah Audio Melayang (Floating Audio Dock: ⏪ 10s | ▶️ / ⏸️ | ⏩ 10s)
          Positioned(
            left: 20,
            right: 20,
            bottom: hasImage ? 85 : 24,
            child: GlassContainer(
              borderRadius: 26,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mundur 10 Detik
                  GlassButton(
                    minSize: 54,
                    borderRadius: 18,
                    onTap: () => reader.seekBackward10s(speechRate: settingsProvider.settings.kecepatanSuara),
                    icon: const Icon(Icons.replay_10_rounded, size: 28, color: AppColors.accentBlue),
                  ),

                  // Putar / Jeda Utama Raksasa (68x68 dp)
                  GlassButton(
                    minSize: 68,
                    borderRadius: 24,
                    isPrimary: true,
                    onTap: () => reader.togglePlayPause(),
                    icon: Icon(
                      reader.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 38,
                      color: Colors.white,
                    ),
                  ),

                  // Maju 10 Detik
                  GlassButton(
                    minSize: 54,
                    borderRadius: 18,
                    onTap: () => reader.seekForward10s(speechRate: settingsProvider.settings.kecepatanSuara),
                    icon: const Icon(Icons.forward_10_rounded, size: 28, color: AppColors.accentBlue),
                  ),
                ],
              ),
            ),
          ),

          // 4. Lembar Transkrip Geser ke Atas (Swipe-Up Bottom Sheet) jika ada gambar
          if (hasImage)
            DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: 0.10,
              minChildSize: 0.08,
              maxChildSize: 0.88,
              builder: (context, scrollController) {
                return GlassContainer(
                  borderRadius: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: ListView(
                    controller: scrollController,
                    padding: EdgeInsets.zero,
                    children: [
                      // Handle Bar Geser Kaca
                      Center(
                        child: Container(
                          width: 48,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white38 : Colors.black26,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Petunjuk Geser
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.keyboard_arrow_up_rounded,
                            color: isDark ? AppColors.accentYellow : AppColors.accentBlue,
                            size: 24,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Geser ke atas untuk teks lengkap',
                            style: TextStyle(
                              fontSize: 14 * fontMultiplier,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      // Pilihan Cepat Kecepatan Suara
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Kecepatan Suara:',
                            style: TextStyle(
                              fontSize: 14 * fontMultiplier,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                            ),
                          ),
                          Row(
                            children: [0.75, 1.0, 1.25].map((rate) {
                              final isSelected = settingsProvider.settings.kecepatanSuara == rate;
                              return Padding(
                                padding: const EdgeInsets.only(left: 6.0),
                                child: ChoiceChip(
                                  label: Text('${rate}x'),
                                  selected: isSelected,
                                  onSelected: (_) {
                                    settingsProvider.setSpeechRate(rate);
                                    if (reader.isPlaying) {
                                      reader.readExistingText(
                                        text: fullText,
                                        speechRate: rate,
                                        language: settingsProvider.settings.bahasaSuara,
                                      );
                                    }
                                  },
                                  selectedColor: AppColors.accentBlue,
                                  labelStyle: TextStyle(
                                    color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Teks Lengkap dengan Synchronized Word Highlighting
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black26 : Colors.white.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                        child: WordHighlightText(
                          fullText: fullText,
                          highlightStart: reader.highlightStart,
                          highlightEnd: reader.highlightEnd,
                          fontSize: 22 * fontMultiplier,
                          textColor: isDark ? Colors.white : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
