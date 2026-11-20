import 'dart:math';

import 'package:flutter/material.dart';

class FullImageResetButton extends StatelessWidget {
  final Rect imageCropRect;
  final Size imageSize;
  final bool isTransformIdentity;
  final Rect screenFrameRect;
  final Size viewportSize;
  final String label;
  final VoidCallback onReset;

  const FullImageResetButton({
    super.key,
    required this.imageCropRect,
    required this.imageSize,
    required this.isTransformIdentity,
    required this.screenFrameRect,
    required this.viewportSize,
    required this.label,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final bool isFullImage =
        (imageCropRect.width >= imageSize.width - 4.0) &&
        (imageCropRect.height >= imageSize.height - 4.0) &&
        isTransformIdentity;
    if (isFullImage) {
      return const SizedBox.shrink();
    }

    final bool hasSpaceBelow =
        (screenFrameRect.bottom + 60) < (viewportSize.height - 110);
    final bool hasSpaceAbove = screenFrameRect.top > 60;
    final double buttonTop = hasSpaceBelow
        ? screenFrameRect.bottom + 12
        : (hasSpaceAbove
              ? screenFrameRect.top - 54
              : max(16.0, viewportSize.height - 100));
    final double buttonLeft = (screenFrameRect.center.dx - 70).clamp(
      16.0,
      max(16.0, viewportSize.width - 156),
    );

    return Positioned(
      top: buttonTop,
      left: buttonLeft,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onReset,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white70, width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.fullscreen_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
