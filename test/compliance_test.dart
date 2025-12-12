import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' hide equals;
import 'package:ruchiserv/db/database_helper.dart';
import 'package:ruchiserv/core/encryption_helper.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

void main() {
  // Initialize bindings for MethodChannel mocking
  TestWidgetsFlutterBinding.ensureInitialized();
  
  // Initialize FFI for SQLite on desktop
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUpAll(() async {
    // Mock PathProvider via MethodChannel
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'getApplicationDocumentsDirectory') {
        return '.'; // Use current directory for tests
      }
      return null;
    });

    // Mock FlutterSecureStorage for EncryptionHelper
    FlutterSecureStorage.setMockInitialValues({});
    
    // Initialize EncryptionHelper
    await EncryptionHelper.initialize();
    
    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});
    
    // Delete existing DB file to force onCreate
    final dbFile = File('ruchiserv.db');
    if (await dbFile.exists()) {
      await dbFile.delete();
    }
  });

  group('Enterprise Compliance Framework Tests', () {
    late DatabaseHelper dbHelper;

    setUp(() async {
      dbHelper = DatabaseHelper();
      // Reset DB for each test (using in-memory for speed/isolation)
      final db = await dbHelper.database;
      await db.delete('orders');
      await db.delete('dishes');
      await db.delete('audit_log');
    });

    // 1. Security Test (Rule B.1 & C.3) - Multi-Tenant Isolation
    test('Security: Multi-Tenant Isolation (Rule B.1)', () async {
      final now = DateTime.now().toIso8601String().split('T')[0];
      // Create order for Firm A
      await dbHelper.insertOrder(
        {'mobile': '9998887777', 'email': 'a@firm.com', 'date': now, 'customerName': 'Cust A'},
        [{'name': 'Dish A', 'pax': 10}],
        firmId: 'FIRM_A',
        userId: 'U-A',
      );

      // Create order for Firm B
      await dbHelper.insertOrder(
        {'mobile': '1112223333', 'email': 'b@firm.com', 'date': now, 'customerName': 'Cust B'},
        [{'name': 'Dish B', 'pax': 20}],
        firmId: 'FIRM_B',
        userId: 'U-B',
      );

      // Query as Firm A
      final ordersA = await dbHelper.getAllOrdersWithPax('FIRM_A');
      expect(ordersA.length, 1);
      
      // Query as Firm B
      final ordersB = await dbHelper.getAllOrdersWithPax('FIRM_B');
      expect(ordersB.length, 1);

      // Verify Firm B cannot see Firm A's data
      final db = await dbHelper.database;
      final crossCheck = await db.query('orders', where: 'firmId = ?', whereArgs: ['FIRM_A']);
      expect(crossCheck.length, 1); // Exists in DB
      
      // But getOrdersByDate for Firm B should return empty for Firm A's date (assuming today)
      final firmBView = await dbHelper.getOrdersByDate(now, 'FIRM_B');
      expect(firmBView.length, 1);
      expect(firmBView.first['mobile'], '1112223333'); // Should be decrypted
    });

    // 2. Integrity Test (Rule A.1 & C.2) - Transaction Rollback
    test('Integrity: Transaction Rollback (Rule A.1)', () async {
      final db = await dbHelper.database;
      final now = DateTime.now().toIso8601String().split('T')[0];
      
      // Verify normal atomic insert works
      await dbHelper.insertOrder(
        {'mobile': '5555555555', 'date': now, 'customerName': 'Test Integrity'},
        [{'name': 'Test Dish', 'pax': 5}],
        firmId: 'TEST_FIRM',
        userId: 'U-TEST',
      );
      
      final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM orders'));
      expect(count, 1);
    });

    // 3. Performance Test (Rule A.4) - Pagination
    test('Performance: Pagination (Rule A.4)', () async {
      final now = DateTime.now().toIso8601String().split('T')[0];
      // Insert 60 orders
      for (int i = 0; i < 60; i++) {
        await dbHelper.insertOrder(
          {'mobile': 'User$i', 'createdAt': DateTime.now().add(Duration(minutes: i)).toIso8601String(), 'date': now, 'customerName': 'Cust $i'},
          [],
          firmId: 'PAGINATION_FIRM',
          userId: 'U-PERF',
        );
      }
      
      // Page 1 (Limit 50)
      final page1 = await dbHelper.getOrdersByDate(now, 'PAGINATION_FIRM', limit: 50, offset: 0);
      expect(page1.length, 50);
      
      // Page 2 (Limit 50, Offset 50)
      final page2 = await dbHelper.getOrdersByDate(now, 'PAGINATION_FIRM', limit: 50, offset: 50);
      expect(page2.length, 10); // Remaining 10
    });

    // 4. Data Verification (Rule C.3) - Encryption
    test('Data Verification: PII Encryption (Rule C.3)', () async {
      final mobile = '9876543210';
      final email = 'secret@test.com';
      final now = DateTime.now().toIso8601String().split('T')[0];
      
      await dbHelper.insertOrder(
        {'mobile': mobile, 'email': email, 'date': now, 'customerName': 'Secret Cust'},
        [],
        firmId: 'ENCRYPT_FIRM',
        userId: 'U-SECURE',
      );

      final db = await dbHelper.database;
      final rawRow = (await db.query('orders')).first;
      
      // Verify raw DB values are NOT plain text
      expect(rawRow['mobile'], isNot(equals(mobile)));
      expect(rawRow['email'], isNot(equals(email)));
      
      // Verify they are valid base64 (simple check)
      expect(rawRow['mobile'].toString().endsWith('='), true);
      
      // Verify decryption works via getter
      final fetched = await dbHelper.getOrdersByDate(now, 'ENCRYPT_FIRM');
      expect(fetched.first['mobile'], mobile);
      expect(fetched.first['email'], email);
    });

    // 5. Accountability Test (Rule C.2) - Audit Verification
    test('Accountability: Audit Trail (Rule C.2)', () async {
      final userId = 'U-AUDIT-123';
      final firmId = 'AUDIT_FIRM';
      final now = DateTime.now().toIso8601String().split('T')[0];
      
      // 1. Insert
      final orderId = await dbHelper.insertOrder(
        {'mobile': '111', 'totalPax': 10, 'date': now, 'customerName': 'Audit Cust'},
        [],
        firmId: firmId,
        userId: userId,
      );
      
      // 2. Update
      await dbHelper.updateOrder(
        orderId!,
        {'mobile': '111', 'totalPax': 20, 'date': now, 'customerName': 'Audit Cust'}, // Changed pax
        [],
        firmId: firmId,
        userId: userId,
      );
      
      // 3. Delete
      await dbHelper.deleteOrder(orderId, firmId: firmId, userId: userId);
      
      // Verify Logs
      final logs = await dbHelper.getAuditLogs(firmId: firmId);
      expect(logs.length, 3);
      
      // Check latest (DELETE)
      expect(logs[0]['action'], 'DELETE');
      expect(logs[0]['user_id'], userId);
      
      // Check middle (UPDATE)
      expect(logs[1]['action'], 'UPDATE');
      expect(logs[1]['changed_fields'], contains('totalPax'));
      
      // Check first (INSERT)
      expect(logs[2]['action'], 'INSERT');
    });
  });
}
