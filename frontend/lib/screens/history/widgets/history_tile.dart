import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../history_screen.dart';

class HistoryTile extends StatelessWidget {
  final HistoryItemModel item;
  final bool isDark;
  final bool isHighContrast;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const HistoryTile({
    super.key,
    required this.item,
    required this.isDark,
    required this.isHighContrast,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        onDelete();
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: const Color(0xFFEF4444),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.black,
                          fontSize: 17,
                          fontWeight: isHighContrast
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.date,
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFF999999)
                              : const Color(0xFF718096),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFEF4444),
                    size: 22,
                  ),
                  onPressed: onDelete,
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark
                      ? const Color(0xFF777777)
                      : const Color(0xFFA0AEC0),
                  size: 26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
