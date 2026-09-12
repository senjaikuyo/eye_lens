import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../providers/settings_provider.dart';
import 'widgets/glass_button.dart';
import 'widgets/glass_container.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isDark = settingsProvider.isDarkMode;
    final fontMultiplier = settingsProvider.settings.fontSizeMultiplier;
    final settings = settingsProvider.settings;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            // Header Atas
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  GlassButton(
                    minSize: 52,
                    borderRadius: 18,
                    onTap: () => Navigator.of(context).pop(),
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
                        'Pengaturan Aksesibilitas',
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

            // Daftar Setelan
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // 1. Tampilan: Mode Terang / Gelap
                  GlassContainer(
                    borderRadius: 22,
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                              color: AppColors.accentBlue,
                              size: 28,
                            ),
                            const SizedBox(width: 14),
                            Text(
                              isDark ? 'Mode Gelap' : 'Mode Terang',
                              style: TextStyle(
                                fontSize: 17 * fontMultiplier,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : AppColors.lightTextPrimary,
                              ),
                            ),
                          ],
                        ),
                        Switch.adaptive(
                          value: isDark,
                          activeColor: AppColors.accentBlue,
                          onChanged: (_) => settingsProvider.toggleTheme(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 2. Ukuran Font
                  GlassContainer(
                    borderRadius: 22,
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.format_size_rounded, color: AppColors.accentBlue, size: 28),
                            const SizedBox(width: 14),
                            Text(
                              'Ukuran Tulisan',
                              style: TextStyle(
                                fontSize: 17 * fontMultiplier,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : AppColors.lightTextPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildFontOption(context, 'Sedang', 'normal', settings.skalaFont == 'normal'),
                            _buildFontOption(context, 'Besar', 'large', settings.skalaFont == 'large'),
                            _buildFontOption(context, 'Ekstra', 'extra_large', settings.skalaFont == 'extra_large'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 3. Kecepatan Suara
                  GlassContainer(
                    borderRadius: 22,
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.speed_rounded, color: AppColors.accentBlue, size: 28),
                            const SizedBox(width: 14),
                            Text(
                              'Kecepatan Suara',
                              style: TextStyle(
                                fontSize: 17 * fontMultiplier,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : AppColors.lightTextPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildRateOption(context, '0.75x Lambat', 0.75, settings.kecepatanSuara == 0.75),
                            _buildRateOption(context, '1.0x Normal', 1.0, settings.kecepatanSuara == 1.0),
                            _buildRateOption(context, '1.25x Cepat', 1.25, settings.kecepatanSuara == 1.25),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 4. Bahasa Pembacaan
                  GlassContainer(
                    borderRadius: 22,
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.language_rounded, color: AppColors.accentBlue, size: 28),
                            const SizedBox(width: 14),
                            Text(
                              'Bahasa Suara',
                              style: TextStyle(
                                fontSize: 17 * fontMultiplier,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : AppColors.lightTextPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('🇮🇩 Bahasa Indonesia'),
                              selected: settings.bahasaSuara == 'id-ID',
                              selectedColor: AppColors.accentBlue,
                              labelStyle: TextStyle(
                                color: settings.bahasaSuara == 'id-ID' ? Colors.white : (isDark ? Colors.white : Colors.black),
                                fontWeight: FontWeight.bold,
                              ),
                              onSelected: (_) => settingsProvider.setLanguage('id-ID'),
                            ),
                            ChoiceChip(
                              label: const Text('🇬🇧 English'),
                              selected: settings.bahasaSuara == 'en-US',
                              selectedColor: AppColors.accentBlue,
                              labelStyle: TextStyle(
                                color: settings.bahasaSuara == 'en-US' ? Colors.white : (isDark ? Colors.white : Colors.black),
                                fontWeight: FontWeight.bold,
                              ),
                              onSelected: (_) => settingsProvider.setLanguage('en-US'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 5. Garis Pembimbing Baca (Toggle)
                  GlassContainer(
                    borderRadius: 22,
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.line_weight_rounded, color: AppColors.accentYellow, size: 28),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Garis Pembimbing Baca',
                                  style: TextStyle(
                                    fontSize: 17 * fontMultiplier,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                                  ),
                                ),
                                Text(
                                  'Fokus 1 baris anti-pusing',
                                  style: TextStyle(
                                    fontSize: 13 * fontMultiplier,
                                    color: isDark ? Colors.white60 : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Switch.adaptive(
                          value: settings.garisPanduanAktif,
                          activeColor: AppColors.accentBlue,
                          onChanged: (_) => settingsProvider.toggleGuideLine(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 6. Getaran Sentuhan (Toggle)
                  GlassContainer(
                    borderRadius: 22,
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.vibration_rounded, color: AppColors.accentBlue, size: 28),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Getaran Sentuhan',
                                  style: TextStyle(
                                    fontSize: 17 * fontMultiplier,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                                  ),
                                ),
                                Text(
                                  'Konfirmasi fisik saat ditekan',
                                  style: TextStyle(
                                    fontSize: 13 * fontMultiplier,
                                    color: isDark ? Colors.white60 : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Switch.adaptive(
                          value: settings.umpanBalikGetar,
                          activeColor: AppColors.accentBlue,
                          onChanged: (_) => settingsProvider.toggleHaptics(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFontOption(BuildContext context, String label, String value, bool isSelected) {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final isDark = settingsProvider.isDarkMode;

    return Expanded(
      child: ChoiceChip(
        label: Center(child: Text(label)),
        selected: isSelected,
        selectedColor: AppColors.accentBlue,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black),
          fontWeight: FontWeight.bold,
        ),
        onSelected: (_) => settingsProvider.setFontSize(value),
      ),
    );
  }

  Widget _buildRateOption(BuildContext context, String label, double value, bool isSelected) {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final isDark = settingsProvider.isDarkMode;

    return Expanded(
      child: ChoiceChip(
        label: Center(child: Text(label)),
        selected: isSelected,
        selectedColor: AppColors.accentBlue,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black),
          fontWeight: FontWeight.bold,
        ),
        onSelected: (_) => settingsProvider.setSpeechRate(value),
      ),
    );
  }
}
