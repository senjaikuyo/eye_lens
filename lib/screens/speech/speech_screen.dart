import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_strings.dart';
import '../../providers/theme_provider.dart';
import '../settings/settings_screen.dart';

class SpeechScreen extends StatefulWidget {
  final String text;

  const SpeechScreen({
    super.key,
    this.text = 'yesterday\ntoday\ntomorrow',
  });

  @override
  State<SpeechScreen> createState() => _SpeechScreenState();
}

class _SpeechScreenState extends State<SpeechScreen> {
  bool _isTextView = false;
  double _fontSize = 32.0;
  bool _isPlaying = false;
  double _progress = 0.25;
  String _selectedLanguage = 'English'; // 'Indonesia' or 'English'
  double _speed = 1.0;
  Timer? _playbackTimer;

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
    });

    if (_isPlaying) {
      _playbackTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
        if (!mounted) return;
        setState(() {
          _progress += 0.01 * _speed;
          if (_progress >= 1.0) {
            _progress = 0.0;
            _isPlaying = false;
            timer.cancel();
          }
        });
      });
    } else {
      _playbackTimer?.cancel();
    }
  }

  void _onSpeedTap() {
    setState(() {
      if (_speed == 1.0) {
        _speed = 1.25;
      } else if (_speed == 1.25) {
        _speed = 1.5;
      } else if (_speed == 1.5) {
        _speed = 2.0;
      } else {
        _speed = 1.0;
      }
    });
  }

  void _showLanguageBottomSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title & Close Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        strings.speechLanguage,
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.black,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close,
                          color: isDark ? Colors.white : AppColors.black,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Option 1: Indonesia (with circular flag)
                  _buildLanguageOption(
                    title: 'Indonesia',
                    flagAsset: 'assets/images/flag_indonesia.png',
                    isSelected: _selectedLanguage == 'Indonesia',
                    isDark: isDark,
                    onTap: () {
                      setState(() {
                        _selectedLanguage = 'Indonesia';
                      });
                      Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(height: 16),

                  // Option 2: English (with circular flag)
                  _buildLanguageOption(
                    title: 'English',
                    flagAsset: 'assets/images/flag_usa.png',
                    isSelected: _selectedLanguage == 'English',
                    isDark: isDark,
                    onTap: () {
                      setState(() {
                        _selectedLanguage = 'English';
                      });
                      Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLanguageOption({
    required String title,
    required String flagAsset,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF2A3444) : const Color(0xFFEDF4FC))
                : (isDark ? const Color(0xFF252525) : const Color(0xFFF4F6F9)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? (isDark ? const Color(0xFF3B82F6) : AppColors.black)
                  : (isDark ? const Color(0xFF3A3A3A) : const Color(0xFFD0D7DE)),
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Row(
            children: [
              // Circular Flag
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Image.asset(
                    flagAsset,
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Title
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.black,
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),

              // Selection Radio Circle
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? (isDark ? const Color(0xFF3B82F6) : AppColors.black)
                        : (isDark ? const Color(0xFF666666) : const Color(0xFF999999)),
                    width: 2.0,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? const Color(0xFF3B82F6) : AppColors.black,
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightedText({
    required String text,
    required double fontSize,
    required bool cursorColorEnabled,
    required Color highlightColor,
    required bool isDark,
  }) {
    final lines = text.split('\n');
    if (!cursorColorEnabled) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines.map((line) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              line,
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.black,
                fontSize: fontSize,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }).toList(),
      );
    }

    // Active line tracked by playback progress (0.0 to 1.0)
    final activeIndex =
        (_progress * lines.length).clamp(0, lines.length - 1).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(lines.length, (index) {
        final line = lines[index];
        final isActive = index == activeIndex;

        return GestureDetector(
          onTap: () {
            setState(() {
              _progress = index / lines.length;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: EdgeInsets.symmetric(
              horizontal: isActive ? 12 : 0,
              vertical: isActive ? 6 : 4,
            ),
            decoration: BoxDecoration(
              color: isActive ? highlightColor : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: highlightColor.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              line,
              style: TextStyle(
                color: isActive
                    ? Colors.white
                    : (isDark ? Colors.white : AppColors.black),
                fontSize: fontSize,
                height: 1.35,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark(context);
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _isTextView
          ? (isDark ? AppColors.black : Colors.white)
          : AppColors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // MAIN BODY
          if (!_isTextView) ...[
            // Photo View Background
            Image.asset(
              'assets/images/UI Validasi.png',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),

            // Subtle gradient
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.4),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.5),
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),

            // Captured frame
            Center(
              child: Container(
                width: size.width * 0.82,
                height: size.width * 0.72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white, width: 4.0),
                ),
              ),
            ),
          ] else ...[
            // Pure Text View with Dark Mode support
            Positioned.fill(
              child: Container(
                color: isDark ? AppColors.black : Colors.white,
                padding: EdgeInsets.only(
                  top: topPadding + 80,
                  left: 28,
                  right: 28,
                  bottom: 160,
                ),
                child: SingleChildScrollView(
                  child: _buildHighlightedText(
                    text: widget.text,
                    fontSize: _fontSize,
                    cursorColorEnabled: themeProvider.cursorColor,
                    highlightColor: themeProvider.highlightColor,
                    isDark: isDark,
                  ),
                ),
              ),
            ),
          ],

          // TOP ACTION BAR
          Positioned(
            top: topPadding + 10,
            left: 16,
            right: 16,
            child: Row(
              children: [
                // Back Button (Solid rounded circle with clear visibility)
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _isTextView
                        ? (isDark
                            ? const Color(0xFF2A2A2A)
                            : const Color(0xFFEAECEF))
                        : const Color(0xFF1E293B).withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isTextView
                          ? (isDark
                              ? const Color(0xFF444444)
                              : const Color(0xFFD0D7DE))
                          : Colors.white.withValues(alpha: 0.3),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => Navigator.of(context).pop(),
                      child: Center(
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: _isTextView
                              ? (isDark ? Colors.white : Colors.black)
                              : Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // Mode Specific Top Actions
                if (!_isTextView) ...[
                  // Switch to Text View Button ('T') with visible button container
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () {
                          setState(() {
                            _isTextView = true;
                          });
                        },
                        child: const Center(
                          child: Text(
                            'T',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Settings Button with visible button container
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const SettingsScreen(),
                            ),
                          );
                        },
                        child: const Center(
                          child: Icon(
                            Icons.settings_outlined,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // Font Size Controls in Text View (-, +, Badge, and Photo icon)
                  IconButton(
                    onPressed: () {
                      if (_fontSize > 12) {
                        setState(() {
                          _fontSize -= 2;
                        });
                      }
                    },
                    icon: Icon(
                      Icons.remove,
                      color: isDark ? Colors.white : Colors.black,
                      size: 26,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      if (_fontSize < 48) {
                        setState(() {
                          _fontSize += 2;
                        });
                      }
                    },
                    icon: Icon(
                      Icons.add,
                      color: isDark ? Colors.white : Colors.black,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 4),

                  // Font Size Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark ? Colors.white : Colors.black,
                        width: 1.2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _fontSize.toInt().toString(),
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Return to Photo View Button with visible button container
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2A2A2A)
                          : const Color(0xFFEAECEF),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF444444)
                            : const Color(0xFFD0D7DE),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          setState(() {
                            _isTextView = false;
                          });
                        },
                        child: Center(
                          child: Icon(
                            Icons.image_outlined,
                            color: isDark ? Colors.white : Colors.black,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Settings Button in Text View
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2A2A2A)
                          : const Color(0xFFEAECEF),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF444444)
                            : const Color(0xFFD0D7DE),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const SettingsScreen(),
                            ),
                          );
                        },
                        child: Center(
                          child: Icon(
                            Icons.settings_outlined,
                            color: isDark ? Colors.white : Colors.black,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // BOTTOM AUDIO PLAYER CONTROLS
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 14,
                bottom: bottomPadding + 18,
              ),
              decoration: BoxDecoration(
                color: _isTextView
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
                  Builder(
                    builder: (context) {
                      final isLightContainer = _isTextView && !isDark;
                      final sliderActiveColor = themeProvider.cursorColor
                          ? themeProvider.highlightColor
                          : (isLightContainer ? AppColors.black : Colors.white);
                      final sliderInactiveColor = isLightContainer
                          ? const Color(0xFFD0D7DE)
                          : Colors.white.withValues(alpha: 0.35);
                      final sliderThumbColor = sliderActiveColor;

                      return SliderTheme(
                        data: SliderThemeData(
                          thumbColor: sliderThumbColor,
                          activeTrackColor: sliderActiveColor,
                          inactiveTrackColor: sliderInactiveColor,
                          trackHeight: 4.0,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 7,
                          ),
                          overlayShape: SliderComponentShape.noOverlay,
                        ),
                        child: Slider(
                          value: _progress,
                          onChanged: (val) {
                            setState(() {
                              _progress = val;
                            });
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // Controls Row: Flag | Rewind | Play/Pause | Forward | Speed
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Flag Button (Circular, consistent 44x44, neat container)
                      GestureDetector(
                        onTap: _showLanguageBottomSheet,
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
                                _selectedLanguage == 'English'
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

                      // Rewind Button
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _progress = (_progress - 0.1).clamp(0.0, 1.0);
                          });
                        },
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
                              Icons.fast_rewind_rounded,
                              color: Colors.black,
                              size: 26,
                            ),
                          ),
                        ),
                      ),

                      // Play / Pause Button (Large Center)
                      GestureDetector(
                        onTap: _togglePlayPause,
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
                              _isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.black,
                              size: 38,
                            ),
                          ),
                        ),
                      ),

                      // Fast Forward Button
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _progress = (_progress + 0.1).clamp(0.0, 1.0);
                          });
                        },
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
                              Icons.fast_forward_rounded,
                              color: Colors.black,
                              size: 26,
                            ),
                          ),
                        ),
                      ),

                      // Speed Toggle Button ("1x", "1.5x", etc.)
                      GestureDetector(
                        onTap: _onSpeedTap,
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
                            '${_speed == 1.0 ? '1' : _speed.toString()}x',
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
            ),
          ),
        ],
      ),
    );
  }
}
