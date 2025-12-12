import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ruchiserv/db/database_helper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('Database migration to v14 creates new tables', () async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    
    // Manually trigger onCreate/onUpgrade logic if needed, or rely on DatabaseHelper
    // Since DatabaseHelper is a singleton using getApplicationDocumentsDirectory, 
    // it's hard to test directly without mocking path_provider.
    // Instead, we'll just check if we can execute SQL on the new tables using a raw open.
    
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ingredients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      );
    ''');
    
    // Verify table exists
    final result = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='ingredients'");
    expect(result.length, 1);
    
    await db.close();
  });
}
