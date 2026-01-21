// @locked
// lib/services/auth_service.dart
// Version: 2.0.0 | Date: 2025-12-28
// Cross-Platform Sync Fix: Case-sensitivity, username column, AWS user fallback
// DO NOT MODIFY without explicit approval - critical auth/sync logic
import 'package:shared_preferences/shared_preferences.dart';
import '../db/aws/aws_api.dart'; // you already have this
import '../db/database_helper.dart';
import 'package:sqflite/sqflite.dart'; // For ConflictAlgorithm
import 'master_data_sync_service.dart';
import 'cloud_sync_service.dart'; // Full operational data sync
import 'fcm_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';


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
        
        // SYNC MASTER DATA (Ingredients/Dishes for this Firm)
        try {
          await MasterDataSyncService().syncFromAWS();
        } catch (e) {
          print('⚠️ Master Data Sync Failed: $e');
        }
        
        // SYNC OPERATIONAL DATA (Orders, Dispatches, Staff, etc.)
        try {
          await CloudSyncService().fullSyncFromCloud();
        } catch (e) {
          print('⚠️ Cloud Sync Failed: $e');
        }

          // TRIGGER FCM TOKEN SAVE
        try {
          final token = await FirebaseMessaging.instance.getToken();
          if (token != null) {
            await FcmService.saveTokenToBackend(token, firmId: firmId, mobile: mobile);
          }
        } catch (e) {
          print('⚠️ FCM Token Save Failed on Login: $e');
        }


        return true;
      }
    } catch (e) {
      print('⚠️ Login Online Failed: $e');
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
    final result = await loginOfflineWithDetails(firmId: firmId, mobile: mobile, password: password);
    return result['success'] == true;
  }
  
  /// Verify credentials with detailed error info
  /// Returns: {'success': bool, 'error': 'firm_not_found' | 'mobile_not_found' | 'wrong_password' | 'access_revoked' | null}
  static Future<Map<String, dynamic>> loginOfflineWithDetails({
    required String firmId,
    required String mobile,
    required String password,
  }) async {
    print('AuthService.loginOfflineWithDetails: Checking credentials for $firmId / $mobile');
    final db = DatabaseHelper();
    
    // SYNC-ON-LOGIN: Pull latest users and authorized_mobiles from AWS first
    // This ensures newly created users from other devices are available immediately
    try {
      final cloudSync = CloudSyncService();
      await cloudSync.syncTableFromCloud('users', firmId);
      await cloudSync.syncTableFromCloud('authorized_mobiles', firmId);
      print('✅ Pre-login sync complete for users & authorized_mobiles');
    } catch (e) {
      print('⚠️ Pre-login sync failed (will use local data): $e');
    }
    
    // Check if firm exists locally
    final database = await db.database;
    var firms = await database.query('firms', where: 'firmId = ?', whereArgs: [firmId]);
    
    // If firm not found locally, try to fetch from AWS
    if (firms.isEmpty) {
      print('⚠️ Firm not found locally, checking AWS...');
      try {
          final resp = await AwsApi.callDbHandler(
            method: 'GET',
            table: 'firms',
            filters: {'firmid': firmId}, // Preserve case - DynamoDB is case-sensitive
          );
          print('🔍 AWS Firm Fetch Response: $resp'); // DEBUG log
        
        Map<String, dynamic>? awsFirm;
        if ((resp['status'] == 'success') && (resp['data'] is List) && (resp['data'] as List).isNotEmpty) {
          awsFirm = (resp['data'] as List).first as Map<String, dynamic>;
        } else if (resp['error'] == null && (resp['firmId'] != null || resp['firmid'] != null)) {
           // Handle direct object return
           awsFirm = resp;
        }

        if (awsFirm != null) {
          print('✅ Found firm in AWS: $awsFirm');
          
          // Store in local DB
          await database.insert('firms', {
            'firmId': firmId,
            'firmName': awsFirm['firmName'] ?? awsFirm['name'] ?? 'Unknown',
            'mobile': awsFirm['mobile'] ?? '',
            'address': awsFirm['address'] ?? '',
            'gstin': awsFirm['gstin'] ?? '',
            'subscriptionStatus': awsFirm['subscriptionStatus'] ?? 'ACTIVE',
            'subscriptionPlan': awsFirm['subscriptionPlan'] ?? 'FREE_TRIAL',
            'subscriptionExpiry': awsFirm['subscriptionExpiry'] ?? '',
            'createdAt': awsFirm['createdAt'] ?? DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          
          // Also fetch and store user from AWS
          final userResp = await AwsApi.callDbHandler(
            method: 'GET',
            table: 'users',
            filters: {'ruchiserv-firms': firmId, 'mobile': mobile},
          );
          
          Map<String, dynamic>? awsUser;
          if ((userResp['status'] == 'success') && (userResp['data'] is List) && (userResp['data'] as List).isNotEmpty) {
             awsUser = (userResp['data'] as List).first as Map<String, dynamic>;
          } else if (userResp['error'] == null && (userResp['userId'] != null || userResp['userid'] != null)) {
             awsUser = userResp;
          }

          if (awsUser != null) {
            print('✅ Found user in AWS: $awsUser');
            
            await database.insert('users', {
              'userId': awsUser['userId'] ?? awsUser['userid'] ?? 'USR_${firmId}_$mobile',
              'firmId': firmId,
              'username': awsUser['username'] ?? awsUser['name'] ?? 'User',
              'mobile': mobile,
              'role': awsUser['role'] ?? 'Admin',
              'permissions': awsUser['permissions'] ?? 'ALL',
              'passwordHash': awsUser['passwordHash'] ?? '',
              'isActive': 1,
              'createdAt': awsUser['createdAt'] ?? DateTime.now().toIso8601String(),
              'updatedAt': DateTime.now().toIso8601String(),
            }, conflictAlgorithm: ConflictAlgorithm.replace);
            
            // Also add to authorized_mobiles
            await database.insert('authorized_mobiles', {
              'firmId': firmId,
              'mobile': mobile,
              'role': awsUser['role'] ?? 'Admin',
              'name': awsUser['name'] ?? 'User',
              'isActive': 1,
              'addedBy': 'AWS_SYNC',
              'addedAt': DateTime.now().toIso8601String(),
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
          
          // Re-check firms after insert
          firms = await database.query('firms', where: 'firmId = ?', whereArgs: [firmId]);
        }
      } catch (e) {
        print('⚠️ AWS fetch failed: $e');
      }
    }
    
    if (firms.isEmpty) {
      print('✗ Firm not found: $firmId');
      return {'success': false, 'error': 'firm_not_found'};
    }
    
    // Check if mobile exists in this firm
    final users = await db.getUsersByFirm(firmId);
    print('AuthService.loginOfflineWithDetails: Found ${users.length} users for firm $firmId');
    
    bool mobileFound = false;
    for (var u in users) {
      final m = u['mobile']?.toString() ?? '';
      final p = u['passwordHash']?.toString() ?? '';
      print(' - User: mobile=$m, passwordHash=$p (checking against: $password)');
      
      if (m == mobile) {
        mobileFound = true;
        if (p == password) {
          print('✓ Password match!');
          
          // Check if mobile is still authorized
          bool isAuthorized = await db.isMobileAuthorized(firmId, mobile);
          
          // SELF-HEALING: If Admin is not authorized (likely due to sync bug), authorize them now
          // CRITICAL SECURITY FIX: Only allow this if NO authorized mobiles exist ( First User / Recovery )
          // Prevent random users from registering as Admin and bypassing checks
          if (!isAuthorized && (u['role'] == 'Admin' || u['role'] == 'Owner')) {
             final authMobiles = await db.getAuthorizedMobiles(firmId);
             if (authMobiles.isEmpty) {
                 print('⚠️ Admin found and Authorization Table Empty. Auto-authorizing for self-healing/setup.');
                 final database = await db.database;
                 await database.insert('authorized_mobiles', {
                    'firmId': firmId,
                    'mobile': mobile,
                    'role': u['role'],
                    'name': u['username'],
                    'isActive': 1,
                    'addedBy': 'SELF_HEALING',
                    'addedAt': DateTime.now().toIso8601String(),
                 }, conflictAlgorithm: ConflictAlgorithm.replace);
                 isAuthorized = true;
             } else {
               print('🛑 Admin found but NOT authorized, and table not empty. Blocking access.');
             }
          }

          if (!isAuthorized) {
            print('✗ Mobile not authorized/deactivated');
            return {'success': false, 'error': 'access_revoked'};
          }
          
          // COMPLIANCE: Save user_id for audit trail (Rule C.2)
          final sp = await SharedPreferences.getInstance();
          final userId = u['userId']?.toString() ?? 'U-$mobile';
          await sp.setString('user_id', userId);
          await sp.setString('last_firm', firmId); // Essential for CloudSync!
          await sp.setString('last_mobile', mobile); // Essential for FCM!
          
          try {
            await CloudSyncService().fullSyncFromCloud();
          } catch (e) {
            print('⚠️ Cloud Sync after offline login failed: $e');
          }

          // TRIGGER FCM TOKEN SAVE
          try {
            final token = await FirebaseMessaging.instance.getToken();
            if (token != null) {
              await FcmService.saveTokenToBackend(token, firmId: firmId, mobile: mobile);
            }
          } catch (e) {
            print('⚠️ FCM Token Save Failed on Offline Login: $e');
          }

          
          return {'success': true, 'error': null};
        } else {
          print('✗ Password mismatch');
          return {'success': false, 'error': 'wrong_password'};
        }
      }
    }
    
    if (!mobileFound) {
      print('✗ Mobile not found locally, checking AWS...');
      
      // Try AWS fallback for user
      try {
        final userResp = await AwsApi.callDbHandler(
          method: 'GET',
          table: 'users',
          filters: {'ruchiserv-firms': firmId, 'mobile': mobile},
        );
        
        Map<String, dynamic>? awsUser;
        if ((userResp['status'] == 'success') && (userResp['data'] is List) && (userResp['data'] as List).isNotEmpty) {
           awsUser = (userResp['data'] as List).first as Map<String, dynamic>;
        } else if (userResp['error'] == null && (userResp['userId'] != null || userResp['userid'] != null)) {
           awsUser = userResp;
        }

        if (awsUser != null) {
          print('✅ Found user in AWS: $awsUser');
          
          // Insert user locally
          final database = await db.database;
          await database.insert('users', {
            'userId': awsUser['userId'] ?? awsUser['userid'] ?? 'USR_${firmId}_$mobile',
            'firmId': firmId,
            'username': awsUser['username'] ?? awsUser['name'] ?? 'User',
            'mobile': mobile,
            'role': awsUser['role'] ?? 'Admin',
            'permissions': awsUser['permissions'] ?? 'ALL',
            'passwordHash': awsUser['passwordHash'] ?? '',
            'isActive': 1,
            'createdAt': awsUser['createdAt'] ?? DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          
          // Also add to authorized_mobiles
          await database.insert('authorized_mobiles', {
            'firmId': firmId,
            'mobile': mobile,
            'role': awsUser['role'] ?? 'Admin',
            'name': awsUser['username'] ?? awsUser['name'] ?? 'User',
            'isActive': 1,
            'addedBy': 'AWS_SYNC',
            'addedAt': DateTime.now().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          
          // Now verify password
          final awsPassword = awsUser['passwordHash']?.toString() ?? '';
          if (awsPassword == password) {
            print('✓ Password match from AWS!');
            
            // COMPLIANCE: Save user_id and firmId for audit trail and sync
            final sp = await SharedPreferences.getInstance();
            final userId = awsUser['userId']?.toString() ?? awsUser['userid']?.toString() ?? 'U-$mobile';
            await sp.setString('user_id', userId);
            await sp.setString('last_firm', firmId); // Essential for CloudSync!
            
            try {
              await CloudSyncService().fullSyncFromCloud();
            } catch (e) {
              print('⚠️ Cloud Sync after AWS login failed: $e');
            }

            // TRIGGER FCM TOKEN SAVE
            try {
              final token = await FirebaseMessaging.instance.getToken();
              if (token != null) {
                await FcmService.saveTokenToBackend(token);
              }
            } catch (e) {
              print('⚠️ FCM Token Save Failed on AWS Login: $e');
            }

            
            return {'success': true, 'error': null};
          } else {
            print('✗ Password mismatch (AWS)');
            return {'success': false, 'error': 'wrong_password'};
          }
        }
      } catch (e) {
        print('⚠️ AWS user fetch failed: $e');
      }
      
      print('✗ Mobile not found in firm');
      return {'success': false, 'error': 'mobile_not_found'};
    }
    
    print('✗ No matching user/password found');
    return {'success': false, 'error': 'wrong_password'};
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
    String role = 'Staff', // Default to Staff, caller must specify Admin if needed
  }) async {
    print('AuthService.registerLocalUser: Registering $firmId / $mobile ($role) with password: $password');
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
        'role': role, 
        'passwordHash': password, // Should be hashed in production
        'permissions': role == 'Admin' ? 'ALL' : 'standard',
        'isActive': role == 'Admin' ? 1 : 0, // Staff inactive by default
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
          filters: {'firmid': firmId}, // Preserve case - DynamoDB is case-sensitive
        );
        if ((resp['status'] == 'success') &&
            (resp['data'] is List) &&
            (resp['data'] as List).isNotEmpty) {
          firmFound = true;
        } else if (resp['error'] == null && (resp['firmId'] != null || resp['firmid'] != null)) {
          // Direct object return
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
        filters: {'ruchiserv-firms': firmId, 'mobile': mobile},
      );
      if ((resp['status'] == 'success') &&
          (resp['data'] is List) &&
          (resp['data'] as List).isNotEmpty) {
        mobileFound = true;
      } else if (resp['error'] == null && (resp['userId'] != null || resp['userid'] != null)) {
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

  // ====== OTP Logic (Rule F.3: Secure Backend) ======

  /// Request OTP from Backend (Supports 2Factor, MSG91, Fast2SMS failovers)
  /// Rate limiting is now enforced server-side.
  static Future<Map<String, dynamic>> sendOtp(String mobile) async {
    print('🔐 AuthService: Requesting OTP for $mobile via Secure Backend...');
    try {
      // 1. Call Backend API
      // Note: Endpoint /auth/otp/request handles provider selection and rate limits
      final resp = await AwsApi.callDbHandler(
        method: 'POST',
        table: 'auth/otp/request',
        data: {'mobile': mobile},
      );
      
      print('🔐 AuthService: OTP Response: $resp');

      // 2. Handle Response
      if (resp['success'] == true) {
         return {
          'success': true,
          'message': resp['message'] ?? 'OTP sent successfully',
          'expiresIn': resp['expires_in'] ?? 300,
        };
      } else {
        return {
          'success': false,
          'error': resp['error'] ?? 'Failed to send OTP',
          'blocked': (resp['error'] ?? '').toString().contains('Rate limit') 
                     || (resp['error'] ?? '').toString().contains('Too many'),
        };
      }
    } catch (e) {
      print('❌ AuthService: OTP Request Failed: $e');
      return {
        'success': false,
        'error': 'Network error. Please try again.',
      };
    }
  }

  /// Verify OTP via Secure Backend
  /// Enforces expiry and max attempts server-side
  static Future<Map<String, dynamic>> verifyOtp({
    required String mobile,
    required String code,
  }) async {
    print('🔐 AuthService: Verifying OTP for $mobile...');
    try {
      final resp = await AwsApi.callDbHandler(
        method: 'POST',
        table: 'auth/otp/verify',
        data: {'mobile': mobile, 'otp': code},
      );
      
      print('🔐 AuthService: Verify Response: $resp');
      
      if (resp['success'] == true) {
        return {'success': true};
      } else {
        return {
          'success': false,
          'error': resp['error'] ?? 'Invalid OTP',
          'blocked': (resp['error'] ?? '').contains('Too many'), // Pass through blocked status
        };
      }
    } catch (e) {
       print('❌ AuthService: Verification Network Error: $e');
       return {'success': false, 'error': 'Verification failed. Check network.'};
    }
  }

  /// Register new firm + admin to AWS (called after local registration)
  static Future<bool> registerFirmToAws({
    required String firmId,
    required Map<String, dynamic> firmData,
    required Map<String, dynamic> adminData,
  }) async {
    try {
      // 1. Create firm in AWS (Multi-Table)
      final awsFirmData = Map<String, dynamic>.from(firmData);
      awsFirmData['firmid'] = firmId; // DynamoDB likely expects this
      
      final firmResp = await AwsApi.callDbHandler(
        method: 'PUT',
        table: 'firms',
        data: awsFirmData,
      );
      
      print('AWS firm sync response: $firmResp');
      if (firmResp['error'] != null) {
        print('⚠️ Failed to sync firm to AWS: ${firmResp['error']}');
      }

      // 2. Create user in AWS (Multi-Table)
      // FIX: Use discovered keys: PK='ruchiserv-firms', SK='mobile'
      final awsUserData = Map<String, dynamic>.from(adminData);
      awsUserData['ruchiserv-firms'] = firmId; 
      awsUserData['mobile'] = adminData['mobile'];
      awsUserData['userid'] = adminData['userId']; // Keeping this as attribute
      
      final userResp = await AwsApi.callDbHandler(
        method: 'PUT',
        table: 'users',
        data: awsUserData,
      );
      
      print('AWS user sync response: $userResp');
      
      bool firmSuccess = true;
      if (firmResp['error'] != null || (firmResp['status'] != 'success' && firmResp['message'] != 'Created')) {
        print('⚠️ Failed to sync firm to AWS: ${firmResp['error']}');
        firmSuccess = false;
      }

      bool userSuccess = true;
    if (userResp['error'] != null || (userResp['status'] != 'success' && userResp['message'] != 'Created')) {
      print('⚠️ Failed to sync user to AWS: ${userResp['error']}');
      userSuccess = false;
    }

    // 3. Sync Authorized Mobiles to AWS (CRITICAL FIX)
    final awsAuthData = {
      'firmId': firmId,
      'mobile': adminData['mobile'],
      'role': 'Admin',
      'name': adminData['username'],
      'isActive': 1,
      'addedBy': 'REGISTRATION_SYNC',
      'addedAt': DateTime.now().toIso8601String(),
    };
    // Flatten for DynamoDB (if needed) or just pass as data
    // The Lambda expects 'data' object.
    
    final authResp = await AwsApi.callDbHandler(
      method: 'PUT',
      table: 'authorized_mobiles',
      data: awsAuthData,
    );
    print('AWS authorized_mobiles sync response: $authResp');

    if (firmSuccess && userSuccess) {
       print('✅ Firm registration synced to AWS');
       return true;
    } else {
       return false;
    }
    } catch (e) {
      print('🔴 AWS sync failed (will retry later): $e');
      return false;
    }
  }
}
