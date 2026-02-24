import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ruchiserv/services/cloud_sync_service.dart';
import 'package:ruchiserv/db/database_helper.dart';
import 'package:ruchiserv/services/connectivity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    
    // Mock PathProvider
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return '.';
    });

    SharedPreferences.setMockInitialValues({
      'last_firm': 'REPAIR_TEST',
    });
  });

  group('Architectural Sync Repair Verification', () {
    late CloudSyncService syncService;
    late DatabaseHelper dbHelper;

    setUp(() async {
      ConnectivityService.testOnlineStatus = true;
      syncService = CloudSyncService();
      dbHelper = DatabaseHelper();
      
      // CRITICAL: Use in-memory database for tests to avoid persistent state/schema issues
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: 44,
        onCreate: dbHelper.onCreateForTest, // I will add this helper
        onUpgrade: dbHelper.onUpgradeForTest, 
      );
      DatabaseHelper.setTestDatabase(db);
    });

    // 1. ATOMIC MERGE TEST
    test('Atomic Merge: updateUser preserves existing passwordHash', () async {
      final db = await dbHelper.database;
      // Seed local user with password
      await db.insert('users', {
        'id': 1,
        'userId': 'u1',
        'firmId': 'REPAIR_TEST',
        'username': 'Initial',
        'mobile': '123',
        'role': 'STAFF',
        'passwordHash': 'SECRET_HASH',
        'updatedAt': '2024-01-01T00:00:00',
      });

      Map<String, dynamic>? capturedPayload;

      final mockClient = MockClient((request) async {
        if (request.method == 'POST') {
          capturedPayload = jsonDecode(request.body);
          return http.Response(jsonEncode({'status': 'SUCCESS'}), 200);
        }
        return http.Response(jsonEncode({'error': 'Not found'}), 404);
      });

      await http.runWithClient(() async {
        // Perform partial update (only role change)
        await dbHelper.updateUser({'id': 1, 'role': 'ADMIN'});
      }, () => mockClient);

      expect(capturedPayload, isNotNull);
      final data = capturedPayload!['data'];
      expect(data['role'], 'ADMIN');
      expect(data['passwordHash'], 'SECRET_HASH', reason: 'Password was WIPED in the cloud payload!');
      expect(capturedPayload!['prev_updated_at'], '2024-01-01T00:00:00', reason: 'OCC metadata missing');
    });

    // 2. SOFT DELETE TEST
    test('Soft Delete: syncTableFromCloud removes local record when is_deleted=true', () async {
      final db = await dbHelper.database;
      // Seed local order
      await db.insert('orders', {
        'id': 500,
        'uuid': 'order-500-uuid',
        'firmId': 'REPAIR_TEST',
        'customerName': 'To Be Deleted',
        'totalAmount': 100.0,
      });

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({
          'Items': [
            {
              'pk': 'REPAIR_TEST',
              'sk': 'orders#order-500-uuid',
              'uuid': 'order-500-uuid',
              'local_id': 500,
              'is_deleted': true, // THE SOFT DELETE EVENT
              'updatedAt': '2024-02-01T00:00:00',
            }
          ]
        }), 200);
      });

      await http.runWithClient(() async {
        await syncService.syncTableFromCloud('orders', 'REPAIR_TEST');
      }, () => mockClient);

      final result = await db.query('orders', where: 'id = 500');
      expect(result.isEmpty, true, reason: 'Order still exists locally after cloud deletion!');
    });

    // 3. CONFLICT DETECTION TEST
    test('OCC: Detects conflict (409) and triggers re-sync', () async {
      final db = await dbHelper.database;
      await db.insert('users', {
        'id': 2,
        'userId': 'u2',
        'firmId': 'REPAIR_TEST',
        'mobile': '0000', // v44: Required field
        'role': 'STAFF',
        'updatedAt': 'OLD_TIME',
      });

      int syncCalls = 0;
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body);
        if (body['method'] == 'PUT') {
          return http.Response(jsonEncode({'error': 'conflict_detected'}), 409);
        } else if (body['method'] == 'GET') {
          syncCalls++;
          return http.Response(jsonEncode({'Items': []}), 200);
        }
        return http.Response(jsonEncode({}), 200);
      });

      await http.runWithClient(() async {
        final success = await dbHelper.updateUser({'id': 2, 'role': 'MANAGER'});
        expect(success, false);
      }, () => mockClient);

      expect(syncCalls, greaterThan(0), reason: 'Did not trigger re-sync after conflict!');
    });

    // 4. TYPE INTEGRITY TEST
    test('Type Integrity: preserves numeric-looking passwordHashes as Strings', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({
          'Items': [
            {
              'pk': 'REPAIR_TEST',
              'sk': 'users#u3',
              'userId': 'u3',
              'firmId': 'REPAIR_TEST',
              'mobile': '1234567890', // v44: Required field
              'local_id': 3,
              'passwordHash': '123456', // NUMERIC STRING
              'role': 'STAFF',
            }
          ]
        }), 200);
      });

      await http.runWithClient(() async {
        await syncService.syncTableFromCloud('users', 'REPAIR_TEST');
      }, () => mockClient);

      final db = await dbHelper.database;
      final user = (await db.query('users', where: 'userId = ?', whereArgs: ['u3'])).first;
      expect(user['passwordHash'], isA<String>(), reason: 'PasswordHash was wrongly cast to a Number!');
      expect(user['passwordHash'], '123456');
    });
  });
}
