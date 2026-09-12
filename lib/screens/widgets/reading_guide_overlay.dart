import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class ReadingGuideOverlay extends StatelessWidget {
  final bool isVisible;
  final double windowHeight;

  const ReadingGuideOverlay({
    super.key,
    required this.isVisible,
    this.windowHeight = 90.0,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalHeight = constraints.maxHeight;
        final topMaskHeight = (totalHeight - windowHeight) / 2;

        return Stack(
          children: [
            // Mask Atas (Dimmed 60%)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: topMaskHeight,
              child: Container(
                color: Colors.black.withOpacity(0.55),
              ),
            ),

            // Mask Bawah (Dimmed 60%)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: topMaskHeight,
              child: Container(
                color: Colors.black.withOpacity(0.55),
              ),
            ),

            // Jendela Fokus Tengah (Bening dengan garis pembatas kontras tinggi)
            Positioned(
              top: topMaskHeight,
              left: 12,
              right: 12,
              height: windowHeight,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border.symmetric(
                    horizontal: BorderSide(
                      color: AppColors.accentYellow,
                      width: 3.0,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 6,
                      height: 24,
                      color: AppColors.accentYellow,
                    ),
                    Container(
                      width: 6,
                      height: 24,
                      color: AppColors.accentYellow,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
