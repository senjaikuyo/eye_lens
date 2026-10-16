import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_strings.dart';

class FeedbackDialog extends StatefulWidget {
  final AppStrings strings;
  final bool isDark;

  const FeedbackDialog({
    super.key,
    required this.strings,
    required this.isDark,
  });

  static Future<void> show(
    BuildContext context, {
    required AppStrings strings,
    required bool isDark,
  }) {
    return showDialog(
      context: context,
      builder: (context) => FeedbackDialog(strings: strings, isDark: isDark),
    );
  }

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    final isDark = widget.isDark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        strings.feedbackTitle,
        style: TextStyle(
          color: isDark ? Colors.white : AppColors.black,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: TextField(
        controller: _textController,
        maxLines: 4,
        cursorColor: isDark ? Colors.white : Colors.black,
        style: TextStyle(
          color: isDark ? Colors.white : AppColors.black,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: strings.feedbackHint,
          hintStyle: TextStyle(
            color: isDark ? const Color(0xFF777777) : const Color(0xFFAAAAAA),
            fontSize: 13,
          ),
          filled: true,
          fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF2F4F7),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            strings.cancel,
            style: TextStyle(
              color: isDark ? const Color(0xFFAAAAAA) : const Color(0xFF777777),
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? Colors.white : AppColors.black,
            foregroundColor: isDark ? Colors.black : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(strings.feedbackSent),
                backgroundColor: AppColors.black,
                duration: const Duration(seconds: 2),
              ),
            );
          },
          child: Text(strings.send, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
