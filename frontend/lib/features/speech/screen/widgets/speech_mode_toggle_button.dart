import 'package:flutter/material.dart';

class SpeechModeToggleButton extends StatelessWidget {
  final bool isTextView;
  final VoidCallback onToggle;

  const SpeechModeToggleButton({
    super.key,
    required this.isTextView,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onToggle,
          child: Center(
            child: isTextView
                ? const Icon(
                    Icons.image_outlined,
                    color: Colors.black,
                    size: 28,
                  )
                : const Text(
                    'T',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
