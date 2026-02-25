// E2E INTEGRATION TEST: ORDER → KITCHEN → DISPATCH → FINANCE → INVOICE
// Full lifecycle simulation through the database layer
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ruchiserv/db/database_helper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // v44: Use in-memory database for clean E2E run
    await DatabaseHelper.reset(newName: inMemoryDatabasePath);

    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return '.';
    });

    SharedPreferences.setMockInitialValues({
      'last_firm': 'INTEG_FIRM',
      'firmId': 'INTEG_FIRM',
      'user_role': 'Admin',
    });

    db = await DatabaseHelper().database;
  });

  // ═══════════════════════════════════════════════
  // INTEGRATION FLOW 1: ORDER → DISHES → KITCHEN → DISPATCH → INVOICE
  // ═══════════════════════════════════════════════

  group('INTEGRATION: Full Order Lifecycle', () {
    late int orderId;
    late List<int> dishIds;
    late int dispatchId;
    late int invoiceId;

    test('STEP 1: Create order with customer details', () async {
      // Create customer first
      await db.insert('customers', {
        'firmId': 'INTEG_FIRM', 'name': 'Integration Test Corp',
        'mobile': '9999888800', 'email': 'integ@test.com',
        'gstin': '29AABCI1234A1Z5',
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      orderId = await db.insert('orders', {
        'firmId': 'INTEG_FIRM',
        'customerName': 'Integration Test Corp',
        'mobile': '9999888800',
        'date': '2024-06-15',
        'time': '19:00',
        'location': 'Convention Centre, Bangalore',
        'totalPax': 300,
        'foodType': 'Veg',
        'mealType': 'Dinner',
        'beforeDiscount': 90000.0,
        'discountPercent': 0,
        'finalAmount': 90000.0,
        'grandTotal': 90000.0,
        'status': 'CONFIRMED',
        'isCancelled': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      expect(orderId, greaterThan(0));
      print('✅ STEP 1: Order#$orderId created — 300 pax, ₹90,000');
    });

    test('STEP 2: Add dishes to order', () async {
      dishIds = [];
      final dishes = [
        {'name': 'Paneer Tikka', 'pax': 300, 'price': 120.0, 'cat': 'Starter'},
        {'name': 'Dal Makhani', 'pax': 300, 'price': 80.0, 'cat': 'Main Course'},
        {'name': 'Biryani', 'pax': 300, 'price': 150.0, 'cat': 'Main Course'},
        {'name': 'Gulab Jamun', 'pax': 300, 'price': 50.0, 'cat': 'Dessert'},
      ];

      for (final d in dishes) {
        final id = await db.insert('dishes', {
          'firmId': 'INTEG_FIRM', 'orderId': orderId,
          'dishName': d['name'], 'pax': d['pax'],
          'pricePerPlate': d['price'], 'category': d['cat'],
          'productionStatus': 'PENDING', 'isSubcontracted': 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        dishIds.add(id);
      }

      expect(dishIds.length, 4);
      final savedDishes = await db.query('dishes', where: 'orderId = ?', whereArgs: [orderId]);
      expect(savedDishes.length, 4);
      print('✅ STEP 2: ${dishIds.length} dishes added — Tikka, Dal, Biryani, Gulab Jamun');
    });

    test('STEP 3: Kitchen marks dishes IN_PROGRESS then READY', () async {
      // Mark all dishes as IN_PROGRESS
      for (final dishId in dishIds) {
        await db.update('dishes', {'productionStatus': 'IN_PROGRESS'},
          where: 'id = ?', whereArgs: [dishId]);
      }

      var progress = await db.query('dishes',
        where: "orderId = ? AND productionStatus = 'IN_PROGRESS'", whereArgs: [orderId]);
      expect(progress.length, 4);

      // Mark all READY
      for (final dishId in dishIds) {
        await db.update('dishes', {
          'productionStatus': 'READY',
          'readyAt': DateTime.now().toIso8601String(),
        }, where: 'id = ?', whereArgs: [dishId]);
      }

      final ready = await db.query('dishes',
        where: "orderId = ? AND productionStatus = 'READY'", whereArgs: [orderId]);
      expect(ready.length, 4);
      expect(ready.every((d) => d['readyAt'] != null), true);
      print('✅ STEP 3: Kitchen — all 4 dishes READY');
    });

    test('STEP 4: Create dispatch (load utensils)', () async {
      // Add vehicle
      await db.insert('vehicles', {
        'firmId': 'INTEG_FIRM', 'vehicleNumber': 'KA-51-ZZ-9999',
        'driverName': 'Integration Driver', 'isActive': 1,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Create dispatch
      dispatchId = await db.insert('dispatches', {
        'orderId': orderId,
        'vehicleId': 1,
        'driverId': 1,
        'dispatchStatus': 'PENDING',
        'dispatchTime': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Load utensils
      for (final item in [
        {'name': 'Plate', 'qty': 300},
        {'name': 'Spoon', 'qty': 300},
        {'name': 'Glass', 'qty': 300},
        {'name': 'Serving Bowl', 'qty': 20},
      ]) {
        await db.insert('dispatch_items', {
          'dispatchId': dispatchId, 'itemType': 'UTENSIL',
          'itemName': item['name'], 'quantity': item['qty'],
          'loadedQty': item['qty'], 'returnedQty': 0, 'status': 'PENDING',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Mark dispatched
      await db.update('dispatches', {'dispatchStatus': 'DISPATCHED'},
        where: 'id = ?', whereArgs: [dispatchId]);

      final dispatch = await db.query('dispatches', where: 'id = ?', whereArgs: [dispatchId]);
      expect(dispatch.first['dispatchStatus'], 'DISPATCHED');
      print('✅ STEP 4: Dispatch#$dispatchId — 4 items loaded, status: DISPATCHED');
    });

    test('STEP 5: Event complete — return with variance', () async {
      // Return items (some variance)
      final returns = {
        'Plate': 295,     // 5 missing
        'Spoon': 300,     // All returned
        'Glass': 298,     // 2 broken
        'Serving Bowl': 20, // All returned
      };

      for (final entry in returns.entries) {
        await db.update('dispatch_items', {
          'returnedQty': entry.value,
          'unloadedQty': entry.value,
          'status': 'COMPLETED',
        }, where: 'dispatchId = ? AND itemName = ?', whereArgs: [dispatchId, entry.key]);
      }

      // Mark delivered
      await db.update('dispatches', {
        'dispatchStatus': 'DELIVERED',
        'returnTime': DateTime.now().toIso8601String(),
      }, where: 'id = ?', whereArgs: [dispatchId]);

      // Calculate total variance
      final items = await db.query('dispatch_items', where: 'dispatchId = ?', whereArgs: [dispatchId]);
      int totalVariance = 0;
      for (final item in items) {
        totalVariance += (item['loadedQty'] as int) - (item['returnedQty'] as int);
      }
      expect(totalVariance, 7); // 5 plates + 2 glasses
      print('✅ STEP 5: Return complete — variance: $totalVariance items (5 plates + 2 glasses)');
    });

    test('STEP 6: Record payment in finance', () async {
      await db.insert('finance', {
        'firmId': 'INTEG_FIRM', 'type': 'INCOME', 'category': 'Order Payment',
        'amount': 90000.0, 'date': '2024-06-15', 'description': 'Integration Test Corp — Wedding',
        'paymentMode': 'UPI',
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final finance = await db.query('finance',
        where: "firmId = 'INTEG_FIRM' AND type = 'INCOME'");
      expect(finance.isNotEmpty, true);
      expect(finance.first['amount'], 90000.0);
      print('✅ STEP 6: Payment ₹90,000 via UPI recorded in finance');
    });

    test('STEP 7: Generate GST invoice', () async {
      invoiceId = await db.insert('invoices', {
        'firmId': 'INTEG_FIRM', 'invoiceNumber': 'INV-INTEG-001',
        'orderId': orderId, 'customerId': 1,
        'customerName': 'Integration Test Corp',
        'customerGstin': '29AABCI1234A1Z5',
        'invoiceDate': '2024-06-16', 'dueDate': '2024-07-16',
        'subtotal': 90000.0,
        'cgst': 8100.0,  // 9%
        'sgst': 8100.0,  // 9%
        'igst': 0.0,
        'totalAmount': 106200.0,
        'amountPaid': 90000.0,
        'balanceDue': 16200.0,
        'status': 'PARTIAL',
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Add invoice items
      for (final dish in [
        {'desc': 'Paneer Tikka (300 pax)', 'qty': 300.0, 'rate': 120.0, 'amt': 36000.0},
        {'desc': 'Dal Makhani (300 pax)', 'qty': 300.0, 'rate': 80.0, 'amt': 24000.0},
        {'desc': 'Biryani (300 pax)', 'qty': 300.0, 'rate': 150.0, 'amt': 45000.0},
        {'desc': 'Gulab Jamun (300 pax)', 'qty': 300.0, 'rate': 50.0, 'amt': 15000.0},
      ]) {
        await db.insert('invoice_items', {
          'invoiceId': invoiceId, 'description': dish['desc'],
          'hsnCode': '996331', 'quantity': dish['qty'],
          'unit': 'pax', 'rate': dish['rate'], 'amount': dish['amt'],
          'gstRate': 18.0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      final inv = await db.query('invoices', where: 'id = ?', whereArgs: [invoiceId]);
      expect(inv.first['totalAmount'], 106200.0);
      expect(inv.first['status'], 'PARTIAL');

      final items = await db.query('invoice_items', where: 'invoiceId = ?', whereArgs: [invoiceId]);
      expect(items.length, 4);
      print('✅ STEP 7: Invoice INV-INTEG-001 — ₹1,06,200 (incl. 18% GST), balance ₹16,200');
    });

    test('STEP 8: Full payment completes invoice', () async {
      await db.update('invoices', {
        'amountPaid': 106200.0, 'balanceDue': 0.0, 'status': 'PAID',
      }, where: 'id = ?', whereArgs: [invoiceId]);

      // Record GST payment in finance
      await db.insert('finance', {
        'firmId': 'INTEG_FIRM', 'type': 'INCOME', 'category': 'GST Collection',
        'amount': 16200.0, 'date': '2024-06-20', 'paymentMode': 'Bank Transfer',
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final inv = await db.query('invoices', where: 'id = ?', whereArgs: [invoiceId]);
      expect(inv.first['status'], 'PAID');
      expect(inv.first['balanceDue'], 0.0);

      // Verify total finance
      final totalIncome = await db.rawQuery(
        "SELECT SUM(amount) as total FROM finance WHERE firmId = 'INTEG_FIRM' AND type = 'INCOME'");
      expect(totalIncome.first['total'], greaterThanOrEqualTo(106200.0));

      print('✅ STEP 8: Fully paid — Invoice PAID, total income: ₹${totalIncome.first['total']}');
    });

    test('STEP 9: Audit trail verification', () async {
      // Record audit entry for the completed order
      await db.insert('audit_log', {
        'firm_id': 'INTEG_FIRM', 'user_id': 'ADMIN-001',
        'action': 'COMPLETE', 'table_name': 'orders',
        'record_id': orderId, 'notes': 'Order lifecycle completed',
        'timestamp': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final log = await db.query('audit_log',
        where: "firm_id = 'INTEG_FIRM' AND action = 'COMPLETE'");
      expect(log.isNotEmpty, true);
      print('✅ STEP 9: Audit trail recorded — lifecycle complete');
    });
  });

  // ═══════════════════════════════════════════════
  // INTEGRATION FLOW 2: STAFF → ATTENDANCE → PAYROLL → DISBURSEMENT
  // ═══════════════════════════════════════════════

  group('INTEGRATION: Staff Payroll Lifecycle', () {
    late int staffId;

    test('STEP 1: Hire staff member', () async {
      staffId = await db.insert('staff', {
        'firmId': 'INTEG_FIRM', 'name': 'Test Cook Ramesh',
        'mobile': '9999888877', 'role': 'Cook',
        'staffType': 'PERMANENT', 'salary': 18000.0,
        'isActive': 1, 'joinDate': '2024-01-01',
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      expect(staffId, greaterThan(0));
      print('✅ STEP 1: Staff#$staffId hired — Ramesh, Cook, ₹18K');
    });

    test('STEP 2: Record 26 days attendance', () async {
      int present = 0;
      for (int day = 1; day <= 30; day++) {
        final date = '2024-03-${day.toString().padLeft(2, '0')}';
        final status = day <= 26 ? 'PRESENT' : 'ABSENT'; // 26 working days
        final ot = (day == 5 || day == 15) ? 2.0 : 0.0; // OT on 5th and 15th

        await db.insert('attendance', {
          'staffId': staffId, 'date': date,
          'status': status,
          'punchInTime': status == 'PRESENT' ? '09:00' : null,
          'punchOutTime': status == 'PRESENT' ? '18:00' : null,
          'overtimeHours': ot,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        if (status == 'PRESENT') present++;
      }

      final attendance = await db.query('attendance',
        where: "staffId = ? AND status = 'PRESENT'", whereArgs: [staffId]);
      expect(attendance.length, 26);

      final totalOT = await db.rawQuery(
        'SELECT SUM(overtimeHours) as ot FROM attendance WHERE staffId = ?', [staffId]);
      expect(totalOT.first['ot'], 4.0); // 2 + 2 hours
      print('✅ STEP 2: 26/30 days present, 4h overtime');
    });

    test('STEP 3: Calculate and disburse salary', () async {
      const basePay = 18000.0;
      const otRate = 150.0;
      const otHours = 4.0;
      const otPay = otRate * otHours; // 600
      const deductions = 500.0; // PF etc
      const netPay = basePay + otPay - deductions; // 18100

      final salId = await db.insert('salary_disbursements', {
        'firmId': 'INTEG_FIRM', 'staffId': staffId, 'monthYear': '2024-03',
        'basePay': basePay, 'otPay': otPay, 'deductions': deductions,
        'netPay': netPay, 'status': 'PAID', 'paymentMode': 'UPI',
        'paidAt': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Auto-record expense in finance
      await db.insert('finance', {
        'firmId': 'INTEG_FIRM', 'type': 'EXPENSE', 'category': 'Salary',
        'amount': netPay, 'date': '2024-03-31', 'paymentMode': 'UPI',
        'description': 'Salary: Ramesh (Mar 2024)',
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final sal = await db.query('salary_disbursements', where: 'id = ?', whereArgs: [salId]);
      expect(sal.first['netPay'], netPay);
      expect(sal.first['status'], 'PAID');

      final expense = await db.query('finance',
        where: "category = 'Salary' AND firmId = 'INTEG_FIRM'");
      expect(expense.isNotEmpty, true);
      print('✅ STEP 3: Salary ₹$netPay disbursed — Base:₹$basePay + OT:₹$otPay - Ded:₹$deductions');
    });
  });

  // ═══════════════════════════════════════════════
  // INTEGRATION FLOW 3: MRP → PO → DELIVERY → STOCK
  // ═══════════════════════════════════════════════

  group('INTEGRATION: MRP → Purchase Order Flow', () {
    late int mrpRunId;
    late int poId;

    test('STEP 1: MRP run identifies shortfalls', () async {
      mrpRunId = await db.insert('mrp_runs', {
        'firmId': 'INTEG_FIRM', 'runDate': '2024-06-10', 'targetDate': '2024-06-15',
        'status': 'COMPLETED', 'totalOrders': 1, 'totalPax': 300,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Record shortfalls
      for (final item in [
        {'ingId': 1, 'name': 'Rice', 'req': 15.0, 'stock': 5.0, 'buy': 10.0, 'unit': 'kg'},
        {'ingId': 2, 'name': 'Oil', 'req': 3.0, 'stock': 3.0, 'buy': 0.0, 'unit': 'ltr'},
        {'ingId': 3, 'name': 'Spices', 'req': 2.0, 'stock': 0.5, 'buy': 1.5, 'unit': 'kg'},
      ]) {
        await db.insert('mrp_output', {
          'mrpRunId': mrpRunId, 'ingredientId': item['ingId'],
          'requiredQty': item['req'], 'unit': item['unit'],
          'inStockQty': item['stock'], 'purchaseQty': item['buy'],
          'allocationStatus': (item['buy'] as double) > 0 ? 'PENDING' : 'ALLOCATED',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      final shortfalls = await db.query('mrp_output',
        where: "mrpRunId = ? AND purchaseQty > 0", whereArgs: [mrpRunId]);
      expect(shortfalls.length, 2); // Rice and Spices
      print('✅ STEP 1: MRP run — 2 shortfalls: Rice(10kg), Spices(1.5kg)');
    });

    test('STEP 2: Generate PO from shortfalls', () async {
      poId = await db.insert('purchase_orders', {
        'firmId': 'INTEG_FIRM', 'mrpRunId': mrpRunId,
        'poNumber': 'PO-INTEG-001', 'type': 'INGREDIENT',
        'vendorId': 1, 'vendorName': 'Fresh Mart',
        'totalItems': 2, 'totalAmount': 825.0, 'status': 'SENT',
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await db.insert('po_items', {
        'poId': poId, 'itemId': 1, 'itemName': 'Rice',
        'quantity': 10.0, 'unit': 'kg', 'pricePerUnit': 60.0, 'totalPrice': 600.0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await db.insert('po_items', {
        'poId': poId, 'itemId': 3, 'itemName': 'Spices',
        'quantity': 1.5, 'unit': 'kg', 'pricePerUnit': 150.0, 'totalPrice': 225.0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final po = await db.query('purchase_orders', where: 'id = ?', whereArgs: [poId]);
      expect(po.first['status'], 'SENT');
      print('✅ STEP 2: PO#PO-INTEG-001 sent — Rice(10kg), Spices(1.5kg), total ₹825');
    });

    test('STEP 3: PO delivered → record expense', () async {
      await db.update('purchase_orders', {
        'status': 'DELIVERED', 'deliveredAt': DateTime.now().toIso8601String(),
      }, where: 'id = ?', whereArgs: [poId]);

      // Record as expense
      await db.insert('finance', {
        'firmId': 'INTEG_FIRM', 'type': 'EXPENSE', 'category': 'Raw Materials',
        'amount': 825.0, 'date': '2024-06-12', 'paymentMode': 'Cash',
        'description': 'PO-INTEG-001: Rice + Spices',
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final po = await db.query('purchase_orders', where: 'id = ?', whereArgs: [poId]);
      expect(po.first['status'], 'DELIVERED');
      print('✅ STEP 3: PO delivered — ₹825 expense recorded');
    });
  });
}
