// @locked
// lib/services/auth_service.dart
import 'package:shared_preferences/shared_preferences.dart';
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
        path: '/login',
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
        
        // COMPLIANCE: Save user_id for audit trail (Rule C.2)
        if (resp['user'] is Map && resp['user']['userId'] != null) {
          await sp.setString('user_id', resp['user']['userId'].toString());
        } else {
          // Fallback: Generate user_id from mobile if API doesn't provide it
          await sp.setString('user_id', 'U-$mobile');
        }
        
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
    // MOCK: API missing /auth/precheck
    // Simulate success if firmId is valid format
    await Future.delayed(const Duration(milliseconds: 500));
    return true;
    /*
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
    */
  }

  /// Set / reset password online.
  static Future<bool> setPassword({
    required String firmId,
    required String mobile,
    required String password,
  }) async {
    // MOCK: API missing /auth/set_password
    await Future.delayed(const Duration(milliseconds: 500));
    return true;
    /*
    try {
      final resp = await AwsApi.post(
        path: '/auth/set_password',
        body: {'firmId': firmId, 'mobile': mobile, 'password': password},
      );
      return (resp['status'] ?? '').toString().toLowerCase() == 'success';
    } catch (_) {
      return false;
    }
    */
  }

  static Future<bool> resetPassword({
    required String firmId,
    required String mobile,
    required String newPassword,
  }) async {
    // MOCK: API missing /auth/reset_password
    await Future.delayed(const Duration(milliseconds: 500));
    return true;
    /*
    try {
      final resp = await AwsApi.post(
        path: '/auth/reset_password',
        body: {'firmId': firmId, 'mobile': mobile, 'password': newPassword},
      );
      return (resp['status'] ?? '').toString().toLowerCase() == 'success';
    } catch (_) {
      return false;
    }
    */
  }

  // ====== Local / offline rules ======

  /// Allow offline login if last successful login was <= 30 days ago and user exists locally.
  static Future<bool> canLoginOffline({
    required String firmId,
    required String mobile,
  }) async {
    print('AuthService: Checking offline login for $firmId / $mobile');
    final sp = await SharedPreferences.getInstance();
    final lastOnlineMs = sp.getInt('last_online_login_ms') ?? 0;
    
    // Allow first login ever (fresh install) OR within 30 days of last online login
    bool within30 = true;
    if (lastOnlineMs > 0) {
      final lastOnline = DateTime.fromMillisecondsSinceEpoch(lastOnlineMs, isUtc: true);
      final diffDays = DateTime.now().toUtc().difference(lastOnline).inDays;
      within30 = diffDays <= 30;
      print('AuthService: Last online: $lastOnline ($diffDays days ago). Within 30? $within30');
    } else {
      print('AuthService: First login ever (no previous online login). Allowing.');
    }

    // additionally check local DB has that user for the firm
    final db = DatabaseHelper();
    final users = await db.getUsersByFirm(firmId);
    print('AuthService: Found ${users.length} users for firm $firmId');
    
    final hasUser = users.any((u) {
      final m = (u['mobile']?.toString() ?? '');
      print(' - Checking user mobile: $m');
      return m == mobile;
    });
    print('AuthService: User found? $hasUser');

    return within30 && hasUser;
  }

  /// Verify credentials against local database
  static Future<bool> loginOffline({
    required String firmId,
    required String mobile,
    required String password,
  }) async {
    print('AuthService.loginOffline: Checking credentials for $firmId / $mobile');
    final db = DatabaseHelper();
    final users = await db.getUsersByFirm(firmId);
    print('AuthService.loginOffline: Found ${users.length} users for firm $firmId');
    
    for (var u in users) {
      final m = u['mobile']?.toString() ?? '';
      final p = u['passwordHash']?.toString() ?? '';
      print(' - User: mobile=$m, passwordHash=$p (checking against: $password)');
      if (m == mobile && p == password) {
        print('✓ Password match!');
        
        // Check if mobile is still authorized
        final isAuthorized = await db.isMobileAuthorized(firmId, mobile);
        if (!isAuthorized) {
          print('✗ Mobile not authorized/deactivated');
          throw Exception('Access revoked. Contact your firm admin.');
        }
        
        
        // COMPLIANCE: Save user_id for audit trail (Rule C.2)
        final sp = await SharedPreferences.getInstance();
        final userId = u['userId']?.toString() ?? 'U-$mobile';
        await sp.setString('user_id', userId);
        
        return true;
      }
    }
    print('✗ No matching user/password found');
    return false;
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

  /// Helper to save user locally after registration (so they can login immediately)
  static Future<void> registerLocalUser({
    required String firmId,
    required String mobile,
    required String password,
    required String name,
  }) async {
    print('AuthService.registerLocalUser: Registering $firmId / $mobile with password: $password');
    final db = DatabaseHelper();
    // Check if exists
    final users = await db.getUsersByFirm(firmId);
    final existing = users.any((u) => (u['mobile']?.toString() ?? '') == mobile);
    
    if (!existing) {
      print('AuthService.registerLocalUser: Inserting new user...');
      final userId = 'U-$mobile'; // Generate a userId
      await db.insertUser({
        'firmId': firmId,
        'userId': userId,
        'username': name,
        'mobile': mobile,
        'role': 'Admin', // Default to Admin for first user
        'passwordHash': password, // Should be hashed in production
        'permissions': 'ALL',
      });
      
      // COMPLIANCE: Save user_id for audit trail (Rule C.2)
      final sp = await SharedPreferences.getInstance();
      await sp.setString('user_id', userId);
      
      print('✓ User registered successfully');
    } else {
      print('⚠ User already exists, skipping insert');
    }
  }

  /// COMPLIANCE: Get current user_id for audit trail (Rule C.2)
  /// Throws exception if user not logged in
  static Future<String> getUserId() async {
    final sp = await SharedPreferences.getInstance();
    final userId = sp.getString('user_id');
    if (userId == null || userId.isEmpty) {
      throw Exception('User not logged in - user_id not found in SharedPreferences');
    }
    return userId;
  }

  // ====== Validation Logic ======

  /// Validates firm and mobile against DB/AWS (Rule: Forgot Password Check)
  static Future<Map<String, dynamic>> validateFirmAndMobile({
    required String firmId,
    required String mobile,
  }) async {
    final db = DatabaseHelper();
    bool firmFound = false;
    bool mobileFound = false;

    // 1. Check Firm ID (Local)
    final localFirms = await db.getFirmByFirmId(firmId);
    if (localFirms.isNotEmpty) {
      firmFound = true;
    } else {
      // 2. Check Firm ID (AWS)
      try {
        final resp = await AwsApi.callDbHandler(
          method: 'GET',
          table: 'firms',
          filters: {'firmId': firmId},
        );
        if ((resp['status'] == 'success') &&
            (resp['data'] is List) &&
            (resp['data'] as List).isNotEmpty) {
          firmFound = true;
        }
      } catch (e) {
        print('AWS Firm Check Failed: $e');
      }
    }

    if (!firmFound) {
      return {'valid': false, 'error': 'Wrong Firm ID'};
    }

    // 3. Check Mobile (AWS preferred as per request)
    try {
      // Check 'users' table
      final resp = await AwsApi.callDbHandler(
        method: 'GET',
        table: 'users',
        filters: {'firmId': firmId, 'mobile': mobile},
      );
      if ((resp['status'] == 'success') &&
          (resp['data'] is List) &&
          (resp['data'] as List).isNotEmpty) {
        mobileFound = true;
      } else {
        // Check 'authorized_mobiles' table
        final respAuth = await AwsApi.callDbHandler(
          method: 'GET',
          table: 'authorized_mobiles',
          filters: {'firmId': firmId, 'mobile': mobile},
        );
        if ((respAuth['status'] == 'success') &&
            (respAuth['data'] is List) &&
            (respAuth['data'] as List).isNotEmpty) {
          mobileFound = true;
        }
      }
    } catch (e) {
      print('AWS Mobile Check Failed: $e');
      // Fallback to local if AWS fails (offline support)
      final localUsers = await db.getUsersByFirm(firmId);
      if (localUsers.any((u) => u['mobile'] == mobile)) {
        mobileFound = true;
      } else {
        // Check local authorized_mobiles via verifyUserEligibility (which checks users table mostly)
        if (await db.verifyUserEligibility(firmId, mobile)) {
           mobileFound = true;
        }
      }
    }

    if (!mobileFound) {
      return {
        'valid': false,
        'error': 'Mobile no not registered with firm, kindly contact admin'
      };
    }

    return {'valid': true};
  }

  // ====== OTP Logic (Rule F.3) ======

  /// Generate and send OTP (Mock)
  /// Enforces rate limiting: Max 3 failed attempts in last hour
  static Future<Map<String, dynamic>> sendOtp(String mobile) async {
    final db = DatabaseHelper();
    final now = DateTime.now();
    
    // 1. Check rate limiting (F.3)
    // Count failed attempts in last hour
    final oneHourAgo = now.subtract(const Duration(hours: 1)).toIso8601String();
    final logs = await db.database.then((d) => d.query(
      'otp_logs',
      where: 'mobile = ? AND created_at > ? AND is_used = 0 AND attempts >= 3',
      whereArgs: [mobile, oneHourAgo],
    ));
    
    if (logs.isNotEmpty) {
      return {
        'success': false,
        'error': 'Too many failed attempts. Please try again in 1 hour.',
        'blocked': true,
      };
    }

    // 2. Generate OTP (Mock 6-digit)
    // In production, use a secure random generator
    final otp = '123456'; // Fixed for testing/mock
    
    // 3. Store in DB with 5 min expiry (F.3)
    final expiresAt = now.add(const Duration(minutes: 5)).toIso8601String();
    
    await db.database.then((d) => d.insert('otp_logs', {
      'mobile': mobile,
      'otp_code': otp,
      'created_at': now.toIso8601String(),
      'expires_at': expiresAt,
      'attempts': 0,
      'is_used': 0,
    }));
    
    // 4. Send SMS (Mock)
    print('🔐 [MOCK SMS] OTP for $mobile: $otp');
    
    return {
      'success': true,
      'message': 'OTP sent successfully',
      'expiresIn': 300, // seconds
    };
  }

  /// Verify OTP
  /// Enforces expiry and max attempts
  static Future<Map<String, dynamic>> verifyOtp({
    required String mobile,
    required String code,
  }) async {
    final db = DatabaseHelper();
    final now = DateTime.now();
    
    // 1. Find latest valid OTP
    final logs = await db.database.then((d) => d.query(
      'otp_logs',
      where: 'mobile = ? AND is_used = 0',
      whereArgs: [mobile],
      orderBy: 'created_at DESC',
      limit: 1,
    ));
    
    if (logs.isEmpty) {
      return {'success': false, 'error': 'No OTP found. Please request a new one.'};
    }
    
    final log = logs.first;
    final logId = log['id'] as int;
    final expiryStr = log['expires_at'] as String;
    final attempts = log['attempts'] as int;
    final correctOtp = log['otp_code'] as String;
    
    // 2. Check expiry
    if (now.isAfter(DateTime.parse(expiryStr))) {
      return {'success': false, 'error': 'OTP expired. Please request a new one.'};
    }
    
    // 3. Check code match
    if (code != correctOtp) {
      // Increment attempts
      final newAttempts = attempts + 1;
      await db.database.then((d) => d.update(
        'otp_logs',
        {'attempts': newAttempts},
        where: 'id = ?',
        whereArgs: [logId],
      ));
      
      if (newAttempts >= 3) {
        return {
          'success': false,
          'error': 'Too many failed attempts. Account blocked for 1 hour.',
          'blocked': true,
        };
      }
      
      return {
        'success': false,
        'error': 'Invalid OTP. ${3 - newAttempts} attempts remaining.',
      };
    }
    
    // 4. Success - Mark used
    await db.database.then((d) => d.update(
      'otp_logs',
      {'is_used': 1},
      where: 'id = ?',
      whereArgs: [logId],
    ));
    
    return {'success': true};
  }
}
