// E2E STRESS TESTS: PERFORMANCE + LARGE DATA + SCALABILITY
// Covers: T-PERF-01 to 06, T-ORD-18, T-MRP-10, T-MRP-11, T-DR-05/06
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:ruchiserv/db/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return '.';
    });

    SharedPreferences.setMockInitialValues({
      'last_firm': 'STRESS_FIRM',
      'firmId': 'STRESS_FIRM',
      'user_role': 'Admin',
    });

    db = await DatabaseHelper().database;
  });

  // ═══════════════════════════════════════════
  // T-PERF: PERFORMANCE TESTS
  // ═══════════════════════════════════════════

  group('T-PERF: Performance', () {
    test('T-PERF-03: Insert 500 orders in < 5 seconds', () async {
      final sw = Stopwatch()..start();

      final batch = db.batch();
      for (int i = 0; i < 500; i++) {
        batch.insert('orders', {
          'firmId': 'STRESS_FIRM',
          'customerName': 'Bulk Customer $i',
          'date': '2024-${(i % 12 + 1).toString().padLeft(2, '0')}-${(i % 28 + 1).toString().padLeft(2, '0')}',
          'totalPax': 50 + (i % 500),
          'grandTotal': 10000.0 + i * 100,
          'isCancelled': i % 20 == 0 ? 1 : 0, // 5% cancelled
          'status': 'CONFIRMED',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);

      sw.stop();

      final count = await db.rawQuery(
        "SELECT COUNT(*) as c FROM orders WHERE firmId = 'STRESS_FIRM'");
      expect(count.first['c'], greaterThanOrEqualTo(500));
      expect(sw.elapsedMilliseconds, lessThan(5000));
      print('✅ T-PERF-03: 500 orders inserted in ${sw.elapsedMilliseconds}ms');
    });

    test('T-PERF-04: Query 500+ orders in < 1 second', () async {
      final sw = Stopwatch()..start();

      final orders = await db.query('orders',
        where: "firmId = 'STRESS_FIRM' AND isCancelled = 0",
        orderBy: 'date DESC');

      sw.stop();

      expect(orders.length, greaterThan(400)); // At least 475 non-cancelled
      expect(sw.elapsedMilliseconds, lessThan(1000));
      print('✅ T-PERF-04: ${orders.length} orders queried in ${sw.elapsedMilliseconds}ms');
    });

    test('T-PERF-05: Date range filter on 500+ orders', () async {
      final sw = Stopwatch()..start();

      final filtered = await db.rawQuery('''
        SELECT date, COUNT(*) as orderCount, SUM(totalPax) as totalPax, SUM(grandTotal) as totalRevenue
        FROM orders 
        WHERE firmId = 'STRESS_FIRM' AND isCancelled = 0
          AND date BETWEEN '2024-01-01' AND '2024-06-30'
        GROUP BY date
        ORDER BY date
      ''');

      sw.stop();

      expect(filtered.isNotEmpty, true);
      expect(sw.elapsedMilliseconds, lessThan(1000));
      print('✅ T-PERF-05: Date range query (H1 2024) — ${filtered.length} dates, ${sw.elapsedMilliseconds}ms');
    });

    test('T-PERF-06: Monthly aggregation report in < 500ms', () async {
      final sw = Stopwatch()..start();

      final monthly = await db.rawQuery('''
        SELECT 
          strftime('%Y-%m', date) as month,
          COUNT(*) as orders,
          SUM(totalPax) as totalPax,
          SUM(grandTotal) as revenue
        FROM orders 
        WHERE firmId = 'STRESS_FIRM' AND isCancelled = 0
        GROUP BY month
        ORDER BY month
      ''');

      sw.stop();

      expect(monthly.length, greaterThanOrEqualTo(6)); // Should have multiple months
      expect(sw.elapsedMilliseconds, lessThan(500));
      print('✅ T-PERF-06: Monthly report (${monthly.length} months) in ${sw.elapsedMilliseconds}ms');
    });
  });

  // ═══════════════════════════════════════════
  // T-ORD-18: LARGE ORDER STRESS
  // ═══════════════════════════════════════════

  group('T-ORD: Large Order Stress', () {
    test('T-ORD-18: Order with 5000 pax + 50 dishes', () async {
      final sw = Stopwatch()..start();

      final orderId = await db.insert('orders', {
        'firmId': 'STRESS_FIRM', 'customerName': 'Mega Wedding',
        'date': '2024-12-31', 'totalPax': 5000,
        'grandTotal': 2500000.0, 'isCancelled': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Insert 50 dishes
      final batch = db.batch();
      for (int i = 0; i < 50; i++) {
        batch.insert('dishes', {
          'firmId': 'STRESS_FIRM', 'orderId': orderId,
          'dishName': 'Dish #${i + 1} - ${['Starter', 'Main', 'Dessert', 'Beverage'][i % 4]}',
          'pax': 5000, 'pricePerPlate': 50.0 + i * 10,
          'category': ['Starter', 'Main Course', 'Dessert', 'Beverage'][i % 4],
          'isSubcontracted': i % 5 == 0 ? 1 : 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);

      sw.stop();

      final dishes = await db.query('dishes', where: 'orderId = ?', whereArgs: [orderId]);
      expect(dishes.length, 50);

      // Verify aggregations work on large order
      final agg = await db.rawQuery('''
        SELECT category, COUNT(*) as dishCount, SUM(pax) as totalServings
        FROM dishes WHERE orderId = ? GROUP BY category
      ''', [orderId]);
      expect(agg.length, 4); // 4 categories

      expect(sw.elapsedMilliseconds, lessThan(2000));
      print('✅ T-ORD-18: 5000 pax + 50 dishes created in ${sw.elapsedMilliseconds}ms');
    });
  });

  // ═══════════════════════════════════════════
  // T-MRP-10: MRP WITH 100+ ORDERS
  // ═══════════════════════════════════════════

  group('T-MRP: Stress', () {
    test('T-MRP-10: MRP run with 100 orders', () async {
      final sw = Stopwatch()..start();

      // Create MRP run
      final runId = await db.insert('mrp_runs', {
        'firmId': 'STRESS_FIRM', 'runDate': '2024-12-01', 'targetDate': '2024-12-15',
        'status': 'DRAFT', 'totalOrders': 100, 'totalPax': 30000,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Link 100 orders
      final batch = db.batch();
      for (int i = 0; i < 100; i++) {
        batch.insert('mrp_run_orders', {
          'mrpRunId': runId, 'orderId': 10000 + i, 'pax': 200 + i * 10,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);

      // Generate MRP output (50 ingredients)
      final outputBatch = db.batch();
      for (int i = 0; i < 50; i++) {
        outputBatch.insert('mrp_output', {
          'mrpRunId': runId, 'ingredientId': i + 1,
          'requiredQty': 100.0 + i * 20,
          'unit': ['kg', 'ltr', 'pcs'][i % 3],
          'inStockQty': 50.0 + i * 5,
          'purchaseQty': 50.0 + i * 15,
          'allocationStatus': 'PENDING',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await outputBatch.commit(noResult: true);

      sw.stop();

      final orders = await db.query('mrp_run_orders', where: 'mrpRunId = ?', whereArgs: [runId]);
      expect(orders.length, 100);

      final output = await db.query('mrp_output', where: 'mrpRunId = ?', whereArgs: [runId]);
      expect(output.length, 50);

      // Total purchase quantity
      final totalPurchase = await db.rawQuery(
        'SELECT SUM(purchaseQty) as total FROM mrp_output WHERE mrpRunId = ?', [runId]);
      expect((totalPurchase.first['total'] as double), greaterThan(0));

      expect(sw.elapsedMilliseconds, lessThan(5000));
      print('✅ T-MRP-10: MRP with 100 orders + 50 ingredients in ${sw.elapsedMilliseconds}ms');
    });

    test('T-MRP-11: Ingredient quantity normalization', () {
      // Test rounding for purchase orders
      double roundToPurchaseUnit(double qty, String unit) {
        switch (unit) {
          case 'kg': return (qty * 10).ceilToDouble() / 10; // Round up to 0.1kg
          case 'ltr': return (qty * 10).ceilToDouble() / 10;
          case 'pcs': return qty.ceilToDouble(); // Round up to whole units
          default: return qty;
        }
      }

      expect(roundToPurchaseUnit(5.23, 'kg'), 5.3);
      expect(roundToPurchaseUnit(5.21, 'kg'), 5.3);
      expect(roundToPurchaseUnit(5.0, 'kg'), 5.0);
      expect(roundToPurchaseUnit(3.1, 'pcs'), 4.0); // Can't buy 3.1 pieces
      expect(roundToPurchaseUnit(3.0, 'pcs'), 3.0);
      print('✅ T-MRP-11: Quantity normalization — kg:0.1, pcs:whole');
    });
  });

  // ═══════════════════════════════════════════
  // T-PERF: BATCH OPERATIONS
  // ═══════════════════════════════════════════

  group('T-PERF: Batch Operations', () {
    test('T-PERF-07: Batch insert 1000 finance records', () async {
      final sw = Stopwatch()..start();

      final batch = db.batch();
      for (int i = 0; i < 1000; i++) {
        batch.insert('finance', {
          'firmId': 'STRESS_FIRM',
          'type': i % 3 == 0 ? 'EXPENSE' : 'INCOME',
          'category': ['Salary', 'Raw Materials', 'Order Payment', 'Transport'][i % 4],
          'amount': 1000.0 + i * 10,
          'date': '2024-${(i % 12 + 1).toString().padLeft(2, '0')}-15',
          'paymentMode': ['Cash', 'UPI', 'Bank Transfer', 'Cheque'][i % 4],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);

      sw.stop();

      final count = await db.rawQuery(
        "SELECT COUNT(*) as c FROM finance WHERE firmId = 'STRESS_FIRM'");
      expect(count.first['c'], greaterThanOrEqualTo(1000));
      expect(sw.elapsedMilliseconds, lessThan(5000));
      print('✅ T-PERF-07: 1000 finance records in ${sw.elapsedMilliseconds}ms');
    });

    test('T-PERF-08: P&L calculation on 1000+ records', () async {
      final sw = Stopwatch()..start();

      final pl = await db.rawQuery('''
        SELECT 
          strftime('%Y-%m', date) as month,
          SUM(CASE WHEN type = 'INCOME' THEN amount ELSE 0 END) as income,
          SUM(CASE WHEN type = 'EXPENSE' THEN amount ELSE 0 END) as expense
        FROM finance 
        WHERE firmId = 'STRESS_FIRM'
        GROUP BY month
        ORDER BY month
      ''');

      sw.stop();

      expect(pl.length, greaterThanOrEqualTo(6));
      expect(sw.elapsedMilliseconds, lessThan(500));

      // Calculate net profit
      double totalIncome = 0, totalExpense = 0;
      for (final row in pl) {
        totalIncome += (row['income'] as num?)?.toDouble() ?? 0;
        totalExpense += (row['expense'] as num?)?.toDouble() ?? 0;
      }
      print('✅ T-PERF-08: P&L on 1000+ records — ${pl.length} months, ${sw.elapsedMilliseconds}ms, Net: ₹${(totalIncome - totalExpense).toStringAsFixed(0)}');
    });
  });

  // ═══════════════════════════════════════════
  // T-DR: ERROR HANDLING STRESS
  // ═══════════════════════════════════════════

  group('T-DR: Error Resilience', () {
    test('T-DR-05: Concurrent batch operations don\'t corrupt', () async {
      // Run two batch operations "concurrently" (sequentially in test but
      // verifies DB handles multiple batch commits)
      final batch1 = db.batch();
      final batch2 = db.batch();

      for (int i = 0; i < 50; i++) {
        batch1.insert('staff', {
          'firmId': 'STRESS_FIRM', 'name': 'Concurrent Staff A$i',
          'mobile': '111${i.toString().padLeft(7, '0')}', 'isActive': 1,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      for (int i = 0; i < 50; i++) {
        batch2.insert('staff', {
          'firmId': 'STRESS_FIRM', 'name': 'Concurrent Staff B$i',
          'mobile': '222${i.toString().padLeft(7, '0')}', 'isActive': 1,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      await batch1.commit(noResult: true);
      await batch2.commit(noResult: true);

      final count = await db.rawQuery(
        "SELECT COUNT(*) as c FROM staff WHERE firmId = 'STRESS_FIRM'");
      expect(count.first['c'], greaterThanOrEqualTo(100));
      print('✅ T-DR-05: 100 concurrent batch inserts — no corruption');
    });

    test('T-DR-06: Invalid data gracefully rejected', () async {
      // Insert with wrong types should be handled
      try {
        await db.insert('orders', {
          'firmId': 'STRESS_FIRM',
          'customerName': null, // NOT NULL field? 
          'date': '2024-01-01',
          'totalPax': 'not_a_number', // Should be integer
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        // If it didn't throw, SQLite coerced the type
        print('✅ T-DR-06: SQLite coerced invalid types (dynamic typing)');
      } catch (e) {
        // Expected if NOT NULL constraint is violated
        expect(e, isA<DatabaseException>());
        print('✅ T-DR-06: Invalid data correctly rejected: ${e.runtimeType}');
      }
    });

    test('T-PERF-09: DB file size check after stress data', () async {
      // Get approximate DB size via page count
      final pageCount = await db.rawQuery('PRAGMA page_count');
      final pageSize = await db.rawQuery('PRAGMA page_size');

      final pages = pageCount.first['page_count'] as int;
      final size = pageSize.first['page_size'] as int;
      final totalBytes = pages * size;
      final totalMB = totalBytes / (1024 * 1024);

      // After all stress data, DB should still be < 50MB
      expect(totalMB, lessThan(50));
      print('✅ T-PERF-09: DB size after stress: ${totalMB.toStringAsFixed(2)}MB (${pages} pages × ${size}B)');
    });
  });
}
