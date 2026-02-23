import 'package:ruchiserv/core/app_logger.dart';
// lib/services/cloud_sync_service.dart
// @locked
// Full AWS DynamoDB sync service for multi-device, multi-user cloud operations
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart'; // For ConflictAlgorithm
import '../db/database_helper.dart';
import '../db/aws/aws_api.dart';
import '../db/sync_event.dart'; // Added
import 'connectivity_service.dart';
import '../config/app_config.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

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

  final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);
  final _db = DatabaseHelper();

  // Tables that sync to AWS
  static const syncTables = [
    'firms', // v38: Firm profile sync for cross-device settings
    'users', // v37: Multi-device user sync (PRIORITY)
    'authorized_mobiles', // v37: Multi-device login authorization (PRIORITY)
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
    'ingredients_master',
    'dish_master',
    'recipe_detail',
    'salary_disbursements',
  ];

  /// Get current firm ID
  Future<String?> _getFirmId() async {
    final sp = await SharedPreferences.getInstance();
    final f = sp.getString('last_firm');
    return f?.toUpperCase().trim();
  }

  // ============ SYNC METADATA ============

  Future<String?> _getLastSync(String table, String firmId) async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString('last_sync_${table}_${firmId.toUpperCase()}');
  }

  Future<void> _setLastSync(
      String table, String firmId, String timestamp) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('last_sync_${table}_${firmId.toUpperCase()}', timestamp);
  }
  // ============ AWS-FIRST WRITE (v38) ============

  /// AWS-First write: Prioritizes cloud write, falls back to local queue
  /// Returns the local record ID for UI continuity
  ///
  /// Flow:
  /// - Online: PUT to AWS → Success → Insert to SQLite with sync_status='SYNCED'
  /// - Offline: Insert to SQLite with sync_status='PENDING' → Queue for later
  Future<int?> awsFirstWrite({
    required String table,
    required Map<String, dynamic> data,
  }) async {
    final firmId = await _getFirmId();
    if (firmId == null || firmId == 'DEFAULT') {
      AppLogger.warning('⚠️ CloudSync: No firmId, cannot write');
      return null;
    }

    isSyncing.value = true;
    try {
      final isOnline = await ConnectivityService().isOnline();
      final now = DateTime.now().toIso8601String();

      // Prepare data with required fields
      data['uuid'] = data['uuid'] ?? const Uuid().v4();
      data['updatedAt'] = now;
      data['createdAt'] = data['createdAt'] ?? now;
      data['firmId'] = firmId;

      final db = await _db.database;

      if (isOnline) {
        // AWS-FIRST: Attempt cloud write first
        try {
          final awsData = _prepareAwsRecord(table, firmId, data);
          final resp = await AwsApi.pushToQueue(
            payload: {
              'method': 'PUT',
              'table': 'ruchiserv_data',
              'firmId': firmId,
              'data': _injectGsiAttributes(table, firmId, awsData),
            },
          );

          if (resp['error'] == null &&
              resp['status'] != 'error' &&
              resp['message'] != 'This account is suspended') {
            // SUCCESS: Mirror to local with SYNCED status
            data['sync_status'] = 'SYNCED';
            data['synced_at'] = now;

            final localId = await db.insert(table, data,
                conflictAlgorithm: ConflictAlgorithm.replace);
            AppLogger.success(
                '✅ CloudSync [AWS-First]: $table#$localId synced to cloud and cached locally');
            return localId;
          } else {
            AppLogger.warning(
                '⚠️ CloudSync [AWS-First]: Backend Error: ${resp['message'] ?? resp['error']}');
          }
        } catch (e) {
          AppLogger.warning(
              '⚠️ CloudSync [AWS-First]: Cloud write failed, falling back to queue: $e');
        }
      }

      // OFFLINE or AWS FAILED: Queue locally with PENDING status
      data['sync_status'] = 'PENDING';
      data['synced_at'] = null;

      final localId = await db.insert(table, data,
          conflictAlgorithm: ConflictAlgorithm.replace);
      await _queuePendingSyncEnhanced(table, localId, data, 'PUT');
      AppLogger.info(
          '📥 CloudSync [AWS-First]: $table#$localId queued locally (offline/error)');
      return localId;
    } finally {
      isSyncing.value = false;
    }
  }

  /// AWS-First update: Similar to write but for existing records
  Future<bool> awsFirstUpdate({
    required String table,
    required int recordId,
    required Map<String, dynamic> data,
  }) async {
    final firmId = await _getFirmId();
    if (firmId == null || firmId == 'DEFAULT') return false;

    isSyncing.value = true;
    try {
      final isOnline = await ConnectivityService().isOnline();
      final now = DateTime.now().toIso8601String();

      data['updatedAt'] = now;
      data['id'] = recordId;

      final db = await _db.database;

      if (isOnline) {
        try {
          final awsData = _prepareAwsRecord(table, firmId, data);
          final resp = await AwsApi.pushToQueue(
            payload: {
              'method': 'PUT',
              'table': 'ruchiserv_data',
              'firmId': firmId,
              'data': _injectGsiAttributes(table, firmId, awsData),
            },
          );

          if (resp['error'] == null &&
              resp['status'] != 'error' &&
              resp['message'] != 'This account is suspended') {
            data['sync_status'] = 'SYNCED';
            data['synced_at'] = now;
            await db
                .update(table, data, where: 'id = ?', whereArgs: [recordId]);
            AppLogger.success(
                '✅ CloudSync [AWS-First]: $table#$recordId updated and synced');
            return true;
          } else {
            AppLogger.warning(
                '⚠️ CloudSync [AWS-First]: Backend Update Error: ${resp['message'] ?? resp['error']}');
          }
        } catch (e) {
          AppLogger.warning(
              '⚠️ CloudSync [AWS-First]: Update failed, queueing: $e');
        }
      }

      data['sync_status'] = 'PENDING';
      await db.update(table, data, where: 'id = ?', whereArgs: [recordId]);
      await _queuePendingSyncEnhanced(table, recordId, data, 'PUT');
      AppLogger.info(
          '📥 CloudSync [AWS-First]: $table#$recordId queued for update');
      return true;
    } finally {
      isSyncing.value = false;
    }
  }

  /// AWS-First delete: Delete from cloud first, then local
  Future<bool> awsFirstDelete({
    required String table,
    required int recordId,
  }) async {
    final firmId = await _getFirmId();
    if (firmId == null) return false;

    isSyncing.value = true;
    try {
      final isOnline = await ConnectivityService().isOnline();
      final db = await _db.database;

      // Get record data for SK generation
      final localData = await _db.getRecordById(table, recordId);
      final skValue = (localData != null && localData['uuid'] != null)
          ? localData['uuid'].toString()
          : '$recordId';

      if (isOnline) {
        try {
          final resp = await AwsApi.pushToQueue(
            payload: {
              'method': 'DELETE',
              'table': 'ruchiserv_data',
              'firmId': firmId,
              'filters': {
                'pk': firmId,
                'sk': '$table#$skValue',
              },
            },
          );

          if (resp['error'] == null && resp['status'] != 'error') {
            await db.delete(table, where: 'id = ?', whereArgs: [recordId]);
            AppLogger.success(
                '✅ CloudSync [AWS-First]: $table#$recordId deleted from cloud and local');
            return true;
          }
        } catch (e) {
          AppLogger.warning(
              '⚠️ CloudSync [AWS-First]: Delete failed, queueing: $e');
        }
      }

      // Queue delete and mark local as deleted (soft delete or queue)
      await _queuePendingSyncEnhanced(table, recordId, {}, 'DELETE');
      await db.delete(table, where: 'id = ?', whereArgs: [recordId]);
      AppLogger.info(
          '📥 CloudSync [AWS-First]: $table#$recordId queued for delete');
      return true;
    } finally {
      isSyncing.value = false;
    }
  }

  /// Prepare AWS record with required DynamoDB fields
  Map<String, dynamic> _prepareAwsRecord(
      String table, String firmId, Map<String, dynamic> data) {
    final awsData = Map<String, dynamic>.from(data);
    awsData['pk'] = firmId;

    String skValue;
    if (table == 'firms') {
      skValue = firmId;
    } else {
      skValue = data['uuid']?.toString() ??
          data['id']?.toString() ??
          const Uuid().v4();
    }

    awsData['sk'] = '$table#$skValue';
    awsData['table_name'] = table;
    awsData['local_id'] = data['id'];
    awsData['firmId'] = firmId;
    awsData['synced_at'] = DateTime.now().toIso8601String();

    return awsData;
  }

  /// Enhanced queue with record_id tracking
  Future<void> _queuePendingSyncEnhanced(
    String table,
    int recordId,
    Map<String, dynamic> data,
    String action,
  ) async {
    final db = await _db.database;
    await db.insert('pending_sync', {
      'table_name': table,
      'record_id': recordId,
      'data': jsonEncode({'id': recordId, ...data}),
      'action': action,
      'timestamp': DateTime.now().toIso8601String(),
      'retry_count': 0,
      'last_error': null,
    });
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
      AppLogger.warning('⚠️ CloudSync: No firmId, skipping sync');
      return false;
    }

    final isOnline = await ConnectivityService().isOnline();
    if (!isOnline) {
      // Queue for later sync
      await _queuePendingSync(table, recordId, data, 'PUT');
      AppLogger.info('📥 CloudSync: Offline - queued for later');
      return false;
    }

    try {
      // Prepare DynamoDB record
      final awsData = Map<String, dynamic>.from(data);
      awsData['pk'] = firmId;
      // v38: For 'firms' table, use firmId as SK to avoid collisions across devices
      // v40: For other tables, use uuid if available to prevent multi-device collisions
      String skValue;
      if (table == 'firms') {
        skValue = firmId;
      } else {
        // If the record has a 'uuid' field, use it. Otherwise fallback to ID.
        // In v40+, we will ensure all new records have a UUID.
        skValue = data['uuid']?.toString() ?? '$recordId';
      }

      awsData['sk'] = '$table#$skValue';
      awsData['table_name'] = table;
      awsData['local_id'] = recordId;
      awsData['firmId'] = firmId; // v37: Ensure firmId is in attributes
      awsData['synced_at'] = DateTime.now().toIso8601String();

      final resp = await AwsApi.pushToQueue(
        payload: {
          'method': 'PUT',
          'table': 'ruchiserv_data',
          'firmId': firmId, // Consolidate auth: Required by backend
          'data': _injectGsiAttributes(table, firmId, awsData),
        },
      );

      if (resp['error'] != null || resp['status'] == 'error') {
        AppLogger.error(
            '❌ CloudSync: Failed to queue $table#$recordId: ${resp['error'] ?? resp['message']}');
        await _queuePendingSync(table, recordId, data, 'PUT');
        return false;
      }

      AppLogger.success('✅ CloudSync: Queued $table#$recordId for SQS');
      return true;
    } catch (e) {
      AppLogger.error('❌ CloudSync: Exception syncing $table#$recordId: $e');
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
      // v40: Use UUID if available for deletion key
      final localData = await _db.getRecordById(table, recordId);
      final skValue = (localData != null && localData['uuid'] != null)
          ? localData['uuid'].toString()
          : '$recordId';

      final resp = await AwsApi.pushToQueue(
        payload: {
          'method': 'DELETE',
          'table': 'ruchiserv_data',
          'firmId': firmId, // Consolidate auth: Required by backend
          'filters': {
            'pk': firmId,
            'sk': '$table#$skValue',
          },
        },
      );

      if (resp['error'] != null || resp['status'] == 'error') {
        AppLogger.error(
            '❌ CloudSync: Failed to queue delete $table#$recordId: ${resp['error'] ?? resp['message']}');
        return false;
      }

      AppLogger.success('✅ CloudSync: Queued delete $table#$recordId for SQS');
      return true;
    } catch (e) {
      AppLogger.error('❌ CloudSync: Exception deleting $table#$recordId: $e');
      return false;
    }
  }

  // ============ FULL SYNC FROM AWS ============

  /// Sync all data from AWS for the current firm
  /// Called on login or when switching devices
  Future<void> fullSyncFromCloud() async {
    final firmId = await _getFirmId();
    if (firmId == null || firmId == 'DEFAULT') {
      AppLogger.warning('⚠️ CloudSync: No firmId for full sync');
      return;
    }

    final isOnline = await ConnectivityService().isOnline();
    if (!isOnline) {
      AppLogger.warning('⚠️ CloudSync: Offline, cannot sync from cloud');
      return;
    }

    AppLogger.info('🔄 CloudSync: Starting full sync for firm $firmId...');

    for (final table in syncTables) {
      await syncTableFromCloud(table, firmId);
    }

    AppLogger.success('✅ CloudSync: Full sync complete');
  }

  Future<void> syncTableFromCloud(String table, String firmId,
      {bool force = false}) async {
    // 1. Normalize Firm ID
    firmId = firmId.trim().toUpperCase();

    AppLogger.info(
        '🔄 CloudSync: Syncing table $table for firm $firmId... (force: $force)');
    try {
      // DEBUG: Print query params
      AppLogger.info('  👉 Querying AWS: pk=$firmId, sk_prefix=$table#');

      final lastSync = force ? null : await _getLastSync(table, firmId);

      final resp = await AwsApi.callDbHandler(
        method: 'GET',
        table: 'ruchiserv_data',
        firmId: firmId, // FIX: Include firmId for Lambda authentication
        filters: {
          'pk': firmId,
          'sk_prefix': '$table#',
          if (lastSync != null) 'since': lastSync,
        },
      );

      // DEBUG: Print raw response keys
      AppLogger.info('  📥 AWS Response Keys: ${resp.keys.toList()}');
      if (resp.containsKey('Items')) {
        AppLogger.info('  📥 Items count: ${(resp['Items'] as List).length}');
      }

      // Handle response - Lambda returns items directly as a List in response body
      // or as a Map with error field
      List<dynamic> records = [];

      if (resp['error'] != null) {
        AppLogger.info('  ❌ $table: API error: ${resp['error']}');
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
        AppLogger.info('  📥 $table: No cloud data (resp: $resp)');
        return;
      }

      if (records.isEmpty) {
        AppLogger.info('  📥 $table: No cloud data found (empty list)');
        return;
      }

      AppLogger.info(
          '  📥 $table: Received ${records.length} records to processing...');

      final db = await _db.database;

      for (final record in records) {
        try {
          final data = Map<String, dynamic>.from(record);
          // Parse local_id - DynamoDB returns numbers as strings
          final localIdRaw = data['local_id'];
          final localId =
              localIdRaw == null ? null : int.tryParse(localIdRaw.toString());

          // Remove DynamoDB metadata (but keep firmId - needed for tables)
          data.remove('pk');
          data.remove('sk');
          data.remove('table_name');
          data.remove('local_id');
          data.remove('synced_at');
          data.remove('gsi_partition'); // Fix: Remove GSI keys not in local DB
          data.remove('gsi_sort'); // Fix: Remove GSI keys not in local DB
          // data.remove('firmId'); // KEEP firmId, required for local DB constraints

          // Sanitize for SQLite (convert string numbers back)
          final sanitized = sanitizeForSqlite(data);

          // CRITICAL: Remove DynamoDB metadata that doesn't exist in local SQLite
          // Note: gsi_partition and gsi_sort are NOW in SQLite (v41) - keep them!
          sanitized.remove('pk');
          sanitized.remove('sk');
          sanitized.remove('table_name');
          sanitized.remove('local_id');
          sanitized.remove('synced_at');

          // DEBUG: Print first record to check sanitization
          if (records.indexOf(record) == 0) {
            AppLogger.info('  📝 Processing first record: $sanitized');
          }

          // v38: Handle 'firms' table specially - uses firmId as unique key, not id
          if (table == 'firms') {
            final recordFirmId = sanitized['firmId']?.toString();
            if (recordFirmId == null || recordFirmId.isEmpty) {
              AppLogger.info('  ⚠️ Skipping firms record without firmId');
              continue;
            }

            final existing = await db.query(
              'firms',
              where: 'LOWER(firmId) = LOWER(?)',
              whereArgs: [recordFirmId],
            );

            if (existing.isEmpty) {
              try {
                await db.insert('firms', sanitized,
                    conflictAlgorithm: ConflictAlgorithm.replace);
                AppLogger.info('    ✅ Inserted firms #$recordFirmId');
              } catch (e) {
                AppLogger.info(
                    '    ❌ firms insert failed for firmId=$recordFirmId: $e');
              }
            } else {
              // Update existing record, preserving local id
              sanitized['id'] = existing.first['id'];
              await db.insert('firms', sanitized,
                  conflictAlgorithm: ConflictAlgorithm.replace);
              AppLogger.info('    ✅ Updated firms #$recordFirmId');
            }
            continue; // Skip standard processing
          }

          // v43: Resilient processing for records missing local_id (e.g. seeded via script)
          int? localIdMatch = localId;

          // v44: ALWAYS check natural keys for users table to prevent multi-device duplicates
          if (table == 'users' && sanitized['userId'] != null) {
            final res = await db.query('users',
                where: 'userId = ?',
                whereArgs: [sanitized['userId']],
                limit: 1);
            if (res.isNotEmpty) localIdMatch = res.first['id'] as int;
          } else if (localIdMatch == null) {
            // Try to find existing record by natural unique keys
            if (table == 'authorized_mobiles' &&
                sanitized['firmId'] != null &&
                sanitized['mobile'] != null) {
              final res = await db.query('authorized_mobiles',
                  where: 'firmId = ? AND mobile = ?',
                  whereArgs: [sanitized['firmId'], sanitized['mobile']],
                  limit: 1);
              if (res.isNotEmpty) localIdMatch = res.first['id'] as int;
            } else if (sanitized['uuid'] != null) {
              // Standard matching by UUID for all other tables
              final res = await db.query(table,
                  where: 'uuid = ?', whereArgs: [sanitized['uuid']], limit: 1);
              if (res.isNotEmpty) localIdMatch = res.first['id'] as int;
            }
          }

          if (localIdMatch == null) {
            // Truly new record (no ID, no UUID match)
            try {
              await db.insert(table, sanitized,
                  conflictAlgorithm: ConflictAlgorithm.replace);
              // AppLogger.info('    ✅ Inserted new $table record');
            } catch (e) {
              AppLogger.info('    ❌ $table initial insert failed: $e');
            }
          } else {
            // Update existing record
            sanitized['id'] = localIdMatch;
            await db.insert(table, sanitized,
                conflictAlgorithm: ConflictAlgorithm.replace);
            // AppLogger.info('    ✅ Updated $table #$localIdMatch');
          }
        } catch (e) {
          AppLogger.info('  ⚠️ Error processing record: $e');
        }
      }
      AppLogger.info('  ✅ $table sync processing complete');
      // After successful sync, update timestamp and notify UI
      final latestTimestamp = records.isNotEmpty
          ? records
              .map((r) => r['updatedAt']?.toString() ?? '')
              .reduce((a, b) => a.compareTo(b) > 0 ? a : b)
          : null;

      if (latestTimestamp != null && latestTimestamp.isNotEmpty) {
        await _setLastSync(table, firmId, latestTimestamp);
      }

      // Broadcast event for UI update
      _db.syncStreamController.add(SyncEvent(
        table: table,
        action: 'CLOUD_SYNC',
        data: {'count': records.length},
      ));

      AppLogger.success('✅ $table sync finished. Notified listeners.');
    } catch (e) {
      AppLogger.info('  ❌ $table sync error: $e');
    }
  }

  /// Fetches live report data from Cloud using Phase 2 GSI optimization.
  /// This is much faster/cheaper than a Scan as it uses GSI_FirmTable_Date.
  static Future<List<Map<String, dynamic>>> getLiveCloudReport({
    required String table,
    required String startDate,
    required String endDate,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final firmId =
        prefs.getString('last_firm'); // FIX: Use correct key 'last_firm'
    if (firmId == null) return [];

    try {
      final resp = await AwsApi.queryGsi(
        table: 'ruchiserv_data',
        indexName: 'GSI_FirmTable_Date',
        pkValue: '$firmId#$table',
        firmId: firmId, // FIX: Pass firmId for Lambda auth
        skValue: startDate,
        skValueEnd: endDate,
        skOp: 'between',
      );

      if (resp['error'] != null) {
        AppLogger.info('🔴 [Cloud Report Error] ${resp['error']}');
        return [];
      }

      final items = resp['Items'] as List?;
      if (items == null) return [];

      return items.map((i) {
        if (i is Map) {
          final stringMap = _deepCastMap(i);
          return sanitizeForSqlite(stringMap);
        }
        return <String, dynamic>{};
      }).toList();
    } catch (e) {
      AppLogger.info('🔴 [Cloud Report Exception] $e');
      return [];
    }
  }

  /// Recursively casts a Map<dynamic, dynamic> to Map<String, dynamic>
  static Map<String, dynamic> _deepCastMap(Map dynamicMap) {
    var stringMap = <String, dynamic>{};
    for (var key in dynamicMap.keys) {
      final value = dynamicMap[key];
      if (value is Map) {
        stringMap[key.toString()] = _deepCastMap(value);
      } else if (value is List) {
        stringMap[key.toString()] =
            value.map((e) => e is Map ? _deepCastMap(e) : e).toList();
      } else {
        stringMap[key.toString()] = value;
      }
    }
    return stringMap;
  }

  /// Injects GSI attributes for optimized cloud queries
  static Map<String, dynamic> _injectGsiAttributes(
      String table, String firmId, Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);

    // 1. Partition: firmId#tableName
    result['gsi_partition'] = '$firmId#$table';

    // 2. Sort key: The most common date/sort field for this table
    result['gsi_sort'] = _getGsiSortKey(table, data);

    return result;
  }

  /// Determines which field to use for GSI sorting
  static String _getGsiSortKey(String table, Map<String, dynamic> data) {
    switch (table) {
      case 'orders':
        return data['eventDate']?.toString() ?? data['date']?.toString() ?? '';
      case 'finance':
      case 'attendance':
      case 'invoices':
        return data['date']?.toString() ??
            data['invoiceDate']?.toString() ??
            '';
      case 'staff':
        return data['joinDate']?.toString() ?? '';
      case 'salary_disbursements':
        return data['monthYear']?.toString() ?? '';
      default:
        return data['createdAt']?.toString() ?? '';
    }
  }

  /// Convert DynamoDB string numbers to proper types for SQLite
  static Map<String, dynamic> sanitizeForSqlite(Map<String, dynamic> data) {
    // Fields that must ALWAYS remain strings, even if they look like numbers
    const stringFields = {
      'mobile',
      'phone',
      'contact',
      'firmId',
      'userId',
      'gstin',
      'date',
      'time',
      'eventDate',
      'eventTime',
      'createdAt',
      'updatedAt',
      'deletedAt',
      'synced_at',
      'joinedAt',
      'sku_name',
      'vehicleNumber',
      'zip',
      'pin',
      'postalCode'
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
      if (stringFields.contains(key) ||
          key.endsWith('Name') ||
          key.endsWith('Url')) {
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

    AppLogger.info(
        '🔄 CloudSync: Processing ${pending.length} pending syncs...');

    for (final item in pending) {
      final table = item['table_name'] as String;
      final action = item['action'] as String;
      final dataJson = item['data'] as String;
      final data = jsonDecode(dataJson) as Map<String, dynamic>;
      final recordId = item['record_id'] as int? ??
          int.tryParse(data['id']?.toString() ?? '0') ??
          0;
      final retryCount = item['retry_count'] as int? ?? 0;

      if (recordId == 0) {
        AppLogger.warning(
            '⚠️ CloudSync: Invalid record ID in pending queue. Deleting item ${item['id']}');
        await db
            .delete('pending_sync', where: 'id = ?', whereArgs: [item['id']]);
        continue;
      }

      bool success = false;
      String? errorMessage;

      try {
        if (action == 'PUT') {
          success =
              await syncRecord(table: table, recordId: recordId, data: data);
        } else if (action == 'DELETE') {
          success = await deleteRecord(table: table, recordId: recordId);
        }
      } catch (e) {
        errorMessage = e.toString();
        AppLogger.error('❌ CloudSync: Exception processing pending sync: $e');
      }

      if (success) {
        // v38: Update local record's sync_status to SYNCED
        if (action == 'PUT') {
          try {
            await db.update(
              table,
              {
                'sync_status': 'SYNCED',
                'synced_at': DateTime.now().toIso8601String()
              },
              where: 'id = ?',
              whereArgs: [recordId],
            );
            AppLogger.success(
                '✅ CloudSync: Updated $table#$recordId sync_status to SYNCED');
          } catch (e) {
            AppLogger.warning(
                '⚠️ CloudSync: Could not update sync_status for $table#$recordId: $e');
          }
        }
        await db
            .delete('pending_sync', where: 'id = ?', whereArgs: [item['id']]);
      } else {
        // v38: Update retry_count and last_error for failed syncs
        await db.update(
          'pending_sync',
          {
            'retry_count': retryCount + 1,
            'last_error': errorMessage ?? 'Unknown error',
          },
          where: 'id = ?',
          whereArgs: [item['id']],
        );
        AppLogger.warning(
            '⚠️ CloudSync: Retry $retryCount failed for $table#$recordId');
      }
    }

    AppLogger.success('✅ CloudSync: Pending sync complete');
  }

  // ============ BATCH SYNC HELPERS ============

  /// Sync all records of a table to AWS (for initial migration)
  Future<void> syncTableToCloud(String table) async {
    final firmId = await _getFirmId();
    if (firmId == null) return;

    final db = await _db.database;
    final records = await db.query(table);

    AppLogger.info(
        '📤 CloudSync: Syncing ${records.length} $table records to cloud...');

    for (final record in records) {
      final id = record['id'] as int;
      await syncRecord(table: table, recordId: id, data: record);
    }

    AppLogger.success('✅ CloudSync: $table batch sync complete');
  }

  // ============ POLLING & BACKGROUND SYNC ============
  // @locked - Push-Pull Architecture. Changed from polling to event-driven sync.
  // See ARCHITECTURE_SYNC.md for rationale.

  bool _isPolling = false;

  /// Start sync listeners (Push-Pull Architecture)
  /// Call this from main.dart or after login
  void startPolling() {
    if (_isPolling) return;

    // SAFETY: Check if Cloud Sync is allowed
    // Need to import '../config/app_config.dart' at top of file
    // But since it's a static access, we can add import and use it
    if (!AppConfig.enableCloudSync) {
      AppLogger.info(
          '🛡️ SAFE MODE: Cloud Sync is DISABLED to protect Production DB.');
      AppLogger.info(
          '👉 To enable: flutter run --dart-define=FORCE_DEV_SYNC=true');
      return;
    }

    _isPolling = true;
    AppLogger.info('🔄 CloudSync: Starting Push-Pull sync (no polling)...');

    // MUTATION LISTENER: Listen to all DB changes and sync them (PUSH)
    // This is the "Push" part of Push-Pull: local changes → cloud
    DatabaseHelper().syncStreamController.stream.listen((event) async {
      AppLogger.info(
          '📥 CloudSync: Received event: ${event.table} ${event.action}');
      final recordId = int.tryParse(event.data['id']?.toString() ?? '0') ?? 0;
      if (recordId == 0) return;

      if (event.action == 'DELETE') {
        await deleteRecord(table: event.table, recordId: recordId);
      } else {
        // INSERT or UPDATE are handled by syncRecord (PUT)
        await syncRecord(
            table: event.table, recordId: recordId, data: event.data);
      }
    });

    // PENDING QUEUE PROCESSOR: Process failed syncs every 30 seconds
    // This is a safety net, not a primary sync mechanism
    Stream.periodic(const Duration(seconds: 30)).listen((_) async {
      if (!_isFrontendActive) return;
      await processPendingSync();
    });

    // ================================================
    // PULL POLLING REMOVED (Push-Pull Architecture)
    // ================================================
    // The following code has been intentionally removed to implement
    // the Push-Pull sync architecture. Instead of periodically polling
    // for updates (which cost ~$12,000/month for 10k users), we now:
    //
    // 1. PUSH: Local changes trigger immediate cloud writes (above listener)
    // 2. PULL: FCM silent push from server triggers immediate sync
    //          (handled in FcmService._handleSyncMessage)
    //
    // See ARCHITECTURE_SYNC.md for cost analysis and design rationale.
    // ================================================
  }

  // ============ LIFECYCLE MANAGEMENT ============

  bool _isFrontendActive = true;

  /// Call this when app goes to background (paused/inactive)
  void setAppBackgrounded() {
    _isFrontendActive = false;
    AppLogger.info('🌙 CloudSync: App backgrounded - pausing polling');
  }

  /// Call this when app resumes (foreground)
  void setAppForegrounded() {
    _isFrontendActive = true;
    AppLogger.info('☀️ CloudSync: App foregrounded - resuming polling');
    // Trigger immediate check on resume
    processPendingSync();
    fullSyncFromCloud();
  }
}
