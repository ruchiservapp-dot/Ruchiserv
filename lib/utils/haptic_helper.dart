import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class HapticHelper {
  /// Light impact for subtle actions (e.g. toggle, small button tap)
  static Future<void> light() async {
    if (kIsWeb) return;
    await HapticFeedback.lightImpact();
  }

  /// Medium impact for successful primary actions (e.g. save, submit)
  static Future<void> success() async {
    if (kIsWeb) return;
    await HapticFeedback.mediumImpact();
  }

  /// Heavy impact or multiple vibrations for errors
  static Future<void> error() async {
    if (kIsWeb) return;
    await HapticFeedback.vibrate();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.vibrate();
  }

  /// Selection click for scrolling or picker changes
  static Future<void> selection() async {
    if (kIsWeb) return;
    await HapticFeedback.selectionClick();
  }
}
