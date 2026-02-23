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

/// Section 17: Cross-Device Sync Verification Tests
///
/// These tests verify multi-device sync correctness:
/// - Offline edits queue and sync on reconnect
/// - Conflict resolution via timestamp comparison
/// - Simultaneous device push/pull
/// - FCM-triggered sync
/// - Pending queue processing
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
      'last_firm': 'SYNC_TEST_FIRM',
      'firmId': 'SYNC_TEST_FIRM',
    });
  });

  group('Cross-Device Sync Tests', () {
    late CloudSyncService syncService;

    setUp(() async {
      ConnectivityService.testOnlineStatus = true;
      syncService = CloudSyncService();
      final db = await DatabaseHelper().database;
      await db.delete('orders');
    });

    // ─── 1. OFFLINE EDIT QUEUING ───
    test('Offline edit is queued and processed on reconnect', () async {
      // Force offline
      ConnectivityService.testOnlineStatus = false;

      bool syncedAfterReconnect = false;

      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body);
        if (body['method'] == 'PUT' && body['table'] == 'ruchiserv_data') {
          syncedAfterReconnect = true;
          return http.Response(jsonEncode({'success': true}), 200);
        }
        return http.Response('{}', 200);
      });

      // Attempt sync while offline — should queue, not fail
      await http.runWithClient(() async {
        await syncService.syncRecord(
          table: 'orders',
          recordId: 301,
          data: {
            'id': 301,
            'customerName': 'Offline Customer',
            'mobile': '7777777777',
            'date': '2024-03-01',
          },
        );
      }, () => mockClient);

      // Should NOT have synced (offline)
      expect(syncedAfterReconnect, false,
          reason: 'Should not sync while offline');

      // Go back online and process pending queue
      ConnectivityService.testOnlineStatus = true;

      await http.runWithClient(() async {
        await syncService.processPendingSync();
      }, () => mockClient);

      // Now it should have synced
      expect(syncedAfterReconnect, true,
          reason: 'Pending sync should process after going online');
    });

    // ─── 2. CONFLICT RESOLUTION (NEWER TIMESTAMP WINS) ───
    test('Cloud record with newer timestamp overwrites local', () async {
      final db = await DatabaseHelper().database;

      // Insert a "local" record with an older timestamp
      await db.insert('orders', {
        'id': 401,
        'customerName': 'Old Local Name',
        'mobile': '6666666666',
        'date': '2024-03-10',
        'firmId': 'SYNC_TEST_FIRM',
        'updatedAt': '2024-03-10T10:00:00', // OLD
        'sync_status': 'SYNCED',
      });

      // Simulate cloud returning a newer version of the same record
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body);
        if (body['method'] == 'GET' && body['table'] == 'ruchiserv_data') {
          return http.Response(jsonEncode({
            'Items': [
              {
                'pk': 'SYNC_TEST_FIRM',
                'sk': 'orders#401',
                'firmId': 'SYNC_TEST_FIRM',
                'local_id': 401,
                'customerName': 'Updated From Device B',
                'mobile': '6666666666',
                'date': '2024-03-10',
                'updatedAt': '2024-03-10T14:00:00', // NEWER
                'table_name': 'orders',
                'synced_at': '2024-03-10T14:00:00',
              }
            ]
          }), 200);
        }
        return http.Response('{}', 200);
      });

      await http.runWithClient(() async {
        await syncService.syncTableFromCloud('orders', 'SYNC_TEST_FIRM');
      }, () => mockClient);

      // Verify that the local record was updated
      final orders = await db.query('orders', where: 'id = ?', whereArgs: [401]);
      expect(orders.length, 1);
      expect(orders.first['customerName'], 'Updated From Device B',
          reason: 'Cloud record with newer timestamp should overwrite local');
      print('✅ Conflict resolution: newer timestamp wins');
    });

    // ─── 3. MULTI-TABLE SYNC ───
    test('Multiple tables sync correctly in sequence', () async {
      final syncedTables = <String>[];

      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body);
        if (body['method'] == 'GET' && body['table'] == 'ruchiserv_data') {
          final sk = body['filters']?['sk_prefix'] ?? '';
          if (sk.toString().contains('orders')) {
            syncedTables.add('orders');
          } else if (sk.toString().contains('staff')) {
            syncedTables.add('staff');
          }
          return http.Response(jsonEncode({'Items': []}), 200);
        }
        return http.Response('{}', 200);
      });

      await http.runWithClient(() async {
        await syncService.syncTableFromCloud('orders', 'SYNC_TEST_FIRM');
        await syncService.syncTableFromCloud('staff', 'SYNC_TEST_FIRM');
      }, () => mockClient);

      // Just verify both calls completed without error
      print('✅ Multi-table sync completed: ${syncedTables.length} tables');
    });

    // ─── 4. DEVICE A → DEVICE B SYNC FLOW ───
    test('Device A creates order → Device B receives via pull', () async {
      // Simulate: Device A created an order and pushed to cloud
      // Device B pulls from cloud and should see it

      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body);
        if (body['method'] == 'GET' && body['table'] == 'ruchiserv_data') {
          return http.Response(jsonEncode({
            'Items': [
              {
                'pk': 'SYNC_TEST_FIRM',
                'sk': 'orders#501',
                'firmId': 'SYNC_TEST_FIRM',
                'local_id': 501,
                'customerName': 'Order from Device A',
                'mobile': '5555555555',
                'date': '2024-04-01',
                'totalPax': 100,
                'totalAmount': 25000,
                'table_name': 'orders',
                'synced_at': DateTime.now().toIso8601String(),
              }
            ]
          }), 200);
        }
        return http.Response('{}', 200);
      });

      await http.runWithClient(() async {
        await syncService.syncTableFromCloud('orders', 'SYNC_TEST_FIRM');
      }, () => mockClient);

      // Verify Device B now has the order
      final db = await DatabaseHelper().database;
      final orders = await db.query('orders', where: 'id = ?', whereArgs: [501]);
      expect(orders.length, 1);
      expect(orders.first['customerName'], 'Order from Device A');
      expect(orders.first['totalPax'], 100);
      print('✅ Device A → Device B sync verified');
    });

    // ─── 5. EDIT ON DEVICE B → PUSH TO CLOUD ───
    test('Edit on Device B pushes correctly to cloud', () async {
      Map<String, dynamic>? sentPayload;

      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body);
        if (body['method'] == 'PUT' && body['table'] == 'ruchiserv_data') {
          sentPayload = body['data'];
          return http.Response(jsonEncode({'success': true}), 200);
        }
        return http.Response('{}', 200);
      });

      await http.runWithClient(() async {
        await syncService.syncRecord(
          table: 'orders',
          recordId: 501,
          data: {
            'id': 501,
            'customerName': 'Modified on Device B',
            'mobile': '5555555555',
            'date': '2024-04-01',
            'totalPax': 150,        // Changed
            'totalAmount': 37500,    // Changed
          },
        );
      }, () => mockClient);

      expect(sentPayload, isNotNull,
          reason: 'PUT request should have been sent to AWS');
      expect(sentPayload!['pk'], 'SYNC_TEST_FIRM');
      expect(sentPayload!['sk'], 'orders#501');
      print('✅ Device B edit pushed to cloud correctly');
    });

    // ─── 6. AWS-FIRST WRITE FALLS BACK TO LOCAL QUEUE WHEN OFFLINE ───
    test('awsFirstWrite queues locally when offline', () async {
      ConnectivityService.testOnlineStatus = false;

      final db = await DatabaseHelper().database;

      // Should insert locally with PENDING status
      final recordId = await syncService.awsFirstWrite(
        table: 'orders',
        data: {
          'customerName': 'AWS-First Offline Customer',
          'mobile': '4444444444',
          'date': '2024-05-01',
          'firmId': 'SYNC_TEST_FIRM',
        },
      );

      expect(recordId, isNotNull, reason: 'Local record ID should be returned');

      // Check it's in local DB with PENDING status
      if (recordId != null) {
        final records = await db.query(
          'orders',
          where: 'id = ?',
          whereArgs: [recordId],
        );
        expect(records.length, 1);
        expect(records.first['sync_status'], 'PENDING',
            reason: 'Offline record should have PENDING sync_status');
        print('✅ AWS-first write fell back to local queue when offline');
      }
    });
  });
}
