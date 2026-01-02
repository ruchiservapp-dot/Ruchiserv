// lib/services/cloud_sync_service.dart
// @locked
// Full AWS DynamoDB sync service for multi-device, multi-user cloud operations
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart'; // For ConflictAlgorithm
import '../db/database_helper.dart';
import '../db/aws/aws_api.dart';
import 'connectivity_service.dart';

/// CloudSyncService - Handles bidirectional sync between local SQLite and AWS DynamoDB.
/// 
/// Architecture:
/// - PK (Partition Key): firmId
/// - SK (Sort Key): {table}#{id}  e.g., "orders#123"
/// - All operational data syncs to `ruchiserv_data` table in DynamoDB
class CloudSyncService {
  static final CloudSyncService _instance = CloudSyncService._internal();
  factory CloudSyncService() => _instance;
  CloudSyncService._internal();

  final _db = DatabaseHelper();
  
  // Tables that sync to AWS
  static const syncTables = [
    'orders',
    'dishes', 
    'dispatches',
    'dispatch',
    'staff',
    'attendance',
    'customers',
    'vehicles',
    'utensils',
    'finance',
    'mrp_runs',
    'mrp_run_orders',
    'mrp_output',
    'purchase_orders',
    'po_items',
    'suppliers',
    'subcontractors',
    'invoices',
    'invoice_items',
    'salary_disbursements',
    'users',                // v37: Multi-device user sync
    'authorized_mobiles',   // v37: Multi-device login authorization
  ];

