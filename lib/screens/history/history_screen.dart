import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_strings.dart';
import '../speech/speech_screen.dart';

class HistoryItemModel {
  final String title;
  final String date;
  final String fullText;

  const HistoryItemModel({
    required this.title,
    required this.date,
    required this.fullText,
  });
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final List<HistoryItemModel> _historyList = const [
    HistoryItemModel(
      title: 'yesterday...',
      date: '25/09/2026',
      fullText: 'yesterday\ntoday\ntomorrow',
    ),
    HistoryItemModel(
      title: 'Pharmacy medicine...',
      date: '24/09/2026',
      fullText:
          'Take 1 tablet twice daily after meals.\nStore in a cool and dry place away from direct sunlight.',
    ),
    HistoryItemModel(
      title: 'Coffee recipe notes...',
      date: '22/09/2026',
      fullText:
          '18g fine espresso grind, 36g extraction in 28 seconds. Temp: 93°C.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings.of(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.black : AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              // Header: Back Button + "History" Title
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
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
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    strings.history,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.black,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // History items list
              Expanded(
                child: ListView.separated(
                  itemCount: _historyList.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final item = _historyList[index];
                    return Material(
                      color: isDark
                          ? const Color(0xFF1E1E1E)
                          : const Color(0xFFF4F6F9),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  SpeechScreen(text: item.fullText),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF333333)
                                  : const Color(0xFFD9E0E8),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : AppColors.black,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.date,
                                      style: TextStyle(
                                        color: isDark
                                            ? const Color(0xFF999999)
                                            : const Color(0xFF718096),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: isDark
                                    ? const Color(0xFF777777)
                                    : const Color(0xFFA0AEC0),
                                size: 28,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
