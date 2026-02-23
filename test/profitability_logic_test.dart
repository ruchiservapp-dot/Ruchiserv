import 'package:flutter_test/flutter_test.dart';
import 'package:ruchiserv/db/database_helper.dart';
import 'package:ruchiserv/repositories/finance_repository.dart';
import 'package:ruchiserv/db/schema_manager.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io';

void main() {
  setUpAll(() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  });

  group('Event Profitability Logic Verification', () {
    final dbHelper = DatabaseHelper();
    const String testFirmId = 'PROF_TEST';
    final String today = DateTime.now().toIso8601String().substring(0, 10);
    final String monthYear = today.substring(0, 7);

    test('Profitability Calculation and Allocation', () async {
      // 1. Initialize In-Memory DB with REAL schema
      final db = await openDatabase(inMemoryDatabasePath, version: 1, onCreate: (db, version) async {
        await SchemaManager.createAllTables(db);
        // Ensure 'transactions' exists as DatabaseHelper uses it instead of 'finance'
        await db.execute('''
          CREATE TABLE IF NOT EXISTS transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            firmId TEXT NOT NULL,
            date TEXT NOT NULL,
            type TEXT NOT NULL,
            amount REAL DEFAULT 0,
            category TEXT,
            description TEXT,
            mode TEXT,
            relatedEntityId INTEGER,
            relatedEntityType TEXT,
            createdAt TEXT,
            updatedAt TEXT
          )
        ''');
      });
      
      // Inject into DatabaseHelper
      DatabaseHelper.setTestDatabase(db);
      
      // 2. Setup Master Data
      final i1 = await db.insert('ingredients_master', {
        'firmId': testFirmId,
        'name': 'Rice',
        'unit_of_measure': 'kg',
        'cost_per_unit': 40.0,
      });

      final d1 = await db.insert('dish_master', {
        'firmId': testFirmId,
        'name': 'Plain Rice',
        'base_pax': 100,
      });

      await db.insert('recipe_detail', {
        'firmId': testFirmId,
        'dish_id': d1,
        'ing_id': i1,
        'quantity_per_base_pax': 10.0, // 10kg per 100 pax
        'unit_override': 'kg',
      });

      // 3. Create Order
      final oId = await db.insert('orders', {
        'firmId': testFirmId,
        'customerName': 'Test Customer',
        'date': today,
        'totalPax': 200, // 2x base pax
        'grandTotal': 10000.0,
      });

      // 4. Create Dish for Order
      await db.insert('dishes', {
        'firmId': testFirmId,
        'orderId': oId,
        'dishMasterId': d1,
        'dishName': 'Plain Rice',
        'pax': 200,
      });

      // 5. Verify Material Cost
      // Expectation: 10kg * (200/100) = 20kg. 20kg * ₹40 = ₹800.
      final materialCost = await FinanceRepository().getOrderMaterialCost(oId, testFirmId);
      expect(materialCost, 800.0);
      print('✅ Material Cost calculation verified: ₹$materialCost');

      // 6. Setup Fixed Costs and Verify Allocation
      // Total monthly pax = 200 (this order)
      // Add a second order to increase monthly pax
      await db.insert('orders', {
        'firmId': testFirmId,
        'date': today,
        'totalPax': 200,
        'isCancelled': 0,
      });
      // Total monthly pax = 400.

      // Add a fixed cost transaction
      await db.insert('transactions', {
        'firmId': testFirmId,
        'date': today,
        'type': 'EXPENSE',
        'amount': 4000.0,
        'category': 'Rent',
      });

      // Verification:
      // Monthly Fixed Costs = ₹4000
      // Monthly Pax = 400
      // Per Plate Operational = 4000 / 400 = ₹10
      // Event Operational Cost (oId) = 10 * 200 = ₹2000
      
      final profitability = await FinanceRepository().getEventProfitability(oId, testFirmId);
      expect(profitability['materialCost'], 800.0);
      expect(profitability['allocatedFixedCost'], 2000.0);
      expect(profitability['perPlateOperational'], 10.0);
      expect(profitability['totalCost'], 2800.0);
      expect(profitability['profit'], 7200.0);
      
      print('✅ Profitability Allocation verified: Operational Cost = ₹${profitability['allocatedFixedCost']}');
      print('✅ Per Plate Operational Cost verified: ₹${profitability['perPlateOperational']}');
      print('✅ Total Cost verified: ₹${profitability['totalCost']}');
      print('✅ Net Profit verified: ₹${profitability['profit']}');
    });
  });
}
