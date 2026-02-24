import 'package:ruchiserv/core/app_logger.dart';
import 'package:ruchiserv/db/aws/aws_api.dart';
import 'package:ruchiserv/db/database_helper.dart';
import 'package:ruchiserv/db/sync_event.dart';
import 'package:ruchiserv/services/cloud_sync_service.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrderRepository {
  static final OrderRepository _instance = OrderRepository._internal();
  factory OrderRepository() => _instance;
  OrderRepository._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();

  Stream<SyncEvent> get syncStream => _dbHelper.syncStreamController.stream;
  String _generateUuid() => const Uuid().v4();

  // ---------- ORDERS CRUD (LOCAL + AWS SYNC) ----------

  Future<int?> insertOrder(
    Map<String, dynamic> order,
    List<Map<String, dynamic>> dishes,
  ) async {
    final now = DateTime.now().toIso8601String();
    final cloudSync = CloudSyncService();

    // Normalize
    order['uuid'] = order['uuid'] ?? _generateUuid();
    order['createdAt'] = order['createdAt'] ?? now;
    order['updatedAt'] = now;
    order['totalPax'] = order['totalPax'] ?? 0;
    order['isLocked'] = order['isLocked'] ?? 0;

    // v38: AWS-First - Write order to cloud first, then cache locally
    final orderId = await cloudSync.awsFirstWrite(
      table: 'orders',
      data: order,
    );

    if (orderId == null) {
      AppLogger.error('❌ [Order] Failed to create order');
      return null;
    }

    // Insert dishes - also using AWS-first
    for (final dish in dishes) {
      dish['orderId'] = orderId;
      dish['uuid'] = dish['uuid'] ?? _generateUuid();
      dish['createdAt'] = now;

      await cloudSync.awsFirstWrite(
        table: 'dishes',
        data: dish,
      );
    }

    AppLogger.success(
        '✅ [Order] Created order #$orderId with ${dishes.length} dishes (AWS-first)');
    return orderId;
  }

  Future<bool> updateOrder(
    int orderId,
    Map<String, dynamic> order,
    List<Map<String, dynamic>> dishes,
  ) async {
    final now = DateTime.now().toIso8601String();
    final cloudSync = CloudSyncService();
    final db = await _dbHelper.database;

    order['updatedAt'] = now;
    order['totalPax'] = order['totalPax'] ?? 0;
    order['id'] = orderId;

    // v38: AWS-First - Update order via cloud sync
    final success = await _dbHelper.updateRecord('orders', orderId, order);

    if (!success) {
      AppLogger.warning('⚠️ [Order] Update queued for order #$orderId');
    }

    // Get existing dish IDs for deletion
    final existingDishes = await db.query('dishes',
        columns: ['id'], where: 'orderId = ?', whereArgs: [orderId]);

    // Delete existing dishes via AWS-first
    for (final existingDish in existingDishes) {
      final dishId = existingDish['id'] as int;
      await cloudSync.awsFirstDelete(table: 'dishes', recordId: dishId);
    }

    // Insert new dishes via AWS-first
    for (final dish in dishes) {
      dish['orderId'] = orderId;
      dish['uuid'] = dish['uuid'] ?? _generateUuid();
      dish['createdAt'] = now;

      await cloudSync.awsFirstWrite(
        table: 'dishes',
        data: dish,
      );
    }

    AppLogger.success(
        '✅ [Order] Updated order #$orderId with ${dishes.length} dishes (AWS-first)');
    return true;
  }

  Future<void> updateOrderFields(
      int orderId, Map<String, dynamic> updates) async {
    updates['updatedAt'] = DateTime.now().toIso8601String();
    await _dbHelper.updateRecord('orders', orderId, updates);
  }

  Future<Map<String, dynamic>?> getFirm(String firmId) async {
    final db = await _dbHelper.database;
    final res = await db.query('firms',
        where: 'firmId = ?', whereArgs: [firmId], limit: 1);
    return res.isNotEmpty ? res.first : null;
  }

  Future<void> upsertServiceRate(
      String firmId, String serviceType, double rate) async {
    final db = await _dbHelper.database;
    final cloudSync = CloudSyncService();

    final existing = await db.query('service_rates',
        where: 'firmId = ? AND serviceType = ?',
        whereArgs: [firmId, serviceType]);
    final data = {
      'firmId': firmId,
      'serviceType': serviceType,
      'rate': rate,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    if (existing.isNotEmpty) {
      await _dbHelper.updateRecord('service_rates',
          existing.first['id'] as int, data);
    } else {
      data['uuid'] = const Uuid().v4();
      await cloudSync.awsFirstWrite(table: 'service_rates', data: data);
    }
  }

  Future<bool> deleteOrder(int orderId) async {
    final cloudSync = CloudSyncService();
    final db = await _dbHelper.database;

    // Get dishes for this order to delete them via AWS-first
    final existingDishes = await db.query('dishes',
        columns: ['id'], where: 'orderId = ?', whereArgs: [orderId]);

    // Delete dishes via AWS-first
    for (final dish in existingDishes) {
      final dishId = dish['id'] as int;
      await cloudSync.awsFirstDelete(table: 'dishes', recordId: dishId);
    }

    // Delete order via AWS-first
    final success = await cloudSync.awsFirstDelete(
      table: 'orders',
      recordId: orderId,
    );

    AppLogger.success(
        '✅ [Order] Deleted order #$orderId and ${existingDishes.length} dishes (AWS-first)');
    return success;
  }

  Future<List<Map<String, dynamic>>> getOrdersByDate(
      String date, String firmId) async {
    final db = await _dbHelper.database;
    return db.query(
      'orders',
      where: 'date = ? AND firmId = ?',
      whereArgs: [date, firmId],
      orderBy: 'id DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getOrdersWithPax(
      String date, String firmId) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT o.*, IFNULL(o.totalPax, 0) AS pax
      FROM orders o
      WHERE o.date = ? AND o.firmId = ?
      ORDER BY o.time ASC
    ''', [date, firmId]);
  }

  Future<List<Map<String, dynamic>>> getDishesForOrder(
      int orderId, String firmId) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT d.* FROM dishes d 
      JOIN orders o ON d.orderId = o.id 
      WHERE d.orderId = ? AND o.firmId = ? AND d.dishName IS NOT NULL AND d.dishName != '' AND d.dishName != 'Unnamed'
      ORDER BY d.id ASC
    ''', [orderId, firmId]);
  }

  Future<bool> updateDish(int id, Map<String, dynamic> updates) async {
    return await _dbHelper.updateRecord('dishes', id, updates);
  }

  Future<bool> isDishLocked(int dishId) async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery('''
      SELECT o.isLocked 
      FROM dishes d
      JOIN orders o ON d.orderId = o.id
      WHERE d.id = ?
    ''', [dishId]);

    if (res.isEmpty) return false;
    return (res.first['isLocked'] as int?) == 1;
  }

  Future<bool> toggleDishSubcontract(int dishId, bool isSubcontracted,
      {int? subcontractorId}) async {
    if (await isDishLocked(dishId)) return false;

    final db = await _dbHelper.database;
    await db.update(
      'dishes',
      {
        'isSubcontracted': isSubcontracted ? 1 : 0,
        'subcontractorId': isSubcontracted ? subcontractorId : null,
        'productionType': isSubcontracted ? 'SUBCONTRACT' : 'INTERNAL',
      },
      where: 'id = ?',
      whereArgs: [dishId],
    );

    // Auto Sync via CloudSyncService (Note: syncStreamController is in DatabaseHelper)
    _dbHelper.syncStreamController.add(SyncEvent(
        table: 'dishes',
        data: {
          'id': dishId,
          'isSubcontracted': isSubcontracted ? 1 : 0,
          'subcontractorId': subcontractorId,
          'productionType': isSubcontracted ? 'SUBCONTRACT' : 'INTERNAL',
        },
        action: 'UPDATE',
        filters: {'id': dishId}));

    return true;
  }

  Future<int> getTotalPaxForDate(String date, String firmId) async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery(
        'SELECT SUM(COALESCE(pax, 0) + COALESCE(totalPax, 0)) as total FROM orders '
        'WHERE date = ? AND firmId = ?',
        [date, firmId]);
    return (res.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<List<Map<String, dynamic>>> getAllOrdersWithPax(String firmId) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT 
        o.date,
        0 AS vegPax,
        0 AS nonVegPax,
        SUM(COALESCE(o.pax, 0) + COALESCE(o.totalPax, 0)) AS totalPax,
        MAX(CASE WHEN o.mrpRunId IS NOT NULL THEN 1 ELSE 0 END) AS hasMrpRun,
        MAX(CASE WHEN o.mrpStatus = 'PO_SENT' THEN 1 ELSE 0 END) AS hasPOSent
      FROM orders o
      WHERE o.date IS NOT NULL AND o.firmId = ?
      GROUP BY o.date
      ORDER BY o.date ASC
    ''', [firmId]);
  }

  Future<void> refreshClientStatusFromAws(String date, String firmId) async {
    try {
      AppLogger.info('🔄 Refreshing clientStatus from AWS for $date...');
      final response = await AwsApi.callDbHandler(
        method: 'GET',
        table: 'orders',
        firmId: firmId,
        filters: {'pk': firmId, 'sk_prefix': 'ORDER#$date'},
      );

      List<dynamic> orders = [];
      if (response.containsKey('Items')) {
        orders = response['Items'] as List? ?? [];
      } else if (response.containsKey('data') && response['data'] is List) {
        orders = response['data'] as List;
      } else if (response.containsKey('id')) {
        orders = [response];
      }

      if (orders.isNotEmpty) {
        final db = await _dbHelper.database;
        for (final awsOrder in orders) {
          if (awsOrder is! Map) continue;
          final orderId = awsOrder['id'];
          final clientStatus = awsOrder['clientStatus'];
          if (orderId != null && clientStatus != null) {
            await db.update(
              'orders',
              {
                'clientStatus': clientStatus,
                if (awsOrder['confirmedAt'] != null)
                  'confirmedAt': awsOrder['confirmedAt'],
                if (awsOrder['changeRequestedAt'] != null)
                  'changeRequestedAt': awsOrder['changeRequestedAt'],
                if (awsOrder['sentAt'] != null) 'sentAt': awsOrder['sentAt'],
              },
              where: 'id = ? AND firmId = ?',
              whereArgs: [orderId, firmId],
            );
            AppLogger.success('✅ Updated order $orderId → $clientStatus');
          }
        }
      }
    } catch (e) {
      AppLogger.warning('⚠️ Failed to refresh clientStatus from AWS: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getPendingOrdersForMrp(
      String date, String firmId) async {
    final db = await _dbHelper.database;
    return await db.query('orders',
        where: "date = ? AND mrpStatus = 'PENDING' AND firmId = ?",
        whereArgs: [date, firmId]);
  }

  Future<List<Map<String, dynamic>>> getProcessedOrdersForMrp(
      String date, String firmId) async {
    final db = await _dbHelper.database;
    return await db.query('orders',
        where: "date = ? AND mrpStatus != 'PENDING' AND firmId = ?",
        whereArgs: [date, firmId]);
  }

  Future<Map<String, dynamic>> getOrderDependencies(
      int orderId, String firmId) async {
    final db = await _dbHelper.database;
    final orders = await db.query('orders',
        where: 'id = ? AND firmId = ?', whereArgs: [orderId, firmId]);
    if (orders.isEmpty) return {'error': 'Order not found'};
    final order = orders.first;
    final dishes =
        await db.query('dishes', where: 'orderId = ?', whereArgs: [orderId]);
    int dispatchCount = 0;
    try {
      final dispatches = await db
          .query('dispatch', where: 'orderId = ?', whereArgs: [orderId]);
      dispatchCount = dispatches.length;
    } catch (_) {
      AppLogger.error('Caught error: $_');
    }
    return {
      'order': order,
      'dishCount': dishes.length,
      'hasDispatch': dispatchCount > 0,
      'dispatchCount': dispatchCount
    };
  }

  Future<bool> cancelOrder(int orderId,
      {required String firmId, required String userId}) async {
    try {
      final db = await _dbHelper.database;
      final now = DateTime.now().toIso8601String();
      await db.update(
          'orders',
          {
            'isCancelled': 1,
            'cancelledAt': now,
            'cancelledBy': userId,
            'status': 'CANCELLED',
            'updatedAt': now
          },
          where: 'id = ? AND firmId = ?',
          whereArgs: [orderId, firmId]);
      _dbHelper.syncStreamController.add(SyncEvent(
          table: 'orders',
          data: {
            'id': orderId,
            'isCancelled': 1,
            'cancelledAt': now,
            'cancelledBy': userId,
            'status': 'CANCELLED',
            'updatedAt': now
          },
          action: 'UPDATE',
          filters: {'id': orderId}));
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getDishesSummaryByDate(
      String date, String firmId) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT d.dishName AS name, COALESCE(d.foodType, 'Veg') AS foodType, COALESCE(o.mealType, 'Snacks/Others') AS mealType,
             SUM(COALESCE(d.pax, 0)) AS totalPax, SUM(COALESCE(d.pax * d.pricePerPlate, 0)) AS totalCost
      FROM dishes d JOIN orders o ON o.id = d.orderId WHERE o.date = ? AND o.firmId = ? GROUP BY d.dishName, d.foodType, o.mealType ORDER BY o.mealType, d.dishName
    ''', [date, firmId]);
  }

  Future<List<Map<String, dynamic>>> getDishesForDate(
      String date, String firmId) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT d.*, o.customerName, o.status as orderStatus, o.time FROM dishes d JOIN orders o ON d.orderId = o.id WHERE o.date = ? AND o.firmId = ? ORDER BY o.time, o.id
    ''', [date, firmId]);
  }

  // Kitchen Production Queue
  Future<List<Map<String, dynamic>>> getProductionQueue(String firmId) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT d.*, o.date, o.time, o.customerName FROM dishes d JOIN orders o ON d.orderId = o.id 
      WHERE d.productionStatus IN ('QUEUED', 'PENDING') AND d.productionType != 'SUBCONTRACT' AND o.firmId = ? ORDER BY o.date ASC, o.time ASC
    ''', [firmId]);
  }

  // Kitchen Ready Queue
  Future<List<Map<String, dynamic>>> getReadyQueue(String firmId) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT d.*, o.date, o.time, o.customerName FROM dishes d JOIN orders o ON d.orderId = o.id 
      WHERE d.productionStatus = 'READY' AND o.firmId = ? ORDER BY d.readyAt DESC, o.date DESC, o.time DESC
    ''', [firmId]);
  }

  // ---------- DISH MASTER (Autocomplete Suggestions) ----------

  Future<bool> getFirmUniversalDataVisibility(String firmId) async {
    final db = await _dbHelper.database;
    final res = await db.query('firms',
        columns: ['showUniversalData'],
        where: 'firmId = ?',
        whereArgs: [firmId]);
    if (res.isNotEmpty) {
      return (res.first['showUniversalData'] as int? ?? 1) == 1;
    }
    return true;
  }

  Future<List<Map<String, dynamic>>> getDishSuggestions(
      String? category) async {
    try {
      final db = await _dbHelper.database;
      final sp = await SharedPreferences.getInstance();
      final firmId = sp.getString('last_firm') ?? 'DEFAULT';
      final showUniversal = await getFirmUniversalDataVisibility(firmId);

      String whereClause =
          "(firmId = ? ${showUniversal ? "OR firmId = 'SEED'" : ""})";
      List<dynamic> args = [firmId];

      if (category != null && category.isNotEmpty) {
        String pattern;
        switch (category) {
          case 'Starters':
            pattern = 'Starter%';
            break;
          case 'Main Course':
            pattern = 'Main Course%';
            break;
          case 'Desserts':
            pattern = 'Dessert%';
            break;
          case 'Beverages':
            pattern = 'Beverage%';
            break;
          case 'Specialties':
            pattern = 'Special%';
            break;
          default:
            pattern = '$category%';
        }
        whereClause += " AND category LIKE ?";
        args.add(pattern);
        return await db.query('dish_master',
            where: whereClause, whereArgs: args, orderBy: 'name ASC');
      }
      return await db.query('dish_master',
          where: whereClause, whereArgs: args, orderBy: 'category, name ASC');
    } catch (_) {
      return [];
    }
  }

  Future<void> upsertDishMaster(
      {required String name,
      required String category,
      required int rate,
      String foodType = 'Veg'}) async {
    if (name.trim().isEmpty) return;
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final sp = await SharedPreferences.getInstance();
    final firmId = sp.getString('last_firm');
    if (firmId == null) return;

    try {
      final firmDish = await db.query('dish_master',
          where: 'name = ? AND category = ? AND firmId = ?',
          whereArgs: [name.trim(), category, firmId],
          limit: 1);
      if (firmDish.isNotEmpty) {
        await db.update(
            'dish_master',
            {
              'rate': rate,
              'foodType': foodType,
              'updatedAt': now,
              'isModified': 1
            },
            where: 'id = ?',
            whereArgs: [firmDish.first['id']]);
      } else {
        final seedDish = await db.query('dish_master',
            where: 'name = ? AND category = ? AND firmId = ?',
            whereArgs: [name.trim(), category, 'SEED'],
            limit: 1);
        if (seedDish.isNotEmpty) {
          final s = seedDish.first;
          if ((s['rate'] as num).toInt() != rate ||
              s['foodType'] as String != foodType) {
            await db.insert('dish_master', {
              'firmId': firmId,
              'baseId': s['id'],
              'name': name.trim(),
              'category': category,
              'rate': rate,
              'foodType': foodType,
              'createdAt': now,
              'updatedAt': now,
              'isModified': 1
            });
          }
        } else {
          await db.insert('dish_master', {
            'firmId': firmId,
            'name': name.trim(),
            'category': category,
            'rate': rate,
            'foodType': foodType,
            'createdAt': now,
            'updatedAt': now,
            'isModified': 1
          });
        }
      }
    } catch (e) {
      AppLogger.error('❌ Error upserting dish master for $name: $e');
    }
  }

  // ---------- ORDER STATUS UPDATES (MRP RELATED) moved to InventoryRepository ----------

  Future<void> updateOrderServiceAssignment(int orderId,
      {int? serviceSubId, int? counterSubId}) async {
    final updates = <String, dynamic>{};
    if (serviceSubId != -1) updates['serviceSubcontractorId'] = serviceSubId;
    if (counterSubId != -1) updates['counterSubcontractorId'] = counterSubId;

    if (updates.isNotEmpty) {
      await _dbHelper.updateRecord('orders', orderId, updates);
    }
  }

  // ---------- REPORTS ----------

  Future<List<Map<String, dynamic>>> getOrderStatusReport(
      String startDate, String endDate, String firmId) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT date, COUNT(*) as totalOrders, SUM(CASE WHEN status = 'Confirmed' THEN 1 ELSE 0 END) as confirmed,
             SUM(CASE WHEN status = 'Completed' THEN 1 ELSE 0 END) as completed, SUM(CASE WHEN isCancelled = 1 THEN 1 ELSE 0 END) as cancelled,
             SUM(totalPax) as totalPax, SUM(CASE WHEN isCancelled = 0 OR isCancelled IS NULL THEN finalAmount ELSE 0 END) as revenue
      FROM orders WHERE date BETWEEN ? AND ? AND firmId = ? GROUP BY date ORDER BY date DESC
    ''', [startDate, endDate, firmId]);
  }

  Future<List<Map<String, dynamic>>> getOrdersByFoodTypeReport(
      String startDate, String endDate, String firmId) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT foodType, COUNT(*) as orderCount, SUM(totalPax) as totalPax,
             SUM(CASE WHEN isCancelled = 0 OR isCancelled IS NULL THEN finalAmount ELSE 0 END) as revenue
      FROM orders WHERE date BETWEEN ? AND ? AND firmId = ? AND (isCancelled = 0 OR isCancelled IS NULL) GROUP BY foodType ORDER BY orderCount DESC
    ''', [startDate, endDate, firmId]);
  }

  Future<List<Map<String, dynamic>>> getOrdersByMealTypeReport(
      String startDate, String endDate, String firmId) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT mealType, COUNT(*) as orderCount, SUM(totalPax) as totalPax,
             SUM(CASE WHEN isCancelled = 0 OR isCancelled IS NULL THEN finalAmount ELSE 0 END) as revenue
      FROM orders WHERE date BETWEEN ? AND ? AND firmId = ? AND (isCancelled = 0 OR isCancelled IS NULL) GROUP BY mealType ORDER BY orderCount DESC
    ''', [startDate, endDate, firmId]);
  }

  Future<List<Map<String, dynamic>>> getKitchenProductionReport(
      String startDate, String endDate, String firmId) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT o.date, COUNT(d.id) as totalDishes, SUM(CASE WHEN d.productionStatus = 'COMPLETED' THEN 1 ELSE 0 END) as completed,
             SUM(CASE WHEN d.productionStatus = 'IN_PROGRESS' THEN 1 ELSE 0 END) as inProgress,
             SUM(CASE WHEN d.productionStatus IS NULL OR d.productionStatus = 'PENDING' THEN 1 ELSE 0 END) as pending, SUM(COALESCE(d.pax, 0)) as totalPax
      FROM dishes d JOIN orders o ON d.orderId = o.id WHERE o.date BETWEEN ? AND ? AND o.firmId = ? GROUP BY o.date ORDER BY o.date DESC
    ''', [startDate, endDate, firmId]);
  }

  Future<List<Map<String, dynamic>>> getTopDishesReport(
      String startDate, String endDate, String firmId,
      {int limit = 10}) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT d.dishName AS name, d.category, COUNT(*) as orderCount, SUM(COALESCE(d.pax, 0)) as totalPax, SUM(COALESCE(d.pax * d.pricePerPlate, 0)) as totalRevenue
      FROM dishes d JOIN orders o ON d.orderId = o.id WHERE o.date BETWEEN ? AND ? AND o.firmId = ? AND (o.isCancelled = 0 OR o.isCancelled IS NULL)
      GROUP BY d.dishName ORDER BY orderCount DESC LIMIT ?
    ''', [startDate, endDate, firmId, limit]);
  }

  Future<List<Map<String, dynamic>>> getDishesByCategoryReport(
      String startDate, String endDate, String firmId) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT COALESCE(d.category, 'Uncategorized') as category, COUNT(*) as dishCount, SUM(COALESCE(d.pax, 0)) as totalPax,
             SUM(COALESCE(d.pax * d.pricePerPlate, 0)) as totalRevenue
      FROM dishes d JOIN orders o ON d.orderId = o.id WHERE o.date BETWEEN ? AND ? AND o.firmId = ? AND (o.isCancelled = 0 OR o.isCancelled IS NULL)
      GROUP BY d.category ORDER BY dishCount DESC
    ''', [startDate, endDate, firmId]);
  }

  Future<List<Map<String, dynamic>>> getDeliveryTimeReport(
      String startDate, String endDate, String firmId) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT CASE WHEN CAST(SUBSTR(o.time, 1, 2) AS INTEGER) < 12 THEN 'Morning (6-12)' WHEN CAST(SUBSTR(o.time, 1, 2) AS INTEGER) < 17 THEN 'Afternoon (12-5)' ELSE 'Evening (5-10)' END as timeSlot,
             COUNT(*) as orderCount, SUM(totalPax) as totalPax
      FROM orders o WHERE o.date BETWEEN ? AND ? AND o.firmId = ? AND (o.isCancelled = 0 OR o.isCancelled IS NULL) GROUP BY timeSlot
      ORDER BY CASE timeSlot WHEN 'Morning (6-12)' THEN 1 WHEN 'Afternoon (12-5)' THEN 2 ELSE 3 END
    ''', [startDate, endDate, firmId]);
  }

  Future<List<Map<String, dynamic>>> getRevenueByLocationReport(
      String startDate, String endDate, String firmId) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT COALESCE(location, venue, 'Unknown') as location, COUNT(*) as orderCount, SUM(totalPax) as totalPax,
             SUM(CASE WHEN isCancelled = 0 OR isCancelled IS NULL THEN finalAmount ELSE 0 END) as revenue
      FROM orders WHERE date BETWEEN ? AND ? AND firmId = ? AND (isCancelled = 0 OR isCancelled IS NULL) GROUP BY location
    ''', [startDate, endDate, firmId]);
  }

  // --- CUSTOMERS ---
  Future<List<Map<String, dynamic>>> getAllCustomers(String firmId) async {
    final db = await _dbHelper.database;
    return await db.query('customers',
        where: 'firmId = ?', whereArgs: [firmId], orderBy: 'name');
  }

  Future<int?> insertCustomer(Map<String, dynamic> data) async {
    final cloudSync = CloudSyncService();
    data['createdAt'] = DateTime.now().toIso8601String();
    data['uuid'] = data['uuid'] ?? _generateUuid();
    final id = await cloudSync.awsFirstWrite(table: 'customers', data: data);
    AppLogger.success('✅ [Customers] Created customer #$id (AWS-first)');
    return id;
  }

  Future<List<Map<String, dynamic>>> getDailyCapacityReport(
      String startDate, String endDate, String firmId) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT date, SUM(totalPax) as totalPax, COUNT(*) as orderCount,
             SUM(CASE WHEN foodType = 'Veg' THEN totalPax ELSE 0 END) as vegPax,
             SUM(CASE WHEN foodType = 'Non-Veg' THEN totalPax ELSE 0 END) as nonVegPax
      FROM orders
      WHERE date BETWEEN ? AND ? AND firmId = ? AND (isCancelled = 0 OR isCancelled IS NULL)
      GROUP BY date ORDER BY date DESC
    ''', [startDate, endDate, firmId]);
  }

  Future<List<Map<String, dynamic>>> getOrdersByFilter(String key, String value,
      {required String startDate,
      required String endDate,
      required String firmId}) async {
    final db = await _dbHelper.database;
    return await db.query(
      'orders',
      where: "$key = ? AND date BETWEEN ? AND ? AND firmId = ?",
      whereArgs: [value, startDate, endDate, firmId],
      orderBy: 'date DESC',
    );
  }
}
