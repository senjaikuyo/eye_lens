import 'package:flutter/material.dart';

class ScanBottomBar extends StatelessWidget {
  final double bottomPadding;
  final String galleryText;
  final VoidCallback onGalleryPressed;
  final VoidCallback onCapturePressed;
  final VoidCallback onCaptureLongPressed;

  const ScanBottomBar({
    super.key,
    required this.bottomPadding,
    required this.galleryText,
    required this.onGalleryPressed,
    required this.onCapturePressed,
    required this.onCaptureLongPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: bottomPadding + 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Gallery Button on the left
          Positioned(
            left: 40,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E384D).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: IconButton(
                    onPressed: onGalleryPressed,
                    icon: const Icon(
                      Icons.photo_library_outlined,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  galleryText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Shutter Camera Button (Center)
          GestureDetector(
            onTap: onCapturePressed,
            onLongPress: onCaptureLongPressed,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.camera_alt_outlined,
                  color: Colors.black,
                  size: 36,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
