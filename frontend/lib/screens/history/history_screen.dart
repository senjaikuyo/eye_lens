import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_strings.dart';
import '../../models/riwayat_model.dart';
import '../../providers/history_provider.dart';
import '../../providers/theme_provider.dart';
import '../speech/speech_screen.dart';
import 'widgets/history_delete_dialog.dart';
import 'widgets/history_empty_state.dart';
import 'widgets/history_tile.dart';

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
        context.read<HistoryProvider>().loadRiwayat();
      }
    });
  }

  Future<void> _handleDeleteSingle(
    RiwayatModel item,
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
    final themeProvider = context.watch<ThemeProvider>();
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

            // Header: Back Button + "History" Title + Clear All Action
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

            // History Flat List or Empty State
            Expanded(
              child: historyProvider.isLoading && historyList.isEmpty
                  ? Center(
                      child: CircularProgressIndicator(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    )
                  : historyList.isEmpty
                  ? HistoryEmptyState(strings: strings, isDark: isDark)
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: historyList.length,
                      separatorBuilder: (context, index) => Divider(
                        color: dividerColor,
                        thickness: dividerThickness,
                        height: 1,
                      ),
                      itemBuilder: (context, index) {
                        final item = historyList[index];
                        return HistoryTile(
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
