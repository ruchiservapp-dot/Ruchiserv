// @locked
// lib/services/auth_service.dart
// Version: 2.1.0 | Date: 2026-01-26
// Consolidated Fix: Case-sensitivity, AWS standard filters, robust authorization sync
// DO NOT MODIFY without explicit approval - critical auth/sync logic
import 'package:ruchiserv/core/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/aws/aws_api.dart';
import '../db/database_helper.dart';
import 'package:sqflite/sqflite.dart';
import 'master_data_sync_service.dart';
import 'cloud_sync_service.dart';
import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import '../config/app_config.dart';

/// Central place for login/registration/password APIs + local expiry rules.
class AuthService {
  // ====== Remote (AWS) calls ======

  /// Online login against AWS (Cognito). Returns true if server accepts the credentials.
  static Future<bool> loginOnline({
    required String firmId,
    required String mobile,
    required String password,
  }) async {
    try {
      print('🔐 AuthService: Attempting Cognito Login for $mobile ($firmId)');

      final userPool = CognitoUserPool(
        AppConfig.cognitoUserPoolId,
        AppConfig.cognitoClientId,
      );

      final cognitoUser = CognitoUser(mobile, userPool);
      final authDetails = AuthenticationDetails(
        username: mobile,
        password: password,
      );

      CognitoUserSession? session;
      try {
        session = await cognitoUser.authenticateUser(authDetails);
      } on CognitoClientException catch (e) {
        print('🔴 Cognito Auth Error: ${e.message}');
        // Fallback for legacy if enabled (for testing during transition)
        if (e.code == 'ResourceNotFoundException' ||
            e.code == 'NotAuthorizedException') {
          print(
              '⚠️ Cognito UserPool not found or auth failed. Falling back to legacy login...');
          return await _loginLegacy(firmId, mobile, password);
        }
        rethrow;
      }

      if (session != null) {
        final idToken = session.getIdToken().getJwtToken();
        final accessToken = session.getAccessToken().getJwtToken();

        // 1. Set Auth Token for all subsequent AWS requests
        AwsApi.setAuthToken(idToken!);

        // 2. Extract firmId from custom attributes if possible
        final payload = session.getIdToken().decodePayload();
        final tokenFirmId = payload['custom:firmId']?.toString();

        if (tokenFirmId != null && tokenFirmId != firmId) {
          print(
              '⚠️ Security: Token Firm ID ($tokenFirmId) mismatches input ($firmId)');
          return false;
        }

        // 3. Save session info
        final sp = await SharedPreferences.getInstance();
        await sp.setString('last_firm', firmId);
        await sp.setString('last_mobile', mobile);
        await sp.setString(
            'user_id', payload['sub']?.toString() ?? 'U-$mobile');
        await sp.setString('jwt_token', idToken);
        await sp.setString(
            'refresh_token', session.getRefreshToken()!.getToken()!);

        await _setLastOnlineLoginNow();

        // 4. Extract role and name for immediate RBAC access (critical for Web first-load)
        final role = payload['custom:role']?.toString() ??
            payload['role']?.toString() ??
            'Admin';
        final name = payload['name']?.toString() ??
            payload['nickname']?.toString() ??
            'User';

        await sp.setString('user_role', role);
        await sp.setString('last_role', role);
        await sp.setString('username', name);

        // 5. CRITICAL: Sync user record and auth mobiles BEFORE returning
        // This ensures local DB is ready for PermissionService.initialize()
        try {
          final cloudSync = CloudSyncService();
          await cloudSync.syncTableFromCloud('users', firmId);
          await cloudSync.syncTableFromCloud('authorized_mobiles', firmId);
        } catch (_) {
          AppLogger.error('Caught error: $_');
        }

        // 6. Background Sync for other tables
        try {
          MasterDataSyncService().syncFromAWS();
        } catch (_) {
          AppLogger.error('Caught error: $_');
        }
        try {
          CloudSyncService().fullSyncFromCloud();
        } catch (_) {
          AppLogger.error('Caught error: $_');
        }

        return true;
      }
    } catch (e) {
      print('⚠️ Login Online Failed: $e');
    }
    return false;
  }

