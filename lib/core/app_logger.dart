import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Centralized logger for RuchiServ.
/// - In DEBUG mode: Prints to console with emojis.
/// - In RELEASE mode: Sends non-fatal errors to Firebase Crashlytics.
class AppLogger {
  /// Initialize Crashlytics (only needed if special setup required)
  static Future<void> initialize() async {
    if (!kDebugMode && !kIsWeb) {
      // Force crashlytics collection in release builds
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    }
  }

  /// Set user context for logs (Firm ID, User ID)
  static Future<void> setUserContext(String userId, {String? firmId}) async {
    if (!kDebugMode && !kIsWeb) {
      await FirebaseCrashlytics.instance.setUserIdentifier(userId);
      if (firmId != null) {
        await FirebaseCrashlytics.instance.setCustomKey('firm_id', firmId);
      }
    }
  }

  static void debug(String message) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('🧩 [DEBUG] $message');
    }
  }

  static void info(String message) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('ℹ️ [INFO] $message');
    } else if (!kIsWeb) {
      // In prod, log info messages to Crashlytics breadcrumbs
      FirebaseCrashlytics.instance.log(message);
    }
  }

  static void warning(String message) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('⚠️ [WARN] $message');
    } else if (!kIsWeb) {
      FirebaseCrashlytics.instance.log('WARN: $message');
    }
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('❌ [ERROR] $message');
      if (error != null) print('Error: $error');
      if (stackTrace != null) print(stackTrace);
    } else if (!kIsWeb) {
      // In prod, record non-fatal error to Crashlytics
      FirebaseCrashlytics.instance.recordError(
        error ?? Exception(message),
        stackTrace,
        reason: message,
        printDetails: false, // Avoid printing to console in release
      );
    }
  }

  static void success(String message) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('✅ [SUCCESS] $message');
    }
  }
}
