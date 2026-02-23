import 'package:flutter_test/flutter_test.dart';
import 'package:ruchiserv/db/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  final dbHelper = DatabaseHelper();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    db = await openDatabase(inMemoryDatabasePath, version: 1,
        onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          firmId TEXT,
          date TEXT,
          type TEXT,
          amount REAL,
          category TEXT,
          description TEXT,
          relatedEntityType TEXT,
          relatedEntityId INTEGER
        )
      ''');
      await db.execute('''
        CREATE TABLE dispatches (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          firmId TEXT,
          driverId INTEGER,
          driverShare REAL,
          dispatchStatus TEXT
        )
      ''');
    });
    DatabaseHelper.setTestDatabase(db);
  });

  setUp(() async {
    await db.delete('transactions');
    await db.delete('dispatches');
  });

  tearDownAll(() async {
    await db.close();
  });

  group('Ledger Logic Tests', () {
    test('Opening/Closing Balance Calculation', () async {
      // Setup: 100 Income on Jan 1, 50 Expense on Jan 5
      await db.insert('transactions', {
        'firmId': 'TEST',
        'date': '2024-01-01',
        'type': 'INCOME',
        'amount': 100.0,
        'category': 'Initial',
        'relatedEntityType': 'STAFF',
        'relatedEntityId': 1,
      });
      await db.insert('transactions', {
        'firmId': 'TEST',
        'date': '2024-01-05',
        'type': 'EXPENSE',
        'amount': 30.0,
        'category': 'Payment',
        'relatedEntityType': 'STAFF',
        'relatedEntityId': 1,
      });

      // Verification
      final opening = await dbHelper.getOpeningBalance(
        relatedEntityType: 'STAFF',
        relatedEntityId: 1,
        date: '2024-01-05',
        firmId: 'TEST',
      );
      expect(opening, 100.0);

      final closing = await dbHelper.getClosingBalance(
        relatedEntityType: 'STAFF',
        relatedEntityId: 1,
        date: '2024-01-05',
        firmId: 'TEST',
      );
      expect(closing, 70.0);
    });

    test('Search Filtering', () async {
      await db.insert('transactions', {
        'firmId': 'TEST',
        'date': '2024-01-10',
        'type': 'INCOME',
        'amount': 200.0,
        'category': 'Special Sale',
        'description': 'Searchable text',
      });

      final results = await dbHelper.getTransactions(
        firmId: 'TEST',
        searchText: 'Special',
      );
      expect(results.length, 1);
      expect(results.first['category'], 'Special Sale');

      final resultsByDesc = await dbHelper.getTransactions(
        firmId: 'TEST',
        searchText: 'searchable',
      );
      expect(resultsByDesc.length, 1);
    });
  });
}
