import 'dart:math';
import 'database_helper.dart';

class LedgerSeeder {
  static Future<void> seedData() async {
    final db = DatabaseHelper();
    const String firmId = 'DEFAULT'; 

    print("🌱 Seeding Ledger Data...");

    // 1. Seed Customers
    List<Map<String, dynamic>> customers = await db.getAllCustomers(firmId);
    if (customers.isEmpty) {
      await db.insertCustomer({
        'firmId': firmId,
        'name': 'Ramesh Kumar',
        'mobile': '9876543210',
        'email': 'ramesh@example.com',
        'address': '123 MG Road, Bangalore',
      });
      await db.insertCustomer({
        'firmId': firmId,
        'name': 'Priya Events',
        'mobile': '9988776655',
        'address': '456 Indiranagar',
        'notes': 'Corporate Client',
      });
      customers = await db.getAllCustomers(firmId);
    }

    // 2. Seed Suppliers
    List<Map<String, dynamic>> suppliers = await db.getAllSuppliers(firmId);
    if (suppliers.isEmpty) {
      await db.insertSupplier({
        'firmId': firmId,
        'name': 'Fresh Veguies Ltd',
        'contactPerson': 'Anil',
        'mobile': '8888888888',
        'category': 'Vegetables',
        'isActive': 1,
      });
      await db.insertSupplier({
        'firmId': firmId,
        'name': 'Golden Grains',
        'contactPerson': 'Sunil',
        'mobile': '7777777777',
        'category': 'Grocery',
        'isActive': 1,
      });
      suppliers = await db.getAllSuppliers(firmId);
    }

    // 3. Seed Staff (if empty, though likely populated by other seeds)
    List<Map<String, dynamic>> staff = await db.getAllStaff();
    if (staff.isEmpty) {
       await db.insertStaff({
         'firmId': firmId,
         'name': 'Raju Chef',
         'role': 'Chef',
         'mobile': '9999999999',
         'salary': 25000,
         'isActive': 1,
       });
       staff = await db.getAllStaff();
    }

    // 4. Seed Transactions
    final r = Random();
    final categories = ['Salary', 'Advance', 'Purchase', 'Sales', 'Event Booking', 'Maintenance'];
    
    // For each entity, add some transactions if none exist
    for (var s in suppliers) {
      await _ensureTransactions(db, 'SUPPLIER', s['id'], s['name'], 'EXPENSE', 'Purchase');
    }
    for (var c in customers) {
      await _ensureTransactions(db, 'CUSTOMER', c['id'], c['name'], 'INCOME', 'Event Booking');
    }
    for (var st in staff) {
      await _ensureTransactions(db, 'STAFF', st['id'], st['name'], 'EXPENSE', 'Salary');
    }

    print("✅ Seeding Complete!");
  }

  static Future<void> _ensureTransactions(
      DatabaseHelper db, String type, int id, String name, String txnType, String category) async {
    
    final existing = await db.getTransactions(
      relatedEntityType: type,
      relatedEntityId: id,
      limit: 1,
    );

    if (existing.isEmpty) {
      final r = Random();
      // Add 3-5 transactions
      int count = 3 + r.nextInt(3);
      for (int i = 0; i < count; i++) {
        await db.insertTransaction({
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
