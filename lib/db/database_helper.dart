// lib/db/database_helper.dart
import 'dart:convert';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

// Optional but useful if you already added these in your project
// If not present, you can safely remove these two imports.
import '../services/connectivity_service.dart';
import '../db/aws/aws_api.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDB("ruchiserv.db");
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, fileName);
    return await openDatabase(
      path,
      version: 3, // keep at 3 as you already bumped
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // === ORDERS ====================================================
    await db.execute('''
      CREATE TABLE IF NOT EXISTS orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        customerName TEXT NOT NULL,
        mobile TEXT,
        email TEXT,
        location TEXT,
        mealType TEXT,
        foodType TEXT,
        time TEXT,
        notes TEXT,
        beforeDiscount REAL DEFAULT 0,
        discountPercent REAL DEFAULT 0,
        discountAmount REAL DEFAULT 0,
        finalAmount REAL DEFAULT 0,
        totalPax INTEGER DEFAULT 0,
        isLocked INTEGER DEFAULT 0,
        createdAt TEXT,
        updatedAt TEXT
      );
    ''');

    // === LOCAL USERS (offline login cache) =========================
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        firm_id INTEGER,
        username TEXT,
        email TEXT,
        password TEXT,
        role TEXT,
        is_active INTEGER DEFAULT 1,
        last_login TEXT
      );
    ''');

    // === DISHES ====================================================
    await db.execute('''
      CREATE TABLE IF NOT EXISTS dishes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orderId INTEGER NOT NULL,
        name TEXT NOT NULL,
        foodType TEXT,
        pax INTEGER DEFAULT 0,
        rate INTEGER DEFAULT 0,
        manualCost INTEGER DEFAULT 0,
        cost INTEGER DEFAULT 0,
        category TEXT,
        createdAt TEXT,
        FOREIGN KEY(orderId) REFERENCES orders(id) ON DELETE CASCADE
      );
    ''');

    // === FIRMS =====================================================
    await db.execute('''
      CREATE TABLE IF NOT EXISTS firms(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firmId TEXT UNIQUE NOT NULL,
        firmName TEXT NOT NULL,
        contactPerson TEXT,
        primaryMobile TEXT UNIQUE,
        alternateMobile TEXT,
        primaryEmail TEXT UNIQUE,
        alternateEmail TEXT,
        subscriptionPlan TEXT,
        subscriptionStart TEXT,
        subscriptionEnd TEXT,
        subscriptionStatus TEXT DEFAULT 'Active',
        allowedModules TEXT,
        maxUsers INTEGER DEFAULT 5,
        billingCycle TEXT,
        paymentMode TEXT,
        lastRenewalTxnId TEXT,
        createdAt TEXT,
        updatedAt TEXT
      );
    ''');

    // === USERS =====================================================
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firmId TEXT NOT NULL,
        userId TEXT UNIQUE NOT NULL,
        username TEXT UNIQUE NOT NULL,
        passwordHash TEXT NOT NULL,
        role TEXT DEFAULT 'User',
        permissions TEXT,
        mobile TEXT,
        email TEXT,
        isActive INTEGER DEFAULT 1,
        biometricEnabled INTEGER DEFAULT 0,
        lastLogin TEXT,
        createdAt TEXT,
        FOREIGN KEY(firmId) REFERENCES firms(firmId)
      );
    ''');

    // === AUTH LOGS =================================================
    await db.execute('''
      CREATE TABLE IF NOT EXISTS auth_logs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId TEXT NOT NULL,
        action TEXT,
        description TEXT,
        timestamp TEXT
      );
    ''');

    // === PENDING SYNC (offline queue) ==============================
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_sync (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT,
        data TEXT,          -- JSON blob
        action TEXT,        -- INSERT | UPDATE | DELETE
        timestamp TEXT
      );
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // defensive upgrades
    if (oldVersion < 3) {
      // Add columns if they don't exist
      try {
        await db.execute('ALTER TABLE orders ADD COLUMN totalPax INTEGER DEFAULT 0;');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE orders ADD COLUMN isLocked INTEGER DEFAULT 0;');
      } catch (_) {}

      // Ensure pending_sync exists with action column
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pending_sync (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          table_name TEXT,
          data TEXT,
          action TEXT,
          timestamp TEXT
        );
      ''');
    }
  }

  // ---------- BASIC UTILS ----------
  Future<void> testDB() async {
    final db = await database;
    // ignore: avoid_print
    print('✅ Database initialized at ${db.path}');
  }

  // ---------- ORDERS CRUD (LOCAL) ----------
  Future<int?> insertOrder(
    Map<String, dynamic> order,
    List<Map<String, dynamic>> dishes, {
    bool queueIfOffline = false,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    // Normalize
    order['createdAt'] = order['createdAt'] ?? now;
    order['updatedAt'] = now;
    order['totalPax'] = order['totalPax'] ?? 0;
    order['isLocked'] = order['isLocked'] ?? 0;

    // Insert order
    final orderId = await db.insert('orders', order);

    // Insert dishes
    for (final dish in dishes) {
      await db.insert('dishes', {
        'orderId': orderId,
        'name': dish['name'] ?? '',
        'foodType': dish['foodType'] ?? 'Veg',
        'pax': dish['pax'] ?? 0,
        'rate': dish['rate'] ?? 0,
        'manualCost': (dish['manualCost'] == true) ? 1 : 0,
        'cost': dish['cost'] ?? 0,
        'category': dish['category'] ?? '',
        'createdAt': now,
      });
    }

    // Hybrid: queue if offline
    if (queueIfOffline) {
      await queuePendingSync(
        table: 'orders',
        data: {
          ...order,
          'id': orderId, // return local id for mapping
          'dishes': dishes,
        },
        action: 'INSERT',
      );
    }

    return orderId;
  }

  Future<bool> updateOrder(
    int orderId,
    Map<String, dynamic> order,
    List<Map<String, dynamic>> dishes, {
    bool queueIfOffline = false,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    order['updatedAt'] = now;
    order['totalPax'] = order['totalPax'] ?? 0;

    await db.update('orders', order, where: 'id = ?', whereArgs: [orderId]);

    // Replace all dishes for the order
    await db.delete('dishes', where: 'orderId = ?', whereArgs: [orderId]);
    for (final dish in dishes) {
      await db.insert('dishes', {
        'orderId': orderId,
        'name': dish['name'] ?? '',
        'foodType': dish['foodType'] ?? 'Veg',
        'pax': dish['pax'] ?? 0,
        'rate': dish['rate'] ?? 0,
        'manualCost': (dish['manualCost'] == true) ? 1 : 0,
        'cost': dish['cost'] ?? 0,
        'category': dish['category'] ?? '',
        'createdAt': now,
      });
    }

    if (queueIfOffline) {
      await queuePendingSync(
        table: 'orders',
        data: {
          ...order,
          'id': orderId,
          'dishes': dishes,
        },
        action: 'UPDATE',
      );
    }

    return true;
  }

  Future<bool> deleteOrder(
    int orderId, {
    bool queueIfOffline = false,
  }) async {
    final db = await database;
    final result =
        await db.delete('orders', where: 'id = ?', whereArgs: [orderId]);

    if (queueIfOffline) {
      await queuePendingSync(
        table: 'orders',
        data: {'id': orderId},
        action: 'DELETE',
      );
    }

    return result > 0;
  }

  Future<List<Map<String, dynamic>>> getOrdersWithPax(String date) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT o.*, IFNULL(o.totalPax, 0) AS pax
      FROM orders o
      WHERE o.date = ?
      ORDER BY o.time ASC
    ''', [date]);
  }

  Future<List<Map<String, dynamic>>> getDishesForOrder(int orderId) async {
    final db = await database;
    return await db.query(
      'dishes',
      where:
          'orderId = ? AND name IS NOT NULL AND name != "" AND name != "Unnamed"',
      whereArgs: [orderId],
      orderBy: 'id ASC',
    );
  }

  Future<Map<String, int>> getTotalPaxForDate(String date) async {
    try {
      final db = await database;
      final result = await db
          .rawQuery('SELECT IFNULL(SUM(totalPax), 0) as total FROM orders WHERE date = ?', [date]);
      final totalPax = (result.first['total'] as int?) ?? 0;
      // Simple split; adjust if you store per-dish foodType for totals
      return {'total': totalPax, 'veg': totalPax ~/ 2, 'nonVeg': totalPax ~/ 2};
    } catch (_) {
      return {'total': 0, 'veg': 0, 'nonVeg': 0};
    }
  }

  Future<List<Map<String, dynamic>>> getAllOrdersWithPax() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        o.date,
        SUM(CASE WHEN o.foodType = 'Veg' THEN o.totalPax ELSE 0 END) AS vegPax,
        SUM(CASE WHEN o.foodType = 'Non-Veg' THEN o.totalPax ELSE 0 END) AS nonVegPax,
        SUM(o.totalPax) AS totalPax
      FROM orders o
      GROUP BY o.date
      ORDER BY o.date ASC
    ''');
  }

  // Simple getter for all orders by date (used by your UI)
  Future<List<Map<String, dynamic>>> getOrdersByDate(String date) async {
    final db = await database;
    return db.query(
      'orders',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'time ASC',
    );
  }

  // Dish summary for a date (used by your Summary screen)
  Future<List<Map<String, dynamic>>> getDishesSummaryByDate(String date) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT d.name,
             COALESCE(d.foodType, 'Veg') AS foodType,
             COALESCE(o.mealType, 'Snacks/Others') AS mealType,
             SUM(COALESCE(d.pax, 0)) AS totalPax,
             SUM(COALESCE(d.cost, 0)) AS totalCost
      FROM dishes d
      JOIN orders o ON o.id = d.orderId
      WHERE o.date = ?
      GROUP BY d.name, d.foodType, o.mealType
      ORDER BY o.mealType, d.name
    ''', [date]);
  }

  // ---------- FIRMS & USERS (LOCAL) ----------
  Future<int?> insertFirm(Map<String, dynamic> firm) async {
    final db = await database;
    return await db.insert('firms', firm);
  }

  Future<List<Map<String, dynamic>>> getAllFirms() async {
    final db = await database;
    return await db.query('firms', orderBy: 'firmName ASC');
  }

  Future<int?> insertUser(Map<String, dynamic> user) async {
    final db = await database;
    return await db.insert('users', user);
  }

  Future<List<Map<String, dynamic>>> getUsersByFirm(String firmId) async {
    final db = await database;
    return await db.query('users', where: 'firmId = ?', whereArgs: [firmId]);
  }

  Future<bool> verifyUserEligibility(String firmId, String mobile) async {
    try {
      final db = await database;
      final result = await db.query(
        'users',
        where: 'firmId = ? AND mobile = ?',
        whereArgs: [firmId, mobile],
      );
      return result.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ---------- LOCAL LOGIN SUPPORT ----------
  Future<void> insertLocalUser(Map<String, dynamic> user) async {
    try {
      final db = await database;
      await db.insert(
        'local_users',
        user,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      // ignore: avoid_print
      print("🟢 Local user cached: ${user['username']}");
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error caching local user: $e');
    }
  }

  Future<Map<String, dynamic>?> validateLocalLogin(
      String username, String password) async {
    try {
      final db = await database;
      final result = await db.query(
        'local_users',
        where: 'username = ? AND password = ?',
        whereArgs: [username, password],
        limit: 1,
      );
      if (result.isNotEmpty) {
        // ignore: avoid_print
        print("🟠 Offline login success for $username");
        return result.first;
      }
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('❌ Offline login check failed: $e');
      return null;
    }
  }

  // ---------- PENDING SYNC (OFFLINE QUEUE) ----------
  Future<int> rawInsertPendingSync(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('pending_sync', row);
  }

  Future<List<Map<String, dynamic>>> getPendingSync() async {
    final db = await database;
    return await db.query('pending_sync', orderBy: 'id ASC');
  }

  Future<void> markSynced(int id) async {
    final db = await database;
    await db.delete('pending_sync', where: 'id = ?', whereArgs: [id]);
  }

  /// Helper your UI (or LocalDbHelper) can call directly
  Future<void> queuePendingSync({
    required String table,
    required Map<String, dynamic> data,
    required String action, // INSERT | UPDATE | DELETE
  }) async {
    final now = DateTime.now().toIso8601String();
    await rawInsertPendingSync({
      'table_name': table,
      'data': jsonEncode(data),
      'action': action,
      'timestamp': now,
    });
  }
  // --- Add near your other "FIRMS" helpers ---

  Future<List<Map<String, dynamic>>> getFirmByFirmId(String firmId) async {
    final db = await database;
    return db.query('firms', where: 'firmId = ?', whereArgs: [firmId], limit: 1);
  }

  Future<void> upsertFirmSubscription({
    required String firmId,
    required String status,
    required String startIso,
    required String endIso,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final data = {
      'firmId': firmId,
      'subscriptionStatus': status,
      'subscriptionStart': startIso.isNotEmpty ? startIso : null,
      'subscriptionEnd': endIso.isNotEmpty ? endIso : null,
      'updatedAt': now,
    };

    // Try update first
    final count = await db.update('firms', data, where: 'firmId = ?', whereArgs: [firmId]);
    if (count == 0) {
      // Insert minimal row if it doesn't exist
      data['firmName'] = data['firmName'] ?? 'Unknown';
      data['createdAt'] = now;
      await db.insert('firms', data, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  /// Process the offline queue if we are online.
  /// - Keeps front-end unchanged.
  /// - Uses AwsApi.callDbHandler for POST/PUT/DELETE.
  Future<void> syncPendingIfOnline() async {
    // If you haven't added ConnectivityService, you can always try syncing.
    bool online = true;
    try {
      online = await ConnectivityService().isOnline();
    } catch (_) {}
    if (!online) return;

    final db = await database;
    final batch = db.batch();

    final pending = await getPendingSync();
    for (final row in pending) {
      final id = row['id'] as int;
      final table = row['table_name'] as String;
      final action = (row['action'] as String?)?.toUpperCase() ?? '';
      final dataStr = row['data'] as String? ?? '{}';
      final Map<String, dynamic> data = jsonDecode(dataStr);

      try {
        Map<String, dynamic> resp;

        if (action == 'INSERT') {
          // POST
          resp = await AwsApi.callDbHandler(
            method: 'POST',
            table: table,
            data: data,
          );
        } else if (action == 'UPDATE') {
          // PUT (expects an id in data)
          final idVal = data['id'];
          resp = await AwsApi.callDbHandler(
            method: 'PUT',
            table: table,
            data: data,
            filters: (idVal != null) ? {'id': idVal} : null,
          );
        } else if (action == 'DELETE') {
          // DELETE (prefers filters for id)
          final idVal = data['id'];
          resp = await AwsApi.callDbHandler(
            method: 'DELETE',
            table: table,
            filters: (idVal != null) ? {'id': idVal} : null,
          );
        } else {
          // Unknown action -> skip
          await markSynced(id);
          continue;
        }

        final ok =
            (resp['status']?.toString().toLowerCase() ?? '') == 'success';

        if (ok) {
          // success -> remove from queue
          await markSynced(id);
        } else {
          // If backend rejects, keep it in queue for next attempt.
          // You can add retry counters if you want later.
        }
      } catch (e) {
        // Network/API failure — keep in queue silently
      }
    }

    await batch.commit(noResult: true);
  }

  // ---------- DANGEROUS UTILS ----------
  Future<void> deleteAllFirms() async {
    final db = await database;
    await db.delete('firms');
    // ignore: avoid_print
    print('🗑️ All firms deleted from local DB');
  }
}
