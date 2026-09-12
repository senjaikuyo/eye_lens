import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../models/history_model.dart';
import '../providers/history_provider.dart';
import '../providers/reader_provider.dart';
import '../providers/settings_provider.dart';
import 'result_screen.dart';
import 'widgets/glass_button.dart';
import 'widgets/glass_container.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<HistoryProvider>(context, listen: false).fetchHistory();
    });
  }

  String _formatDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return DateFormat('dd MMM yyyy, HH:mm').format(dt);
    } catch (_) {
      return isoString;
    }
  }

  void _openDetail(HistoryModel item) {
    final reader = Provider.of<ReaderProvider>(context, listen: false);
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    reader.readExistingText(
      text: item.isiTeks,
      speechRate: settings.settings.kecepatanSuara,
      language: settings.settings.bahasaSuara,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ResultScreen(),
      ),
    );
  }

  Future<void> _confirmClearAll() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final isDark = settings.isDarkMode;
    final fontMultiplier = settings.settings.fontSizeMultiplier;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCardBg : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          'Hapus Semua Riwayat?',
          style: TextStyle(
            fontSize: 20 * fontMultiplier,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.lightTextPrimary,
          ),
        ),
        content: Text(
          'Seluruh daftar teks yang pernah dibaca akan dihapus secara permanen.',
          style: TextStyle(
            fontSize: 16 * fontMultiplier,
            color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Batal',
              style: TextStyle(
                fontSize: 16 * fontMultiplier,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Hapus',
              style: TextStyle(
                fontSize: 16 * fontMultiplier,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      Provider.of<HistoryProvider>(context, listen: false).clearAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyProvider = Provider.of<HistoryProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isDark = settingsProvider.isDarkMode;
    final fontMultiplier = settingsProvider.settings.fontSizeMultiplier;

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
                        'Riwayat Bacaan',
                        style: TextStyle(
                          fontSize: 18 * fontMultiplier,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                  ),
                  if (historyProvider.historyList.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    GlassButton(
                      minSize: 52,
                      borderRadius: 18,
                      onTap: _confirmClearAll,
                      icon: const Icon(
                        Icons.delete_sweep_rounded,
                        color: AppColors.accentRed,
                        size: 26,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Daftar Riwayat
            Expanded(
              child: historyProvider.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.accentBlue),
                    )
                  : historyProvider.historyList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.history_edu_rounded,
                                size: 68,
                                color: isDark ? Colors.white30 : Colors.black26,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Belum Ada Riwayat',
                                style: TextStyle(
                                  fontSize: 20 * fontMultiplier,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white70 : AppColors.lightTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Teks yang Anda pindai akan tersimpan di sini.',
                                style: TextStyle(
                                  fontSize: 15 * fontMultiplier,
                                  color: isDark ? Colors.white38 : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: historyProvider.historyList.length,
                          itemBuilder: (context, index) {
                            final item = historyProvider.historyList[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: GlassContainer(
                                borderRadius: 22,
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.judul,
                                            style: TextStyle(
                                              fontSize: 17 * fontMultiplier,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white : AppColors.lightTextPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
                                          onPressed: () {
                                            if (item.id != null) {
                                              historyProvider.deleteHistory(item.id!);
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      item.isiTeks,
                                      style: TextStyle(
                                        fontSize: 15 * fontMultiplier,
                                        color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                                        height: 1.4,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _formatDate(item.tanggalPindai),
                                          style: TextStyle(
                                            fontSize: 12 * fontMultiplier,
                                            color: isDark ? Colors.white38 : Colors.black45,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        GlassButton(
                                          minSize: 42,
                                          borderRadius: 14,
                                          isPrimary: true,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          onTap: () => _openDetail(item),
                                          icon: const Icon(Icons.volume_up_rounded, size: 20, color: Colors.white),
                                          label: 'Dengar',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
