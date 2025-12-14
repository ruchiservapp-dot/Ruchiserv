import 'package:sqflite/sqflite.dart';
import 'schema_definitions.dart';

class SchemaManager {
  static const String TAG = '[SchemaManager]';

  /// Synchronizes the database schema with the definitions in AppSchema.
  /// This ensures that all tables and columns exist as defined.
  static Future<void> syncSchema(Database db) async {
    print('$TAG Starting schema synchronization...');
    
    for (var table in AppSchema.tables) {
      await _syncTable(db, table);
    }
    
    print('$TAG Schema synchronization complete.');
  }

  /// Creates all tables for a fresh database.
  static Future<void> createAllTables(Database db) async {
    print('$TAG Creating all tables for fresh database...');
    for (var table in AppSchema.tables) {
      print('$TAG Creating table: ${table.tableName}');
      await db.execute(table.createTableSql);
    }
  }

  static Future<void> _syncTable(Database db, TableSchema schema) async {
    // 1. Check if table exists
    final tableExists = await _tableExists(db, schema.tableName);
    
    if (!tableExists) {
      print('$TAG Table "${schema.tableName}" missing. Creating...');
      await db.execute(schema.createTableSql);
      return;
    }

    // 2. Sync columns
    // Get existing columns
    final tableInfo = await db.rawQuery('PRAGMA table_info(${schema.tableName})');
    final existingColumns = tableInfo.map((row) => row['name'] as String).toSet();

    // Check for missing columns
    for (var entry in schema.columns.entries) {
      final colName = entry.key;
      final colDef = entry.value;

      if (!existingColumns.contains(colName)) {
        print('$TAG Column "$colName" missing in "${schema.tableName}". Adding...');
        try {
          // Extract just the definition part if it contains PRIMARY KEY (which can't be added via ALTER)
          // But usually we are adding non-PK columns. 
          // SQLite ALTER TABLE ADD COLUMN supports simple definitions.
          // Note: Cannot add PRIMARY KEY or UNIQUE constraints via ALTER TABLE ADD COLUMN in SQLite
          // But DEFAULT values work.
          
          await db.execute('ALTER TABLE ${schema.tableName} ADD COLUMN $colName $colDef');
          print('$TAG Added column "$colName" to "${schema.tableName}"');
        } catch (e) {
          print('$TAG ❌ Failed to add column "$colName" to "${schema.tableName}": $e');
        }
      }
    }
  }

  static Future<bool> _tableExists(Database db, String tableName) async {
    final res = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableName],
    );
    return res.isNotEmpty;
  }
}
