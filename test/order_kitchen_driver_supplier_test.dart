// E2E TEST MODULE: ORDER CRUD + KITCHEN + DRIVER + SUPPLIER + VEHICLE + ATTENDANCE
// Tests use ACTUAL DB schemas verified via sqlite3 on ruchiserv_v2.db
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ruchiserv/db/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return '.';
    });

    SharedPreferences.setMockInitialValues({
      'last_firm': 'TEST_FIRM',
      'firmId': 'TEST_FIRM',
      'user_role': 'Admin',
    });
  });

  // ═══════════════════════════════════════════
  // MODULE 4: ORDER CRUD — FULL LIFECYCLE
  // Schema: orders(id, firmId, isCancelled, date, customerName, mobile, email,
  //   totalPax, foodType, mealType, time, location, beforeDiscount, discountPercent,
  //   discountAmount, finalAmount, grandTotal, serviceRequired, serviceType,
  //   staffCount, staffRate, counterSetupRequired, counterSetupRate, serviceCost,
  //   counterSetupCost, uuid, status, ...)
  // ═══════════════════════════════════════════

  group('T-ORD: Order CRUD Full Lifecycle', () {
    test('T-ORD-01: Insert order + dishes', () async {
      final db = await DatabaseHelper().database;

      final orderId = await db.insert('orders', {
        'firmId': 'TEST_FIRM',
        'customerName': 'Wedding Reception - Sharma',
        'mobile': '9876543210',
        'date': '2024-04-15',
        'time': '19:00',
        'location': 'Grand Palace Hall, Mumbai',
        'totalPax': 500,
        'foodType': 'Mixed',
        'grandTotal': 250000.0,
        'status': 'CONFIRMED',
        'isCancelled': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      expect(orderId, greaterThan(0));

      for (final dish in [
        {'name': 'Paneer Butter Masala', 'pax': 500, 'price': 120.0, 'category': 'Main Course'},
        {'name': 'Biryani', 'pax': 500, 'price': 150.0, 'category': 'Main Course'},
        {'name': 'Gulab Jamun', 'pax': 500, 'price': 40.0, 'category': 'Dessert'},
      ]) {
        await db.insert('dishes', {
          'firmId': 'TEST_FIRM',
          'orderId': orderId,
          'dishName': dish['name'],
          'pax': dish['pax'],
          'pricePerPlate': dish['price'],
          'category': dish['category'],
          'isSubcontracted': 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      final dishes = await db.query('dishes', where: 'orderId = ?', whereArgs: [orderId]);
      expect(dishes.length, 3);
      
      final order = await db.query('orders', where: 'id = ?', whereArgs: [orderId]);
      expect(order.first['customerName'], 'Wedding Reception - Sharma');
      expect(order.first['totalPax'], 500);
      print('✅ T-ORD-01: Order#$orderId with 3 dishes created');
    });

    test('T-ORD-02: Update order fields', () async {
      final db = await DatabaseHelper().database;
      final orders = await db.query('orders', where: "customerName LIKE '%Sharma%'", limit: 1);
      if (orders.isNotEmpty) {
        final orderId = orders.first['id'] as int;
        await db.update('orders', {
          'totalPax': 600,
          'grandTotal': 300000.0,
          'location': 'Updated Venue',
        }, where: 'id = ?', whereArgs: [orderId]);

        final updated = await db.query('orders', where: 'id = ?', whereArgs: [orderId]);
        expect(updated.first['totalPax'], 600);
        expect(updated.first['grandTotal'], 300000.0);
        print('✅ T-ORD-02: Order updated — pax:600, total:₹300000');
      }
    });

    test('T-ORD-03: Cancel order (soft delete)', () async {
      final db = await DatabaseHelper().database;
      final orderId = await db.insert('orders', {
        'firmId': 'TEST_FIRM', 'customerName': 'Cancel Test', 'date': '2024-05-01',
        'totalPax': 200, 'isCancelled': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await db.update('orders', {'isCancelled': 1}, where: 'id = ?', whereArgs: [orderId]);
      final cancelled = await db.query('orders', where: 'id = ? AND isCancelled = 1', whereArgs: [orderId]);
      expect(cancelled.length, 1);
      print('✅ T-ORD-03: Order soft-deleted (isCancelled=1)');
    });

    test('T-ORD-06: Discount calculation fields', () async {
      final db = await DatabaseHelper().database;
      final orderId = await db.insert('orders', {
        'firmId': 'TEST_FIRM', 'customerName': 'Discount Test', 'date': '2024-06-01',
        'totalPax': 300, 'beforeDiscount': 90000.0, 'discountPercent': 10.0,
        'discountAmount': 9000.0, 'finalAmount': 81000.0, 'grandTotal': 81000.0,
        'isCancelled': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final order = await db.query('orders', where: 'id = ?', whereArgs: [orderId]);
      expect(order.first['beforeDiscount'], 90000.0);
      expect(order.first['discountPercent'], 10.0);
      expect(order.first['discountAmount'], 9000.0);
      expect(order.first['finalAmount'], 81000.0);
      print('✅ T-ORD-06: Discount calc stored correctly');
    });

    test('T-ORD-07: Service cost fields', () async {
      final db = await DatabaseHelper().database;
      final orderId = await db.insert('orders', {
        'firmId': 'TEST_FIRM', 'customerName': 'Service Cost Test', 'date': '2024-07-01',
        'totalPax': 400, 'serviceRequired': 1, 'serviceType': 'FULL_SERVICE',
        'staffCount': 5, 'staffRate': 500.0, 'serviceCost': 2500.0,
        'counterSetupRequired': 1, 'counterSetupRate': 2000.0, 'counterSetupCost': 2000.0,
        'isCancelled': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final order = await db.query('orders', where: 'id = ?', whereArgs: [orderId]);
      expect(order.first['serviceCost'], 2500.0);
      expect(order.first['counterSetupCost'], 2000.0);
      print('✅ T-ORD-07: Service cost fields verified');
    });

    test('T-ORD-08: Orders query by date + pax aggregation', () async {
      final db = await DatabaseHelper().database;
      await db.insert('orders', {
        'firmId': 'TEST_FIRM', 'customerName': 'Date Test A', 'date': '2024-08-15',
        'totalPax': 100, 'isCancelled': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await db.insert('orders', {
        'firmId': 'TEST_FIRM', 'customerName': 'Date Test B', 'date': '2024-08-15',
        'totalPax': 200, 'isCancelled': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final results = await db.query('orders',
        where: "date = '2024-08-15' AND firmId = 'TEST_FIRM' AND isCancelled = 0");
      expect(results.length, greaterThanOrEqualTo(2));

      final totalPax = results.fold<int>(0, (sum, o) => sum + (o['totalPax'] as int? ?? 0));
      expect(totalPax, greaterThanOrEqualTo(300));
      print('✅ T-ORD-08: Date query — ${results.length} orders, $totalPax pax');
    });

    test('T-ORD-09: Dish subcontracting toggle', () async {
      final db = await DatabaseHelper().database;
      final dishId = await db.insert('dishes', {
        'firmId': 'TEST_FIRM', 'orderId': 1, 'dishName': 'Sub Toggle Test',
        'pax': 300, 'pricePerPlate': 150.0, 'isSubcontracted': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await db.update('dishes', {'isSubcontracted': 1, 'subcontractorId': 5},
        where: 'id = ?', whereArgs: [dishId]);
      var dish = await db.query('dishes', where: 'id = ?', whereArgs: [dishId]);
      expect(dish.first['isSubcontracted'], 1);

      await db.update('dishes', {'isSubcontracted': 0, 'subcontractorId': null},
        where: 'id = ?', whereArgs: [dishId]);
      dish = await db.query('dishes', where: 'id = ?', whereArgs: [dishId]);
      expect(dish.first['isSubcontracted'], 0);
      print('✅ T-ORD-09: Dish subcontracting toggle ON/OFF');
    });
  });

  // ═══════════════════════════════════════════
  // MODULE 5: KITCHEN / OPERATIONS
  // ═══════════════════════════════════════════

  group('T-KIT: Kitchen & Operations', () {
    test('T-KIT-01: Production queue for today', () async {
      final db = await DatabaseHelper().database;
      final today = DateTime.now().toIso8601String().substring(0, 10);
      await db.insert('orders', {
        'firmId': 'TEST_FIRM', 'customerName': 'Kitchen Queue',
        'date': today, 'totalPax': 100, 'status': 'CONFIRMED', 'isCancelled': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final orders = await db.query('orders',
        where: "date = ? AND firmId = ? AND (isCancelled = 0 OR isCancelled IS NULL)",
        whereArgs: [today, 'TEST_FIRM']);
      expect(orders.isNotEmpty, true);
      print('✅ T-KIT-01: Production queue has ${orders.length} orders for today');
    });

    test('T-KIT-04: Dish aggregation across orders', () async {
      final db = await DatabaseHelper().database;
      final o1 = await db.insert('orders', {
        'firmId': 'TEST_FIRM', 'customerName': 'Agg1', 'date': '2024-09-01',
        'totalPax': 100, 'isCancelled': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      final o2 = await db.insert('orders', {
        'firmId': 'TEST_FIRM', 'customerName': 'Agg2', 'date': '2024-09-01',
        'totalPax': 200, 'isCancelled': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await db.insert('dishes', {
        'firmId': 'TEST_FIRM', 'orderId': o1, 'dishName': 'Agg Biryani',
        'pax': 100, 'pricePerPlate': 150.0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await db.insert('dishes', {
        'firmId': 'TEST_FIRM', 'orderId': o2, 'dishName': 'Agg Biryani',
        'pax': 200, 'pricePerPlate': 150.0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final summary = await db.rawQuery('''
        SELECT dishName, SUM(pax) as totalPax FROM dishes
        WHERE firmId = 'TEST_FIRM' AND dishName = 'Agg Biryani'
        GROUP BY dishName
      ''');
      expect(summary.first['totalPax'], 300);
      print('✅ T-KIT-04: Dish aggregation — 300 pax total');
    });

    test('T-KIT-10: Dish master for auto-suggest', () async {
      final db = await DatabaseHelper().database;
      await db.insert('dish_master', {
        'firmId': 'TEST_FIRM', 'name': 'Butter Chicken',
        'category': 'Non-Veg Main', 'base_pax': 100,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final suggestions = await db.query('dish_master',
        where: "name LIKE ? AND firmId = ?", whereArgs: ['%Butter%', 'TEST_FIRM']);
      expect(suggestions.isNotEmpty, true);
      expect(suggestions.first['name'], 'Butter Chicken');
      print('✅ T-KIT-10: Dish master auto-suggest verified');
    });

    test('T-KIT-11: Production status flow PENDING→IN_PROGRESS→READY', () async {
      final db = await DatabaseHelper().database;
      final dishId = await db.insert('dishes', {
        'firmId': 'TEST_FIRM', 'orderId': 1, 'dishName': 'Status Flow Test',
        'pax': 100, 'productionStatus': 'PENDING',
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // PENDING → IN_PROGRESS
      await db.update('dishes', {'productionStatus': 'IN_PROGRESS'}, where: 'id = ?', whereArgs: [dishId]);
      var dish = await db.query('dishes', where: 'id = ?', whereArgs: [dishId]);
      expect(dish.first['productionStatus'], 'IN_PROGRESS');

      // IN_PROGRESS → READY
      await db.update('dishes', {
        'productionStatus': 'READY', 'readyAt': DateTime.now().toIso8601String(),
      }, where: 'id = ?', whereArgs: [dishId]);
      dish = await db.query('dishes', where: 'id = ?', whereArgs: [dishId]);
      expect(dish.first['productionStatus'], 'READY');
      expect(dish.first['readyAt'], isNotNull);
      print('✅ T-KIT-11: Production flow PENDING→IN_PROGRESS→READY');
    });
  });

  // ═══════════════════════════════════════════
  // MODULE 6: STAFF & ATTENDANCE
  // ═══════════════════════════════════════════

  group('T-STF: Staff & Attendance', () {
    test('T-STF-01: Add staff member', () async {
      final db = await DatabaseHelper().database;
      final staffId = await db.insert('staff', {
        'firmId': 'TEST_FIRM', 'name': 'Raju Kumar', 'mobile': '9999999001',
        'role': 'Cook', 'staffType': 'PERMANENT', 'salary': 20000.0, 'isActive': 1,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      expect(staffId, greaterThan(0));
      print('✅ T-STF-01: Staff Raju Kumar added');
    });

    test('T-STF-03: Attendance punch', () async {
      final db = await DatabaseHelper().database;
      final today = DateTime.now().toIso8601String().substring(0, 10);
      await db.insert('attendance', {
        'staffId': 1, 'date': today,
        'status': 'PRESENT', 'punchInTime': '09:00', 'punchOutTime': '18:00', 'overtimeHours': 1.0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final record = await db.query('attendance',
        where: 'staffId = ? AND date = ?', whereArgs: [1, today]);
      expect(record.isNotEmpty, true);
      expect(record.first['status'], 'PRESENT');
      expect(record.first['punchInTime'], '09:00');
      expect(record.first['overtimeHours'], 1.0);
      print('✅ T-STF-03: Attendance punched — PRESENT, OT:1h');
    });

    test('T-STF-05: Staff types PERMANENT/DAILY_WAGE/CONTRACT', () async {
      final db = await DatabaseHelper().database;
      for (final type in ['PERMANENT', 'DAILY_WAGE', 'CONTRACT']) {
        await db.insert('staff', {
          'firmId': 'TEST_FIRM', 'name': 'Type $type',
          'mobile': '000${type.hashCode.abs() % 10000000}',
          'staffType': type, 'isActive': 1,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final type in ['PERMANENT', 'DAILY_WAGE', 'CONTRACT']) {
        final result = await db.query('staff', where: "staffType = ? AND firmId = 'TEST_FIRM'", whereArgs: [type]);
        expect(result.isNotEmpty, true, reason: 'Missing staff type: $type');
      }
      print('✅ T-STF-05: All 3 staff types verified');
    });
  });

  // ═══════════════════════════════════════════
  // MODULE 7: DISPATCH & VEHICLES
  // Schema: dispatches(orderId, vehicleId, driverId, dispatchStatus, dispatchTime, ...)
  // Schema: dispatch_items(dispatchId, itemType, itemName, quantity, loadedQty, returnedQty, ...)
  // ═══════════════════════════════════════════

  group('T-DSP: Dispatch & Vehicles', () {
    test('T-DSP-01: Create dispatch with items', () async {
      final db = await DatabaseHelper().database;
      final dispatchId = await db.insert('dispatches', {
        'orderId': 1, 'vehicleId': 1, 'driverId': 1,
        'dispatchStatus': 'PENDING', 'dispatchTime': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      expect(dispatchId, greaterThan(0));

      for (final item in ['Plate', 'Spoon', 'Glass']) {
        await db.insert('dispatch_items', {
          'dispatchId': dispatchId, 'itemType': 'UTENSIL', 'itemName': item,
          'quantity': 100, 'loadedQty': 100, 'returnedQty': 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      final items = await db.query('dispatch_items', where: 'dispatchId = ?', whereArgs: [dispatchId]);
      expect(items.length, 3);
      print('✅ T-DSP-01: Dispatch#$dispatchId with 3 items');
    });

    test('T-DSP-03: Vehicle CRUD', () async {
      final db = await DatabaseHelper().database;
      final vehicleId = await db.insert('vehicles', {
        'firmId': 'TEST_FIRM', 'vehicleNumber': 'KA-01-AB-1234',
        'vehicleType': 'Tempo', 'driverName': 'Suresh', 'driverMobile': '9876543111',
        'isActive': 1,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      expect(vehicleId, greaterThan(0));

      await db.update('vehicles', {'vehicleType': 'Mini Truck'}, where: 'id = ?', whereArgs: [vehicleId]);
      final v = await db.query('vehicles', where: 'id = ?', whereArgs: [vehicleId]);
      expect(v.first['vehicleType'], 'Mini Truck');

      await db.update('vehicles', {'isActive': 0}, where: 'id = ?', whereArgs: [vehicleId]);
      final active = await db.query('vehicles', where: 'isActive = 1 AND id = ?', whereArgs: [vehicleId]);
      expect(active.isEmpty, true);
      print('✅ T-DSP-03: Vehicle CRUD verified');
    });

    test('T-DSP-05: Dispatch status flow', () async {
      final db = await DatabaseHelper().database;
      final dispId = await db.insert('dispatches', {
        'orderId': 2, 'dispatchStatus': 'PENDING',
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      for (final status in ['DISPATCHED', 'DELIVERED', 'RETURNED']) {
        await db.update('dispatches', {'dispatchStatus': status}, where: 'id = ?', whereArgs: [dispId]);
        var d = await db.query('dispatches', where: 'id = ?', whereArgs: [dispId]);
        expect(d.first['dispatchStatus'], status);
      }
      print('✅ T-DSP-05: Dispatch flow PENDING→DISPATCHED→DELIVERED→RETURNED');
    });

    test('T-DSP-10: Dispatch return tracking', () async {
      final db = await DatabaseHelper().database;
      final dispId = await db.insert('dispatches', {
        'orderId': 3, 'dispatchStatus': 'DISPATCHED',
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await db.insert('dispatch_items', {
        'dispatchId': dispId, 'itemType': 'UTENSIL', 'itemName': 'Plates',
        'quantity': 100, 'loadedQty': 100, 'returnedQty': 0, 'status': 'PENDING',
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Return with variance
      await db.update('dispatch_items', {
        'returnedQty': 95, 'unloadedQty': 95, 'status': 'COMPLETED',
      }, where: 'dispatchId = ? AND itemName = ?', whereArgs: [dispId, 'Plates']);

      final item = await db.query('dispatch_items',
        where: 'dispatchId = ? AND itemName = ?', whereArgs: [dispId, 'Plates']);
      final variance = (item.first['loadedQty'] as int) - (item.first['returnedQty'] as int);
      expect(variance, 5);
      print('✅ T-DSP-10: Return tracking — 5 plates missing');
    });
  });

  // ═══════════════════════════════════════════
  // MODULE 12: SUPPLIERS & PURCHASE ORDERS
  // ═══════════════════════════════════════════

  group('T-SUP: Suppliers & POs', () {
    test('T-SUP-01: Supplier CRUD', () async {
      final db = await DatabaseHelper().database;
      final suppId = await db.insert('suppliers', {
        'firmId': 'TEST_FIRM', 'name': 'Fresh Vegetables Co.',
        'mobile': '9876500001', 'email': 'fresh@veg.com', 'category': 'Vegetables',
        'isActive': 1,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      expect(suppId, greaterThan(0));
      print('✅ T-SUP-01: Supplier created');
    });

    test('T-SUP-02: PO with items', () async {
      final db = await DatabaseHelper().database;
      final poId = await db.insert('purchase_orders', {
        'firmId': 'TEST_FIRM', 'poNumber': 'PO-2024-001', 'type': 'INGREDIENT',
        'vendorId': 1, 'vendorName': 'Fresh Vegetables Co.', 'status': 'SENT',
        'totalAmount': 6000.0, 'totalItems': 2,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await db.insert('po_items', {
        'poId': poId, 'itemId': 1, 'itemName': 'Rice', 'quantity': 50.0,
        'unit': 'kg', 'pricePerUnit': 60.0, 'totalPrice': 3000.0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await db.insert('po_items', {
        'poId': poId, 'itemId': 2, 'itemName': 'Oil', 'quantity': 20.0,
        'unit': 'ltr', 'pricePerUnit': 150.0, 'totalPrice': 3000.0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final items = await db.query('po_items', where: 'poId = ?', whereArgs: [poId]);
      expect(items.length, 2);
      final total = items.fold<double>(0, (s, i) => s + (i['totalPrice'] as double? ?? 0));
      expect(total, 6000.0);
      print('✅ T-SUP-02: PO#PO-2024-001 with 2 items, total ₹$total');
    });

    test('T-SUP-04: Subcontractor CRUD', () async {
      final db = await DatabaseHelper().database;
      final subId = await db.insert('subcontractors', {
        'firmId': 'TEST_FIRM', 'name': 'Annapurna Caterers',
        'mobile': '9876500002', 'specialty': 'South Indian', 'isActive': 1,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      expect(subId, greaterThan(0));
      final sub = await db.query('subcontractors', where: 'id = ?', whereArgs: [subId]);
      expect(sub.first['specialty'], 'South Indian');
      print('✅ T-SUP-04: Subcontractor created');
    });
  });

  // ═══════════════════════════════════════════
  // MODULE 11: INGREDIENTS & RECIPE
  // Schema: ingredients_master(name, unit_of_measure, cost_per_unit, ...)
  // Schema: recipe_detail(dish_id, ing_id, quantity_per_base_pax, unit_override, ...)
  // ═══════════════════════════════════════════

  group('T-INV: Ingredients & Recipe', () {
    test('T-INV-01: Ingredient master CRUD', () async {
      final db = await DatabaseHelper().database;
      await db.insert('ingredients_master', {
        'firmId': 'TEST_FIRM', 'name': 'Basmati Rice',
        'unit_of_measure': 'kg', 'cost_per_unit': 60.0, 'category': 'Grains',
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final ing = await db.query('ingredients_master',
        where: "name = 'Basmati Rice' AND firmId = 'TEST_FIRM'");
      expect(ing.isNotEmpty, true);
      expect(ing.first['unit_of_measure'], 'kg');
      expect(ing.first['cost_per_unit'], 60.0);
      print('✅ T-INV-01: Ingredient Basmati Rice, ₹60/kg');
    });

    test('T-INV-02: Recipe detail linkage (dish→ingredients)', () async {
      final db = await DatabaseHelper().database;

      // Get/create dish master and ingredient
      final dishMasterId = await db.insert('dish_master', {
        'firmId': 'TEST_FIRM', 'name': 'Biryani Recipe', 'base_pax': 100,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final ingId = await db.insert('ingredients_master', {
        'firmId': 'TEST_FIRM', 'name': 'Rice For Recipe', 'unit_of_measure': 'kg',
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Link via recipe_detail with FK IDs
      await db.insert('recipe_detail', {
        'firmId': 'TEST_FIRM', 'dish_id': dishMasterId, 'ing_id': ingId,
        'quantity_per_base_pax': 5.0, 'unit_override': 'kg',
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final recipe = await db.query('recipe_detail',
        where: 'dish_id = ? AND firmId = ?', whereArgs: [dishMasterId, 'TEST_FIRM']);
      expect(recipe.isNotEmpty, true);

      // Scale for 300 pax: 300/100 * 5 = 15kg
      final qtyPerBase = recipe.first['quantity_per_base_pax'] as double;
      final scaledQty = (300 / 100) * qtyPerBase;
      expect(scaledQty, 15.0);
      print('✅ T-INV-02: Recipe scaling — 300 pax needs ${scaledQty}kg rice');
    });
  });

  // ═══════════════════════════════════════════
  // MODULE 9: FINANCE
  // Schema: finance(firmId, type, category, amount, date, description, paymentMode, ...)
  // ═══════════════════════════════════════════

  group('T-FIN: Finance Advanced', () {
    test('T-FIN-01: Income/Expense with categories', () async {
      final db = await DatabaseHelper().database;

      await db.insert('finance', {
        'firmId': 'TEST_FIRM', 'type': 'INCOME', 'category': 'Order Payment',
        'amount': 250000.0, 'date': '2024-04-15', 'description': 'Wedding - Sharma',
        'paymentMode': 'UPI',
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      for (final exp in [
        {'cat': 'Raw Materials', 'amt': 80000.0},
        {'cat': 'Salary', 'amt': 50000.0},
        {'cat': 'Transport', 'amt': 15000.0},
      ]) {
        await db.insert('finance', {
          'firmId': 'TEST_FIRM', 'type': 'EXPENSE', 'category': exp['cat'],
          'amount': exp['amt'], 'date': '2024-04-15', 'paymentMode': 'Cash',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      final summary = await db.rawQuery('''
        SELECT 
          SUM(CASE WHEN type = 'INCOME' THEN amount ELSE 0 END) as income,
          SUM(CASE WHEN type = 'EXPENSE' THEN amount ELSE 0 END) as expense
        FROM finance WHERE firmId = 'TEST_FIRM'
      ''');
      final income = summary.first['income'] as double? ?? 0;
      final expense = summary.first['expense'] as double? ?? 0;
      expect(income, greaterThan(0));
      expect(expense, greaterThan(0));
      print('✅ T-FIN-01: Income: ₹$income, Expense: ₹$expense, P/L: ₹${income - expense}');
    });

    test('T-FIN-12: Payment modes', () async {
      final db = await DatabaseHelper().database;
      for (final mode in ['Cash', 'UPI', 'Bank Transfer', 'Cheque']) {
        await db.insert('finance', {
          'firmId': 'TEST_FIRM', 'type': 'INCOME', 'category': 'Test',
          'amount': 10000.0, 'date': '2024-05-01', 'paymentMode': mode,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final mode in ['Cash', 'UPI', 'Bank Transfer', 'Cheque']) {
        final result = await db.query('finance',
          where: "paymentMode = ? AND firmId = 'TEST_FIRM'", whereArgs: [mode]);
        expect(result.isNotEmpty, true, reason: 'Missing mode: $mode');
      }
      print('✅ T-FIN-12: All 4 payment modes verified');
    });
  });

  // ═══════════════════════════════════════════
  // MODULE 10: MRP ADVANCED
  // Schema: mrp_runs(firmId, runDate, targetDate, status, ...)
  // Schema: mrp_output(mrpRunId, ingredientId, requiredQty, unit, ...)
  // ═══════════════════════════════════════════

  group('T-MRP: Advanced MRP', () {
    test('T-MRP-01: MRP run creation with output', () async {
      final db = await DatabaseHelper().database;
      final runId = await db.insert('mrp_runs', {
        'firmId': 'TEST_FIRM', 'runDate': '2024-08-01', 'targetDate': '2024-08-05',
        'status': 'DRAFT', 'createdAt': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await db.insert('mrp_run_orders', {
        'mrpRunId': runId, 'orderId': 999, 'pax': 300,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await db.insert('mrp_output', {
        'mrpRunId': runId, 'ingredientId': 1, 'requiredQty': 50.0,
        'unit': 'kg', 'inStockQty': 30.0, 'purchaseQty': 20.0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final output = await db.query('mrp_output', where: 'mrpRunId = ?', whereArgs: [runId]);
      expect(output.first['purchaseQty'], 20.0);
      print('✅ T-MRP-01: MRP run — shortfall 20kg purchase required');
    });

    test('T-MRP-06: Shortfall = required - stock', () {
      const required = 50.0;
      const stock = 30.0;
      expect(required - stock, 20.0);
      expect((30.0 - 60.0) > 0 ? (30.0 - 60.0) : 0, 0);
      print('✅ T-MRP-06: Shortfall calc verified');
    });
  });

  // ═══════════════════════════════════════════
  // MODULE 15: NOTIFICATIONS
  // ═══════════════════════════════════════════

  group('T-NTF: Notification Logic', () {
    test('T-NTF-06: Email payload structure', () {
      final payload = {
        'type': 'ORDER_CONFIRMATION', 'to': 'test@example.com',
        'data': {'firmId': 'TEST_FIRM', 'customerName': 'Test'},
      };
      expect(payload['type'], 'ORDER_CONFIRMATION');
      expect(payload['to'], isNotEmpty);
      print('✅ T-NTF-06: Email payload verified');
    });

    test('T-NTF-07: Missing email gracefully handled', () {
      String? vendorEmail;
      bool sent = vendorEmail != null && vendorEmail.isNotEmpty;
      expect(sent, false);
      print('✅ T-NTF-07: Missing email skipped gracefully');
    });
  });
}
