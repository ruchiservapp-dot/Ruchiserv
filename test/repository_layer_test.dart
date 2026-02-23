// REPOSITORY LAYER TESTS: Tests REAL code paths, not raw SQL
// This catches schema/column mismatches that raw db.insert tests miss
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ruchiserv/db/database_helper.dart';
import 'package:ruchiserv/repositories/order_repository.dart';
import 'package:ruchiserv/repositories/operation_repository.dart';
import 'package:ruchiserv/repositories/finance_repository.dart';
import 'package:ruchiserv/repositories/inventory_repository.dart';

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
      'last_firm': 'REPO_TEST',
      'firmId': 'REPO_TEST',
      'user_role': 'Admin',
    });
  });

  // ═══════════════════════════════════════════
  // 1. SCHEMA VALIDATION — verify all tables can be created
  // ═══════════════════════════════════════════

  group('SCHEMA: All tables exist and are usable', () {
    test('SCHEMA-01: DatabaseHelper initializes without error', () async {
      final db = await DatabaseHelper().database;
      expect(db, isNotNull);
      expect(db.isOpen, true);
      print('✅ SCHEMA-01: Database initialized successfully');
    });

    test('SCHEMA-02: All core tables are queryable', () async {
      final db = await DatabaseHelper().database;
      final tables = [
        'firms', 'customers', 'staff', 'attendance', 'orders',
        'dishes', 'finance', 'utensils', 'ingredients_master',
        'recipe_detail', 'subcontractors', 'suppliers', 'dispatches',
        'dispatch_items', 'vehicles', 'mrp_runs', 'mrp_run_orders',
        'mrp_output', 'dish_master', 'purchase_orders', 'po_items',
        'invoices', 'invoice_items', 'authorized_mobiles', 'users',
        'transactions', 'staff_assignments', 'pending_sync',
        'salary_disbursements', 'service_rates',
      ];

      for (final table in tables) {
        try {
          await db.query(table, limit: 1);
          print('  ✓ $table');
        } catch (e) {
          fail('❌ Table "$table" failed: $e');
        }
      }
      print('✅ SCHEMA-02: All ${tables.length} tables are queryable');
    });
  });

  // ═══════════════════════════════════════════
  // 2. ORDER REPOSITORY — Real code paths
  // ═══════════════════════════════════════════

  group('REPO-ORD: OrderRepository real code paths', () {
    test('REPO-ORD-01: insertOrder through repository', () async {
      final repo = OrderRepository();
      final orderId = await repo.insertOrder({
        'firmId': 'REPO_TEST',
        'customerName': 'Repo Test Customer',
        'mobile': '9999900001',
        'date': '2024-10-15',
        'time': '18:00',
        'location': 'Test Venue',
        'totalPax': 200,
        'foodType': 'Veg',
        'mealType': 'Dinner',
        'grandTotal': 50000.0,
        'status': 'CONFIRMED',
        'isCancelled': 0,
      }, [
        {
          'dishName': 'Paneer Tikka',
          'pax': 200,
          'pricePerPlate': 120.0,
          'category': 'Starter',
          'foodType': 'Veg',
        },
        {
          'dishName': 'Dal Makhani',
          'pax': 200,
          'pricePerPlate': 80.0,
          'category': 'Main Course',
          'foodType': 'Veg',
        },
      ]);
      expect(orderId, isNotNull);
      expect(orderId, greaterThan(0));
      print('✅ REPO-ORD-01: Order#$orderId created with 2 dishes via repository');
    });

    test('REPO-ORD-02: getOrdersByDate returns results', () async {
      final repo = OrderRepository();
      final orders = await repo.getOrdersByDate('2024-10-15', 'REPO_TEST');
      expect(orders.isNotEmpty, true);
      expect(orders.first['customerName'], 'Repo Test Customer');
      print('✅ REPO-ORD-02: getOrdersByDate found ${orders.length} orders');
    });

    test('REPO-ORD-03: getDishesForOrder returns dishes', () async {
      final repo = OrderRepository();
      final orders = await repo.getOrdersByDate('2024-10-15', 'REPO_TEST');
      final dishes = await repo.getDishesForOrder(orders.first['id'] as int, 'REPO_TEST');
      expect(dishes.isNotEmpty, true);
      expect(dishes.length, 2);
      print('✅ REPO-ORD-03: getDishesForOrder found ${dishes.length} dishes');
    });

    test('REPO-ORD-04: getOrdersWithPax returns correct data', () async {
      final repo = OrderRepository();
      final orders = await repo.getOrdersWithPax('2024-10-15', 'REPO_TEST');
      expect(orders.isNotEmpty, true);
      print('✅ REPO-ORD-04: getOrdersWithPax returns data with pax info');
    });

    test('REPO-ORD-05: getTotalPaxForDate returns aggregate', () async {
      final repo = OrderRepository();
      final pax = await repo.getTotalPaxForDate('2024-10-15', 'REPO_TEST');
      expect(pax, greaterThanOrEqualTo(200));
      print('✅ REPO-ORD-05: getTotalPaxForDate = $pax');
    });

    test('REPO-ORD-06: getProductionQueue returns dishes', () async {
      final repo = OrderRepository();
      final queue = await repo.getProductionQueue('REPO_TEST');
      expect(queue, isA<List>());
      print('✅ REPO-ORD-06: getProductionQueue returned ${queue.length} items');
    });

    test('REPO-ORD-07: getReadyQueue returns list', () async {
      final repo = OrderRepository();
      final ready = await repo.getReadyQueue('REPO_TEST');
      expect(ready, isA<List>());
      print('✅ REPO-ORD-07: getReadyQueue returned ${ready.length} items');
    });

    test('REPO-ORD-08: getDishesSummaryByDate SQL is valid', () async {
      final repo = OrderRepository();
      final summary = await repo.getDishesSummaryByDate('2024-10-15', 'REPO_TEST');
      expect(summary, isA<List>());
      print('✅ REPO-ORD-08: getDishesSummaryByDate SQL valid, ${summary.length} results');
    });

    test('REPO-ORD-09: getDishesForDate SQL is valid', () async {
      final repo = OrderRepository();
      final dishes = await repo.getDishesForDate('2024-10-15', 'REPO_TEST');
      expect(dishes, isA<List>());
      print('✅ REPO-ORD-09: getDishesForDate SQL valid, ${dishes.length} results');
    });

    test('REPO-ORD-10: getPendingOrdersForMrp SQL is valid', () async {
      final repo = OrderRepository();
      final pending = await repo.getPendingOrdersForMrp('2024-10-15', 'REPO_TEST');
      expect(pending, isA<List>());
      print('✅ REPO-ORD-10: getPendingOrdersForMrp SQL valid');
    });

    test('REPO-ORD-11: updateOrderFields through repository', () async {
      final repo = OrderRepository();
      final orders = await repo.getOrdersByDate('2024-10-15', 'REPO_TEST');
      if (orders.isNotEmpty) {
        await repo.updateOrderFields(orders.first['id'] as int, {'totalPax': 300});
        final updated = await repo.getOrdersByDate('2024-10-15', 'REPO_TEST');
        expect(updated.first['totalPax'], 300);
        print('✅ REPO-ORD-11: updateOrderFields updated pax to 300');
      }
    });

    test('REPO-ORD-12: updateDish through repository', () async {
      final repo = OrderRepository();
      final orders = await repo.getOrdersByDate('2024-10-15', 'REPO_TEST');
      if (orders.isNotEmpty) {
        final dishes = await repo.getDishesForOrder(orders.first['id'] as int, 'REPO_TEST');
        if (dishes.isNotEmpty) {
          await repo.updateDish(dishes.first['id'] as int, {'productionStatus': 'QUEUED'});
          print('✅ REPO-ORD-12: updateDish to QUEUED');
        }
      }
    });

    test('REPO-ORD-13: Report queries run without error', () async {
      final repo = OrderRepository();
      final status = await repo.getOrderStatusReport('2024-01-01', '2024-12-31', 'REPO_TEST');
      expect(status, isA<List>());
      final food = await repo.getOrdersByFoodTypeReport('2024-01-01', '2024-12-31', 'REPO_TEST');
      expect(food, isA<List>());
      final meal = await repo.getOrdersByMealTypeReport('2024-01-01', '2024-12-31', 'REPO_TEST');
      expect(meal, isA<List>());
      print('✅ REPO-ORD-13: All 3 report queries execute without error');
    });
  });

  // ═══════════════════════════════════════════
  // 3. OPERATION REPOSITORY — Real code paths
  // ═══════════════════════════════════════════

  group('REPO-OPS: OperationRepository real code paths', () {
    test('REPO-OPS-01: insertStaff through repository', () async {
      final repo = OperationRepository();
      final id = await repo.insertStaff({
        'firmId': 'REPO_TEST',
        'name': 'Test Staff',
        'mobile': '9999900100',
        'role': 'Cook',
        'staffType': 'PERMANENT',
        'salary': 20000.0,
        'isActive': 1,
      });
      expect(id, isNotNull);
      print('✅ REPO-OPS-01: Staff#$id created via repository');
    });

    test('REPO-OPS-02: insertAttendance through repository', () async {
      final repo = OperationRepository();
      final id = await repo.insertAttendance({
        'staffId': 1,
        'date': '2024-10-15',
        'punchInTime': '09:00',
        'punchOutTime': '18:00',
        'overtimeHours': 1.0,
        'status': 'PRESENT',
      });
      expect(id, isNotNull);
      print('✅ REPO-OPS-02: Attendance#$id recorded via repository');
    });

    test('REPO-OPS-03: getHRAttendanceReport SQL is valid', () async {
      final repo = OperationRepository();
      final report = await repo.getHRAttendanceReport('2024-01-01', '2024-12-31', 'REPO_TEST');
      expect(report, isA<List>());
      print('✅ REPO-OPS-03: HR attendance report returns ${report.length} records');
    });

    test('REPO-OPS-04: getHROvertimeReport SQL is valid', () async {
      final repo = OperationRepository();
      final report = await repo.getHROvertimeReport('2024-01-01', '2024-12-31', 'REPO_TEST');
      expect(report, isA<List>());
      print('✅ REPO-OPS-04: HR overtime report returns ${report.length} records');
    });

    test('REPO-OPS-05: getDispatchReport SQL is valid', () async {
      final repo = OperationRepository();
      final report = await repo.getDispatchReport('2024-01-01', '2024-12-31', 'REPO_TEST');
      expect(report, isA<List>());
      print('✅ REPO-OPS-05: Dispatch report returns ${report.length} records');
    });

    test('REPO-OPS-06: insertUtensil through repository', () async {
      final repo = OperationRepository();
      final id = await repo.insertUtensil({
        'firmId': 'REPO_TEST',
        'name': 'Test Plates',
        'totalStock': 100,
        'availableStock': 100,
      });
      expect(id, isNotNull);
      print('✅ REPO-OPS-06: Utensil#$id created via repository');
    });

    test('REPO-OPS-07: insertVehicle through repository', () async {
      final repo = OperationRepository();
      final id = await repo.insertVehicle({
        'firmId': 'REPO_TEST',
        'vehicleNumber': 'KA-01-TEST-001',
        'vehicleType': 'Tempo',
        'driverName': 'Test Driver',
        'driverMobile': '9999900200',
        'isActive': 1,
      });
      expect(id, isNotNull);
      print('✅ REPO-OPS-07: Vehicle#$id created via repository');
    });

    test('REPO-OPS-08: insertDispatch through repository', () async {
      final repo = OperationRepository();
      final id = await repo.insertDispatch({
        'orderId': 1,
        'vehicleId': 1,
        'dispatchStatus': 'PENDING',
        'dispatchTime': DateTime.now().toIso8601String(),
      });
      expect(id, isNotNull);
      print('✅ REPO-OPS-08: Dispatch#$id created via repository');
    });

    test('REPO-OPS-09: assignStaffToOrder uses staff_assignments table', () async {
      final repo = OperationRepository();
      final id = await repo.assignStaffToOrder(1, 1, 'Server');
      expect(id, greaterThan(0));
      print('✅ REPO-OPS-09: Staff assignment#$id created');
    });

    test('REPO-OPS-10: getOrderStaffAssignments returns data', () async {
      final repo = OperationRepository();
      final assignments = await repo.getOrderStaffAssignments(1);
      expect(assignments, isA<List>());
      print('✅ REPO-OPS-10: Staff assignments query returns ${assignments.length} results');
    });

    test('REPO-OPS-11: getAvailableStaff SQL is valid', () async {
      final repo = OperationRepository();
      final staff = await repo.getAvailableStaff('2024-10-15');
      expect(staff, isA<List>());
      print('✅ REPO-OPS-11: Available staff query returns ${staff.length} results');
    });

    test('REPO-OPS-12: getDispatchesForDate SQL is valid', () async {
      final repo = OperationRepository();
      final dispatches = await repo.getDispatchesForDate('2024-10-15');
      expect(dispatches, isA<List>());
      print('✅ REPO-OPS-12: Dispatches for date returns ${dispatches.length} results');
    });

    test('REPO-OPS-13: getAttendanceForStaff SQL is valid', () async {
      final repo = OperationRepository();
      final attendance = await repo.getAttendanceForStaff(
        1, DateTime(2024, 1, 1), DateTime(2024, 12, 31));
      expect(attendance, isA<List>());
      print('✅ REPO-OPS-13: Attendance for staff returns ${attendance.length} records');
    });
  });

  // ═══════════════════════════════════════════
  // 4. FINANCE REPOSITORY — Real code paths
  // ═══════════════════════════════════════════

  group('REPO-FIN: FinanceRepository real code paths', () {
    test('REPO-FIN-01: insertTransaction through repository', () async {
      final repo = FinanceRepository();
      final id = await repo.insertTransaction({
        'firmId': 'REPO_TEST',
        'type': 'INCOME',
        'category': 'Order Payment',
        'amount': 50000.0,
        'date': '2024-10-15',
        'description': 'Test payment',
        'paymentMode': 'UPI',
        'relatedEntityType': 'ORDER',
        'relatedEntityId': 1,
      });
      expect(id, greaterThan(0));
      print('✅ REPO-FIN-01: Transaction#$id created via repository');
    });

    test('REPO-FIN-02: getTransactions returns results', () async {
      final repo = FinanceRepository();
      final txns = await repo.getTransactions(firmId: 'REPO_TEST');
      expect(txns.isNotEmpty, true);
      print('✅ REPO-FIN-02: getTransactions found ${txns.length} transactions');
    });

    test('REPO-FIN-03: getTransactions with relatedEntityType filter', () async {
      final repo = FinanceRepository();
      final txns = await repo.getTransactions(
        firmId: 'REPO_TEST',
        relatedEntityType: 'ORDER',
        relatedEntityId: 1,
      );
      expect(txns, isA<List>());
      print('✅ REPO-FIN-03: Entity-filtered transactions: ${txns.length}');
    });

    test('REPO-FIN-04: getOpeningBalance SQL is valid', () async {
      final repo = FinanceRepository();
      final balance = await repo.getOpeningBalance(
        relatedEntityType: 'ORDER',
        relatedEntityId: 1,
        date: '2024-12-31',
        firmId: 'REPO_TEST',
      );
      expect(balance, isA<double>());
      print('✅ REPO-FIN-04: Opening balance = $balance');
    });

    test('REPO-FIN-05: getClosingBalance SQL is valid', () async {
      final repo = FinanceRepository();
      final balance = await repo.getClosingBalance(
        relatedEntityType: 'ORDER',
        relatedEntityId: 1,
        date: '2024-12-31',
        firmId: 'REPO_TEST',
      );
      expect(balance, isA<double>());
      print('✅ REPO-FIN-05: Closing balance = $balance');
    });

    test('REPO-FIN-06: insertSupplier through repository', () async {
      final repo = FinanceRepository();
      final id = await repo.insertSupplier({
        'firmId': 'REPO_TEST',
        'name': 'Test Supplier',
        'mobile': '9999900300',
        'category': 'Vegetables',
        'isActive': 1,
      });
      expect(id, isNotNull);
      print('✅ REPO-FIN-06: Supplier#$id created via repository');
    });

    test('REPO-FIN-07: getAllSuppliers returns results', () async {
      final repo = FinanceRepository();
      final suppliers = await repo.getAllSuppliers('REPO_TEST');
      expect(suppliers, isA<List>());
      print('✅ REPO-FIN-07: getAllSuppliers returned ${suppliers.length}');
    });

    test('REPO-FIN-08: getFinanceSummary SQL is valid', () async {
      final repo = FinanceRepository();
      final summary = await repo.getFinanceSummary('REPO_TEST', '2024-01-01', '2024-12-31');
      expect(summary, isA<Map>());
      print('✅ REPO-FIN-08: Finance summary: $summary');
    });

    test('REPO-FIN-09: insertSubcontractor through repository', () async {
      final repo = FinanceRepository();
      final id = await repo.insertSubcontractor({
        'firmId': 'REPO_TEST',
        'name': 'Test Subcontractor',
        'mobile': '9999900400',
        'specialization': 'South Indian',
        'ratePerPax': 150.0,
        'category': 'FOOD',
      });
      expect(id, isNotNull);
      print('✅ REPO-FIN-09: Subcontractor#$id created via repository');
    });

    test('REPO-FIN-10: getAllSubcontractors returns results', () async {
      final repo = FinanceRepository();
      final subs = await repo.getAllSubcontractors('REPO_TEST');
      expect(subs, isA<List>());
      print('✅ REPO-FIN-10: getAllSubcontractors returned ${subs.length}');
    });

    test('REPO-FIN-11: insertSubcontractor through DatabaseHelper', () async {
      // This is the code path the UI uses
      final id = await DatabaseHelper().insertSubcontractor({
        'firmId': 'REPO_TEST',
        'name': 'DB Test Subcontractor',
        'mobile': '9999900500',
        'specialization': 'Biryani',
        'ratePerPax': 200.0,
        'category': 'FOOD',
      });
      expect(id, isNotNull);
      print('✅ REPO-FIN-11: Subcontractor via DatabaseHelper#$id');
    });

    test('REPO-FIN-12: updateTransaction through repository', () async {
      final repo = FinanceRepository();
      final id = await repo.insertTransaction({
        'firmId': 'REPO_TEST', 'type': 'EXPENSE', 'category': 'Update Test',
        'amount': 1000.0, 'date': '2024-10-16',
      });
      final rows = await repo.updateTransaction(id, {'amount': 2000.0});
      expect(rows, 1);
      print('✅ REPO-FIN-12: Transaction updated');
    });

    test('REPO-FIN-13: deleteTransaction through repository', () async {
      final repo = FinanceRepository();
      final id = await repo.insertTransaction({
        'firmId': 'REPO_TEST', 'type': 'EXPENSE', 'category': 'Delete Test',
        'amount': 500.0, 'date': '2024-10-16',
      });
      final rows = await repo.deleteTransaction(id);
      expect(rows, 1);
      print('✅ REPO-FIN-13: Transaction deleted');
    });
  });

  // ═══════════════════════════════════════════
  // 5. INVENTORY REPOSITORY — Real code paths
  // ═══════════════════════════════════════════

  group('REPO-INV: InventoryRepository real code paths', () {
    test('REPO-INV-01: insertIngredient through repository', () async {
      final repo = InventoryRepository();
      final id = await repo.insertIngredient({
        'firmId': 'REPO_TEST',
        'name': 'Test Rice',
        'unit_of_measure': 'kg',
        'cost_per_unit': 60.0,
        'category': 'Grains',
      });
      expect(id, isNotNull);
      print('✅ REPO-INV-01: Ingredient#$id created via repository');
    });

    test('REPO-INV-02: getAllIngredients returns results', () async {
      final repo = InventoryRepository();
      final ingredients = await repo.getAllIngredients('REPO_TEST');
      expect(ingredients, isA<List>());
      print('✅ REPO-INV-02: getAllIngredients returned ${ingredients.length}');
    });

    test('REPO-INV-03: getAllDishes returns results', () async {
      final repo = InventoryRepository();
      final dishes = await repo.getAllDishes('REPO_TEST');
      expect(dishes, isA<List>());
      print('✅ REPO-INV-03: getAllDishes returned ${dishes.length}');
    });

    test('REPO-INV-04: getIngredientsMaster returns results', () async {
      final repo = InventoryRepository();
      final master = await repo.getIngredientsMaster('REPO_TEST');
      expect(master, isA<List>());
      print('✅ REPO-INV-04: getIngredientsMaster returned ${master.length}');
    });

    test('REPO-INV-05: createMrpRun through repository', () async {
      final repo = InventoryRepository();
      final id = await repo.createMrpRun({
        'firmId': 'REPO_TEST',
        'runDate': DateTime.now().toIso8601String(),
        'targetDate': '2024-10-20',
        'status': 'DRAFT',
      });
      expect(id, isNotNull);
      print('✅ REPO-INV-05: MRP run#$id created via repository');
    });

    test('REPO-INV-06: getMrpRuns returns results', () async {
      final repo = InventoryRepository();
      final runs = await repo.getMrpRuns('REPO_TEST');
      expect(runs, isA<List>());
      print('✅ REPO-INV-06: getMrpRuns returned ${runs.length}');
    });

    test('REPO-INV-07: insertBomItem through repository', () async {
      final repo = InventoryRepository();
      // Create a dish master first
      final db = await DatabaseHelper().database;
      final dishId = await db.insert('dish_master', {
        'firmId': 'REPO_TEST', 'name': 'BOM Test Dish', 'base_pax': 100,
      });

      final id = await repo.insertBomItem({
        'firmId': 'REPO_TEST',
        'dish_id': dishId,
        'ing_id': 1,
        'quantity_per_base_pax': 5.0,
        'unit_override': 'kg',
      });
      expect(id, isNotNull);
      print('✅ REPO-INV-07: BOM item#$id created via repository');
    });
  });

  // ═══════════════════════════════════════════
  // 6. DATABASE HELPER — Direct methods
  // ═══════════════════════════════════════════

  group('REPO-DBH: DatabaseHelper direct methods', () {
    test('REPO-DBH-01: insertAuthorizedMobile', () async {
      final dbHelper = DatabaseHelper();
      await dbHelper.insertAuthorizedMobile({
        'firmId': 'REPO_TEST',
        'mobile': '9999900600',
        'role': 'Admin',
        'name': 'Test Admin',
        'addedBy': 'ADMIN_APP',
      });
      print('✅ REPO-DBH-01: Authorized mobile inserted');
    });

    test('REPO-DBH-02: insertSubcontractor with all UI fields', () async {
      // Test the exact data the subcontractor_screen.dart sends
      final id = await DatabaseHelper().insertSubcontractor({
        'firmId': 'REPO_TEST',
        'name': 'UI Test Kitchen',
        'mobile': '9999900700',
        'email': 'test@kitchen.com',
        'address': '123 Test Street',
        'specialization': 'Biryani & Pulao',
        'ratePerPax': 150.0,
        'category': 'FOOD',
      });
      expect(id, isNotNull);
      print('✅ REPO-DBH-02: Subcontractor with all UI fields inserted (id=$id)');
    });

    test('REPO-DBH-03: updateSubcontractor', () async {
      final dbHelper = DatabaseHelper();
      final id = await dbHelper.insertSubcontractor({
        'firmId': 'REPO_TEST', 'name': 'Update Test', 'mobile': '9999900800',
        'specialization': 'Test', 'ratePerPax': 100.0, 'category': 'EVENT',
      });
      if (id != null) {
        await dbHelper.updateSubcontractor(id, {
          'name': 'Updated Name',
          'specialization': 'Updated Specialization',
          'ratePerPax': 250.0,
        });
        print('✅ REPO-DBH-03: Subcontractor#$id updated');
      }
    });
  });

  // ═══════════════════════════════════════════
  // 7. CROSS-TABLE QUERY INTEGRATION
  // ═══════════════════════════════════════════

  group('REPO-INT: Cross-table integration queries', () {
    test('REPO-INT-01: Kitchen screen data flow (orders + dishes)', () async {
      // Simulate what KitchenScreen._loadOrdersForDate does
      final repo = OrderRepository();
      final orders = await repo.getOrdersByDate('2024-10-15', 'REPO_TEST');
      final List<Map<String, dynamic>> enriched = [];
      for (var o in orders) {
        final dishes = await repo.getDishesForOrder(o['id'] as int, 'REPO_TEST');
        final map = Map<String, dynamic>.from(o);
        map['dishes'] = dishes;
        enriched.add(map);
      }
      expect(enriched.isNotEmpty, true);
      expect(enriched.first['dishes'], isA<List>());
      print('✅ REPO-INT-01: Kitchen data flow: ${enriched.length} orders enriched');
    });

    test('REPO-INT-02: Service requirements query with subcontractor JOINs', () async {
      // This uses serviceSubcontractorId/counterSubcontractorId columns
      final repo = OperationRepository();
      // Create a quick MRP run for the test
      final db = await DatabaseHelper().database;
      final runId = await db.insert('mrp_runs', {
        'firmId': 'REPO_TEST', 'runDate': DateTime.now().toIso8601String(),
        'targetDate': '2024-10-20', 'status': 'DRAFT',
      });
      final requirements = await repo.getServiceRequirementsForMrpRun(runId);
      expect(requirements, isA<List>());
      print('✅ REPO-INT-02: Service requirements query valid (${requirements.length} results)');
    });

    test('REPO-INT-03: Subcontractor ledger query', () async {
      final repo = OperationRepository();
      final ledger = await repo.getSubcontractorLedger(
        'Test Kitchen', '2024-01-01', '2024-12-31');
      expect(ledger, isA<List>());
      print('✅ REPO-INT-03: Subcontractor ledger query valid');
    });

    test('REPO-INT-04: Profitability calculation', () async {
      final repo = FinanceRepository();
      // Create test data
      final db = await DatabaseHelper().database;
      await db.insert('finance', {
        'firmId': 'REPO_TEST', 'type': 'INCOME', 'category': 'Order Payment',
        'amount': 50000.0, 'date': '2024-10-15', 'paymentMode': 'Cash',
      });
      await db.insert('finance', {
        'firmId': 'REPO_TEST', 'type': 'EXPENSE', 'category': 'Raw Materials',
        'amount': 15000.0, 'date': '2024-10-15', 'paymentMode': 'Cash',
      });

      final summary = await repo.getFinanceSummary('REPO_TEST', '2024-10-01', '2024-10-31');
      expect(summary['income'], greaterThan(0));
      print('✅ REPO-INT-04: Profitability: income=${summary['income']}, expense=${summary['expense']}');
    });
  });
}