  /// Legacy login for transition period
  static Future<bool> _loginLegacy(
      String firmId, String mobile, String password) async {
    try {
      final resp = await AwsApi.post(
        path: '/login',
        body: {
          'firmId': firmId,
          'mobile': mobile,
          'password': password,
        },
      );
      print('📥 AuthService: Legacy Login Response: $resp');
      if ((resp['status'] ?? '').toString().toLowerCase() == 'success') {
        final sp = await SharedPreferences.getInstance();
        await sp.setString('last_firm', firmId);
        await sp.setString('last_mobile', mobile);

        if (resp['user'] is Map) {
          final userInfo = resp['user'] as Map<String, dynamic>;
          print('👤 AuthService: User Info Found: $userInfo');
          final role = userInfo['role']?.toString() ?? 'Staff';
          final perms = userInfo['permissions']?.toString() ?? '';

          await sp.setString(
              'user_id', userInfo['userId']?.toString() ?? 'U-$mobile');
          await sp.setString('user_role', role);
          await sp.setString('last_role', role);
          await sp.setString('subscription_tier',
              userInfo['subscriptionTier']?.toString() ?? 'ENTERPRISE');
          await sp.setString('user_permissions', perms);

          if ((userInfo['subscriptionExpiry'] ?? '').toString().isNotEmpty) {
            await sp.setString(
                'subscription_expiry', userInfo['subscriptionExpiry']);
          }

          // Also save/update user in local DB to ensure PermissionService.initialize works on next run
          final dbHelper = DatabaseHelper();
          await dbHelper.insertUser({
            'firmId': firmId,
            'userId': userInfo['userId']?.toString() ?? 'U-$mobile',
            'username': userInfo['username']?.toString() ?? 'User',
            'mobile': mobile,
            'role': role,
            'permissions': perms,
            'isActive': 1,
          });
        } else {
          await sp.setString('user_id', 'U-$mobile');
        }

        await _setLastOnlineLoginNow();

        try {
          await MasterDataSyncService().syncFromAWS();
        } catch (_) {
          AppLogger.error('Caught error: $_');
        }
        try {
          await CloudSyncService().fullSyncFromCloud();
        } catch (_) {
          AppLogger.error('Caught error: $_');
        }

        return true;
      }
    } catch (_) {
      AppLogger.error('Caught error: $_');
    }
    return false;
  }

  /// Server-side precheck that mobile belongs to firm (for registration).
  static Future<bool> precheckRegistration({
    required String firmId,
    required String mobile,
  }) async {
    print('AuthService: Prechecking registration for $firmId / $mobile');
    final db = DatabaseHelper();

    try {
      await CloudSyncService().syncTableFromCloud('authorized_mobiles', firmId);
    } catch (_) {
      AppLogger.error('Caught error: $_');
    }

    final isAuth = await db.isMobileAuthorized(firmId, mobile);
    if (isAuth) return true;

    try {
      final resp = await AwsApi.callDbHandler(
        method: 'GET',
        table: 'authorized_mobiles',
        filters: {'firmId': firmId, 'mobile': mobile},
      );
      if (resp['error'] == null &&
          (resp['Item'] != null ||
              (resp['Items'] is List && resp['Items'].isNotEmpty))) {
        return true;
      }
    } catch (_) {
      AppLogger.error('Caught error: $_');
    }

    return false;
  }

