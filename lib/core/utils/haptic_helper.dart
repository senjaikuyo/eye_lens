import 'package:flutter/services.dart';

class HapticHelper {
  static void lightImpact({bool enabled = true}) {
    if (enabled) {
      HapticFeedback.lightImpact();
    }
  }

  static void mediumImpact({bool enabled = true}) {
    if (enabled) {
      HapticFeedback.mediumImpact();
    }
  }

  static void heavyImpact({bool enabled = true}) {
    if (enabled) {
      HapticFeedback.heavyImpact();
    }
  }

  static void selectionClick({bool enabled = true}) {
    if (enabled) {
      HapticFeedback.selectionClick();
    }
  }
}