  /// Get current firm ID
  Future<String?> _getFirmId() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString('last_firm');
  }

  // ============ SYNC SINGLE RECORD TO AWS ============

  /// Sync a single record to AWS after insert/update
  /// Call this after every local insert/update operation
  Future<bool> syncRecord({
    required String table,
    required int recordId,
    required Map<String, dynamic> data,
  }) async {
    final firmId = await _getFirmId();
    if (firmId == null || firmId == 'DEFAULT') {
      print('⚠️ CloudSync: No firmId, skipping sync');
      return false;
    }

    final isOnline = await ConnectivityService().isOnline();
    if (!isOnline) {
      // Queue for later sync
      await _queuePendingSync(table, recordId, data, 'PUT');
      print('📥 CloudSync: Offline - queued for later');
      return false;
    }

    try {
      // Prepare DynamoDB record
      final awsData = Map<String, dynamic>.from(data);
      awsData['pk'] = firmId;
      awsData['sk'] = '$table#$recordId';
      awsData['table_name'] = table;
      awsData['local_id'] = recordId;
      awsData['synced_at'] = DateTime.now().toIso8601String();

      final resp = await AwsApi.callDbHandler(
        method: 'PUT',
        table: 'ruchiserv_data',
        data: awsData,
      );

      if (resp['error'] != null) {
        print('❌ CloudSync: Failed to sync $table#$recordId: ${resp['error']}');
        await _queuePendingSync(table, recordId, data, 'PUT');
        return false;
      }

      print('✅ CloudSync: Synced $table#$recordId');
      return true;
    } catch (e) {
      print('❌ CloudSync: Exception syncing $table#$recordId: $e');
      await _queuePendingSync(table, recordId, data, 'PUT');
      return false;
    }
  }

  /// Delete a record from AWS
  Future<bool> deleteRecord({
    required String table,
    required int recordId,
  }) async {
    final firmId = await _getFirmId();
    if (firmId == null) return false;

    final isOnline = await ConnectivityService().isOnline();
    if (!isOnline) {
      await _queuePendingSync(table, recordId, {}, 'DELETE');
      return false;
    }

    try {
      final resp = await AwsApi.callDbHandler(
        method: 'DELETE',
        table: 'ruchiserv_data',
        filters: {
          'pk': firmId,
          'sk': '$table#$recordId',
        },
      );

      if (resp['error'] != null) {
        print('❌ CloudSync: Failed to delete $table#$recordId');
        return false;
      }

      print('✅ CloudSync: Deleted $table#$recordId from cloud');
      return true;
    } catch (e) {
      print('❌ CloudSync: Exception deleting $table#$recordId: $e');
      return false;
    }
  }

  // ============ FULL SYNC FROM AWS ============

  /// Sync all data from AWS for the current firm
  /// Called on login or when switching devices
  Future<void> fullSyncFromCloud() async {
    final firmId = await _getFirmId();
    if (firmId == null || firmId == 'DEFAULT') {
      print('⚠️ CloudSync: No firmId for full sync');
      return;
    }

    final isOnline = await ConnectivityService().isOnline();
    if (!isOnline) {
      print('⚠️ CloudSync: Offline, cannot sync from cloud');
      return;
    }

    print('🔄 CloudSync: Starting full sync for firm $firmId...');

    for (final table in syncTables) {
      await syncTableFromCloud(table, firmId);
    }

    print('✅ CloudSync: Full sync complete');
  }

  Future<void> syncTableFromCloud(String table, String firmId) async {
    try {
      final resp = await AwsApi.callDbHandler(
        method: 'GET',
        table: 'ruchiserv_data',
        filters: {
          'pk': firmId,
          'sk_prefix': '$table#',
        },
      );

      // Handle response - Lambda returns items directly as a List in response body
      // or as a Map with error field
      List<dynamic> records = [];
      
      if (resp['error'] != null) {
        print('  ❌ $table: API error: ${resp['error']}');
        return;
      }
      
      // The Lambda should return a list for query results
      // Check if response has items in different formats
      if (resp['Items'] != null && resp['Items'] is List) {
        records = resp['Items'] as List;
      } else if (resp.containsKey('local_id') || resp.containsKey('id')) {
        // Single item response
        records = [resp];
      } else {
        print('  📥 $table: No cloud data (resp: $resp)');
        return;
      }
      
      if (records.isEmpty) {
        print('  📥 $table: No cloud data');
        return;
      }

      print('  📥 $table: Received ${records.length} records');

      final db = await _db.database;

      for (final record in records) {
        final data = Map<String, dynamic>.from(record);
        // Parse local_id - DynamoDB returns numbers as strings
        final localIdRaw = data['local_id'];
        final localId = localIdRaw == null ? null : int.tryParse(localIdRaw.toString());
        
        // Remove DynamoDB metadata (but keep firmId - needed for tables)
        data.remove('pk');
        data.remove('sk');
        data.remove('table_name');
        data.remove('local_id');
        data.remove('synced_at');

        if (localId == null) continue;

        // Sanitize data - convert DynamoDB string numbers to proper types
        final sanitized = _sanitizeForSqlite(data);

        // Check if record exists locally
        final existing = await db.query(
          table,
          where: 'id = ?',
          whereArgs: [localId],
        );

        if (existing.isEmpty) {
          // Insert new record (preserve original ID)
          sanitized['id'] = localId;
          try {
            // Use ConflictAlgorithm.replace to handle UNIQUE constraints (like userId)
            await db.insert(table, sanitized, conflictAlgorithm: ConflictAlgorithm.replace);
          } catch (e) {
            print('  ⚠️ $table insert failed for id=$localId: $e');
          }
        } else {
          // Update existing record - use replace to handle UNIQUE constraints
          sanitized['id'] = localId;
          await db.insert(table, sanitized, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    } catch (e) {
      print('  ❌ $table sync error: $e');
    }
  }

  /// Convert DynamoDB string numbers to proper types for SQLite
  static Map<String, dynamic> _sanitizeForSqlite(Map<String, dynamic> data) {
    // Fields that must ALWAYS remain strings, even if they look like numbers
    const stringFields = {
      'mobile', 'phone', 'contact', 
      'firmId', 'userId', 'gstin', 
      'date', 'time', 'eventDate', 'eventTime', 
      'createdAt', 'updatedAt', 'deletedAt', 'synced_at', 'joinedAt',
      'sku_name', 'vehicleNumber',
      'zip', 'pin', 'postalCode'
    };

    final result = <String, dynamic>{};
    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;
      
      if (value == null) {
        result[key] = null;
        continue;
      }
      
      // If manually flagged as string field, keep as is
      if (stringFields.contains(key) || key.endsWith('Name') || key.endsWith('Url')) {
        result[key] = value.toString();
        continue;
      }

      if (value is String) {
        // Try to convert string to int if it's a numeric string
        final intVal = int.tryParse(value);
        final doubleVal = double.tryParse(value);
        
        // Only convert if it helps (e.g. "1" -> 1). 
        // If it's a mix of chars, tryParse returns null.
        if (intVal != null) {
           // Double check: if it starts with 0 and length > 1, it might be a code (e.g. "01")
           // Keep "0" as 0. Keep "05" as "05"? No, SQLite int 5 is fine usually.
           // But just in case, typical IDs don't start with 0.
           result[key] = intVal;
        } else if (doubleVal != null) {
           result[key] = doubleVal;
        } else {
           result[key] = value;
        }
      } else {
        // Already a number or boolean
        result[key] = value;
      }
    }
    return result;
  }

  // ============ PENDING SYNC QUEUE ============

  /// Queue a sync operation for when back online
  Future<void> _queuePendingSync(
    String table,
    int recordId,
    Map<String, dynamic> data,
    String action,
  ) async {
    final db = await _db.database;
    await db.insert('pending_sync', {
      'table_name': table,
      'data': jsonEncode({'id': recordId, ...data}),
      'action': action,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Process pending sync queue (call periodically or on connectivity change)
  Future<void> processPendingSync() async {
    final isOnline = await ConnectivityService().isOnline();
    if (!isOnline) return;

    final firmId = await _getFirmId();
    if (firmId == null) return;

    final db = await _db.database;
    final pending = await db.query('pending_sync', orderBy: 'timestamp ASC');

    if (pending.isEmpty) return;

    print('🔄 CloudSync: Processing ${pending.length} pending syncs...');

    for (final item in pending) {
      final table = item['table_name'] as String;
      final action = item['action'] as String;
      final dataJson = item['data'] as String;
      final data = jsonDecode(dataJson) as Map<String, dynamic>;
      final recordId = data['id'] as int;

      bool success = false;
      if (action == 'PUT') {
        success = await syncRecord(table: table, recordId: recordId, data: data);
      } else if (action == 'DELETE') {
        success = await deleteRecord(table: table, recordId: recordId);
      }

      if (success) {
        await db.delete('pending_sync', where: 'id = ?', whereArgs: [item['id']]);
      }
    }

    print('✅ CloudSync: Pending sync complete');
  }

  // ============ BATCH SYNC HELPERS ============

  /// Sync all records of a table to AWS (for initial migration)
  Future<void> syncTableToCloud(String table) async {
    final firmId = await _getFirmId();
    if (firmId == null) return;

    final db = await _db.database;
    final records = await db.query(table);

    print('📤 CloudSync: Syncing ${records.length} $table records to cloud...');

    for (final record in records) {
      final id = record['id'] as int;
      await syncRecord(table: table, recordId: id, data: record);
    }

    print('✅ CloudSync: $table batch sync complete');
  }

  // ============ POLLING & BACKGROUND SYNC ============

  bool _isPolling = false;

  /// Start periodic sync (Push & Pull)
  /// Call this from main.dart or after login
  void startPolling() {
    if (_isPolling) return;
    _isPolling = true;
    print('🔄 CloudSync: Starting background polling...');

    // PUSH: Process pending queue every 30 seconds
    Stream.periodic(const Duration(seconds: 30)).listen((_) async {
      await processPendingSync();
    });

    // PUSH: Process pending queue every 30 seconds (Cheap - only if local changes)
    Stream.periodic(const Duration(seconds: 30)).listen((_) async {
      if (!_isFrontendActive) return; // Optimization
      await processPendingSync();
    });

    // PULL (HOT): Sync high-velocity tables every 60 seconds
    // Cost: ~6 requests/minute per device (Orders, Dispatch, MRP, Users)
    Stream.periodic(const Duration(seconds: 60)).listen((_) async {
      if (!_isFrontendActive) return; // Optimization
      final isOnline = await ConnectivityService().isOnline();
      if (isOnline) {
        final firmId = await _getFirmId();
        if (firmId != null) {
          await syncTableFromCloud('orders', firmId);
          await syncTableFromCloud('dispatch', firmId);
          await syncTableFromCloud('mrp_runs', firmId);
          await syncTableFromCloud('mrp_output', firmId);
          await syncTableFromCloud('users', firmId);              // v37: Multi-device login
          await syncTableFromCloud('authorized_mobiles', firmId); // v37: Multi-device login
        }
      }
    });

    // PULL (COLD): Sync static/low-velocity data every 5 minutes
    // Cost: reduced by 5x
    // PULL (COLD): Sync static/low-velocity data every 5 minutes
    // Cost: reduced by 5x
    Stream.periodic(const Duration(minutes: 5)).listen((_) async {
       if (!_isFrontendActive) return; // Optimization: Skip if app backgrounded
       
       final isOnline = await ConnectivityService().isOnline();
       if (isOnline) {
         final firmId = await _getFirmId();
         if (firmId != null) {
           // Sync everything else
           for (final table in syncTables) {
             if (!['orders', 'dispatch', 'mrp_runs', 'mrp_output'].contains(table)) {
               await syncTableFromCloud(table, firmId);
             }
           }
         }
       }
    });
  }

  // ============ LIFECYCLE MANAGEMENT ============
  
  bool _isFrontendActive = true;

  /// Call this when app goes to background (paused/inactive)
  void setAppBackgrounded() {
    _isFrontendActive = false;
    print('🌙 CloudSync: App backgrounded - pausing polling');
  }

  /// Call this when app resumes (foreground)
  void setAppForegrounded() {
    _isFrontendActive = true;
    print('☀️ CloudSync: App foregrounded - resuming polling');
    // Trigger immediate check on resume
    processPendingSync();
    fullSyncFromCloud(); 
  }
}
