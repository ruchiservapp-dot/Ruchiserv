import 'package:ruchiserv/repositories/finance_repository.dart';
import 'package:ruchiserv/repositories/operation_repository.dart';
import 'package:ruchiserv/repositories/order_repository.dart';
import 'package:ruchiserv/core/app_logger.dart';
import 'dart:math';
import 'database_helper.dart';

class LedgerSeeder {
  static Future<void> seedData() async {
    final db = DatabaseHelper();
    const String firmId = 'DEFAULT'; 

    AppLogger.info("🌱 Seeding Ledger Data...");

    // 1. Seed Customers
    final orderRepo = OrderRepository();
    List<Map<String, dynamic>> customers = await orderRepo.getAllCustomers(firmId);
    if (customers.isEmpty) {
      await orderRepo.insertCustomer({
        'firmId': firmId,
        'name': 'Ramesh Kumar',
        'mobile': '9876543210',
        'email': 'ramesh@example.com',
        'address': '123 MG Road, Bangalore',
      });
      await orderRepo.insertCustomer({
        'firmId': firmId,
        'name': 'Priya Events',
        'mobile': '9988776655',
        'address': '456 Indiranagar',
        'notes': 'Corporate Client',
      });
      customers = await orderRepo.getAllCustomers(firmId);
    }

    // 2. Seed Suppliers
    final financeRepo = FinanceRepository();
    List<Map<String, dynamic>> suppliers = await financeRepo.getAllSuppliers(firmId);
    if (suppliers.isEmpty) {
      await financeRepo.insertSupplier({
        'firmId': firmId,
        'name': 'Fresh Veguies Ltd',
        'contactPerson': 'Anil',
        'mobile': '8888888888',
        'category': 'Vegetables',
        'isActive': 1,
      });
      await financeRepo.insertSupplier({
        'firmId': firmId,
        'name': 'Golden Grains',
        'contactPerson': 'Sunil',
        'mobile': '7777777777',
        'category': 'Grocery',
        'isActive': 1,
      });
      suppliers = await financeRepo.getAllSuppliers(firmId);
    }

    // 3. Seed Staff (if empty, though likely populated by other seeds)
    List<Map<String, dynamic>> staff = await OperationRepository().getAllStaff(onlyActive: false);
    if (staff.isEmpty) {
    final opRepo = OperationRepository();
    await opRepo.insertStaff({
      'name': 'Gopi S',
         'role': 'Chef',
         'mobile': '9999999999',
         'salary': 25000,
         'isActive': 1,
       });
       staff = await OperationRepository().getAllStaff();
    }

    // 4. Seed Transactions
    final r = Random();
    final categories = ['Salary', 'Advance', 'Purchase', 'Sales', 'Event Booking', 'Maintenance'];
    
    for (var s in suppliers) {
      await _ensureTransactions(financeRepo, 'SUPPLIER', s['id'], s['name'], 'EXPENSE', 'Purchase');
    }
    for (var c in customers) {
      await _ensureTransactions(financeRepo, 'CUSTOMER', c['id'], c['name'], 'INCOME', 'Event Booking');
    }
    for (var st in staff) {
      await _ensureTransactions(financeRepo, 'STAFF', st['id'], st['name'], 'EXPENSE', 'Salary');
    }

    AppLogger.info("✅ Seeding Complete!");
  }

  static Future<void> _ensureTransactions(
      FinanceRepository financeRepo, String type, int id, String name, String txnType, String category) async {
    
    final existing = await financeRepo.getTransactions(
      relatedEntityType: type,
      relatedEntityId: id,
      limit: 1,
    );

    if (existing.isEmpty) {
      final r = Random();
      // Add 3-5 transactions
      int count = 3 + r.nextInt(3);
      for (int i = 0; i < count; i++) {
        await financeRepo.insertTransaction({
          'firmId': 'DEFAULT',
          'date': DateTime.now().subtract(Duration(days: r.nextInt(30))).toIso8601String().substring(0, 10),
          'type': txnType,
          'amount': (r.nextInt(50) + 1) * 100.0 + (txnType == 'INCOME' ? 5000 : 0),
          'category': category,
          'description': 'Auto-generated seed transaction',
          'mode': r.nextBool() ? 'Cash' : 'UPI',
          'relatedEntityType': type,
          'relatedEntityId': id,
          'partyName': name, // Redundant but good for quick display
        });
      }
    }
  }
}
