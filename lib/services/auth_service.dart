// lib/services/auth_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../db/aws/aws_api.dart'; // you already have this
import '../db/database_helper.dart';

/// Central place for login/registration/password APIs + local expiry rules.
class AuthService {
  // ====== Remote (AWS) calls ======

  /// Online login against AWS. Returns true if server accepts the mobile+password.
  static Future<bool> loginOnline({
    required String firmId,
    required String mobile,
    required String password,
  }) async {
    try {
      // Adjust to your API signature. Example using a generic handler:
      final resp = await AwsApi.post(
        path: '/auth/login',
        body: {
          'firmId': firmId,
          'mobile': mobile,
          'password': password,
        },
      );
      // Expecting { status: 'success', user: {...} }
      if ((resp['status'] ?? '').toString().toLowerCase() == 'success') {
        // optionally persist a user profile returned by API
        final sp = await SharedPreferences.getInstance();
        await sp.setString('last_firm', firmId);
        await sp.setString('last_mobile', mobile);
        await _setLastOnlineLoginNow();
        // store subscription expiry if API sends it (yyyy-MM-dd)
        if (resp['user'] is Map &&
            (resp['user']['subscriptionExpiry'] ?? '').toString().isNotEmpty) {
          await sp.setString('subscription_expiry', resp['user']['subscriptionExpiry']);
        }
        return true;
      }
    } catch (e) {
      // fall through to false
    }
    return false;
  }

  /// Server-side precheck that mobile belongs to firm (for registration).
  static Future<bool> precheckRegistration({
    required String firmId,
    required String mobile,
  }) async {
    try {
      final resp = await AwsApi.post(
        path: '/auth/precheck',
        body: {'firmId': firmId, 'mobile': mobile},
      );
      return (resp['allowed'] == true) ||
          ((resp['status'] ?? '').toString().toLowerCase() == 'success');
    } catch (_) {
      return false;
    }
  }

  /// Set / reset password online.
  static Future<bool> setPassword({
    required String firmId,
    required String mobile,
    required String password,
  }) async {
    try {
      final resp = await AwsApi.post(
        path: '/auth/set_password',
        body: {'firmId': firmId, 'mobile': mobile, 'password': password},
      );
      return (resp['status'] ?? '').toString().toLowerCase() == 'success';
    } catch (_) {
      return false;
    }
  }

  static Future<bool> resetPassword({
    required String firmId,
    required String mobile,
    required String newPassword,
  }) async {
    try {
      final resp = await AwsApi.post(
        path: '/auth/reset_password',
        body: {'firmId': firmId, 'mobile': mobile, 'password': newPassword},
      );
      return (resp['status'] ?? '').toString().toLowerCase() == 'success';
    } catch (_) {
      return false;
    }
  }

  // ====== Local / offline rules ======

  /// Allow offline login if last successful login was <= 30 days ago and user exists locally.
  static Future<bool> canLoginOffline({
    required String firmId,
    required String mobile,
  }) async {
    final sp = await SharedPreferences.getInstance();
    final lastOnlineMs = sp.getInt('last_online_login_ms') ?? 0;
    final lastOnline = DateTime.fromMillisecondsSinceEpoch(lastOnlineMs, isUtc: true);
    final diffDays = DateTime.now().toUtc().difference(lastOnline).inDays;
    final within30 = diffDays <= 30;

    // additionally check local DB has that user for the firm
    final db = DatabaseHelper();
    final users = await db.getUsersByFirm(firmId);
    final hasUser = users.any((u) => (u['mobile']?.toString() ?? '') == mobile);

    return within30 && hasUser;
  }

  /// Variant used by biometric quick-login path.
  static Future<bool> canLoginOfflineWithBiometric({required String firmId}) async {
    final sp = await SharedPreferences.getInstance();
    final lastOnlineMs = sp.getInt('last_online_login_ms') ?? 0;
    final lastOnline = DateTime.fromMillisecondsSinceEpoch(lastOnlineMs, isUtc: true);
    final diffDays = DateTime.now().toUtc().difference(lastOnline).inDays;
    if (diffDays > 30) return false;

    // We only check firm existence locally for biometric shortcut
    final db = DatabaseHelper();
    final users = await db.getUsersByFirm(firmId);
    return users.isNotEmpty;
  }

  /// Stamp a successful login (online/offline) locally.
  static Future<void> stampLocalLogin({required bool online}) async {
    final sp = await SharedPreferences.getInstance();
    if (online) {
      await _setLastOnlineLoginNow();
    }
    await sp.setString('last_login_ts', DateTime.now().toIso8601String());
  }

  static Future<void> persistLastLogin({
    required String firmId,
    required String mobile,
    required bool online,
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('last_firm', firmId);
    await sp.setString('last_mobile', mobile);
    await stampLocalLogin(online: online);
  }

  /// Subscription helpers (warn at <=5 days, block if expired)
  static Future<bool> isExpired() async {
    final sp = await SharedPreferences.getInstance();
    final s = sp.getString('subscription_expiry');
    if (s == null || s.isEmpty) return false; // no info -> do not block
    final expiry = DateTime.tryParse(s);
    if (expiry == null) return false;
    return DateTime.now().isAfter(expiry);
  }

  static Future<bool> shouldWarnExpiry() async {
    final days = await daysToExpiry();
    return days != null && days >= 0 && days <= 5;
  }

  static Future<int?> daysToExpiry() async {
    final sp = await SharedPreferences.getInstance();
    final s = sp.getString('subscription_expiry');
    if (s == null || s.isEmpty) return null;
    final expiry = DateTime.tryParse(s);
    if (expiry == null) return null;
    return expiry.difference(DateTime.now()).inDays;
  }

  // ====== private ======
  static Future<void> _setLastOnlineLoginNow() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt('last_online_login_ms', DateTime.now().toUtc().millisecondsSinceEpoch);
  }
}
