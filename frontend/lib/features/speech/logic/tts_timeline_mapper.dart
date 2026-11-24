import 'dart:math';

class TtsWordTiming {
  final String word;
  final int charStart;
  final int charEnd;
  final Duration startTime;
  final Duration endTime;

  const TtsWordTiming({
    required this.word,
    required this.charStart,
    required this.charEnd,
    required this.startTime,
    required this.endTime,
  });
}

class TtsTimelineMapper {
  final String text;
  final double speedMultiplier;
  final List<TtsWordTiming> _timings;
  final Duration totalDuration;

  static final RegExp _wordPattern = RegExp(r'\S+');
  static const double _baseCharsPerSecond = 14.0;

  TtsTimelineMapper._(
    this._timings, {
    required this.text,
    required this.speedMultiplier,
    required this.totalDuration,
  });

  factory TtsTimelineMapper({
    required String text,
    required double speedMultiplier,
  }) {
    final safeSpeed = speedMultiplier.clamp(0.5, 3.0);
    final matches = _wordPattern.allMatches(text);
    final timings = <TtsWordTiming>[];
    int elapsedMs = 0;

    for (final match in matches) {
      final word = match.group(0)!;
      final start = match.start;
      final end = match.end;

      // Durasi dasar kata proporsional terhadap panjang karakter
      final effectiveChars = max(2, word.length);
      int wordMs = ((effectiveChars / (_baseCharsPerSecond * safeSpeed)) * 1000)
          .round();

      // Tambahan jeda alami tanda baca
      final trimmed = word.trimRight();
      if (trimmed.endsWith('.') ||
          trimmed.endsWith('!') ||
          trimmed.endsWith('?')) {
        wordMs += (380 / safeSpeed).round();
      } else if (trimmed.endsWith(',') ||
          trimmed.endsWith(';') ||
          trimmed.endsWith(':')) {
        wordMs += (180 / safeSpeed).round();
      }

      // Tambahan jeda jika diikuti baris baru
      if (end < text.length && text[end] == '\n') {
        wordMs += (320 / safeSpeed).round();
      }

      final startTime = Duration(milliseconds: elapsedMs);
      elapsedMs += wordMs;
      final endTime = Duration(milliseconds: elapsedMs);

      timings.add(
        TtsWordTiming(
          word: word,
          charStart: start,
          charEnd: end,
          startTime: startTime,
          endTime: endTime,
        ),
      );
    }

    return TtsTimelineMapper._(
      timings,
      text: text,
      speedMultiplier: safeSpeed,
      totalDuration: Duration(milliseconds: elapsedMs),
    );
  }

  bool get isEmpty => _timings.isEmpty;

  Duration durationForCharIndex(int charIndex) {
    if (_timings.isEmpty || text.isEmpty) return Duration.zero;
    if (charIndex <= 0) return Duration.zero;
    if (charIndex >= text.length) return totalDuration;

    // Binary search untuk menemukan kata yang memuat atau terdekat dengan charIndex
    int low = 0;
    int high = _timings.length - 1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final item = _timings[mid];
      if (charIndex < item.charStart) {
        high = mid - 1;
      } else if (charIndex > item.charEnd) {
        low = mid + 1;
      } else {
        return item.startTime;
      }
    }

    if (low >= _timings.length) return totalDuration;
    return _timings[low].startTime;
  }

  int charIndexForDuration(Duration target) {
    if (_timings.isEmpty) return 0;
    final targetMs = target.inMilliseconds.clamp(
      0,
      totalDuration.inMilliseconds,
    );
    if (targetMs <= 0) return _timings.first.charStart;
    if (targetMs >= totalDuration.inMilliseconds) {
      return _timings.last.charStart;
    }

    int low = 0;
    int high = _timings.length - 1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final item = _timings[mid];
      if (targetMs < item.startTime.inMilliseconds) {
        high = mid - 1;
      } else if (targetMs > item.endTime.inMilliseconds) {
        low = mid + 1;
      } else {
        return item.charStart;
      }
    }

    final idx = low.clamp(0, _timings.length - 1);
    return _timings[idx].charStart;
  }

  double progressForDuration(Duration position) {
    final totalMs = totalDuration.inMilliseconds;
    if (totalMs <= 0) return 0.0;
    return (position.inMilliseconds / totalMs).clamp(0.0, 1.0);
  }

  Duration durationForProgress(double progress) {
    final totalMs = totalDuration.inMilliseconds;
    if (totalMs <= 0) return Duration.zero;
    return Duration(milliseconds: (progress.clamp(0.0, 1.0) * totalMs).round());
  }

  static String formatDuration(Duration d) {
    final totalSeconds = max(0, d.inSeconds);
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$mm:$ss';
    }
    return '$mm:$ss';
  }
}
