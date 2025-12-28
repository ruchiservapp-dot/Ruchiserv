// lib/services/cloud_sync_service.dart
// @locked
// Full AWS DynamoDB sync service for multi-device, multi-user cloud operations
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
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
      await _syncTableFromCloud(table, firmId);
    }

    print('✅ CloudSync: Full sync complete');
  }

  Future<void> _syncTableFromCloud(String table, String firmId) async {
    try {
      final resp = await AwsApi.callDbHandler(
        method: 'GET',
        table: 'ruchiserv_data',
        filters: {
          'pk': firmId,
          'sk_prefix': '$table#',
        },
      );

      if (resp is! List || resp.isEmpty) {
        print('  📥 $table: No cloud data');
        return;
      }

      final records = resp as List;
      print('  📥 $table: Received ${records.length} records');

      final db = await _db.database;

      for (final record in records) {
        final data = Map<String, dynamic>.from(record);
        final localId = data['local_id'] as int?;
        
        // Remove DynamoDB metadata
        data.remove('pk');
        data.remove('sk');
        data.remove('table_name');
        data.remove('local_id');
        data.remove('synced_at');

        if (localId == null) continue;

        // Check if record exists locally
        final existing = await db.query(
          table,
          where: 'id = ?',
          whereArgs: [localId],
        );

        if (existing.isEmpty) {
          // Insert new record (preserve original ID)
          data['id'] = localId;
          try {
            await db.insert(table, data);
          } catch (e) {
            // ID conflict - update instead
            await db.update(table, data, where: 'id = ?', whereArgs: [localId]);
          }
        } else {
          // Update existing record
          await db.update(table, data, where: 'id = ?', whereArgs: [localId]);
        }
      }
    } catch (e) {
      print('  ❌ $table sync error: $e');
    }
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
}
