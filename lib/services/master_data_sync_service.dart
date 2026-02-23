import 'package:ruchiserv/core/app_logger.dart';
// lib/services/master_data_sync_service.dart
// Multi-tenant master data sync service for DynamoDB
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import '../db/aws/aws_api.dart';
import 'package:sqflite/sqflite.dart';
import 'cloud_sync_service.dart';
import 'connectivity_service.dart';

/// Service to sync firm-specific master data (ingredients, dishes, BOM) with AWS DynamoDB.
///
/// Architecture:
/// - Base seed data: firmId = 'SEED' (bundled with app, read-only)
/// - Firm customizations: firmId = actual firm ID (synced to AWS)
/// - When user edits seed data, a copy is created with their firmId
class MasterDataSyncService {
  static final MasterDataSyncService _instance =
      MasterDataSyncService._internal();
  factory MasterDataSyncService() => _instance;
  MasterDataSyncService._internal();

  final _db = DatabaseHelper();

  // Tables to sync
  static const _syncTables = [
    'ingredients_master',
    'dish_master',
    'recipe_detail',
    'utensils',
    'vehicles',
  ];

  /// Get current firm ID from SharedPreferences
  Future<String?> _getFirmId() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString('last_firm');
  }

  // ============ SYNC TO AWS ============

  /// Sync all modified master data to AWS
  /// Called after user saves an ingredient/dish/BOM edit
  Future<void> syncToAWS() async {
    final firmId = await _getFirmId();
    if (firmId == null || firmId == 'DEFAULT') {
      AppLogger.warning('⚠️ MasterDataSync: No firmId, skipping sync');
      return;
    }

    final isOnline = await ConnectivityService().isOnline();
    if (!isOnline) {
      AppLogger.warning('⚠️ MasterDataSync: Offline, will sync later');
      return;
    }

    AppLogger.info(
        '🔄 MasterDataSync: Syncing modified data for firm $firmId...');

    for (final table in _syncTables) {
      await _syncTableToAWS(table, firmId);
    }

    AppLogger.success('✅ MasterDataSync: Sync complete');
  }

  Future<void> _syncTableToAWS(String table, String firmId) async {
    try {
      final db = await _db.database;

      // Get all modified records for this firm
      final records = await db.query(
        table,
        where: 'firmId = ? AND isModified = 1',
        whereArgs: [firmId],
      );

      if (records.isEmpty) {
        AppLogger.info('  📤 $table: No modified records');
        return;
      }

      AppLogger.info('  📤 $table: Syncing ${records.length} records...');

      for (final record in records) {
        final success = await CloudSyncService().syncRecord(
          table: table,
          recordId: record['id'] as int,
          data: record,
        );

        if (success) {
          await db.update(table, {'isModified': 0},
              where: 'id = ?', whereArgs: [record['id']]);
        }
      }
    } catch (e) {
      AppLogger.info('  ❌ $table sync error: $e');
    }
  }

  // ============ SYNC FROM AWS ============

  /// Fetch master data from AWS for a firm
  /// Called on login or when user switches firms
  Future<void> syncFromAWS() async {
    final firmId = await _getFirmId();
    if (firmId == null || firmId == 'DEFAULT') {
      AppLogger.warning('⚠️ MasterDataSync: No firmId, using seed data only');
      return;
    }

    final isOnline = await ConnectivityService().isOnline();
    if (!isOnline) {
      AppLogger.warning('⚠️ MasterDataSync: Offline, using local data');
      return;
    }

    AppLogger.info('🔄 MasterDataSync: Fetching data for firm $firmId...');

    for (final table in _syncTables) {
      await _syncTableFromAWS(table, firmId);
    }

    AppLogger.success('✅ MasterDataSync: Data fetched');
  }

  Future<void> _syncTableFromAWS(String table, String firmId) async {
    try {
      // Query DynamoDB for all records with this firmId in the unified table
      final resp = await AwsApi.callDbHandler(
        method: 'GET',
        table: 'ruchiserv_data',
        firmId: firmId, // Pass firmId for Lambda authentication
        filters: {
          'pk': firmId,
          'sk_prefix': '$table#', // All records for this table
        },
      );

      // Unified Lambda returns {'Items': [...]} or {'Items': [], ...}
      final records = resp['Items'] as List?;
      if (records == null || records.isEmpty) {
        AppLogger.info('  📥 $table: No cloud data found');
        return;
      }

      AppLogger.info(
          '  📥 $table: Received ${records.length} records from cloud');

      final db = await _db.database;

      for (final record in records) {
        // Remove DynamoDB keys before local insert
        final data = Map<String, dynamic>.from(record);

        // Parse local_id if present, otherwise use 'id'
        final rawId = data['local_id'] ?? data['id'];
        final recordId = int.tryParse(rawId.toString());

        if (recordId == null) continue;

        data.remove('pk');
        data.remove('sk');
        data.remove('table_name');
        data.remove('local_id');
        data.remove('synced_at');
        data.remove('gsi_partition');
        data.remove('gsi_sort');

        data['id'] = recordId;
        data['isModified'] = 0; // Already synced

        // Sanitize for SQLite (convert string numbers back)
        final sanitized = CloudSyncService.sanitizeForSqlite(data);

        // Upsert: Update if exists, insert if not
        await db.insert(table, sanitized,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    } catch (e) {
      AppLogger.info('  ❌ $table fetch error: $e');
    }
  }

  // ============ FIRM-SPECIFIC COPY ============

  /// When user edits seed data, create a firm-specific copy
  /// Returns the new ID of the copied record
  Future<int> createFirmCopy({
    required String table,
    required int baseId,
    required Map<String, dynamic> modifiedData,
  }) async {
    final firmId = await _getFirmId();
    if (firmId == null) throw Exception('No firm ID');

    final db = await _db.database;

    // Get seed data
    final seed = await db.query(
      table,
      where: 'baseId = ? AND firmId = ?',
      whereArgs: [baseId, 'SEED'],
    );

    if (seed.isEmpty) throw Exception('Seed data not found');

    // Merge seed + modifications
    final newRecord = Map<String, dynamic>.from(seed.first);
    newRecord.remove('id'); // Let autoincrement generate new ID
    newRecord['firmId'] = firmId;
    newRecord['baseId'] = baseId;
    newRecord['isModified'] = 1;
    newRecord['updatedAt'] = DateTime.now().toIso8601String();

    // Apply user modifications
    newRecord.addAll(modifiedData);

    // Insert firm-specific copy
    final newId = await db.insert(table, newRecord);

    AppLogger.debug(
        '📝 Created firm copy: $table #$newId (from seed #$baseId)');

    return newId;
  }

  // ============ QUERY HELPERS ============

  /// Get ingredients for current firm (firm-specific + seed data)
  Future<List<Map<String, dynamic>>> getIngredientsForFirm() async {
    final firmId = await _getFirmId() ?? 'DEFAULT';
    final db = await _db.database;

    // Get firm-specific data
    final firmData = await db.query(
      'ingredients_master',
      where: 'firmId = ?',
      whereArgs: [firmId],
      orderBy: 'category, name',
    );

    // Get seed data (excluding items user has customized)
    final customizedBaseIds =
        firmData.map((r) => r['baseId']).where((id) => id != null).toList();

    String seedWhere = "firmId = 'SEED'";
    if (customizedBaseIds.isNotEmpty) {
      seedWhere += " AND baseId NOT IN (${customizedBaseIds.join(',')})";
    }

    final seedData = await db.rawQuery(
      'SELECT * FROM ingredients_master WHERE $seedWhere ORDER BY category, name',
    );

    // Combine: firm data + remaining seed data
    return [...firmData, ...seedData];
  }

  /// Get dishes for current firm (firm-specific + seed data)
  Future<List<Map<String, dynamic>>> getDishesForFirm() async {
    final firmId = await _getFirmId() ?? 'DEFAULT';
    final db = await _db.database;

    final firmData = await db.query(
      'dish_master',
      where: 'firmId = ?',
      whereArgs: [firmId],
      orderBy: 'category, name',
    );

    final customizedBaseIds =
        firmData.map((r) => r['baseId']).where((id) => id != null).toList();

    String seedWhere = "firmId = 'SEED'";
    if (customizedBaseIds.isNotEmpty) {
      seedWhere += " AND baseId NOT IN (${customizedBaseIds.join(',')})";
    }

    final seedData = await db.rawQuery(
      'SELECT * FROM dish_master WHERE $seedWhere ORDER BY category, name',
    );

    return [...firmData, ...seedData];
  }

  /// Get BOM/recipe details for a dish
  Future<List<Map<String, dynamic>>> getBOMForDish(int dishId) async {
    final firmId = await _getFirmId() ?? 'DEFAULT';
    final db = await _db.database;

    // First check for firm-specific BOM
    var bom = await db.query(
      'recipe_detail',
      where: 'dish_id = ? AND firmId = ?',
      whereArgs: [dishId, firmId],
    );

    // If no firm-specific, use seed data
    if (bom.isEmpty) {
      bom = await db.query(
        'recipe_detail',
        where: 'dish_id = ? AND firmId = ?',
        whereArgs: [dishId, 'SEED'],
      );
    }

    return bom;
  }
}
