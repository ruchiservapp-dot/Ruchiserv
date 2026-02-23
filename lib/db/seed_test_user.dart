import 'package:ruchiserv/core/app_logger.dart';
import 'package:ruchiserv/db/database_helper.dart';

/// Run this once to create a test user account with UNIVERSAL ACCESS
/// 
/// TEST CREDENTIALS:
/// Firm ID: RCHSRV
/// Mobile: 9999999999
/// Password: test1234
/// 
/// ACCESS LEVEL:
/// - Subscription Tier: ENTERPRISE (all features enabled)
/// - Role: Admin (all modules accessible)
/// - Rate Visibility: ENABLED
Future<void> seedTestUser() async {
  final db = DatabaseHelper();
  final database = await db.database;
  
  AppLogger.info('🌱 Seeding test data with UNIVERSAL ACCESS...');
  
  // 1. Create test firm with ENTERPRISE tier (all features)
  try {
    await db.insertFirm({
      'firmId': 'RCHSRV',
      'firmName': 'RuchiServ Test Firm',
      'mobile': '9999999999',
      'email': 'admin@ruchiserv.com',
      'address': 'Test Address, Bangalore',
      'gst': 'RUCHI123456',
      'subscriptionTier': 'ENTERPRISE',  // Full access
      'subscriptionExpiry': '2026-12-31', // Future date
      'enabledFeatures': 'GPS_TRACKING,WHATSAPP,EMAIL,ANALYTICS,MULTI_BRANCH,API_ACCESS',
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
    AppLogger.success('✅ Test firm created: RCHSRV (ENTERPRISE tier)');
  } catch (e) {
    // Try update if exists
    try {
      await database.update('firms', {
        'subscriptionTier': 'ENTERPRISE',
        'subscriptionExpiry': '2026-12-31',
        'enabledFeatures': 'GPS_TRACKING,WHATSAPP,EMAIL,ANALYTICS,MULTI_BRANCH,API_ACCESS',
        'updatedAt': DateTime.now().toIso8601String(),
      }, where: 'firmId = ?', whereArgs: ['RCHSRV']);
      AppLogger.success('✅ Updated RCHSRV to ENTERPRISE tier');
    } catch (_) {
      AppLogger.warning('⚠️  Firm update failed: $e');
    }
  }
  
  // 2. Create test Admin user with FULL ACCESS
  try {
    await db.insertUser({
      'firmId': 'RCHSRV',
      'userId': 'U-9999999999',
      'username': 'Admin User',
      'mobile': '9999999999',
      'email': 'admin@ruchiserv.com',
      'passwordHash': 'test1234',
      'role': 'Admin',
      'permissions': 'ALL',
      'moduleAccess': 'ALL',
      'showRates': 1,  // Can see all rates
      'isActive': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
    AppLogger.success('✅ Admin user created: 9999999999');
  } catch (e) {
    // Try update if exists
    try {
      await database.update('users', {
        'role': 'Admin',
        'permissions': 'ALL',
        'moduleAccess': 'ALL',
        'showRates': 1,
        'isActive': 1,
        'updatedAt': DateTime.now().toIso8601String(),
      }, where: 'mobile = ? AND firmId = ?', whereArgs: ['9999999999', 'RCHSRV']);
      AppLogger.success('✅ Updated user to Admin with full access');
    } catch (_) {
      AppLogger.warning('⚠️  User update failed: $e');
    }
  }
  
  // 3. Add mobile to authorized list
  try {
    await db.addAuthorizedMobile(
      firmId: 'RCHSRV',
      mobile: '9999999999',
      type: 'USER',
      name: 'Admin User',
      addedBy: 'SEED_SCRIPT',
    );
    AppLogger.success('✅ Mobile authorized');
  } catch (e) {
    AppLogger.warning('⚠️  Mobile may already be authorized');
  }
  
  // 4. Create test staff member for attendance/punching
  try {
    await database.insert('staff', {
      'firmId': 'RCHSRV',
      'name': 'Admin Staff',
      'mobile': '9999999999',
      'email': 'admin@ruchiserv.com',
      'role': 'Manager',
      'salary': 50000,
      'staffType': 'PERMANENT',
      'isActive': 1,
      'joinDate': DateTime.now().toIso8601String().split('T')[0],
      'createdAt': DateTime.now().toIso8601String(),
    });
    AppLogger.success('✅ Staff member created for punching module');
  } catch (e) {
    // Try update if exists
    try {
      await database.update('staff', {
        'isActive': 1,
        'updatedAt': DateTime.now().toIso8601String(),
      }, where: 'mobile = ? AND firmId = ?', whereArgs: ['9999999999', 'RCHSRV']);
      AppLogger.success('✅ Staff member updated');
    } catch (_) {
      AppLogger.warning('⚠️  Staff creation may have failed: $e');
    }
  }
  
  AppLogger.info('\n🎉 TEST ACCOUNT READY WITH UNIVERSAL ACCESS!');
  AppLogger.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  AppLogger.info('📱 Firm ID:   RCHSRV');
  AppLogger.info('📱 Mobile:    9999999999');
  AppLogger.info('🔑 Password:  test1234');
  AppLogger.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  AppLogger.info('🏅 Tier:      ENTERPRISE (All Features)');
  AppLogger.info('👤 Role:      Admin (All Modules)');
  AppLogger.info('💰 Rates:     VISIBLE');
  AppLogger.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
}

/// Quick method to reset test firm to ENTERPRISE tier
Future<void> resetToEnterprise() async {
  final db = await DatabaseHelper().database;
  
  await db.update('firms', {
    'subscriptionTier': 'ENTERPRISE',
    'subscriptionExpiry': '2026-12-31',
    'enabledFeatures': 'GPS_TRACKING,WHATSAPP,EMAIL,ANALYTICS,MULTI_BRANCH,API_ACCESS',
  }, where: 'firmId = ?', whereArgs: ['RCHSRV']);
  
  await db.update('users', {
    'role': 'Admin',
    'permissions': 'ALL',
    'moduleAccess': 'ALL',
    'showRates': 1,
  }, where: 'firmId = ?', whereArgs: ['RCHSRV']);
  
  AppLogger.success('✅ RCHSRV reset to ENTERPRISE with full Admin access');
}
