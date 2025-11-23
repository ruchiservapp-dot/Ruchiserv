import 'package:flutter/foundation.dart';

class AppLogger {
  static void log(String message) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('🧩 RuchiServ Log → $message');
    }
  }

  static void error(String message) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('❌ RuchiServ Error → $message');
    }
  }

  static void success(String message) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('✅ RuchiServ Success → $message');
    }
  }
}
