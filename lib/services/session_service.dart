// lib/services/session_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const _kBiometricEnabled = 'biometric_enabled';
  static const _kLastUsername = 'last_username';

  static Future<void> setBiometricEnabled(bool enabled) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kBiometricEnabled, enabled);
  }

  static Future<bool> isBiometricEnabled() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kBiometricEnabled) ?? false;
  }

  static Future<void> saveLastUsername(String username) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kLastUsername, username);
  }

  static Future<String?> lastUsername() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kLastUsername);
  }
}
