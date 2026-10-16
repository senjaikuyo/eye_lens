import 'package:flutter/material.dart';
import '../../../core/app_colors.dart';

class AudioPlayerBar extends StatelessWidget {
  final bool isTextView;
  final bool isDark;
  final bool cursorColorEnabled;
  final Color highlightColor;
  final double progress;
  final ValueChanged<double> onProgressChanged;
  final String selectedLanguage;
  final VoidCallback onLanguageTap;
  final VoidCallback onRewind;
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onForward;
  final double speed;
  final VoidCallback onSpeedTap;
  final double bottomPadding;

  const AudioPlayerBar({
    super.key,
    required this.isTextView,
    required this.isDark,
    required this.cursorColorEnabled,
    required this.highlightColor,
    required this.progress,
    required this.onProgressChanged,
    required this.selectedLanguage,
    required this.onLanguageTap,
    required this.onRewind,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onForward,
    required this.speed,
    required this.onSpeedTap,
    required this.bottomPadding,
  });

  @override
  Widget build(BuildContext context) {
    final isLightContainer = isTextView && !isDark;
    final sliderActiveColor = cursorColorEnabled
        ? highlightColor
        : (isLightContainer ? AppColors.black : Colors.white);
    final sliderInactiveColor = isLightContainer
        ? const Color(0xFFD0D7DE)
        : Colors.white.withValues(alpha: 0.35);

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: bottomPadding + 18,
      ),
      decoration: BoxDecoration(
        color: isTextView
            ? (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF4F4F6))
            : Colors.black.withValues(alpha: 0.35),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress Slider
          SliderTheme(
            data: SliderThemeData(
              thumbColor: sliderActiveColor,
              activeTrackColor: sliderActiveColor,
              inactiveTrackColor: sliderInactiveColor,
              trackHeight: 4.0,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 7,
              ),
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(
              value: progress,
              onChanged: onProgressChanged,
            ),
          ),
          const SizedBox(height: 12),

          // Controls Row: Flag | 10s Rewind | Play/Pause | 10s Forward | Speed
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Flag Button
              GestureDetector(
                onTap: onLanguageTap,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: ClipOval(
                      child: Image.asset(
                        selectedLanguage == 'English'
                            ? 'assets/images/flag_usa.png'
                            : 'assets/images/flag_indonesia.png',
                        width: 34,
                        height: 34,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),

              // 10s Rewind Button
              GestureDetector(
                onTap: onRewind,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.replay_10_rounded,
                      color: Colors.black,
                      size: 28,
                    ),
                  ),
                ),
              ),

              // Play / Pause Button
              GestureDetector(
                onTap: onPlayPause,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.black,
                      size: 38,
                    ),
                  ),
                ),
              ),

              // 10s Fast Forward Button
              GestureDetector(
                onTap: onForward,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.forward_10_rounded,
                      color: Colors.black,
                      size: 28,
                    ),
                  ),
                ),
              ),

              // Speed Toggle Button
              GestureDetector(
                onTap: onSpeedTap,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${speed == 1.0 ? '1' : speed.toString()}x',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
