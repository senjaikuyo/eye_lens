import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_strings.dart';
import '../services/feedback_service.dart';

class FeedbackDialog extends StatefulWidget {
  final AppStrings strings;
  final bool isDark;
  final FeedbackService? service;

  const FeedbackDialog({
    super.key,
    required this.strings,
    required this.isDark,
    this.service,
  });

  static Future<void> show(
    BuildContext context, {
    required AppStrings strings,
    required bool isDark,
    FeedbackService? service,
  }) {
    return showDialog(
      context: context,
      builder: (context) =>
          FeedbackDialog(strings: strings, isDark: isDark, service: service),
    );
  }

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  late final TextEditingController _textController;
  late final FeedbackService _service;

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _service = widget.service ?? FeedbackService();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _errorMessage = widget.strings.feedbackEmpty;
      });
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await _service.submit(text);
      if (!mounted) return;
      // Sukses hanya setelah backend mengonfirmasi penyimpanan.
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            widget.strings.feedbackSent,
            style: const TextStyle(fontSize: 16),
          ),
          backgroundColor: AppColors.black,
          duration: const Duration(seconds: 2),
        ),
      );
    } on FeedbackException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = _messageFor(e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = widget.strings.feedbackFailed;
      });
    }
  }

  String _messageFor(FeedbackException exception) {
    switch (exception.failure) {
      case FeedbackFailure.empty:
        return widget.strings.feedbackEmpty;
      case FeedbackFailure.unauthorized:
        return widget.strings.feedbackSessionExpired;
      case FeedbackFailure.offline:
        return widget.strings.feedbackOffline;
      case FeedbackFailure.timeout:
        return widget.strings.feedbackTimeout;
      case FeedbackFailure.validation:
        return exception.serverMessage ?? widget.strings.feedbackFailed;
      case FeedbackFailure.server:
        return widget.strings.feedbackFailed;
    }
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
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _textController,
            maxLines: 4,
            enabled: !_isSubmitting,
            cursorColor: isDark ? Colors.white : Colors.black,
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.black,
              fontSize: 18,
            ),
            decoration: InputDecoration(
              hintText: strings.feedbackHint,
              hintStyle: TextStyle(
                color: isDark
                    ? const Color(0xFF777777)
                    : const Color(0xFFAAAAAA),
                fontSize: 18,
              ),
              filled: true,
              fillColor: isDark
                  ? const Color(0xFF2A2A2A)
                  : const Color(0xFFF2F4F7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: Color(0xFFD8224E),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(
            strings.cancel,
            style: TextStyle(
              color: isDark ? const Color(0xFFAAAAAA) : const Color(0xFF777777),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? Colors.white : AppColors.black,
            foregroundColor: isDark ? Colors.black : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            minimumSize: const Size(80, 48),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isDark ? Colors.black : Colors.white,
                  ),
                )
              : Text(
                  strings.send,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ],
    );
  }
}
