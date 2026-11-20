import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:eye_lens/app/theme/app_colors.dart';
import 'package:eye_lens/core/constants/app_strings.dart';
import 'package:eye_lens/core/models/history_model.dart';
import 'package:eye_lens/core/services/display_preferences_provider.dart';
import 'package:eye_lens/features/history/logic/history_provider.dart';
import 'package:eye_lens/features/history/screen/widgets/history_delete_dialog.dart';
import 'package:eye_lens/features/history/screen/widgets/history_empty_state.dart';
import 'package:eye_lens/features/history/screen/widgets/history_tile.dart';
import 'package:eye_lens/features/speech/screen/speech_screen.dart';

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
      if (mounted) {
        final historyProvider = context.read<HistoryProvider>();
        historyProvider.loadRiwayat();
        _triggerSync();
      }
    });
  }

  Future<void> _triggerSync() async {
    if (!mounted) return;
    await context.read<HistoryProvider>().syncToServer();
  }

  Future<void> _handleDeleteSingle(
    HistoryModel item,
    AppStrings strings,
    bool isDark,
  ) async {
    final confirmed = await HistoryDeleteDialog.showDeleteSingle(
      context,
      strings: strings,
      isDark: isDark,
    );
    if (confirmed == true && mounted && item.idRiwayat != null) {
      await context.read<HistoryProvider>().deleteRiwayat(item.idRiwayat!);
    }
  }

  Future<void> _handleClearAll(AppStrings strings, bool isDark) async {
    final confirmed = await HistoryDeleteDialog.showClearAll(
      context,
      strings: strings,
      isDark: isDark,
    );
    if (confirmed == true && mounted) {
      await context.read<HistoryProvider>().clearAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<DisplayPreferencesProvider>();
    final historyProvider = context.watch<HistoryProvider>();
    final isDark = themeProvider.isDark(context);
    final isHighContrast = themeProvider.isHighContrast;
    final strings = AppStrings.of(context);
    final historyList = historyProvider.items;

    final dividerColor = isHighContrast
        ? (isDark ? Colors.white : Colors.black)
        : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEDEDED));
    final dividerThickness = isHighContrast ? 1.5 : 0.8;

    return Scaffold(
      backgroundColor: isDark ? AppColors.black : AppColors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),

            // Header: Back Button + "History" Title + Sync Action + Clear All Action
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2A2A2A)
                          : const Color(0xFFD9D9D9),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: isDark ? Colors.white : Colors.black,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      strings.history,
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.black,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),

                  // Tombol Indikator Sinkronisasi
                  if (historyProvider.isSyncing)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    )
                  else
                    IconButton(
                      icon: Icon(
                        Icons.sync_rounded,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      onPressed: _triggerSync,
                    ),

                  if (historyList.isNotEmpty)
                    TextButton(
                      onPressed: () => _handleClearAll(strings, isDark),
                      child: Text(
                        strings.clearAll,
                        style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            Divider(
              color: dividerColor,
              thickness: dividerThickness,
              height: 1,
            ),

            // History Flat List or Empty State dengan Pull-to-Refresh
            Expanded(
              child: historyProvider.isLoading && historyList.isEmpty
                  ? Center(
                      child: CircularProgressIndicator(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    )
                  : historyList.isEmpty
                  ? HistoryEmptyState(strings: strings, isDark: isDark)
                  : RefreshIndicator(
                      onRefresh: _triggerSync,
                      color: isDark ? Colors.black : Colors.white,
                      backgroundColor: isDark ? Colors.white : Colors.black,
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: historyList.length,
                        separatorBuilder: (context, index) => Divider(
                          color: dividerColor,
                          thickness: dividerThickness,
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          final item = historyList[index];
                          final isSynced = item.statusSinkron == 1;

                          return Stack(
                            children: [
                              HistoryTile(
                                item: item,
                                isDark: isDark,
                                isHighContrast: isHighContrast,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => SpeechScreen(
                                        text: item.isiTeks,
                                        hasImage: false,
                                      ),
                                    ),
                                  );
                                },
                                onDelete: () =>
                                    _handleDeleteSingle(item, strings, isDark),
                              ),
                              // Indikator Status Sinkronisasi di pojok kanan bawah item
                              Positioned(
                                right: 16,
                                bottom: 12,
                                child: Icon(
                                  isSynced
                                      ? Icons.cloud_done_rounded
                                      : Icons.cloud_upload_rounded,
                                  size: 16,
                                  color: isSynced
                                      ? const Color(0xFF10B981) // Hijau
                                      : const Color(0xFFF59E0B), // Oranye
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
