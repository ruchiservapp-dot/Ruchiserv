import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ruchiserv/db/database_helper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('Finance Module: Transactions Table and CRUD', () async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    
    // Create table manually to simulate migration
    await db.execute('''
      CREATE TABLE IF NOT EXISTS transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        category TEXT,
        amount REAL DEFAULT 0,
        date TEXT NOT NULL,
        notes TEXT,
        paymentMode TEXT,
        relatedId INTEGER,
        relatedTable TEXT,
        createdAt TEXT
      );
    ''');

    // Insert
    final id = await db.insert('transactions', {
      'type': 'EXPENSE',
      'category': 'Rent',
      'amount': 5000.0,
      'date': '2024-01-01',
      'notes': 'Office Rent',
      'createdAt': DateTime.now().toIso8601String(),
    });
    expect(id, 1);

    // Query
    final result = await db.query('transactions');
    expect(result.length, 1);
    expect(result.first['amount'], 5000.0);
    expect(result.first['type'], 'EXPENSE');

    // Summary Logic Check
    final summary = await db.rawQuery('''
      SELECT 
        SUM(CASE WHEN type = 'INCOME' THEN amount ELSE 0 END) as income,
        SUM(CASE WHEN type = 'EXPENSE' THEN amount ELSE 0 END) as expense
      FROM transactions
    ''');
    expect(summary.first['expense'], 5000.0);
    expect(summary.first['income'], 0.0);

    await db.close();
  });
}
