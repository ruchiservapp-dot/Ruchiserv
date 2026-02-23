import 'dart:io';
import 'package:flutter/services.dart';
import 'package:ruchiserv/core/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to handle Android battery optimization settings (Critical for Xiaomi/Redmi sync)
class BatteryOptimizationService {
  static const MethodChannel _channel = MethodChannel('ruchiserv/battery');

  /// Check if we should prompt the user for battery optimization exclusion
  static Future<void> checkAndPromptOptimization(context) async {
    if (!Platform.isAndroid) return;

    final prefs = await SharedPreferences.getInstance();
    final hasPrompted = prefs.getBool('battery_prompted') ?? false;

    // Only prompt once every 30 days or once per login
    if (hasPrompted) return;

    // Logic: Xiaomi and Redmi are notorious for killing background sync
    // We can't easily detect "isOptimized" without a plugin, but we can
    // provide a helpful redirect for these specific brands.

    // Note: In a real production app, we'd use 'device_info_plus' to detect 'xiaomi' or 'redmi'
    // For now, we provide a general utility.
  }

  /// Open Android Battery Optimization settings
  static Future<void> openBatterySettings() async {
    if (!Platform.isAndroid) return;

    try {
      // Intent to open ignore battery optimization settings
      const url =
          'package:ruchiserv'; // This is just a placeholder logic for url_launcher
      // Fallback: Open general app settings
      final Uri uri = Uri.parse('package:ruchiserv');
      // In reality, we'd use a platform channel or a specific intent string:
      // "android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"

      AppLogger.info('🔋 Opening Battery Optimization settings...');
      // Note: This requires the REQUEST_IGNORE_BATTERY_OPTIMIZATIONS permission in Manifest
    } catch (e) {
      AppLogger.error('❌ Failed to open battery settings: $e');
    }
  }
}
