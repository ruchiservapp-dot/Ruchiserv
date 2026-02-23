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
      'last_firm': 'TEST_FIRM',
      'firmId': 'TEST_FIRM',
    });
  });

  group('Multi-Device Sync Logic Tests', () {
    late CloudSyncService syncService;

    setUp(() async {
      ConnectivityService.testOnlineStatus = true; // Force online
      syncService = CloudSyncService();
      // Reset DB
      final db = await DatabaseHelper().database;
      await db.delete('orders');
    });

    // 1. PUSH TEST: Local -> Cloud
    test('Push Sync: Calls AWS API with correct PUT payload', () async {
      bool putCalled = false;

      final mockClient = MockClient((request) async {
        // Handle both legacy dbhandler and new pushToQueue (Lambda Function URL)
        final isDbHandler = request.url.path.contains('/dbhandler');
        final isFunctionUrl = request.url.host.contains('lambda-url');

        if ((isDbHandler || isFunctionUrl) && request.method == 'POST') {
          final json = jsonDecode(request.body);
          
          // Verify it's a PUT operation to DynamoDB
          // payload wrapper for pushToQueue, or direct body for dbhandler
          final payload = isFunctionUrl ? json : json; // In pushToQueue, we send the whole payload
          
          if (payload['method'] == 'PUT' && payload['table'] == 'ruchiserv_data') {
             final data = payload['data'];
             // Verify Partition Key and Sort Key generation
             if (data['gsi_partition'] == 'TEST_FIRM#orders' && 
                 data['pk'] == 'TEST_FIRM' &&
                 data['sk'] != null && data['sk'].toString().startsWith('orders#')) {
               putCalled = true;
               return http.Response(jsonEncode({'success': true}), 200);
             }
          }
        }
        return http.Response(jsonEncode({'success': true}), 200);
      });

      // Execute syncRecord within runWithClient scope
      await http.runWithClient(() async {
        await syncService.syncRecord(
          table: 'orders',
          recordId: 101,
          data: {
            'id': 101,
            'customerName': 'Test Customer',
            'mobile': '9999999999',
            'date': '2024-02-01',
          },
        );
      }, () => mockClient);

      expect(putCalled, true, reason: "Api was not called with correct parameters");
    });

    // 2. PULL TEST: Cloud -> Local merging
    test('Pull Sync: Merges cloud data into local DB', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/dbhandler') && request.method == 'POST') {
          final json = jsonDecode(request.body);
          
          // Verify it's a GET operation
          if (json['method'] == 'GET' && json['table'] == 'ruchiserv_data') {
             // Return mocked "Device B" data
             return http.Response(jsonEncode({
               'Items': [
                 {
                   'pk': 'TEST_FIRM',
                   'sk': 'orders#202-uuid',
                   'firmId': 'TEST_FIRM', // Required by local DB
                   'local_id': 202,
                   'uuid': '202-uuid',
                   'customerName': 'Device B Customer', // Data created on Device B
                   'mobile': '8888888888',
                   'date': '2024-02-02',
                   'table_name': 'orders', // Used by sync service
                   'synced_at': '2024-02-02T12:00:00',
                 }
               ]
             }), 200);
          }
        }
        return http.Response(jsonEncode({'success': true}), 200);
      });

      // Execute syncTableFromCloud within runWithClient scope
      await http.runWithClient(() async {
        await syncService.syncTableFromCloud('orders', 'TEST_FIRM');
      }, () => mockClient);

      // Verify data persisted in Local DB
      final db = await DatabaseHelper().database;
      final orders = await db.query('orders');

      expect(orders.length, 1);
      final order = orders.first;
      expect(order['id'], 202);
      expect(order['customerName'], 'Device B Customer');
      print('✅ Verified: Cloud data merged into local DB');
    });
  });
}
