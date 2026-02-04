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
import 'package:sqflite/sqflite.dart';

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
        if (request.url.path.contains('/dbhandler') && request.method == 'POST') {
          final json = jsonDecode(request.body);
          
          // Verify it's a PUT operation to DynamoDB
          if (json['method'] == 'PUT' && json['table'] == 'ruchiserv_data') {
             final data = json['data'];
             // Verify Partition Key and Sort Key generation
             if (data['gsi_partition'] == 'TEST_FIRM#orders' && 
                 data['pk'] == 'TEST_FIRM' &&
                 data['sk'] == 'orders#101') {
               putCalled = true;
               return http.Response(jsonEncode({'success': true}), 200);
             }
          }
        }
        return http.Response('{}', 200);
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
                   'sk': 'orders#202',
                   'firmId': 'TEST_FIRM', // Required by local DB
                   'local_id': 202,
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
        return http.Response('{}', 200);
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
