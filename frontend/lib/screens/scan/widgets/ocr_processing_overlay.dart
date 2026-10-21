import 'package:flutter/material.dart';

import '../../../core/app_strings.dart';

class OcrProcessingOverlay extends StatelessWidget {
  final AppStrings strings;

  const OcrProcessingOverlay({super.key, required this.strings});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFFFACC15),
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              strings.isIndonesian
                  ? 'Mengekstrak teks...'
                  : 'Extracting text...',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
