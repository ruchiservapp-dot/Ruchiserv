import 'package:ruchiserv/core/app_logger.dart';
import 'package:ruchiserv/db/aws/aws_api.dart';
import 'package:ruchiserv/db/database_helper.dart';
import 'package:ruchiserv/db/sync_event.dart';
import 'package:ruchiserv/services/cloud_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class InventoryRepository {
  static final InventoryRepository _instance = InventoryRepository._internal();
  factory InventoryRepository() => _instance;
  InventoryRepository._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();

  // ---------- INGREDIENTS MASTER (Autocomplete & Seed Logic) ----------

  Future<List<Map<String, dynamic>>> getIngredientsMaster(String firmId) async {
    final db = await _dbHelper.database;

    // 1. Get Firm-Specific Data
    final firmData = await db.query(
      'ingredients_master',
      where: 'firmId = ?',
      whereArgs: [firmId],
      orderBy: 'category, name',
    );

    // 2. Get Seed Data (excluding overridden)
    final res = await db.query('firms', columns: ['showUniversalData'], where: 'firmId = ?', whereArgs: [firmId]);
    bool showUniversal = res.isNotEmpty ? (res.first['showUniversalData'] as int? ?? 1) == 1 : true;

    if (!showUniversal) return firmData;

    final customizedBaseIds = firmData.map((r) => r['baseId']).where((id) => id != null).toList();
    final firmIngNames = firmData.map((r) => (r['name'] as String?)?.toLowerCase()).where((n) => n != null).toSet();
    
    String seedWhere = "firmId = 'SEED'";
    if (customizedBaseIds.isNotEmpty) {
      seedWhere += " AND baseId NOT IN (${customizedBaseIds.join(',')})";
    }

    final seedData = await db.rawQuery('SELECT * FROM ingredients_master WHERE $seedWhere ORDER BY category, name');
    
    final filteredSeedData = seedData.where((sd) {
      final seedName = (sd['name'] as String?)?.toLowerCase();
      return seedName == null || !firmIngNames.contains(seedName);
    }).toList();
    
    final combined = [...firmData, ...filteredSeedData];
    combined.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    
    return combined;
  }

  Future<int> insertIngredient(Map<String, dynamic> data) async {
    final db = await _dbHelper.database;
    if (data['firmId'] == null) {
       final sp = await SharedPreferences.getInstance();
       final fid = sp.getString('last_firm');
       if (fid != null) data['firmId'] = fid;
    }
    data['createdAt'] = DateTime.now().toIso8601String();
    data['updatedAt'] = DateTime.now().toIso8601String();
    data['uuid'] = data['uuid'] ?? const Uuid().v4();
    return await db.insert('ingredients_master', data);
  }

  Future<List<Map<String, dynamic>>> getAllIngredients(String firmId) async {
    return await getIngredientsMaster(firmId);
  }

  Future<List<Map<String, dynamic>>> getAllDishes(String firmId) async {
    final db = await _dbHelper.database;
    return await db.query('dish_master', where: 'firmId = ? OR firmId = ?', whereArgs: [firmId, 'SEED'], orderBy: 'name');
  }

  Future<int> updateIngredient(int id, Map<String, dynamic> data) async {
    final db = await _dbHelper.database;
    data['updatedAt'] = DateTime.now().toIso8601String();
    return await db.update('ingredients_master', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> cancelPOsForOrder(int orderId) async {
    final db = await _dbHelper.database;
    final cloudSync = CloudSyncService();
    
    // Find POs linked to this order
    final pos = await db.query('purchase_orders', where: 'orderId = ?', whereArgs: [orderId]);
    for (var po in pos) {
      final poId = po['id'] as int;
      await cloudSync.awsFirstUpdate(
        table: 'purchase_orders',
        recordId: poId,
        data: {
          'status': 'CANCELLED',
          'updatedAt': DateTime.now().toIso8601String(),
        },
      );
      AppLogger.info('🚫 [Inventory] Cancelled PO #$poId for order #$orderId');
    }
  }

  Future<double> getLastServiceRate(String firmId, String serviceType) async {
    final db = await _dbHelper.database;
    final res = await db.query('service_rates', 
      where: 'firmId = ? AND serviceType = ?', 
      whereArgs: [firmId, serviceType],
      orderBy: 'updatedAt DESC',
      limit: 1,
    );
    return res.isNotEmpty ? (res.first['rate'] as num).toDouble() : 0.0;
  }

  // --- BOM & RECIPES ---

  Future<List<Map<String, dynamic>>> getBomForDish(String firmId, int dishId) async {
    final db = await _dbHelper.database;
    var result = await db.rawQuery('''
      SELECT rd.*, i.name as ingredientName, i.category, COALESCE(rd.unit_override, i.unit_of_measure) as unit,
             (rd.quantity_per_base_pax * 100) as quantityPer100Pax
      FROM recipe_detail rd JOIN ingredients_master i ON rd.ing_id = i.id
      WHERE rd.dish_id = ? AND rd.firmId = ? ORDER BY i.category, i.name
    ''', [dishId, firmId]);
    
    if (result.isEmpty) {
      final dish = await db.query('dish_master', where: 'id = ?', whereArgs: [dishId]);
      if (dish.isNotEmpty) {
        final baseId = dish.first['baseId'];
        if (baseId != null) {
          result = await db.rawQuery('''
            SELECT rd.*, i.name as ingredientName, i.category, COALESCE(rd.unit_override, i.unit_of_measure) as unit,
                   (rd.quantity_per_base_pax * 100) as quantityPer100Pax
            FROM recipe_detail rd JOIN ingredients_master i ON rd.ing_id = i.baseId AND i.firmId = 'SEED'
            WHERE rd.dish_id = ? AND rd.firmId = 'SEED' ORDER BY i.category, i.name
          ''', [baseId]);
        }
      }
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> getRecipeForDishByName(String dishName, int paxQty) async {
    final db = await _dbHelper.database;
    final sp = await SharedPreferences.getInstance();
    final firmId = sp.getString('last_firm') ?? 'DEFAULT';
    
    final resF = await db.query('firms', columns: ['showUniversalData'], where: 'firmId = ?', whereArgs: [firmId]);
    bool showUniversal = resF.isNotEmpty ? (resF.first['showUniversalData'] as int? ?? 1) == 1 : true;

    var where = "name = ? AND (firmId = ? ${showUniversal ? "OR firmId = 'SEED'" : ""})";
    var args = <Object>[dishName.trim(), firmId];

    var dishMaster = await db.query('dish_master', columns: ['id', 'baseId', 'base_pax', 'firmId', 'name'],
      where: where, whereArgs: args, orderBy: "CASE WHEN firmId = '$firmId' THEN 0 ELSE 1 END", limit: 1);
    
    if (dishMaster.isEmpty) {
      where = "name LIKE ? AND (firmId = ? ${showUniversal ? "OR firmId = 'SEED'" : ""})";
      args = ['%${dishName.trim()}%', firmId];
      dishMaster = await db.query('dish_master', columns: ['id', 'baseId', 'base_pax', 'firmId', 'name'],
        where: where, whereArgs: args, orderBy: "CASE WHEN firmId = '$firmId' THEN 0 ELSE 1 END", limit: 1);
    }

    if (dishMaster.isEmpty) return [];
    
    final dishId = dishMaster.first['id'] as int;
    final baseId = dishMaster.first['baseId'];
    final basePax = (dishMaster.first['base_pax'] as int?) ?? 1;
    final isSeedDish = dishMaster.first['firmId'] == 'SEED';
    final foundName = dishMaster.first['name'] as String;
    
    var recipe = await db.rawQuery('''
      SELECT rd.*, i.name as ingredientName, i.id as ing_id, i.category, COALESCE(i.cost_per_unit, 0) as cost_per_unit,
             COALESCE(rd.unit_override, i.unit_of_measure) as unit, (rd.quantity_per_base_pax * ? / ?) as scaledQuantity
      FROM recipe_detail rd JOIN ingredients_master i ON rd.ing_id = i.id
      WHERE rd.dish_id = ? AND rd.firmId = ? ORDER BY i.category, i.name
    ''', [paxQty, basePax, dishId, firmId]);
    
    if (recipe.isEmpty && isSeedDish && baseId != null) {
      recipe = await db.rawQuery('''
        SELECT rd.*, i.name as ingredientName, i.id as ing_id, i.category, COALESCE(i.cost_per_unit, 0) as cost_per_unit,
               COALESCE(rd.unit_override, i.unit_of_measure) as unit, (rd.quantity_per_base_pax * ? / ?) as scaledQuantity
        FROM recipe_detail rd JOIN ingredients_master i ON rd.ing_id = i.baseId AND i.firmId = 'SEED'
        WHERE rd.dish_id = ? AND rd.firmId = 'SEED' ORDER BY i.category, i.name
      ''', [paxQty, basePax, baseId]);
    }

    if (recipe.isEmpty && !isSeedDish && showUniversal) {
      final seedDish = await db.query('dish_master', where: "name = ? AND firmId = 'SEED'", whereArgs: [foundName.trim()], limit: 1);
      if (seedDish.isNotEmpty) {
        final seedBaseId = seedDish.first['baseId'];
        final seedBasePax = (seedDish.first['base_pax'] as int?) ?? 1;
        if (seedBaseId != null) {
          recipe = await db.rawQuery('''
            SELECT rd.*, i.name as ingredientName, i.id as ing_id, i.category, COALESCE(i.cost_per_unit, 0) as cost_per_unit,
                   COALESCE(rd.unit_override, i.unit_of_measure) as unit, (rd.quantity_per_base_pax * ? / ?) as scaledQuantity
            FROM recipe_detail rd JOIN ingredients_master i ON rd.ing_id = i.baseId AND i.firmId = 'SEED'
            WHERE rd.dish_id = ? AND rd.firmId = 'SEED' ORDER BY i.category, i.name
          ''', [paxQty, seedBasePax, seedBaseId]);
        }
      }
    }
    return recipe;
  }

  Future<int> insertBomItem(Map<String, dynamic> data) async {
    final cloudSync = CloudSyncService();
    final bomData = {
      'firmId': data['firmId'] ?? 'SEED',
      'dish_id': data['dishId'],
      'ing_id': data['ingredientId'],
      'quantity_per_base_pax': (data['quantityPer100Pax'] as num) / 100.0,
      'unit_override': data['unit'],
      'isModified': 1,
      'uuid': data['uuid'] ?? const Uuid().v4(),
    };
    final id = await cloudSync.awsFirstWrite(table: 'recipe_detail', data: bomData);
    AppLogger.success('✅ [BOM] Created recipe_detail #$id (AWS-first)');
    return id ?? 0;
  }

  Future<bool> deleteBomItem(int id) async {
    await CloudSyncService().awsFirstDelete(table: 'recipe_detail', recordId: id);
    AppLogger.success('✅ [BOM] Deleted recipe_detail #$id (AWS-first)');
    return true;
  }

  Future<bool> updateBomItem(int id, Map<String, dynamic> data) async {
    final success = await CloudSyncService().awsFirstUpdate(table: 'recipe_detail', recordId: id, data: data);
    AppLogger.success('✅ [BOM] Updated recipe_detail #$id (AWS-first)');
    return success;
  }

  // ---------- MRP (Material Requirements Planning) ----------

  Future<int?> createMrpRun(Map<String, dynamic> data) async {
    final db = await _dbHelper.database;
    final cloudSync = CloudSyncService();
    final now = DateTime.now();
    data['createdAt'] = now.toIso8601String();
    
    final firmId = data['firmId'] as String?;
    final monthStart = DateTime(now.year, now.month, 1).toIso8601String().substring(0, 10);
    final monthEnd = DateTime(now.year, now.month + 1, 0).toIso8601String().substring(0, 10);
    
    final existingRuns = await db.rawQuery('''
      SELECT MAX(runNumber) as maxNum FROM mrp_runs 
      WHERE firmId = ? AND date(runDate) >= date(?) AND date(runDate) <= date(?)
    ''', [firmId, monthStart, monthEnd]);
    
    int runNumber = (existingRuns.isNotEmpty && existingRuns.first['maxNum'] != null) 
        ? (existingRuns.first['maxNum'] as int) + 1 : 1;
    
    const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final runName = '${monthNames[now.month - 1]}-$runNumber';
    
    data['runNumber'] = runNumber;
    data['runName'] = runName;
    data['uuid'] = data['uuid'] ?? const Uuid().v4();
    
    final id = await cloudSync.awsFirstWrite(table: 'mrp_runs', data: data);
    AppLogger.success('✅ [MRP] Created MRP run #$id "$runName" (AWS-first)');
    return id;
  }

  Future<List<Map<String, dynamic>>> getMrpRuns(String firmId) async {
    final db = await _dbHelper.database;
    return await db.query('mrp_runs', where: 'firmId = ?', whereArgs: [firmId], orderBy: 'createdAt DESC');
  }

  Future<void> addOrdersToMrpRun(int mrpRunId, List<Map<String, dynamic>> orders) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (var order in orders) {
      batch.insert('mrp_run_orders', {
        'mrpRunId': mrpRunId,
        'orderId': order['orderId'],
        'pax': order['pax'],
        'isSubcontracted': order['isSubcontracted'] ?? 0,
        'subcontractorId': order['subcontractorId'],
        'uuid': order['uuid'] ?? const Uuid().v4(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> saveMrpOutput(int mrpRunId, List<Map<String, dynamic>> output) async {
    final db = await _dbHelper.database;
    await db.delete('mrp_output', where: 'mrpRunId = ?', whereArgs: [mrpRunId]);
    final batch = db.batch();
    for (var item in output) {
      batch.insert('mrp_output', {'mrpRunId': mrpRunId, ...item});
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getMrpOutput(int mrpRunId) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT mo.*, i.name as ingredientName, COALESCE(i.cost_per_unit, 0) as rate,
             (mo.requiredQty * COALESCE(i.cost_per_unit, 0)) as totalCost, s.name as supplierName
      FROM mrp_output mo JOIN ingredients_master i ON mo.ingredientId = i.id
      LEFT JOIN suppliers s ON mo.supplierId = s.id
      WHERE mo.mrpRunId = ? ORDER BY mo.category, i.name
    ''', [mrpRunId]);
  }

  Future<List<Map<String, dynamic>>> getMrpOutputForAllotment(int mrpRunId) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT mo.*, i.name as ingredientName, COALESCE(i.cost_per_unit, 0) as rate,
             (mo.requiredQty * COALESCE(i.cost_per_unit, 0)) as totalCost, s.name as supplierName
      FROM mrp_output mo JOIN ingredients_master i ON mo.ingredientId = i.id
      LEFT JOIN suppliers s ON mo.supplierId = s.id
      WHERE mo.mrpRunId = ? AND (mo.allocationStatus IS NULL OR mo.allocationStatus != 'PO_SENT')
      ORDER BY mo.category, i.name
    ''', [mrpRunId]);
  }

  Future<void> updateMrpOutputAllocation(int mrpOutputId, int? supplierId) async {
    final db = await _dbHelper.database;
    final qty = (await db.query('mrp_output', columns: ['requiredQty'], where: 'id = ?', whereArgs: [mrpOutputId])).first['requiredQty'];
    await db.update('mrp_output', {
      'supplierId': supplierId,
      'allocationStatus': supplierId != null ? 'ALLOCATED' : 'PENDING',
      'allocatedQty': supplierId != null ? qty : 0,
    }, where: 'id = ?', whereArgs: [mrpOutputId]);
  }

  Future<void> updateMrpOutputAllocations(int mrpRunId, Map<int, int?> allocations) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (var entry in allocations.entries) {
      final ingredientId = entry.key;
      final supplierId = entry.value;
      final outputs = await db.query('mrp_output', where: 'mrpRunId = ? AND ingredientId = ?', whereArgs: [mrpRunId, ingredientId]);
      if (outputs.isNotEmpty) {
        batch.update('mrp_output', {
          'supplierId': supplierId,
          'allocationStatus': supplierId != null ? 'ALLOCATED' : 'PENDING',
          'allocatedQty': supplierId != null ? outputs.first['requiredQty'] : 0,
        }, where: 'id = ?', whereArgs: [outputs.first['id']]);
      }
    }
    await batch.commit(noResult: true);
  }

  Future<void> markMrpOutputAsPOSent(int mrpRunId, int poId, List<int> ingredientIds) async {
    final db = await _dbHelper.database;
    for (var ingredientId in ingredientIds) {
      final qty = (await db.query('mrp_output', columns: ['requiredQty'], where: 'mrpRunId = ? AND ingredientId = ?', whereArgs: [mrpRunId, ingredientId])).firstOrNull?['requiredQty'] ?? 0;
      await db.update('mrp_output', {
        'allocationStatus': 'PO_SENT',
        'poId': poId,
        'purchaseQty': qty,
      }, where: 'mrpRunId = ? AND ingredientId = ?', whereArgs: [mrpRunId, ingredientId]);
    }
  }

  Future<Map<int, int?>> getExistingAllocations(int mrpRunId) async {
    final db = await _dbHelper.database;
    final results = await db.query('mrp_output', columns: ['ingredientId', 'supplierId'], where: 'mrpRunId = ? AND supplierId IS NOT NULL', whereArgs: [mrpRunId]);
    return Map.fromEntries(results.map((r) => MapEntry(r['ingredientId'] as int, r['supplierId'] as int?)));
  }

  Future<void> lockOrdersForMrp(int mrpRunId, List<int> orderIds) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    for (var orderId in orderIds) {
      final existing = await db.query('orders', columns: ['mrpRunId', 'mrpStatus'], where: 'id = ?', whereArgs: [orderId]);
      if (existing.isNotEmpty) {
        final curId = existing.first['mrpRunId'];
        final curStatus = existing.first['mrpStatus'];
        if (curId == null || curStatus == 'PENDING' || curStatus == null) {
          await db.update('orders', {'mrpRunId': mrpRunId, 'mrpStatus': 'MRP_DONE', 'isLocked': 1, 'lockedAt': now}, where: 'id = ?', whereArgs: [orderId]);
        } else {
          await db.update('orders', {'isLocked': 1, 'lockedAt': now}, where: 'id = ?', whereArgs: [orderId]);
        }
      }
    }
  }

  Future<void> updateOrderStatusIfAllItemsPOd(int mrpRunId) async {
    final db = await _dbHelper.database;
    final pending = await db.query('mrp_output', where: "mrpRunId = ? AND (allocationStatus IS NULL OR allocationStatus != 'PO_SENT')", whereArgs: [mrpRunId]);
    if (pending.isEmpty) {
      final runOrders = await db.query('mrp_run_orders', columns: ['orderId'], where: 'mrpRunId = ?', whereArgs: [mrpRunId]);
      for (var ro in runOrders) {
        await db.update('orders', {'mrpStatus': 'PO_SENT'}, where: 'id = ?', whereArgs: [ro['orderId']]);
      }
      await db.update('mrp_runs', {'status': 'PO_SENT', 'completedAt': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [mrpRunId]);
    }
  }

  double normalizeToCanonicalUnit(double qty, String fromUnit, String toUnit) {
    if (fromUnit.toLowerCase() == toUnit.toLowerCase()) return qty;
    const weightToKg = {'g': 0.001, 'gm': 0.001, 'gram': 0.001, 'kg': 1.0, 'kgs': 1.0};
    const volumeToLitre = {'ml': 0.001, 'l': 1.0, 'litre': 1.0, 'liter': 1.0};
    final from = fromUnit.toLowerCase(); final to = toUnit.toLowerCase();
    if (weightToKg.containsKey(from) && weightToKg.containsKey(to)) return qty * weightToKg[from]! / weightToKg[to]!;
    if (volumeToLitre.containsKey(from) && volumeToLitre.containsKey(to)) return qty * volumeToLitre[from]! / volumeToLitre[to]!;
    return qty;
  }

  double roundByCategory(double qty, String? category) {
    final cat = (category ?? 'other').toLowerCase();
    switch (cat) {
      case 'spices': case 'masalas': case 'flavoring': return double.parse(qty.toStringAsFixed(3));
      case 'vegetables': case 'fruits': case 'meat': case 'seafood': case 'grocery': return double.parse(qty.toStringAsFixed(2));
      case 'oil': case 'liquid': case 'dairy': return double.parse(qty.toStringAsFixed(3));
      default: return double.parse(qty.toStringAsFixed(2));
    }
  }

  Future<List<Map<String, dynamic>>> getRecipeForDishById(int dishMasterId, int paxQty) async {
    final db = await _dbHelper.database;
    final dish = await db.query('dish_master', columns: ['id', 'base_pax', 'firmId'], where: 'id = ?', whereArgs: [dishMasterId], limit: 1);
    if (dish.isEmpty) return [];
    final basePax = (dish.first['base_pax'] as int?) ?? 1;
    return db.rawQuery('''
      SELECT rd.*, i.name as ingredientName, i.id as ing_id, i.category, i.unit_of_measure as canonical_unit,
             COALESCE(i.cost_per_unit, 0) as cost_per_unit, COALESCE(rd.unit_override, i.unit_of_measure) as unit,
             (rd.quantity_per_base_pax * ? / ?) as scaledQuantity
      FROM recipe_detail rd JOIN ingredients_master i ON rd.ing_id = i.id
      WHERE rd.dish_id = ? ORDER BY i.category, i.name
    ''', [paxQty, basePax, dishMasterId]);
  }

  Future<bool> safeResetOrderForMRP(int orderId) async {
    final db = await _dbHelper.database;
    final order = await db.query('orders', columns: ['mrpRunId'], where: 'id = ?', whereArgs: [orderId]);
    if (order.isEmpty) return false;
    final mrpRunId = order.first['mrpRunId'];
    if (mrpRunId != null) {
      final activePOs = await db.query('purchase_orders', where: "mrpRunId = ? AND status != 'CANCELLED'", whereArgs: [mrpRunId]);
      if (activePOs.isNotEmpty) return false;
      await db.update('mrp_output', {'allocationStatus': 'CANCELLED'}, where: 'mrpRunId = ?', whereArgs: [mrpRunId]);
      await db.delete('mrp_run_orders', where: 'orderId = ?', whereArgs: [orderId]);
    }
    await db.update('orders', {'mrpStatus': 'PENDING', 'mrpRunId': null, 'isLocked': 0, 'lockedAt': null}, where: 'id = ?', whereArgs: [orderId]);
    return true;
  }

  Future<void> cancelOrderAfterMRP(int orderId, String reason) async {
    final db = await _dbHelper.database;
    await db.update('orders', {'mrpStatus': 'CANCELLED', 'cancelReason': reason, 'cancelledAt': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [orderId]);
  }

  Future<int?> runMrpInTransaction({required String firmId, required String targetDate, required List<int> orderIds, required Future<Map<int, Map<String, dynamic>>> Function(List<int> orderIds) calculateOutput}) async {
    final db = await _dbHelper.database;
    try {
      final result = await db.transaction((txn) async {
        final now = DateTime.now();
        for (var oid in orderIds) {
          final check = await txn.query('orders', columns: ['mrpStatus', 'mrpRunId'], where: 'id = ?', whereArgs: [oid]);
          if (check.isEmpty) throw Exception('Order $oid not found');
          if (check.first['mrpStatus'] != null && check.first['mrpStatus'] != 'PENDING' && check.first['mrpRunId'] != null) throw Exception('Order $oid already processed');
        }
        final monthStart = DateTime(now.year, now.month, 1).toIso8601String().substring(0, 10);
        final monthEnd = DateTime(now.year, now.month + 1, 0).toIso8601String().substring(0, 10);
        final existingRuns = await txn.rawQuery('SELECT MAX(runNumber) as maxNum FROM mrp_runs WHERE firmId = ? AND date(runDate) >= date(?) AND date(runDate) <= date(?)', [firmId, monthStart, monthEnd]);
        int runNumber = (existingRuns.isNotEmpty && existingRuns.first['maxNum'] != null) ? (existingRuns.first['maxNum'] as int) + 1 : 1;
        const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        final runName = '${monthNames[now.month - 1]}-$runNumber';
        final mrpRunId = await txn.insert('mrp_runs', {'firmId': firmId, 'runDate': now.toIso8601String(), 'targetDate': targetDate, 'status': 'DRAFT', 'runNumber': runNumber, 'runName': runName, 'totalOrders': orderIds.length, 'createdAt': now.toIso8601String()});
        for (var oid in orderIds) { await txn.insert('mrp_run_orders', {'mrpRunId': mrpRunId, 'orderId': oid}, conflictAlgorithm: ConflictAlgorithm.ignore); }
        final output = await calculateOutput(orderIds);
        final batch = txn.batch();
        for (var entry in output.entries) {
          final item = entry.value; final qty = (item['requiredQty'] as num?)?.toDouble() ?? 0;
          item['requiredQty'] = roundByCategory(qty, item['category'] as String?);
          batch.insert('mrp_output', {'mrpRunId': mrpRunId, ...item});
        }
        await batch.commit(noResult: true);
        final lockNow = now.toIso8601String();
        for (var oid in orderIds) { await txn.update('orders', {'mrpRunId': mrpRunId, 'mrpStatus': 'MRP_DONE', 'isLocked': 1, 'lockedAt': lockNow}, where: 'id = ?', whereArgs: [oid]); }
        return mrpRunId;
      });
      return result;
    } catch (e) { AppLogger.error('❌ [MRP Transaction] Failed: $e'); return null; }
  }
  Future<void> resetOrderForMRP(int orderId) async {
    final cloudSync = CloudSyncService();
    final updates = {
      'id': orderId,
      'mrpStatus': 'PENDING',
      'mrpRunId': null,
      'isLocked': 0,
      'lockedAt': null,
    };
    await cloudSync.awsFirstUpdate(table: 'orders', recordId: orderId, data: updates);
    AppLogger.info('📦 [Inventory] Reset order $orderId for MRP re-run (AWS-first)');
  }
}
