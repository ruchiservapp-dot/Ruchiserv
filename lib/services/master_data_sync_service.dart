// lib/services/master_data_sync_service.dart
// Multi-tenant master data sync service for DynamoDB
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import '../db/aws/aws_api.dart';
import 'connectivity_service.dart';

/// Service to sync firm-specific master data (ingredients, dishes, BOM) with AWS DynamoDB.
/// 
/// Architecture:
/// - Base seed data: firmId = 'SEED' (bundled with app, read-only)
/// - Firm customizations: firmId = actual firm ID (synced to AWS)
/// - When user edits seed data, a copy is created with their firmId
class MasterDataSyncService {
  static final MasterDataSyncService _instance = MasterDataSyncService._internal();
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
      print('⚠️ MasterDataSync: No firmId, skipping sync');
      return;
    }

    final isOnline = await ConnectivityService().isOnline();
    if (!isOnline) {
      print('⚠️ MasterDataSync: Offline, will sync later');
      return;
    }

    print('🔄 MasterDataSync: Syncing modified data for firm $firmId...');

    for (final table in _syncTables) {
      await _syncTableToAWS(table, firmId);
    }

    print('✅ MasterDataSync: Sync complete');
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
        print('  📤 $table: No modified records');
        return;
      }

      print('  📤 $table: Syncing ${records.length} records...');

      for (final record in records) {
        // Prepare data for DynamoDB (firmId is partition key)
        final data = Map<String, dynamic>.from(record);
        data['pk'] = firmId; // Partition key
        data['sk'] = '${table}#${record['id']}'; // Sort key
        
        await AwsApi.callDbHandler(
          method: 'PUT',
          table: 'master_data', // Single table for all master data
          data: data,
        );

        // Mark as synced
        await db.update(
          table,
          {'isModified': 0},
          where: 'id = ?',
          whereArgs: [record['id']],
        );
      }
    } catch (e) {
      print('  ❌ $table sync error: $e');
    }
  }

  // ============ SYNC FROM AWS ============

  /// Fetch master data from AWS for a firm
  /// Called on login or when user switches firms
  Future<void> syncFromAWS() async {
    final firmId = await _getFirmId();
    if (firmId == null || firmId == 'DEFAULT') {
      print('⚠️ MasterDataSync: No firmId, using seed data only');
      return;
    }

    final isOnline = await ConnectivityService().isOnline();
    if (!isOnline) {
      print('⚠️ MasterDataSync: Offline, using local data');
      return;
    }

    print('🔄 MasterDataSync: Fetching data for firm $firmId...');

    for (final table in _syncTables) {
      await _syncTableFromAWS(table, firmId);
    }

    print('✅ MasterDataSync: Data fetched');
  }

  Future<void> _syncTableFromAWS(String table, String firmId) async {
    try {
      // Query DynamoDB for all records with this firmId
      final resp = await AwsApi.callDbHandler(
        method: 'GET',
        table: 'master_data',
        filters: {
          'pk': firmId,
          'sk_prefix': '$table#', // All records for this table
        },
      );

      if (resp['status'] != 'success' || resp['data'] == null) {
        print('  📥 $table: No cloud data found');
        return;
      }

      final records = resp['data'] as List;
      print('  📥 $table: Received ${records.length} records from cloud');

      final db = await _db.database;
      
      for (final record in records) {
        // Remove DynamoDB keys before local insert
        final data = Map<String, dynamic>.from(record);
        data.remove('pk');
        data.remove('sk');
        data['isModified'] = 0; // Already synced
        
        // Upsert: Update if exists, insert if not
        final existing = await db.query(
          table,
          where: 'id = ? AND firmId = ?',
          whereArgs: [data['id'], firmId],
        );

        if (existing.isEmpty) {
          await db.insert(table, data);
        } else {
          await db.update(table, data, where: 'id = ?', whereArgs: [data['id']]);
        }
      }
    } catch (e) {
      print('  ❌ $table fetch error: $e');
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
    
    print('📝 Created firm copy: $table #$newId (from seed #$baseId)');
    
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
    final customizedBaseIds = firmData.map((r) => r['baseId']).where((id) => id != null).toList();
    
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

    final customizedBaseIds = firmData.map((r) => r['baseId']).where((id) => id != null).toList();
    
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