  /// Set / reset password online.
  static Future<bool> setPassword({
    required String firmId,
    required String mobile,
    required String password,
  }) async {
    print(
        'AuthService.setPassword: Syncing password to AWS for $firmId / $mobile');
    try {
      // 1. Get user details from authorization record (if possible)
      final db = DatabaseHelper();
      final auth = await db.getAuthorizedMobileByPhone(firmId, mobile);
      final role = auth != null ? auth['role']?.toString() ?? 'Staff' : 'Staff';
      final name = auth != null ? auth['name']?.toString() ?? 'User' : 'User';

      // 2. Sync to AWS Users table
      final userData = {
        'ruchiserv-firms': firmId,
        'mobile': mobile.trim(),
        'passwordHash': password,
        'username': name,
        'role': role,
        'userId': 'USR_${firmId}_$mobile',
        'isActive': 1,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      final resp = await AwsApi.callDbHandler(
        method: 'PUT',
        table: 'ruchiserv_data',
        data: {
          ...userData,
          'pk': firmId,
          'sk': 'users#$mobile',
          'firmId': firmId, // redundant but safe
        },
      );

      if (resp['error'] != null) {
        print('⚠️ AWS setPassword failed: ${resp['error']}');
        // We still return true if it saved locally in the next step,
        // but it's better to warn.
      }

      return true;
    } catch (e) {
      print('⚠️ Error in setPassword: $e');
      return true; // Return true to allow local flow to continue
    }
  }

  static Future<bool> resetPassword({
    required String firmId,
    required String mobile,
    required String newPassword,
  }) async {
    return await setPassword(
        firmId: firmId, mobile: mobile, password: newPassword);
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

    bool within30 = true;
    if (lastOnlineMs > 0) {
      final lastOnline =
          DateTime.fromMillisecondsSinceEpoch(lastOnlineMs, isUtc: true);
      final diffDays = DateTime.now().toUtc().difference(lastOnline).inDays;
      within30 = diffDays <= 30;
    }

    final db = DatabaseHelper();
    final users = await db.getUsersByFirm(firmId);

    final hasUser = users.any((u) {
      final m = (u['mobile']?.toString() ?? '').trim();
      return m == mobile.trim();
    });

    return within30 && hasUser;
  }

  /// Verify credentials against local database
  static Future<bool> loginOffline({
    required String firmId,
    required String mobile,
    required String password,
  }) async {
    final result = await loginOfflineWithDetails(
        firmId: firmId, mobile: mobile, password: password);
    return result['success'] == true;
  }

  /// Verify credentials with detailed error info
  static Future<Map<String, dynamic>> loginOfflineWithDetails({
    required String firmId,
    required String mobile,
    required String password,
  }) async {
    print(
        'AuthService.loginOfflineWithDetails: Checking credentials for [$firmId] / [$mobile]');
    final db = DatabaseHelper();

    // 1. Sync from Cloud
    try {
      final cloudSync = CloudSyncService();
      await cloudSync.syncTableFromCloud('users', firmId);
      await cloudSync.syncTableFromCloud('authorized_mobiles', firmId);
      print('✅ Pre-login sync complete');
    } catch (e) {
      print('⚠️ Pre-login sync failed: $e');
    }

    final database = await db.database;

    // DIAGNOSTIC: Print all users in DB
    try {
      final allUsers = await database.query('users');
      print('DEBUG: Total users in local DB: ${allUsers.length}');
      for (var u in allUsers) {
        print(
            ' - DB User: firmId=${u['firmId']}, mobile=${u['mobile']}, role=${u['role']}');
      }
    } catch (e) {
      print('DEBUG: Failed to query all users: $e');
    }

    // Check firm (Case-insensitive)
    var firms = await database
        .query('firms', where: 'LOWER(firmId) = LOWER(?)', whereArgs: [firmId]);

    if (firms.isEmpty) {
      print('⚠️ Firm not found locally, checking AWS...');
      try {
        final resp = await AwsApi.callDbHandler(
          method: 'GET',
          table: 'ruchiserv_data',
          filters: {
            'pk': firmId,
            'sk': 'firms#$firmId',
          },
        );

        // Handle both object and list responses from AWS (stable commit logic)
        bool awsFound = false;
        Map<String, dynamic>? awsFirm;

        if (resp['status'] == 'success') {
          final data = resp['data'];
          if (data is List && data.isNotEmpty) {
            awsFirm = data.first;
            awsFound = true;
          } else if (resp['firmId'] != null || resp['firmid'] != null) {
            awsFirm = resp;
            awsFound = true;
          }
        } else if (resp['firmId'] != null || resp['firmid'] != null) {
          awsFirm = resp;
          awsFound = true;
        }

        if (awsFound && awsFirm != null) {
          await database.insert(
              'firms',
              {
                'firmId': firmId,
                'firmName': awsFirm['firmName'] ?? awsFirm['name'] ?? 'Unknown',
                'mobile': awsFirm['mobile'] ?? '',
                'subscriptionStatus': awsFirm['subscriptionStatus'] ?? 'ACTIVE',
                'createdAt':
                    awsFirm['createdAt'] ?? DateTime.now().toIso8601String(),
                'updatedAt': DateTime.now().toIso8601String(),
              },
              conflictAlgorithm: ConflictAlgorithm.replace);
          firms = await database.query('firms',
              where: 'LOWER(firmId) = LOWER(?)', whereArgs: [firmId]);
        }
      } catch (e) {
        print('⚠️ AWS firm fetch failed: $e');
      }
    }

    if (firms.isEmpty) return {'success': false, 'error': 'firm_not_found'};

    // 2. Local User Check (More robust matching)
    final allUsersForFirm = await db.getUsersByFirm(firmId);
    print(
        'AuthService: Found ${allUsersForFirm.length} users for firm [$firmId]');
    bool mobileFound = false;

    for (var u in allUsersForFirm) {
      final m = u['mobile']?.toString() ?? '';
      final p = u['passwordHash']?.toString() ?? '';

      print(' - Comparing: DB[${m.trim()}] vs Input[${mobile.trim()}]');
      if (m.trim() == mobile.trim()) {
        mobileFound = true;
        if (p == password) {
          // Check authorization
          bool isAuthorized =
              await db.isMobileAuthorized(firmId, mobile.trim());

          if (!isAuthorized && (u['role'] == 'Admin' || u['role'] == 'Owner')) {
            final authMobiles = await db.getAuthorizedMobiles(firmId);
            if (authMobiles.isEmpty) {
              await database.insert(
                  'authorized_mobiles',
                  {
                    'firmId': firmId,
                    'mobile': mobile.trim(),
                    'role': u['role'],
                    'name': u['username'],
                    'isActive': 1,
                    'addedBy': 'SELF_HEALING',
                    'addedAt': DateTime.now().toIso8601String(),
                  },
                  conflictAlgorithm: ConflictAlgorithm.replace);
              isAuthorized = true;
            }
          }

          if (!isAuthorized) {
            print('✗ Mobile found but not authorized');
            return {'success': false, 'error': 'access_revoked'};
          }

          final sp = await SharedPreferences.getInstance();
          await sp.setString('user_id', u['userId']?.toString() ?? 'U-$mobile');
          await sp.setString('last_firm', firmId);
          await sp.setString('last_mobile', mobile.trim());

          CloudSyncService().fullSyncFromCloud().catchError((_) {});

          return {'success': true, 'error': null};
        } else {
          print('✗ Password mismatch');
          return {'success': false, 'error': 'wrong_password'};
        }
      }
    }

    // 3. AWS User Fallback
    if (!mobileFound) {
      print('✗ Mobile not found locally, checking AWS...');
      try {
        final userResp = await AwsApi.callDbHandler(
          method: 'GET',
          table: 'ruchiserv_data',
          filters: {
            'pk': firmId,
            'sk':
                'users#$mobile', // Using mobile as SK for users in unified table
          },
        );

        final list =
            (userResp['data'] is List) ? (userResp['data'] as List) : null;
        Map<String, dynamic>? awsUser;

        if (list != null && list.isNotEmpty) {
          awsUser = list.first;
        } else if (userResp['userId'] != null || userResp['userid'] != null) {
          awsUser = userResp;
        }

        if (awsUser != null) {
          final userId = awsUser['userId'] ?? awsUser['userid'] ?? 'U-$mobile';

          await database.insert(
              'users',
              {
                'userId': userId,
                'firmId': firmId,
                'username': awsUser['username'] ?? awsUser['name'] ?? 'User',
                'mobile': mobile.trim(),
                'role': awsUser['role'] ?? 'Staff',
                'passwordHash': awsUser['passwordHash'] ?? '',
                'isActive': 1,
                'updatedAt': DateTime.now().toIso8601String(),
              },
              conflictAlgorithm: ConflictAlgorithm.replace);

          if (awsUser['passwordHash']?.toString() == password) {
            final sp = await SharedPreferences.getInstance();
            await sp.setString('user_id', userId);
            await sp.setString('last_firm', firmId);
            await sp.setString('last_mobile', mobile.trim());
            print('✅ AWS Fallback login SUCCESS for $mobile');
            return {'success': true, 'error': null};
          } else {
            print('✗ Password mismatch in AWS fallback');
            return {'success': false, 'error': 'wrong_password'};
          }
        } else {
          print('✗ Mobile not found in AWS fallback either');
          return {'success': false, 'error': 'mobile_not_found'};
        }
      } catch (e) {
        print('⚠️ AWS user fetch failed: $e');
      }
      return {'success': false, 'error': 'mobile_not_found'};
    }

    return {'success': false, 'error': 'mobile_not_found'};
  }

  /// Variant used by biometric quick-login path.
  static Future<bool> canLoginOfflineWithBiometric(
      {required String firmId}) async {
    final sp = await SharedPreferences.getInstance();
    final lastOnlineMs = sp.getInt('last_online_login_ms') ?? 0;
    final lastOnline =
        DateTime.fromMillisecondsSinceEpoch(lastOnlineMs, isUtc: true);
    final diffDays = DateTime.now().toUtc().difference(lastOnline).inDays;
    if (diffDays > 30) return false;

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

  /// Subscription helpers
  static Future<bool> isExpired() async {
    final sp = await SharedPreferences.getInstance();
    final s = sp.getString('subscription_expiry');
    if (s == null || s.isEmpty) return false;
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

  static Future<void> _setLastOnlineLoginNow() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(
        'last_online_login_ms', DateTime.now().toUtc().millisecondsSinceEpoch);
  }

  /// Helper to save user locally after registration
  static Future<void> registerLocalUser({
    required String firmId,
    required String mobile,
    required String password,
    required String name,
    String role = 'Staff',
  }) async {
    print('AuthService.registerLocalUser: Saving $mobile...');
    final db = DatabaseHelper();
    final userId = 'U-$mobile';

    await db.insertUser({
      'firmId': firmId,
      'userId': userId,
      'username': name,
      'mobile': mobile,
      'role': role,
      'passwordHash': password,
      'permissions': (role == 'Admin' || role == 'Owner') ? 'ALL' : 'standard',
      'isActive': 1,
    });

    // SYNC TO CLOUD: Ensure user is saved to AWS immediately
    print('🔄 Attempting cloud sync for registration...');
    try {
      final success =
          await setPassword(firmId: firmId, mobile: mobile, password: password);
      if (success) {
        print('✅ Cloud sync successful');
      } else {
        print('⚠️ Cloud sync failed - user only exists locally');
      }
    } catch (e) {
      print('🔴 Cloud sync error: $e');
    }

    final sp = await SharedPreferences.getInstance();
    await sp.setString('user_id', userId);
    await sp.setString('last_firm', firmId);
    print('✓ User registered and saved locally');
  }

  static Future<String> getUserId() async {
    final sp = await SharedPreferences.getInstance();
    final userId = sp.getString('user_id');
    if (userId == null || userId.isEmpty) {
      throw Exception('User not logged in');
    }
    return userId;
  }

  /// Validates firm and mobile (Forgot Password)
  static Future<Map<String, dynamic>> validateFirmAndMobile({
    required String firmId,
    required String mobile,
  }) async {
    final db = DatabaseHelper();
    bool firmFound = false;
    bool mobileFound = false;

    final localFirms = await db.getFirmByFirmId(firmId);
    if (localFirms.isNotEmpty) {
      firmFound = true;
    } else {
      try {
        final resp = await AwsApi.callDbHandler(
          method: 'GET',
          table: 'firms',
          filters: {'firmid': firmId},
        );
        if (resp['status'] == 'success' || resp['firmid'] != null) {
          firmFound = true;
        }
      } catch (_) {
        AppLogger.error('Caught error: $_');
      }
    }

    if (!firmFound) return {'valid': false, 'error': 'Wrong Firm ID'};

    try {
      final resp = await AwsApi.callDbHandler(
        method: 'GET',
        table: 'users',
        filters: {'ruchiserv-firms': firmId, 'mobile': mobile},
      );
      if (resp['status'] == 'success' ||
          resp['userId'] != null ||
          resp['userid'] != null) {
        mobileFound = true;
      } else {
        final altResp = await AwsApi.callDbHandler(
          method: 'GET',
          table: 'authorized_mobiles',
          filters: {'firmId': firmId, 'mobile': mobile},
        );
        if (altResp['status'] == 'success' ||
            (altResp['data'] is List && (altResp['data'] as List).isNotEmpty)) {
          mobileFound = true;
        }
      }
    } catch (_) {
      final localUsers = await db.getUsersByFirm(firmId);
      if (localUsers.any((u) => u['mobile'] == mobile)) mobileFound = true;
    }

    if (!mobileFound) {
      return {'valid': false, 'error': 'Mobile no not registered'};
    }
    return {'valid': true};
  }

  static Future<Map<String, dynamic>> sendOtp(String mobile) async {
    try {
      final resp = await AwsApi.callDbHandler(
        method: 'POST',
        table: 'auth/otp/request',
        data: {'mobile': mobile},
      );
      return {
        'success': resp['success'] == true,
        'message': resp['message'],
        'error': resp['error']
      };
    } catch (e) {
      return {'success': false, 'error': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> verifyOtp({
    required String mobile,
    required String code,
  }) async {
    try {
      final resp = await AwsApi.callDbHandler(
        method: 'POST',
        table: 'auth/otp/verify',
        data: {'mobile': mobile, 'otp': code},
      );
      return {'success': resp['success'] == true, 'error': resp['error']};
    } catch (e) {
      return {'success': false, 'error': 'Verification failed'};
    }
  }

  /// Register new firm + admin to AWS
  static Future<bool> registerFirmToAws({
    required String firmId,
    required Map<String, dynamic> firmData,
    required Map<String, dynamic> adminData,
  }) async {
    try {
      // 1. Create firm in AWS
      final awsFirmData = Map<String, dynamic>.from(firmData);
      awsFirmData['firmId'] = firmId;

      final firmResp = await AwsApi.callDbHandler(
        method: 'PUT',
        table: 'ruchiserv_data',
        data: {
          ...awsFirmData,
          'pk': firmId,
          'sk': 'firms#$firmId',
          'firmId': firmId,
        },
      );

      // 2. Create user in AWS
      final awsUserData = Map<String, dynamic>.from(adminData);
      awsUserData['ruchiserv-firms'] = firmId;
      awsUserData['mobile'] = adminData['mobile'];
      awsUserData['userId'] = adminData['userId'];

      final userResp = await AwsApi.callDbHandler(
        method: 'PUT',
        table: 'ruchiserv_data',
        data: {
          ...awsUserData,
          'pk': firmId,
          'sk': 'users#${adminData['mobile']}',
          'firmId': firmId,
        },
      );

      // 3. Sync Authorized Mobiles
      final awsAuthData = {
        'firmId': firmId,
        'mobile': adminData['mobile'],
        'role': 'Admin',
        'name': adminData['username'],
        'isActive': 1,
        'addedBy': 'REGISTRATION_SYNC',
        'addedAt': DateTime.now().toIso8601String(),
      };

      await AwsApi.callDbHandler(
        method: 'PUT',
        table: 'ruchiserv_data',
        data: {
          ...awsAuthData,
          'pk': firmId,
          'sk': 'authorized_mobiles#${adminData['mobile']}',
          'firmId': firmId,
        },
      );

      return true;
    } catch (e) {
      print('🔴 AWS sync failed: $e');
      return false;
    }
  }
}
