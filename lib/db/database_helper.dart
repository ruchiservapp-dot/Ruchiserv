// lib/db/database_helper.dart
// @locked
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // Desktop support

// Optional but useful if you already added these in your project
// If not present, you can safely remove these two imports.
import '../services/connectivity_service.dart';
import '../db/aws/aws_api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'schema_manager.dart';
import 'sync_event.dart';
import 'dart:async';
import 'package:uuid/uuid.dart';
import '../services/cloud_sync_service.dart'; // v38: AWS-first sync
import '../core/app_logger.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  /// Testing hook to inject a mock or in-memory database
  static void setTestDatabase(Database db) {
    _database = db;
  }

  /// Event stream for database mutations that need cloud sync.
  /// Decouples DatabaseHelper from CloudSyncService to avoid circular dependencies.
  final syncStreamController = StreamController<SyncEvent>.broadcast();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String fileName = 'ruchiserv_v2.db';
    
    Database db;
    if (kIsWeb) {
      // Web initialization
      databaseFactory = databaseFactoryFfiWeb;
      db = await openDatabase(
        fileName,
        version: 38, // v38: AWS-first sync architecture
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } else {
      // Mobile/Desktop initialization
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // Initialize FFI for Desktop
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }

      final dir = await getApplicationDocumentsDirectory();
      final path = join(dir.path, fileName);
      db = await openDatabase(
        path,
        version: 39, // v39: Added firmId to dishes table for cloud sync
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    }
    
    // Always sync schema on startup to ensure all columns exist
    await SchemaManager.syncSchema(db);
    
    // v40: Backfill missing UUIDs for offline/legacy data
    await _backfillUuids(db);
    
    return db;
  }

  /// v40: Helper to generate unique IDs for multi-device sync
  String _generateUuid() => const Uuid().v4();

  /// v40: Backfills UUIDs for any existing records that don't have one.
  /// This ensures legacy data can be synced without collisions moving forward.
  Future<void> _backfillUuids(Database db) async {
    AppLogger.debug('📦 [DB] Checking for missing UUIDs to backfill...');
    for (var table in [
      'firms', 'users', 'authorized_mobiles', 'staff', 'attendance', 
      'customers', 'orders', 'dishes', 'finance', 'utensils', 
      'vehicles', 'ingredients_master', 'dish_master', 'recipe_detail',
      'mrp_runs', 'mrp_run_orders', 'mrp_output', 'suppliers', 
      'subcontractors', 'purchase_orders', 'po_items', 'dispatches', 
      'invoices', 'invoice_items', 'salary_disbursements', 
      'service_rates', 'dispatch_items'
    ]) {
      try {
        final records = await db.query(table, where: 'uuid IS NULL');
        if (records.isNotEmpty) {
          AppLogger.info('📦 [DB] Backfilling ${records.length} UUIDs in $table...');
          for (var row in records) {
            final id = row['id'];
            await db.update(
              table, 
              {'uuid': _generateUuid()}, 
              where: 'id = ?', 
              whereArgs: [id]
            );
          }
        }
      } catch (e) {
        // Table might not exist or doesn't have uuid column yet
        // AppLogger.warning('⚠️ [DB] Skip backfill for $table: $e');
      }
    }
  }

  /// General helper to get a single record by ID from any table
  Future<Map<String, dynamic>?> getRecordById(String table, int id) async {
    final db = await database;
    final res = await db.query(table, where: 'id = ?', whereArgs: [id], limit: 1);
    return res.isNotEmpty ? res.first : null;
  }

  Future<void> _onCreate(Database db, int version) async {
    AppLogger.info('📦 [DB] Creating new database with version $version');
    
    // Use SchemaManager to create all tables from central definition
    await SchemaManager.createAllTables(db);
    
    // Seed initial data
    await _loadSeeds(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // defensive upgrades
    if (oldVersion < 3) {
      // Add columns if they don't exist
      try {
        await db.execute('ALTER TABLE orders ADD COLUMN totalPax INTEGER DEFAULT 0;');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE orders ADD COLUMN isLocked INTEGER DEFAULT 0;');
      } catch (_) {}

      // Ensure pending_sync exists with action column
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pending_sync (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          table_name TEXT,
          data TEXT,
          action TEXT,
          timestamp TEXT
        );
      ''');
    }

    // Upgrade to v4: Mobile Authorization System
    if (oldVersion < 4) {
      // Add authorized_mobiles table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS authorized_mobiles (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          firmId TEXT NOT NULL,
          mobile TEXT NOT NULL,
          type TEXT NOT NULL,
          name TEXT,
          isActive INTEGER DEFAULT 1,
          addedBy TEXT,
          addedAt TEXT,
          UNIQUE(firmId, mobile)
        );
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_authorized_mobiles_firm ON authorized_mobiles(firmId);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_authorized_mobiles_mobile ON authorized_mobiles(firmId, mobile);');
      
      // Migrate existing users to authorized_mobiles
      final existingUsers = await db.query('users');
      for (var user in existingUsers) {
        try {
          await db.insert('authorized_mobiles', {
            'firmId': user['firmId'],
            'mobile': user['mobile'],
            'type': 'USER',
            'name': user['username'] ?? 'Existing User',
            'isActive': user['isActive'] ?? 1,
            'addedBy': 'SYSTEM_MIGRATION',
            'addedAt': DateTime.now().toIso8601String(),
          });
        } catch (_) {}
      }
    }

    // Upgrade to v5: Dish Master table for autocomplete
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS dish_master (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          category TEXT NOT NULL,
          rate INTEGER DEFAULT 0,
          foodType TEXT DEFAULT 'Veg',
          createdAt TEXT,
          updatedAt TEXT,
          UNIQUE(name, category)
        );
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_dish_master_category ON dish_master(category);');
    }

    // Upgrade to v6: Defensive add for showRates in users 
    if (oldVersion < 37) { // Bumped version check safely
       try {
         await db.execute('ALTER TABLE users ADD COLUMN showRates INTEGER DEFAULT 1;');
       } catch (_) {}
    }

    // Upgrade to v36: Order Emails & Enhanced Fields
    if (oldVersion < 36) {
      final orderCols = [
        'ALTER TABLE orders ADD COLUMN email TEXT;',
        'ALTER TABLE orders ADD COLUMN time TEXT;',
        'ALTER TABLE orders ADD COLUMN beforeDiscount REAL DEFAULT 0;',
        'ALTER TABLE orders ADD COLUMN discountPercent REAL DEFAULT 0;',
        'ALTER TABLE orders ADD COLUMN discountAmount REAL DEFAULT 0;',
        'ALTER TABLE orders ADD COLUMN finalAmount REAL DEFAULT 0;',
        'ALTER TABLE orders ADD COLUMN serviceRequired INTEGER DEFAULT 0;',
        'ALTER TABLE orders ADD COLUMN serviceType TEXT;',
        'ALTER TABLE orders ADD COLUMN counterCount INTEGER DEFAULT 1;',
        'ALTER TABLE orders ADD COLUMN staffCount INTEGER DEFAULT 0;',
        'ALTER TABLE orders ADD COLUMN staffRate REAL DEFAULT 0;',
        'ALTER TABLE orders ADD COLUMN counterSetupRequired INTEGER DEFAULT 0;',
        'ALTER TABLE orders ADD COLUMN counterSetupRate REAL DEFAULT 0;',
        'ALTER TABLE orders ADD COLUMN serviceCost REAL DEFAULT 0;',
        'ALTER TABLE orders ADD COLUMN counterSetupCost REAL DEFAULT 0;',
        'ALTER TABLE orders ADD COLUMN deliveredAt TEXT;',
      ];
      for (final sql in orderCols) {
        try {
          await db.execute(sql);
        } catch (_) {}
      }
      
      // Dishes table columns
      final dishCols = [
        'ALTER TABLE dishes ADD COLUMN foodType TEXT DEFAULT "Veg";',
        'ALTER TABLE dishes ADD COLUMN createdAt TEXT;',
        'ALTER TABLE dishes ADD COLUMN updatedAt TEXT;',
        'ALTER TABLE dishes ADD COLUMN readyAt TEXT;',
      ];
      for (final sql in dishCols) {
        try {
          await db.execute(sql);
        } catch (_) {}
      }
    }

    // Upgrade to v6: Service and Counter Setup fields
    if (oldVersion < 6) {
      // Add service fields to orders table (wrap in try-catch for existing columns)
      final cols = [
        'ALTER TABLE orders ADD COLUMN serviceRequired INTEGER DEFAULT 0;',
        'ALTER TABLE orders ADD COLUMN serviceType TEXT;',
        'ALTER TABLE orders ADD COLUMN counterCount INTEGER DEFAULT 1;',
        'ALTER TABLE orders ADD COLUMN staffCount INTEGER DEFAULT 0;',
        'ALTER TABLE orders ADD COLUMN staffRate REAL DEFAULT 0;',
        'ALTER TABLE orders ADD COLUMN counterSetupRequired INTEGER DEFAULT 0;',
        'ALTER TABLE orders ADD COLUMN counterSetupRate REAL DEFAULT 0;',
        'ALTER TABLE orders ADD COLUMN serviceCost REAL DEFAULT 0;',
        'ALTER TABLE orders ADD COLUMN counterSetupCost REAL DEFAULT 0;',
        'ALTER TABLE orders ADD COLUMN grandTotal REAL DEFAULT 0;',
      ];
      for (final sql in cols) {
        try {
          await db.execute(sql);
        } catch (_) {
          // Column already exists, ignore
        }
      }
    }

    // Upgrade to v7: Firm Profile Details
    if (oldVersion < 7) {
      final cols = [
        'ALTER TABLE firms ADD COLUMN capacity INTEGER DEFAULT 500;',
        'ALTER TABLE firms ADD COLUMN address TEXT;',
        'ALTER TABLE firms ADD COLUMN ownerName TEXT;',
        'ALTER TABLE firms ADD COLUMN gstNumber TEXT;',
        'ALTER TABLE firms ADD COLUMN website TEXT;',
        // Defensive additions for older schemas
        'ALTER TABLE firms ADD COLUMN contactPerson TEXT;',
        'ALTER TABLE firms ADD COLUMN firmName TEXT;',
        'ALTER TABLE firms ADD COLUMN primaryMobile TEXT;',
        'ALTER TABLE firms ADD COLUMN primaryEmail TEXT;',
      ];
      for (final sql in cols) {
        try {
          await db.execute(sql);
        } catch (_) {}
      }

      // Create service_rates table for storing last used rates
      await db.execute('''
        CREATE TABLE IF NOT EXISTS service_rates (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          firmId TEXT NOT NULL,
          rateType TEXT NOT NULL,
          rate REAL DEFAULT 0,
          updatedAt TEXT,
          UNIQUE(firmId, rateType)
        );
      ''');
    }

    // Upgrade to v8: Defensive fix for missing columns (Orders & Firms)
    if (oldVersion < 8) {
      // 1. Ensure Firms table has all profile columns
      final firmCols = [
        'ALTER TABLE firms ADD COLUMN capacity INTEGER DEFAULT 500;',
        'ALTER TABLE firms ADD COLUMN address TEXT;',
        'ALTER TABLE firms ADD COLUMN ownerName TEXT;',
        'ALTER TABLE firms ADD COLUMN gstNumber TEXT;',
        'ALTER TABLE firms ADD COLUMN website TEXT;',
        'ALTER TABLE firms ADD COLUMN contactPerson TEXT;',
        'ALTER TABLE firms ADD COLUMN firmName TEXT;',
        'ALTER TABLE firms ADD COLUMN primaryMobile TEXT;',
        'ALTER TABLE firms ADD COLUMN primaryEmail TEXT;',
      ];
      for (final sql in firmCols) {
        try { await db.execute(sql); } catch (_) {}
      }
      
      // 2. Ensure Orders table has service columns (Defensive)
      final orderCols = [
        'ALTER TABLE orders ADD COLUMN serviceRequired INTEGER DEFAULT 0;',
        'ALTER TABLE orders ADD COLUMN serviceType TEXT;',
        'ALTER TABLE orders ADD COLUMN counterCount INTEGER DEFAULT 1;',
        'ALTER TABLE orders ADD COLUMN staffCount INTEGER DEFAULT 0;',
        'ALTER TABLE orders ADD COLUMN staffRate REAL DEFAULT 0;',
        'ALTER TABLE orders ADD COLUMN counterSetupRequired INTEGER DEFAULT 0;',
        'ALTER TABLE orders ADD COLUMN counterSetupRate REAL DEFAULT 0;',
        'ALTER TABLE orders ADD COLUMN serviceCost REAL DEFAULT 0;',
        'ALTER TABLE orders ADD COLUMN counterSetupCost REAL DEFAULT 0;',
        'ALTER TABLE orders ADD COLUMN grandTotal REAL DEFAULT 0;',
      ];
      for (final sql in orderCols) {
        try { await db.execute(sql); } catch (_) {}
      }

      // 3. Ensure service_rates exists
      await db.execute('''
        CREATE TABLE IF NOT EXISTS service_rates (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          firmId TEXT NOT NULL,
          rateType TEXT NOT NULL,
          rate REAL DEFAULT 0,
          updatedAt TEXT,
          UNIQUE(firmId, rateType)
        );
      ''');
    }

    // Upgrade to v9: Fix missing firmId in Orders (Legacy Migration)
    if (oldVersion < 9) {
      try {
        await db.execute("ALTER TABLE orders ADD COLUMN firmId TEXT DEFAULT 'DEFAULT';");
      } catch (_) {}
    }

    // Upgrade to v35: Add UPI Subscription Fields (Client UPI ID)
    if (oldVersion < 35) {
      try {
        await db.execute("ALTER TABLE firms ADD COLUMN client_upi_id TEXT;");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE firms ADD COLUMN subscription_end_date TEXT;");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE firms ADD COLUMN subscription_plan TEXT;");
      } catch (_) {}
    }


    // Upgrade to v10: Kitchen & Production workflow
    if (oldVersion < 10) {
      try {
        await db.execute("ALTER TABLE dishes ADD COLUMN productionStatus TEXT DEFAULT 'PENDING';");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE dishes ADD COLUMN productionType TEXT DEFAULT 'INTERNAL';");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE dishes ADD COLUMN subcontractorId TEXT;");
      } catch (_) {}
    }

    // Upgrade to v11: Dispatch module tables
    if (oldVersion < 11) {
      // Vehicles table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS vehicles (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          firmId TEXT NOT NULL,
          vehicleNumber TEXT NOT NULL,
          type TEXT DEFAULT 'INHOUSE',
          driverName TEXT,
          driverMobile TEXT,
          capacity INTEGER DEFAULT 0,
          isActive INTEGER DEFAULT 1,
          createdAt TEXT,
          updatedAt TEXT
        );
      ''');

      // Dispatches table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS dispatches (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          orderId INTEGER NOT NULL,
          vehicleId INTEGER,
          dispatchTime TEXT,
          dispatchStatus TEXT DEFAULT 'PENDING',
          returnVehicleId INTEGER,
          returnTime TEXT,
          driverLat REAL,
          driverLng REAL,
          lastLocationUpdate TEXT,
          notes TEXT,
          createdAt TEXT,
          updatedAt TEXT,
          FOREIGN KEY(orderId) REFERENCES orders(id)
        );
      ''');

      // Dispatch items table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS dispatch_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          dispatchId INTEGER NOT NULL,
          itemType TEXT NOT NULL,
          itemName TEXT NOT NULL,
          quantity INTEGER DEFAULT 0,
          loadedQty INTEGER DEFAULT 0,
          returnedQty INTEGER DEFAULT 0,
          unloadedQty INTEGER DEFAULT 0,
          status TEXT DEFAULT 'PENDING',
          notes TEXT,
          FOREIGN KEY(dispatchId) REFERENCES dispatches(id)
        );
      ''');

      // Utensils master table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS utensils (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          firmId TEXT NOT NULL,
          name TEXT NOT NULL,
          category TEXT DEFAULT 'SERVING',
          isReturnable INTEGER DEFAULT 1,
          createdAt TEXT,
          UNIQUE(firmId, name)
        );
      ''');

      // Orders table - add dispatch tracking columns
      try { await db.execute("ALTER TABLE orders ADD COLUMN dispatchStatus TEXT DEFAULT 'PENDING';"); } catch (_) {}
      try { await db.execute("ALTER TABLE orders ADD COLUMN dispatchedAt TEXT;"); } catch (_) {}
      try { await db.execute("ALTER TABLE orders ADD COLUMN deliveredAt TEXT;"); } catch (_) {}
      try { await db.execute("ALTER TABLE orders ADD COLUMN returnedAt TEXT;"); } catch (_) {}
    }

    // Upgrade to v12: Add vehicleType column to vehicles
    if (oldVersion < 12) {
      try { await db.execute("ALTER TABLE vehicles ADD COLUMN vehicleType TEXT;"); } catch (_) {}
    }

    // Upgrade to v13: RBAC & Subscription Tiers
    if (oldVersion < 13) {
      // Users table - RBAC columns
      try { await db.execute("ALTER TABLE users ADD COLUMN showRates INTEGER DEFAULT 1;"); } catch (_) {}
      try { await db.execute("ALTER TABLE users ADD COLUMN moduleAccess TEXT;"); } catch (_) {}
      
      // Firms table - Subscription tier columns
      try { await db.execute("ALTER TABLE firms ADD COLUMN subscriptionTier TEXT DEFAULT 'BASIC';"); } catch (_) {}
      try { await db.execute("ALTER TABLE firms ADD COLUMN enabledFeatures TEXT;"); } catch (_) {}
      
      // Suppliers table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS suppliers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          firmId TEXT NOT NULL,
          name TEXT NOT NULL,
          contactPerson TEXT,
          mobile TEXT,
          email TEXT,
          address TEXT,
          gstNumber TEXT,
          category TEXT DEFAULT 'GENERAL',
          isActive INTEGER DEFAULT 1,
          createdAt TEXT,
          updatedAt TEXT
        );
      ''');
      
      // Subcontractors table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS subcontractors (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          firmId TEXT NOT NULL,
          name TEXT NOT NULL,
          contactPerson TEXT,
          mobile TEXT,
          email TEXT,
          address TEXT,
          specialization TEXT,
          ratePerPax REAL DEFAULT 0,
          isActive INTEGER DEFAULT 1,
          rating INTEGER DEFAULT 3,
          createdAt TEXT,
          updatedAt TEXT
        );
      ''');
    }
    
    // Upgrade to v14: Add readyAt timestamp for dishes (sort Ready Queue by newest)
    if (oldVersion < 14) {
      try { await db.execute("ALTER TABLE dishes ADD COLUMN readyAt TEXT;"); } catch (_) {}
    }

    // Upgrade to v15: Staff Management enhancements with GPS geo-fencing
    if (oldVersion < 15) {
      // --- FIRMS TABLE: GPS Kitchen Location & OT Multiplier ---
      try { await db.execute("ALTER TABLE firms ADD COLUMN kitchenLatitude REAL;"); } catch (_) {}
      try { await db.execute("ALTER TABLE firms ADD COLUMN kitchenLongitude REAL;"); } catch (_) {}
      try { await db.execute("ALTER TABLE firms ADD COLUMN geoFenceRadius INTEGER DEFAULT 100;"); } catch (_) {}
      try { await db.execute("ALTER TABLE firms ADD COLUMN otMultiplier REAL DEFAULT 1.5;"); } catch (_) {}

      // --- STAFF TABLE: Create if not exists with enhanced fields ---
      await db.execute('''
        CREATE TABLE IF NOT EXISTS staff (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          firmId TEXT NOT NULL,
          name TEXT NOT NULL,
          role TEXT,
          mobile TEXT,
          email TEXT,
          salary REAL DEFAULT 0,
          joinDate TEXT,
          isActive INTEGER DEFAULT 1,
          staffType TEXT DEFAULT 'PERMANENT',
          dailyWageRate REAL DEFAULT 0,
          hourlyRate REAL DEFAULT 0,
          payoutFrequency TEXT DEFAULT 'MONTHLY',
          bankAccountNo TEXT,
          bankIfsc TEXT,
          bankName TEXT,
          aadharNumber TEXT,
          emergencyContact TEXT,
          emergencyContactName TEXT,
          address TEXT,
          photoUrl TEXT,
          createdAt TEXT,
          updatedAt TEXT
        );
      ''');
      // Add new columns to existing staff table if it already exists
      try { await db.execute("ALTER TABLE staff ADD COLUMN firmId TEXT DEFAULT 'DEFAULT';"); } catch (_) {}
      try { await db.execute("ALTER TABLE staff ADD COLUMN staffType TEXT DEFAULT 'PERMANENT';"); } catch (_) {}
      try { await db.execute("ALTER TABLE staff ADD COLUMN dailyWageRate REAL DEFAULT 0;"); } catch (_) {}
      try { await db.execute("ALTER TABLE staff ADD COLUMN hourlyRate REAL DEFAULT 0;"); } catch (_) {}
      try { await db.execute("ALTER TABLE staff ADD COLUMN payoutFrequency TEXT DEFAULT 'MONTHLY';"); } catch (_) {}
      try { await db.execute("ALTER TABLE staff ADD COLUMN bankAccountNo TEXT;"); } catch (_) {}
      try { await db.execute("ALTER TABLE staff ADD COLUMN bankIfsc TEXT;"); } catch (_) {}
      try { await db.execute("ALTER TABLE staff ADD COLUMN bankName TEXT;"); } catch (_) {}
      try { await db.execute("ALTER TABLE staff ADD COLUMN aadharNumber TEXT;"); } catch (_) {}
      try { await db.execute("ALTER TABLE staff ADD COLUMN emergencyContact TEXT;"); } catch (_) {}
      try { await db.execute("ALTER TABLE staff ADD COLUMN emergencyContactName TEXT;"); } catch (_) {}
      try { await db.execute("ALTER TABLE staff ADD COLUMN address TEXT;"); } catch (_) {}
      try { await db.execute("ALTER TABLE staff ADD COLUMN photoUrl TEXT;"); } catch (_) {}
      try { await db.execute("ALTER TABLE staff ADD COLUMN email TEXT;"); } catch (_) {}

      // --- ATTENDANCE TABLE: Create with GPS columns ---
      await db.execute('''
        CREATE TABLE IF NOT EXISTS attendance (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          staffId INTEGER NOT NULL,
          date TEXT NOT NULL,
          punchInTime TEXT,
          punchOutTime TEXT,
          punchInLat REAL,
          punchInLng REAL,
          punchOutLat REAL,
          punchOutLng REAL,
          isWithinGeoFence INTEGER DEFAULT 0,
          hoursWorked REAL DEFAULT 0,
          overtime REAL DEFAULT 0,
          location TEXT,
          status TEXT DEFAULT 'Present',
          notes TEXT,
          createdAt TEXT,
          FOREIGN KEY(staffId) REFERENCES staff(id)
        );
      ''');
      // Add GPS columns to existing attendance table
      try { await db.execute("ALTER TABLE attendance ADD COLUMN punchOutTime TEXT;"); } catch (_) {}
      try { await db.execute("ALTER TABLE attendance ADD COLUMN punchInLat REAL;"); } catch (_) {}
      try { await db.execute("ALTER TABLE attendance ADD COLUMN punchInLng REAL;"); } catch (_) {}
      try { await db.execute("ALTER TABLE attendance ADD COLUMN punchOutLat REAL;"); } catch (_) {}
      try { await db.execute("ALTER TABLE attendance ADD COLUMN punchOutLng REAL;"); } catch (_) {}
      try { await db.execute("ALTER TABLE attendance ADD COLUMN isWithinGeoFence INTEGER DEFAULT 0;"); } catch (_) {}
      try { await db.execute("ALTER TABLE attendance ADD COLUMN hoursWorked REAL DEFAULT 0;"); } catch (_) {}
      try { await db.execute("ALTER TABLE attendance ADD COLUMN overtime REAL DEFAULT 0;"); } catch (_) {}

      // --- STAFF ASSIGNMENTS TABLE: Link staff to orders ---
      await db.execute('''
        CREATE TABLE IF NOT EXISTS staff_assignments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          orderId INTEGER NOT NULL,
          staffId INTEGER NOT NULL,
          role TEXT,
          assignedAt TEXT,
          status TEXT DEFAULT 'ASSIGNED',
          FOREIGN KEY(orderId) REFERENCES orders(id),
          FOREIGN KEY(staffId) REFERENCES staff(id)
        );
      ''');

      // --- STAFF ADVANCES TABLE: Track salary advances ---
      await db.execute('''
        CREATE TABLE IF NOT EXISTS staff_advances (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          staffId INTEGER NOT NULL,
          amount REAL NOT NULL,
          advanceDate TEXT NOT NULL,
          reason TEXT,
          deductedFromPayroll INTEGER DEFAULT 0,
          payrollMonth TEXT,
          approvedBy TEXT,
          createdAt TEXT,
          FOREIGN KEY(staffId) REFERENCES staff(id)
        );
      ''');
      
      // --- UTENSILS TABLE ---
      await db.execute('''
        CREATE TABLE IF NOT EXISTS utensils (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          totalStock INTEGER DEFAULT 0,
          availableStock INTEGER DEFAULT 0,
          category TEXT,
          unit TEXT DEFAULT 'pcs',
          createdAt TEXT,
          updatedAt TEXT
        );
      ''');
    }
    
    // v16: Ensure utensils table exists with correct columns
    if (oldVersion < 16) {
      // Create table if it doesn't exist
      await db.execute('''
        CREATE TABLE IF NOT EXISTS utensils (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          totalStock INTEGER DEFAULT 0,
          availableStock INTEGER DEFAULT 0,
          category TEXT,
          unit TEXT DEFAULT 'pcs',
          createdAt TEXT,
          updatedAt TEXT
        );
      ''');
      
      // Add missing columns if table already existed with old schema
      try { await db.execute("ALTER TABLE utensils ADD COLUMN totalStock INTEGER DEFAULT 0;"); } catch (_) {}
      try { await db.execute("ALTER TABLE utensils ADD COLUMN availableStock INTEGER DEFAULT 0;"); } catch (_) {}
      try { await db.execute("ALTER TABLE utensils ADD COLUMN category TEXT;"); } catch (_) {}
      try { await db.execute("ALTER TABLE utensils ADD COLUMN unit TEXT DEFAULT 'pcs';"); } catch (_) {}
      try { await db.execute("ALTER TABLE utensils ADD COLUMN createdAt TEXT;"); } catch (_) {}
      try { await db.execute("ALTER TABLE utensils ADD COLUMN updatedAt TEXT;"); } catch (_) {}
    }
    
    // v17: Fix utensils table columns (for users already at v16)
    if (oldVersion < 17) {
      try { await db.execute("ALTER TABLE utensils ADD COLUMN totalStock INTEGER DEFAULT 0;"); } catch (_) {}
      try { await db.execute("ALTER TABLE utensils ADD COLUMN availableStock INTEGER DEFAULT 0;"); } catch (_) {}
      try { await db.execute("ALTER TABLE utensils ADD COLUMN category TEXT;"); } catch (_) {}
      try { await db.execute("ALTER TABLE utensils ADD COLUMN unit TEXT DEFAULT 'pcs';"); } catch (_) {}
      try { await db.execute("ALTER TABLE utensils ADD COLUMN createdAt TEXT;"); } catch (_) {}
      try { await db.execute("ALTER TABLE utensils ADD COLUMN updatedAt TEXT;"); } catch (_) {}
    }
    
    // v18: Inventory Module - Ingredients, BOM, MRP, Suppliers, PO
    if (oldVersion < 18) {
      // Ingredients Master
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ingredients (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          firmId TEXT NOT NULL,
          name TEXT NOT NULL,
          category TEXT,
          subcategory TEXT,
          unit TEXT DEFAULT 'kg',
          defaultPrice REAL DEFAULT 0,
          supplierId INTEGER,
          isActive INTEGER DEFAULT 1,
          isSystemPreloaded INTEGER DEFAULT 0,
          createdAt TEXT,
          updatedAt TEXT
        );
      ''');
      
      // BOM (Bill of Materials) - Dish to Ingredients
      await db.execute('''
        CREATE TABLE IF NOT EXISTS bom (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          firmId TEXT NOT NULL,
          dishId INTEGER NOT NULL,
          ingredientId INTEGER NOT NULL,
          quantityPer100Pax REAL NOT NULL,
          unit TEXT NOT NULL,
          notes TEXT,
          createdAt TEXT,
          updatedAt TEXT,
          UNIQUE(firmId, dishId, ingredientId)
        );
      ''');
      
      // MRP Runs
      await db.execute('''
        CREATE TABLE IF NOT EXISTS mrp_runs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          firmId TEXT NOT NULL,
          runDate TEXT NOT NULL,
          targetDate TEXT NOT NULL,
          status TEXT DEFAULT 'DRAFT',
          totalOrders INTEGER DEFAULT 0,
          totalPax INTEGER DEFAULT 0,
          createdBy TEXT,
          createdAt TEXT,
          completedAt TEXT
        );
      ''');
      
      // MRP Run Orders
      await db.execute('''
        CREATE TABLE IF NOT EXISTS mrp_run_orders (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          mrpRunId INTEGER NOT NULL,
          orderId INTEGER NOT NULL,
          pax INTEGER NOT NULL,
          isSubcontracted INTEGER DEFAULT 0,
          subcontractorId INTEGER,
          UNIQUE(mrpRunId, orderId)
        );
      ''');
      
      // MRP Output
      await db.execute('''
        CREATE TABLE IF NOT EXISTS mrp_output (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          mrpRunId INTEGER NOT NULL,
          ingredientId INTEGER NOT NULL,
          requiredQty REAL NOT NULL,
          unit TEXT NOT NULL,
          category TEXT,
          subcategory TEXT,
          allocatedQty REAL DEFAULT 0,
          status TEXT DEFAULT 'PENDING'
        );
      ''');
      
      // Suppliers
      await db.execute('''
        CREATE TABLE IF NOT EXISTS suppliers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          firmId TEXT NOT NULL,
          name TEXT NOT NULL,
          mobile TEXT,
          email TEXT,
          address TEXT,
          category TEXT,
          gstNumber TEXT,
          bankAccountNo TEXT,
          bankIfsc TEXT,
          bankName TEXT,
          isActive INTEGER DEFAULT 1,
          createdAt TEXT,
          updatedAt TEXT
        );
      ''');
      
      // Subcontractors
      await db.execute('''
        CREATE TABLE IF NOT EXISTS subcontractors (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          firmId TEXT NOT NULL,
          name TEXT NOT NULL,
          mobile TEXT NOT NULL,
          email TEXT,
          address TEXT,
          specialization TEXT,
          perPaxRate REAL DEFAULT 0,
          isActive INTEGER DEFAULT 1,
          userId INTEGER,
          createdAt TEXT,
          updatedAt TEXT
        );
      ''');
      
      // Purchase Orders
      await db.execute('''
        CREATE TABLE IF NOT EXISTS purchase_orders (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          firmId TEXT NOT NULL,
          mrpRunId INTEGER,
          poNumber TEXT NOT NULL,
          type TEXT NOT NULL,
          vendorId INTEGER NOT NULL,
          vendorName TEXT,
          totalItems INTEGER DEFAULT 0,
          totalAmount REAL DEFAULT 0,
          status TEXT DEFAULT 'SENT',
          sentAt TEXT,
          acceptedAt TEXT,
          dispatchedAt TEXT,
          deliveredAt TEXT,
          notes TEXT,
          createdAt TEXT
        );
      ''');
      
      // PO Line Items
      await db.execute('''
        CREATE TABLE IF NOT EXISTS po_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          poId INTEGER NOT NULL,
          itemType TEXT NOT NULL,
          itemId INTEGER NOT NULL,
          itemName TEXT,
          quantity REAL NOT NULL,
          unit TEXT,
          rate REAL DEFAULT 0,
          amount REAL DEFAULT 0
        );
      ''');
      
      // Invoices
      await db.execute('''
        CREATE TABLE IF NOT EXISTS invoices (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          firmId TEXT NOT NULL,
          poId INTEGER,
          supplierId INTEGER,
          invoiceNumber TEXT,
          invoiceDate TEXT,
          totalAmount REAL,
          photoPath TEXT,
          ocrText TEXT,
          ocrParsedData TEXT,
          status TEXT DEFAULT 'PENDING',
          verifiedBy TEXT,
          verifiedAt TEXT,
          approvedBy TEXT,
          approvedAt TEXT,
          notes TEXT,
          createdAt TEXT
        );
      ''');
      
      // Add order locking columns
      try { await db.execute("ALTER TABLE orders ADD COLUMN mrpRunId INTEGER;"); } catch (_) {}
      try { await db.execute("ALTER TABLE orders ADD COLUMN isLocked INTEGER DEFAULT 0;"); } catch (_) {}
      try { await db.execute("ALTER TABLE orders ADD COLUMN lockedAt TEXT;"); } catch (_) {}
    }

    // v19: Integrated Master Data (Ingredients, Dishes, BOM)
    if (oldVersion < 19) {
      // 1. Ingredients Master
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ingredients_master (
          id INTEGER PRIMARY KEY, -- We use explicit IDs from seed
          name TEXT NOT NULL,
          sku_name TEXT,
          unit_of_measure TEXT,
          cost_per_unit REAL DEFAULT 0,
          category TEXT,
          createdAt TEXT,
          updatedAt TEXT
        );
      ''');

      // 2. Dish Master (Recreate with new schema including Region & BasePax)
      // Drop old dish_master if exists (from v5)
      await db.execute('DROP TABLE IF EXISTS dish_master');
      await db.execute('''
        CREATE TABLE dish_master (
          id INTEGER PRIMARY KEY, -- We use explicit IDs from seed
          name TEXT NOT NULL,
          region TEXT,
          category TEXT,
          base_pax INTEGER DEFAULT 1,
          rate INTEGER DEFAULT 0,
          foodType TEXT DEFAULT 'Veg',
          createdAt TEXT,
          updatedAt TEXT,
          UNIQUE(name, category)
        );
      ''');

      // 3. Recipe Detail (BOM)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS recipe_detail (
          id INTEGER PRIMARY KEY, -- We use explicit IDs from seed (rd_id)
          dish_id INTEGER NOT NULL,
          ing_id INTEGER NOT NULL,
          quantity_per_base_pax REAL NOT NULL,
          unit_override TEXT,
          FOREIGN KEY(dish_id) REFERENCES dish_master(id),
          FOREIGN KEY(ing_id) REFERENCES ingredients_master(id)
        );
      ''');

      // 4. Load Initial Seed Data
      await _loadSeeds(db);
    }

    // v20: Finance Transactions
    if (oldVersion < 20) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          firmId TEXT NOT NULL,
          date TEXT NOT NULL,
          type TEXT NOT NULL, -- INCOME, EXPENSE, TRANSFER, ADJUSTMENT
          amount REAL DEFAULT 0,
          category TEXT,
          description TEXT,
          mode TEXT, -- Cash, UPI, Bank
          relatedEntityId INTEGER,
          relatedEntityType TEXT, -- SUPPLIER, ORDER, STAFF
          createdAt TEXT,
          updatedAt TEXT
        );
      ''');
    }

    // v21: Multi-Language Content Translations
    if (oldVersion < 21) {
      // 1. Content Translations Table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS content_translations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          entity_type TEXT NOT NULL, -- 'DISH', 'INGREDIENT', 'CATEGORY'
          entity_id INTEGER NOT NULL, -- ID from dish_master or ingredients_master
          language_code TEXT NOT NULL, -- 'ml', 'ta', 'hi', 'kn', 'te'
          field_name TEXT DEFAULT 'name', -- 'name', 'description', etc.
          translated_text TEXT NOT NULL,
          created_at TEXT,
          UNIQUE(entity_type, entity_id, language_code, field_name)
        );
      ''');
      
      // Index for fast lookups
      await db.execute('CREATE INDEX IF NOT EXISTS idx_content_translations_lookup ON content_translations(entity_type, entity_id, language_code);');
      
      // Defensive: Ensure pending_sync table exists (may have been missed in early migrations)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pending_sync (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          table_name TEXT,
          data TEXT,
          action TEXT,
          timestamp TEXT
        );
      ''');
    }

    // v22: Multi-Tenant Master Data (firmId partitioning)
    if (oldVersion < 22) {
      // Add firmId, baseId, isModified to ingredients_master
      try { await db.execute("ALTER TABLE ingredients_master ADD COLUMN firmId TEXT DEFAULT 'SEED';"); } catch (_) {}
      try { await db.execute("ALTER TABLE ingredients_master ADD COLUMN baseId INTEGER;"); } catch (_) {}
      try { await db.execute("ALTER TABLE ingredients_master ADD COLUMN isModified INTEGER DEFAULT 0;"); } catch (_) {}
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_ingredients_firmId ON ingredients_master(firmId);'); } catch (_) {}
      
      // Add firmId, baseId, isModified to dish_master
      try { await db.execute("ALTER TABLE dish_master ADD COLUMN firmId TEXT DEFAULT 'SEED';"); } catch (_) {}
      try { await db.execute("ALTER TABLE dish_master ADD COLUMN baseId INTEGER;"); } catch (_) {}
      try { await db.execute("ALTER TABLE dish_master ADD COLUMN isModified INTEGER DEFAULT 0;"); } catch (_) {}
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_dish_firmId ON dish_master(firmId);'); } catch (_) {}
      
      // Add firmId, baseId, isModified to recipe_detail
      try { await db.execute("ALTER TABLE recipe_detail ADD COLUMN firmId TEXT DEFAULT 'SEED';"); } catch (_) {}
      try { await db.execute("ALTER TABLE recipe_detail ADD COLUMN baseId INTEGER;"); } catch (_) {}
      try { await db.execute("ALTER TABLE recipe_detail ADD COLUMN isModified INTEGER DEFAULT 0;"); } catch (_) {}
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_recipe_firmId ON recipe_detail(firmId);'); } catch (_) {}
      
      // Copy existing seed data's id to baseId for reference
      try { await db.execute("UPDATE ingredients_master SET baseId = id WHERE firmId = 'SEED' AND baseId IS NULL;"); } catch (_) {}
      try { await db.execute("UPDATE dish_master SET baseId = id WHERE firmId = 'SEED' AND baseId IS NULL;"); } catch (_) {}
      try { await db.execute("UPDATE recipe_detail SET baseId = id WHERE firmId = 'SEED' AND baseId IS NULL;"); } catch (_) {}
    }

    // Upgrade to v23: Show Universal Data Flag
    if (oldVersion < 23) {
      try {
        await db.execute("ALTER TABLE firms ADD COLUMN showUniversalData INTEGER DEFAULT 1;");
      } catch (_) {}
    }

    // Upgrade to v24: Add readyAt to dishes (for Ready Queue sorting)
    if (oldVersion < 24) {
      try {
        await db.execute("ALTER TABLE dishes ADD COLUMN readyAt TEXT;");
      } catch (_) {}
    }

    // Upgrade to v25: Add mrpRunId to purchase_orders for MRP integration
    if (oldVersion < 25) {
      try {
        await db.execute("ALTER TABLE purchase_orders ADD COLUMN mrpRunId INTEGER;");
      } catch (_) {}
    }

    // Upgrade to v25: Add dispatch status fields to orders
    if (oldVersion < 25) {
      try {
        await db.execute("ALTER TABLE orders ADD COLUMN dispatchStatus TEXT;");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE orders ADD COLUMN dispatchedAt TEXT;");
      } catch (_) {}
    }

    // Upgrade to v26: Fix Dispatch Schema (audit_log, returnedAt, isModified)
    if (oldVersion < 26) {
      // 1. Create audit_log table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS audit_log (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          table_name TEXT,
          record_id INTEGER,
          action TEXT,
          user_id TEXT,
          firm_id TEXT,
          notes TEXT,
          timestamp TEXT
        );
      ''');

      // 2. Add returnedAt to orders
      try {
        await db.execute("ALTER TABLE orders ADD COLUMN returnedAt TEXT;");
      } catch (_) {}

      // 3. Add isModified to vehicles
      try {
        await db.execute("ALTER TABLE vehicles ADD COLUMN isModified INTEGER DEFAULT 0;");
      } catch (_) {}

      // 4. Add isModified to utensils
      try {
        await db.execute("ALTER TABLE utensils ADD COLUMN isModified INTEGER DEFAULT 0;");
      } catch (_) {}
      // 4. Add isModified to utensils
      try {
        await db.execute("ALTER TABLE utensils ADD COLUMN isModified INTEGER DEFAULT 0;");
      } catch (_) {}
    }

    // Upgrade to v38: Subcontractor Categories & Service Assignment
    if (oldVersion < 38) {
      // 1. Add category to subcontractors
      try {
        await db.execute("ALTER TABLE subcontractors ADD COLUMN category TEXT DEFAULT 'FOOD';");
      } catch (_) {}

      // 2. Add assignment columns to orders
      try {
        await db.execute("ALTER TABLE orders ADD COLUMN serviceSubcontractorId INTEGER;");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE orders ADD COLUMN counterSubcontractorId INTEGER;");
      } catch (_) {}
    }

    // === DEFENSIVE: Always ensure critical tables exist (for any DB version) ===
    // This fixes issues where tables were added in migrations but not in _onCreate
    
    // Ensure purchase_orders has mrpRunId column (may be missing in older DBs)
    try {
      await db.execute("ALTER TABLE purchase_orders ADD COLUMN mrpRunId INTEGER;");
    } catch (_) {}
    
    // Staff table (missed in some DBs)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS staff (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firmId TEXT NOT NULL,
        name TEXT NOT NULL,
        role TEXT,
        mobile TEXT,
        email TEXT,
        salary REAL DEFAULT 0,
        joinDate TEXT,
        isActive INTEGER DEFAULT 1,
        staffType TEXT DEFAULT 'PERMANENT',
        dailyWageRate REAL DEFAULT 0,
        hourlyRate REAL DEFAULT 0,
        payoutFrequency TEXT DEFAULT 'MONTHLY',
        bankAccountNo TEXT,
        bankIfsc TEXT,
        bankName TEXT,
        aadharNumber TEXT,
        emergencyContact TEXT,
        emergencyContactName TEXT,
        address TEXT,
        photoUrl TEXT,
        createdAt TEXT,
        updatedAt TEXT
      );
    ''');

    // Attendance table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        staffId INTEGER NOT NULL,
        date TEXT NOT NULL,
        punchInTime TEXT,
        punchOutTime TEXT,
        punchInLat REAL,
        punchInLng REAL,
        punchOutLat REAL,
        punchOutLng REAL,
        isWithinGeoFence INTEGER DEFAULT 0,
        hoursWorked REAL DEFAULT 0,
        overtime REAL DEFAULT 0,
        location TEXT,
        status TEXT DEFAULT 'Present',
        notes TEXT,
        createdAt TEXT,
        FOREIGN KEY(staffId) REFERENCES staff(id)
      );
    ''');

    // Staff assignments table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS staff_assignments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orderId INTEGER NOT NULL,
        staffId INTEGER NOT NULL,
        role TEXT,
        assignedAt TEXT,
        status TEXT DEFAULT 'ASSIGNED',
        FOREIGN KEY(orderId) REFERENCES orders(id),
        FOREIGN KEY(staffId) REFERENCES staff(id)
      );
    ''');

    // Staff advances table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS staff_advances (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        staffId INTEGER NOT NULL,
        amount REAL DEFAULT 0,
        reason TEXT,
        date TEXT,
        deductedFromPayroll INTEGER DEFAULT 0,
        payrollDate TEXT,
        createdAt TEXT,
        FOREIGN KEY(staffId) REFERENCES staff(id)
      );
    ''');

    // Add missing utensils columns
    try { await db.execute("ALTER TABLE utensils ADD COLUMN totalStock INTEGER DEFAULT 0;"); } catch (_) {}
    try { await db.execute("ALTER TABLE utensils ADD COLUMN availableStock INTEGER DEFAULT 0;"); } catch (_) {}
    try { await db.execute("ALTER TABLE utensils ADD COLUMN updatedAt TEXT;"); } catch (_) {}

    // Suppliers table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firmId TEXT NOT NULL,
        name TEXT NOT NULL,
        contactPerson TEXT,
        mobile TEXT,
        email TEXT,
        address TEXT,
        gstNumber TEXT,
        category TEXT DEFAULT 'GENERAL',
        bankAccountNo TEXT,
        bankIfsc TEXT,
        bankName TEXT,
        isActive INTEGER DEFAULT 1,
        createdAt TEXT,
        updatedAt TEXT
      );
    ''');
    
    // Add bank columns if missing (for existing DBs)
    try { await db.execute("ALTER TABLE suppliers ADD COLUMN bankAccountNo TEXT;"); } catch (_) {}
    try { await db.execute("ALTER TABLE suppliers ADD COLUMN bankIfsc TEXT;"); } catch (_) {}
    try { await db.execute("ALTER TABLE suppliers ADD COLUMN bankName TEXT;"); } catch (_) {}

    // Subcontractors table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS subcontractors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firmId TEXT NOT NULL,
        name TEXT NOT NULL,
        contactPerson TEXT,
        mobile TEXT,
        email TEXT,
        address TEXT,
        specialization TEXT,
        ratePerPax REAL DEFAULT 0,
        isActive INTEGER DEFAULT 1,
        rating INTEGER DEFAULT 3,
        createdAt TEXT,
        updatedAt TEXT
      );
    ''');
    
    // Add ratePerPax column if missing (for existing DBs)
    try { await db.execute("ALTER TABLE subcontractors ADD COLUMN ratePerPax REAL DEFAULT 0;"); } catch (_) {}

    // Purchase Orders table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firmId TEXT NOT NULL,
        poNumber TEXT UNIQUE,
        supplierId INTEGER,
        date TEXT,
        deliveryDate TEXT,
        status TEXT DEFAULT 'DRAFT',
        totalAmount REAL DEFAULT 0,
        notes TEXT,
        createdAt TEXT,
        updatedAt TEXT,
        FOREIGN KEY(supplierId) REFERENCES suppliers(id)
      );
    ''');

    // PO Items table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS po_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        poId INTEGER NOT NULL,
        ingredientId INTEGER,
        itemName TEXT,
        quantity REAL DEFAULT 0,
        unit TEXT,
        rate REAL DEFAULT 0,
        amount REAL DEFAULT 0,
        FOREIGN KEY(poId) REFERENCES purchase_orders(id)
      );
    ''');

    // Invoices table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firmId TEXT NOT NULL,
        invoiceNumber TEXT,
        orderId INTEGER,
        customerId INTEGER,
        date TEXT,
        dueDate TEXT,
        subtotal REAL DEFAULT 0,
        taxPercent REAL DEFAULT 0,
        taxAmount REAL DEFAULT 0,
        discountAmount REAL DEFAULT 0,
        finalAmount REAL DEFAULT 0,
        status TEXT DEFAULT 'PENDING',
        paidAmount REAL DEFAULT 0,
        createdAt TEXT,
        updatedAt TEXT,
        FOREIGN KEY(orderId) REFERENCES orders(id)
      );
    ''');

    // Service rates table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS service_rates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firmId TEXT NOT NULL,
        rateType TEXT NOT NULL,
        rate REAL DEFAULT 0,
        updatedAt TEXT,
        UNIQUE(firmId, rateType)
      );
    ''');

    // MRP tables (defensive - ensure they exist for all DBs)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mrp_runs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firmId TEXT NOT NULL,
        runDate TEXT NOT NULL,
        targetDate TEXT NOT NULL,
        status TEXT DEFAULT 'DRAFT',
        totalOrders INTEGER DEFAULT 0,
        totalPax INTEGER DEFAULT 0,
        createdBy TEXT,
        createdAt TEXT,
        completedAt TEXT
      );
    ''');
    
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mrp_run_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mrpRunId INTEGER NOT NULL,
        orderId INTEGER NOT NULL,
        pax INTEGER NOT NULL,
        isSubcontracted INTEGER DEFAULT 0,
        subcontractorId INTEGER,
        UNIQUE(mrpRunId, orderId)
      );
    ''');
    
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mrp_output (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mrpRunId INTEGER NOT NULL,
        ingredientId INTEGER NOT NULL,
        requiredQty REAL NOT NULL,
        unit TEXT NOT NULL,
        category TEXT,
        subcategory TEXT,
        allocatedQty REAL DEFAULT 0,
        status TEXT DEFAULT 'PENDING'
      );
    ''');

    // Add missing columns to orders table for reports
    try { await db.execute("ALTER TABLE orders ADD COLUMN isCancelled INTEGER DEFAULT 0;"); } catch (_) {}
    try { await db.execute("ALTER TABLE orders ADD COLUMN status TEXT DEFAULT 'Confirmed';"); } catch (_) {}
    try { await db.execute("ALTER TABLE orders ADD COLUMN venue TEXT;"); } catch (_) {}
    
    // === DEFENSIVE: Ensure default vehicles exist (User Request) ===
    // These are SEED vehicles available to all firms for basic dispatch without full vehicle setup
    // FIX: First remove duplicates if they exist, then insert only if not present
    final now = DateTime.now().toIso8601String();
    try {
      // Remove duplicates - keep only the first occurrence of each vehicleNumber
      await db.rawDelete('''
        DELETE FROM vehicles 
        WHERE id NOT IN (
          SELECT MIN(id) FROM vehicles GROUP BY vehicleNumber
        )
      ''');
      
      // Insert only if not exists (check by vehicleNumber)
      final existingCustomerVehicle = await db.query('vehicles', where: "vehicleNumber = 'Customer Vehicle'", limit: 1);
      if (existingCustomerVehicle.isEmpty) {
        await db.insert('vehicles', {
          'firmId': 'SEED',
          'vehicleNumber': 'Customer Vehicle',
          'type': 'OUTSIDE',
          'driverName': 'Customer',
          'isActive': 1,
          'createdAt': now,
          'updatedAt': now,
        });
      }
      
      final existingOwnVehicle = await db.query('vehicles', where: "vehicleNumber = 'Own Vehicle'", limit: 1);
      if (existingOwnVehicle.isEmpty) {
        await db.insert('vehicles', {
          'firmId': 'SEED',
          'vehicleNumber': 'Own Vehicle',
          'type': 'INHOUSE',
          'driverName': 'Self',
          'isActive': 1,
          'createdAt': now,
          'updatedAt': now,
        });
      }
    } catch (_) {}
    
    // v38: AWS-First Sync Architecture - Add sync_status and synced_at columns
    if (oldVersion < 38) {
      AppLogger.info('📦 [DB] Migrating to v38: AWS-first sync architecture...');
      
      // List of all tables that need sync_status/synced_at columns
      final syncTables = [
        'firms', 'users', 'authorized_mobiles', 'staff', 'attendance',
        'customers', 'orders', 'dishes', 'finance', 'utensils',
        'dispatch', 'vehicles', 'ingredients_master', 'dish_master', 'recipe_detail',
        'mrp_runs', 'mrp_run_orders', 'mrp_output', 'suppliers', 'subcontractors',
        'purchase_orders', 'po_items', 'dispatches', 'invoices', 'invoice_items',
        'salary_disbursements', 'service_rates', 'dispatch_items',
      ];
      
      for (final table in syncTables) {
        try { await db.execute("ALTER TABLE $table ADD COLUMN sync_status TEXT DEFAULT 'SYNCED';"); } catch (_) {}
        try { await db.execute("ALTER TABLE $table ADD COLUMN synced_at TEXT;"); } catch (_) {}
      }
      
      // Enhance pending_sync table with record_id, retry_count, last_error
      try { await db.execute("ALTER TABLE pending_sync ADD COLUMN record_id INTEGER;"); } catch (_) {}
      try { await db.execute("ALTER TABLE pending_sync ADD COLUMN retry_count INTEGER DEFAULT 0;"); } catch (_) {}
      try { await db.execute("ALTER TABLE pending_sync ADD COLUMN last_error TEXT;"); } catch (_) {}
      
      AppLogger.success('✅ [DB] v38 migration complete');
    }
    
    await SchemaManager.syncSchema(db);
  }

  // ---------- SEED DATA LOADER ----------
  Future<void> _loadSeeds(Database db) async {
    AppLogger.info('🌱 Loading Seed Data for v22 (multi-tenant)...');
    try {
      final batch = db.batch(); // Use batch for performance

      // Load Ingredients (firmId='SEED' marks base seed data)
      final ingJson = await rootBundle.loadString('assets/seeds/ingredients_seed.json');
      final List<dynamic> ingredients = json.decode(ingJson);
      for (var item in ingredients) {
        batch.insert('ingredients_master', {
          'firmId': 'SEED', // Base seed data marker
          'baseId': item['ing_id'], // Original ID for reference
          'name': item['name'],
          'sku_name': item['sku_name'],
          'unit_of_measure': item['unit_of_measure'],
          'cost_per_unit': item['cost_per_unit'],
          'category': item['category'],
          'isModified': 0,
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Load Dishes
      final dishJson = await rootBundle.loadString('assets/seeds/dishes_seed.json');
      final List<dynamic> dishes = json.decode(dishJson);
      for (var item in dishes) {
        batch.insert('dish_master', {
          'firmId': 'SEED',
          'baseId': item['dish_id'],
          'name': item['dish_name'],
          'region': item['region'],
          'category': item['category'],
          'base_pax': item['base_pax'] ?? 1,
          'isModified': 0,
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Load BOM
      final bomJson = await rootBundle.loadString('assets/seeds/bom_seed.json');
      final List<dynamic> bom = json.decode(bomJson);
      for (var item in bom) {
        batch.insert('recipe_detail', {
          'firmId': 'SEED',
          'baseId': item['rd_id'],
          'dish_id': item['dish_id'],
          'ing_id': item['ing_id'],
          'quantity_per_base_pax': item['quantity_per_base_pax'],
          'unit_override': item['unit_override'],
          'isModified': 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // NOTE: Default vehicles ("Customer Vehicle" and "Own Vehicle") are now managed
      // in _onUpgrade to avoid duplicates. Do NOT insert them here in _loadSeeds.

      await batch.commit(noResult: true);
      AppLogger.success('✅ Seed Data Loaded Successfully!');
    } catch (e) {
      AppLogger.error('❌ Error loading seeds: $e');
    }
  }

  // ---------- BASIC UTILS ----------
  Future<void> testDB() async {
    final db = await database;
    // ignore: avoid_print
    AppLogger.success('✅ Database initialized at ${db.path}');
  }

  /// Unified Sync Trigger: Emits an event for CloudSyncService to handle.
  /// This removes direct dependency on sync logic from DatabaseHelper.
  Future<void> _syncOrQueue({
    required String table,
    required Map<String, dynamic> data,
    required String action, // 'INSERT', 'UPDATE', 'DELETE'
    Map<String, dynamic>? filters,
  }) async {
    syncStreamController.add(SyncEvent(
      table: table,
      data: data,
      action: action,
      filters: filters,
    ));
  }



  // ---------- ORDERS CRUD moved to OrderRepository ----------


  // ---------- DISH Master and SECONDARY Order methods moved to OrderRepository ----------

  // ---------- FIRMS & USERS (LOCAL) ----------
  Future<int?> insertFirm(Map<String, dynamic> firm) async {
    final db = await database;
    firm['uuid'] = firm['uuid'] ?? _generateUuid();
    return await db.insert('firms', firm);
  }

  Future<List<Map<String, dynamic>>> getAllFirms() async {
    final db = await database;
    return await db.query('firms', orderBy: 'firmName ASC');
  }

  Future<int?> insertUser(Map<String, dynamic> user) async {
    final db = await database;
    user['uuid'] = user['uuid'] ?? _generateUuid();
    // Use replace to avoid unique constraint crashes during registration/sync
    final id = await db.insert('users', user, conflictAlgorithm: ConflictAlgorithm.replace);
    
    // AUTO-AUTHORIZE: Add mobile to authorized_mobiles so user can login
    final mobile = user['mobile']?.toString();
    final firmId = user['firmId']?.toString();
    final role = user['role']?.toString() ?? 'Staff';
    final username = user['username']?.toString() ?? 'User';
    
    if (mobile != null && firmId != null && mobile.isNotEmpty) {
      try {
        final authData = {
          'firmId': firmId,
          'mobile': mobile,
          'role': role,
          'name': username,
          'isActive': 1,
          'addedBy': 'SYSTEM',
          'addedAt': DateTime.now().toIso8601String(),
        };
        
        final authId = await db.insert('authorized_mobiles', authData, 
          conflictAlgorithm: ConflictAlgorithm.replace);
        
        // SYNC: Push to cloud
        if (authId > 0) {
          await _syncOrQueue(
            table: 'authorized_mobiles',
            data: {...authData, 'id': authId},
            action: 'INSERT'
          );
        }
        AppLogger.success('✅ [DB] User $username ($mobile) auto-authorized for login');
      } catch (e) {
        AppLogger.warning('⚠️ [DB] Failed to auto-authorize mobile: $e');
      }
    }
    
    // SYNC: Push new user to cloud
    await _syncOrQueue(
      table: 'users',
      data: {...user, 'id': id},
      action: 'INSERT'
    );
    
    return id;
  }

  Future<List<Map<String, dynamic>>> getUsersByFirm(String firmId) async {
    final db = await database;
    return await db.query('users', where: 'LOWER(firmId) = LOWER(?)', whereArgs: [firmId]);
  }

  Future<Map<String, dynamic>?> getUserByMobile(String firmId, String mobile) async {
    final db = await database;
    final res = await db.query('users', 
      where: 'LOWER(firmId) = LOWER(?) AND mobile = ?', 
      whereArgs: [firmId, mobile], 
      limit: 1
    );
    return res.isNotEmpty ? res.first : null;
  }

  Future<bool> verifyUserEligibility(String firmId, String mobile) async {
    try {
      final db = await database;
      final result = await db.query(
        'users',
        where: 'LOWER(firmId) = LOWER(?) AND mobile = ?',
        whereArgs: [firmId, mobile],
      );
      return result.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ---------- AUTHORIZED MOBILES (WHITELIST) ----------
  Future<void> insertAuthorizedMobile(Map<String, dynamic> data) async {
    final db = await database;
    try {
      // Upsert into authorized_mobiles
      final id = await db.insert(
        'authorized_mobiles',
        {
          ...data,
          'uuid': data['uuid'] ?? _generateUuid(),
          'isActive': 1,
          'addedAt': data['addedAt'] ?? DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Auto Sync
      await _syncOrQueue(
        table: 'authorized_mobiles',
        data: {...data, 'id': id, 'isActive': 1},
        action: 'INSERT',
        filters: {'firmId': data['firmId'], 'mobile': data['mobile']},
      );
      AppLogger.success('✅ [DB] Added ${data['mobile']} to authorized list');
    } catch (e) {
      AppLogger.warning('⚠️ [DB] Failed to insert authorized mobile: $e');
    }
  }

  // ---------- LOCAL LOGIN SUPPORT ----------
  Future<void> insertLocalUser(Map<String, dynamic> user) async {
    try {
      final db = await database;
      await db.insert(
        'local_users',
        user,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      // ignore: avoid_print
      AppLogger.info("🟢 Local user cached: ${user['username']}");
    } catch (e) {
      // ignore: avoid_print
      AppLogger.error('❌ Error caching local user: $e');
    }
  }

  Future<Map<String, dynamic>?> validateLocalLogin(
      String username, String password) async {
    try {
      final db = await database;
      final result = await db.query(
        'local_users',
        where: 'username = ? AND password = ?',
        whereArgs: [username, password],
        limit: 1,
      );
      if (result.isNotEmpty) {
        // ignore: avoid_print
        AppLogger.info("🟠 Offline login success for $username");
        return result.first;
      }
      return null;
    } catch (e) {
      // ignore: avoid_print
      AppLogger.error('❌ Offline login check failed: $e');
      return null;
    }
  }

  // ---------- PENDING SYNC (OFFLINE QUEUE) ----------
  Future<int> rawInsertPendingSync(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('pending_sync', row);
  }

  Future<List<Map<String, dynamic>>> getPendingSync() async {
    final db = await database;
    return await db.query('pending_sync', orderBy: 'id ASC');
  }

  Future<void> markSynced(int id) async {
    final db = await database;
    await db.delete('pending_sync', where: 'id = ?', whereArgs: [id]);
  }

  /// Helper your UI (or LocalDbHelper) can call directly
  Future<void> queuePendingSync({
    required String table,
    required Map<String, dynamic> data,
    required String action, // INSERT | UPDATE | DELETE
  }) async {
    final now = DateTime.now().toIso8601String();
    await rawInsertPendingSync({
      'table_name': table,
      'data': jsonEncode(data),
      'action': action,
      'timestamp': now,
    });
  }
  // --- Add near your other "FIRMS" helpers ---

  Future<Map<String, dynamic>?> getFirm(String firmId) async {
    final db = await database;
    final results = await db.query('firms', where: 'firmId = ?', whereArgs: [firmId], limit: 1);
    if (results.isNotEmpty) return results.first;
    return null;
  }

  Future<List<Map<String, dynamic>>> getFirmByFirmId(String firmId) async {
    final db = await database;
    return db.query('firms', where: 'firmId = ?', whereArgs: [firmId], limit: 1);
  }

  Future<void> upsertFirmSubscription({
    required String firmId,
    required String status,
    required String startIso,
    required String endIso,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final data = {
      'firmId': firmId,
      'subscriptionStatus': status,
      'subscriptionStart': startIso.isNotEmpty ? startIso : null,
      'subscriptionEnd': endIso.isNotEmpty ? endIso : null,
      'updatedAt': now,
    };

    // Try update first
    final count = await db.update('firms', data, where: 'firmId = ?', whereArgs: [firmId]);
    if (count == 0) {
      // Insert minimal row if it doesn't exist
      data['firmName'] = data['firmName'] ?? 'Unknown';
      data['createdAt'] = now;
      await db.insert('firms', data, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  /// Process the offline queue if we are online.
  /// - Keeps front-end unchanged.
  /// - Uses AwsApi.callDbHandler for POST/PUT/DELETE.
  Future<void> syncPendingIfOnline() async {
    // If you haven't added ConnectivityService, you can always try syncing.
    bool online = true;
    try {
      online = await ConnectivityService().isOnline();
    } catch (_) {}
    if (!online) return;

    final db = await database;
    final batch = db.batch();

    final pending = await getPendingSync();
    for (final row in pending) {
      final id = row['id'] as int;
      final table = row['table_name'] as String;
      final action = (row['action'] as String?)?.toUpperCase() ?? '';
      final dataStr = row['data'] as String? ?? '{}';
      final Map<String, dynamic> data = jsonDecode(dataStr);

      try {
        Map<String, dynamic> resp;

        final prefs = await SharedPreferences.getInstance();
        final firmId = prefs.getString('last_firm') ?? 'UNKNOWN';

        if (action == 'INSERT') {
          // POST
          resp = await AwsApi.callDbHandler(
            method: 'POST',
            table: table,
            firmId: firmId, // Required for Lambda authentication
            data: data,
          );
        } else if (action == 'UPDATE') {
          // PUT (expects an id in data)
          final idVal = data['id'];
          resp = await AwsApi.callDbHandler(
            method: 'PUT',
            table: table,
            firmId: firmId, // Required for Lambda authentication
            data: data,
            filters: (idVal != null) ? {'id': idVal} : null,
          );
        } else if (action == 'DELETE') {
          // DELETE (prefers filters for id)
          final idVal = data['id'];
          resp = await AwsApi.callDbHandler(
            method: 'DELETE',
            table: table,
            firmId: firmId, // Required for Lambda authentication
            filters: (idVal != null) ? {'id': idVal} : null,
          );
        } else {
          // Unknown action -> skip
          await markSynced(id);
          continue;
        }

        final ok =
            (resp['status']?.toString().toLowerCase() ?? '') == 'success';

        if (ok) {
          // success -> remove from queue
          await markSynced(id);
        } else {
          // If backend rejects, keep it in queue for next attempt.
          // You can add retry counters if you want later.
        }
      } catch (e) {
        // Network/API failure — keep in queue silently
      }
    }

    await batch.commit(noResult: true);
  }

  // ---------- DANGEROUS UTILS ----------
  Future<void> deleteAllFirms() async {
    final db = await database;
    await db.delete('firms');
    // ignore: avoid_print
    AppLogger.info('🗑️ All firms deleted from local DB');
  }

  // Helper to fetch distinct customers from orders for toggle
  Future<List<Map<String, dynamic>>> getDistinctCustomers() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT DISTINCT customerName as name, mobile 
      FROM orders 
      WHERE customerName IS NOT NULL AND customerName != ''
      ORDER BY customerName ASC
    ''');
  }

  // Firm Subscription Methods
  Future<void> updateFirmSubscription({
    required String firmId,
    required String plan,
    required String endDate, // yyyy-MM-dd
    required String status,
    String? txnId,
  }) async {
    final db = await database;
    final data = {
      'subscriptionPlan': plan,
      'subscriptionEnd': endDate,
      'subscriptionStatus': status,
      if (txnId != null) 'lastRenewalTxnId': txnId,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    
    await db.update(
      'firms',
      data,
      where: 'firmId = ?',
      whereArgs: [firmId],
    );
    
    // Auto Sync
    await _syncOrQueue(
      table: 'firms',
      data: {...data, 'firmId': firmId}, // Ensure Primary Key helps identification
      action: 'UPDATE', 
      filters: {'firmId': firmId}
    );
  }

  // ========== NEW MODULE METHODS ==========
  
  // Finance Module
  Future<int> insertTransaction(Map<String, dynamic> data) async {
    final db = await database;
    data['uuid'] = data['uuid'] ?? _generateUuid();
    data['createdAt'] = DateTime.now().toIso8601String();
    data['updatedAt'] = DateTime.now().toIso8601String();
    final id = await db.insert('transactions', data);
    
    // Auto Sync
    await _syncOrQueue(
      table: 'transactions',
      data: {...data, 'id': id},
      action: 'INSERT'
    );
    return id;
  }
  
  Future<int> updateTransaction(int id, Map<String, dynamic> data) async {
    final db = await database;
    data['updatedAt'] = DateTime.now().toIso8601String();
    final rows = await db.update('transactions', data, where: 'id = ?', whereArgs: [id]);
    
    // Auto Sync
    await _syncOrQueue(
      table: 'transactions',
      data: {...data, 'id': id},
      action: 'UPDATE',
      filters: {'id': id}
    );
    return rows;
  }
  
  Future<int> deleteTransaction(int id) async {
    final db = await database;
    final rows = await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
    
    // Auto Sync
    await _syncOrQueue(
      table: 'transactions',
      data: {'id': id},
      action: 'DELETE',
      filters: {'id': id}
    );
    return rows;
  }

  Future<List<Map<String, dynamic>>> getTransactions({
    String? firmId,
    String? startDate,
    String? endDate,
    String? type,
    String? category,
    String? relatedEntityType,
    int? relatedEntityId,
    String? searchText,
    int? limit
  }) async {
    final db = await database;
    String where = '1=1';
    List<dynamic> args = [];

    if (firmId != null) {
      where += ' AND firmId = ?';
      args.add(firmId);
    }
    if (startDate != null && endDate != null) {
      where += ' AND date BETWEEN ? AND ?';
      args.add(startDate);
    } else if (startDate != null) {
      where += ' AND date >= ?';
      args.add(startDate);
    } else if (endDate != null) {
      where += ' AND date <= ?';
      args.add(endDate);
    }

    if (type != null) {
      where += ' AND type = ?';
      args.add(type);
    }
    if (category != null) {
      where += ' AND category = ?';
      args.add(category);
    }
    if (relatedEntityType != null) {
      where += ' AND relatedEntityType = ?';
      args.add(relatedEntityType);
    }
    if (relatedEntityId != null) {
      where += ' AND relatedEntityId = ?';
      args.add(relatedEntityId);
    }
    if (searchText != null && searchText.isNotEmpty) {
      where += ' AND (category LIKE ? OR description LIKE ?)';
      args.add('%$searchText%');
      args.add('%$searchText%');
    }

    return await db.query(
      'transactions',
      where: where,
      whereArgs: args,
      orderBy: 'date DESC, id DESC',
      limit: limit,
    );
  }

  Future<double> getOpeningBalance({
    required String relatedEntityType,
    required int relatedEntityId,
    required String date,
    String? firmId,
  }) async {
    final db = await database;
    final res = await db.rawQuery('''
      SELECT SUM(CASE WHEN type = 'INCOME' THEN amount ELSE -amount END) as balance
      FROM transactions
      WHERE relatedEntityType = ? AND relatedEntityId = ? AND date < ?
      ${firmId != null ? 'AND firmId = ?' : ''}
    ''', [relatedEntityType, relatedEntityId, date, if (firmId != null) firmId]);
    
    return (res.first['balance'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getClosingBalance({
    required String relatedEntityType,
    required int relatedEntityId,
    required String date,
    String? firmId,
  }) async {
    final db = await database;
    final res = await db.rawQuery('''
      SELECT SUM(CASE WHEN type = 'INCOME' THEN amount ELSE -amount END) as balance
      FROM transactions
      WHERE relatedEntityType = ? AND relatedEntityId = ? AND date <= ?
      ${firmId != null ? 'AND firmId = ?' : ''}
    ''', [relatedEntityType, relatedEntityId, date, if (firmId != null) firmId]);
    
    return (res.first['balance'] as num?)?.toDouble() ?? 0.0;
  }
  
  Future<Map<String, double>> getFinanceSummary(String firmId, String startDate, String endDate, {String? relatedEntityType}) async {
    final db = await database;
    
    String entityClause = "";
    if (relatedEntityType != null) {
      entityClause = "AND relatedEntityType = '$relatedEntityType'";
    }
    
    // Income
    final incomeRes = await db.rawQuery('''
      SELECT SUM(amount) as total FROM transactions 
      WHERE firmId = ? AND type = 'INCOME' AND date BETWEEN ? AND ? $entityClause
    ''', [firmId, startDate, endDate]);
    
    // Expense
    final expenseRes = await db.rawQuery('''
      SELECT SUM(amount) as total FROM transactions 
      WHERE firmId = ? AND type = 'EXPENSE' AND date BETWEEN ? AND ? $entityClause
    ''', [firmId, startDate, endDate]);
    
    return {
      'income': (incomeRes.first['total'] as num?)?.toDouble() ?? 0.0,
      'expense': (expenseRes.first['total'] as num?)?.toDouble() ?? 0.0,
    };
  }
  
  Future<List<Map<String, dynamic>>> getSummaryByPeriod(String firmId, String startDate, String endDate, String groupBy) async {
    // groupBy: 'day', 'month'
    final db = await database;
    final dateFormat = groupBy == 'month' ? '%Y-%m' : '%Y-%m-%d';
    
    return await db.rawQuery('''
      SELECT 
        strftime(?, date) as period,
        SUM(CASE WHEN type = 'INCOME' THEN amount ELSE 0 END) as income,
        SUM(CASE WHEN type = 'EXPENSE' THEN amount ELSE 0 END) as expense
      FROM transactions
      WHERE firmId = ? AND date BETWEEN ? AND ?
      GROUP BY period
      ORDER BY period ASC
    ''', [dateFormat, firmId, startDate, endDate]);
  }
  
  // NOTE: Inventory Module methods moved to end of file (v18 section)
  
  Future<List<Map<String, dynamic>>> getSupplierOrders() async {
    final db = await database;
    return await db.query('supplier_orders', orderBy: 'date DESC');
  }
  
  Future<int> insertSupplierOrder(Map<String, dynamic> data, [List<Map<String, dynamic>>? items]) async {
    final cloudSync = CloudSyncService();
    data['uuid'] = data['uuid'] ?? _generateUuid();
    final orderId = await cloudSync.awsFirstWrite(table: 'supplier_orders', data: data);
    AppLogger.success('✅ [SupplierOrders] Created supplier order #$orderId (AWS-first)');

    if (items != null && items.isNotEmpty) {
      for (var item in items) {
        item['orderId'] = orderId;
        item['uuid'] = item['uuid'] ?? _generateUuid();
        await cloudSync.awsFirstWrite(table: 'supplier_order_items', data: item);
      }
    }
    
    return orderId ?? 0;
  }
  

  // ---------- OPERATIONS moved to OperationRepository ----------

  // --- DISH MASTER (AWS-first) ---
  Future<int?> insertDishMaster(Map<String, dynamic> data) async {
    final cloudSync = CloudSyncService();
    data['uuid'] = data['uuid'] ?? _generateUuid();
    data['createdAt'] ??= DateTime.now().toIso8601String();
    data['updatedAt'] = DateTime.now().toIso8601String();
    final id = await cloudSync.awsFirstWrite(table: 'dish_master', data: data);
    AppLogger.success('✅ [DishMaster] Created dish #$id (AWS-first)');
    return id;
  }

  // --- PURCHASE ORDERS update (AWS-first) ---
  Future<bool> updatePurchaseOrderFields(int id, Map<String, dynamic> updates) async {
    final cloudSync = CloudSyncService();
    updates['id'] = id;
    final success = await cloudSync.awsFirstUpdate(table: 'purchase_orders', recordId: id, data: updates);
    AppLogger.success('✅ [PurchaseOrders] Updated PO #$id (AWS-first)');
    return success;
  }

  // --- SUPPLIERS delete (AWS-first) ---
  Future<bool> deleteSupplier(int id) async {
    final cloudSync = CloudSyncService();
    final success = await cloudSync.awsFirstDelete(table: 'suppliers', recordId: id);
    AppLogger.success('✅ [Suppliers] Deleted supplier #$id (AWS-first)');
    return success;
  }

  // --- SUBCONTRACTORS delete (AWS-first) ---
  Future<bool> deleteSubcontractor(int id) async {
    final cloudSync = CloudSyncService();
    final success = await cloudSync.awsFirstDelete(table: 'subcontractors', recordId: id);
    AppLogger.success('✅ [Subcontractors] Deleted subcontractor #$id (AWS-first)');
    return success;
  }

  // User Management
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await database;
    return await db.query('users');
  }

  Future<Map<String, dynamic>?> getUser(int id) async {
    final db = await database;
    final res = await db.query('users', where: 'id = ?', whereArgs: [id], limit: 1);
    return res.isNotEmpty ? res.first : null;
  }

  Future<bool> updateUser(Map<String, dynamic> user) async {
    final cloudSync = CloudSyncService();
    final id = user['id'] as int;
    final success = await cloudSync.awsFirstUpdate(table: 'users', recordId: id, data: user);
    AppLogger.success('✅ [User] Updated user #$id (AWS-first)');
    return success;
  }

  Future<bool> updateDish(int id, Map<String, dynamic> updates) async {
    final cloudSync = CloudSyncService();
    updates['id'] = id;
    final success = await cloudSync.awsFirstUpdate(table: 'dishes', recordId: id, data: updates);
    AppLogger.success('✅ [Dishes] Updated dish #$id (AWS-first)');
    return success;
  }

  Future<bool> updateUtensilDispatch(int id, Map<String, dynamic> updates) async {
    final cloudSync = CloudSyncService();
    updates['id'] = id;
    final success = await cloudSync.awsFirstUpdate(table: 'dispatch', recordId: id, data: updates);
    AppLogger.success('✅ [Dispatch] Updated dispatch #$id (AWS-first)');
    return success;
  }

  Future<bool> updateDispatch(int id, Map<String, dynamic> updates) async {
    final cloudSync = CloudSyncService();
    updates['id'] = id;
    final success = await cloudSync.awsFirstUpdate(table: 'dispatches', recordId: id, data: updates);
    AppLogger.success('✅ [Dispatches] Updated dispatch #$id (AWS-first)');

    // ERP Integration: Auto-record earnings if completed
    if (success && updates['dispatchStatus'] == 'COMPLETED') {
      _recordDriverEarning(id);
    }

    return success;
  }

  Future<void> _recordDriverEarning(int dispatchId) async {
    final db = await database;
    final dispatchRes = await db.query('dispatches', where: 'id = ?', whereArgs: [dispatchId]);
    if (dispatchRes.isEmpty) return;
    
    final dispatch = dispatchRes.first;
    final driverId = dispatch['driverId'] as int?;
    final driverShare = (dispatch['driverShare'] as num?)?.toDouble() ?? 0;
    final firmId = (dispatch['firmId']?.toString()) ?? 'DEFAULT';
    
    if (driverId == null || driverShare <= 0) return;
    
    // Check if transaction already exists for this dispatch
    final existing = await getTransactions(
      relatedEntityType: 'DRIVER',
      relatedEntityId: driverId,
      searchText: 'Dispatch #$dispatchId',
    );
    
    if (existing.isNotEmpty) {
      AppLogger.info('ℹ️ [Finance] Earning for Dispatch #$dispatchId already recorded. Skipping.');
      return;
    }
    
    // Record earning as INCOME (Credit) for the driver's ledger
    await insertTransaction({
      'firmId': firmId,
      'date': DateTime.now().toIso8601String().split('T')[0],
      'type': 'INCOME', // Using INCOME as Credit (standard in this app's ledger logic)
      'category': 'Driver Earning',
      'amount': driverShare,
      'description': 'Earnings for Dispatch #$dispatchId',
      'relatedEntityType': 'DRIVER',
      'relatedEntityId': driverId,
      'mode': 'Accrued',
    });
    AppLogger.success('✅ [Finance] Automatically recorded ₹$driverShare as earnings for Driver #$driverId (Dispatch #$dispatchId)');
  }

  Future<bool> updateOrderFields(int id, Map<String, dynamic> updates) async {
    final cloudSync = CloudSyncService();
    updates['id'] = id;
    final success = await cloudSync.awsFirstUpdate(table: 'orders', recordId: id, data: updates);
    AppLogger.success('✅ [Orders] Updated order #$id (AWS-first)');
    return success;
  }

  Future<bool> updateDispatchItem(int id, Map<String, dynamic> updates) async {
    final cloudSync = CloudSyncService();
    updates['id'] = id;
    final success = await cloudSync.awsFirstUpdate(table: 'dispatch_items', recordId: id, data: updates);
    AppLogger.success('✅ [DispatchItems] Updated item #$id (AWS-first)');
    return success;
  }

  Future<bool> updateUtensilByName(String name, Map<String, dynamic> updates) async {
    final cloudSync = CloudSyncService();
    final db = await database;
    final rows = await db.update('utensils', updates, where: 'name = ?', whereArgs: [name]);
    // Fetch ID and sync via AWS-first
    final records = await db.query('utensils', where: 'name = ?', whereArgs: [name]);
    if (records.isNotEmpty) {
      final id = records.first['id'] as int;
      updates['id'] = id;
      await cloudSync.awsFirstUpdate(table: 'utensils', recordId: id, data: updates);
      AppLogger.success('✅ [Utensils] Updated utensil "$name" (AWS-first)');
    }
    return rows > 0;
  }
  
  Future<bool> deleteUser(int id) async {
    final cloudSync = CloudSyncService();
    final success = await cloudSync.awsFirstDelete(table: 'users', recordId: id);
    AppLogger.success('✅ [User] Deleted user #$id (AWS-first)');
    return success;
  }
  
  // Audit
  Future<List<Map<String, dynamic>>> getAuditLogs({String? firmId, String? tableName, String? userId}) async {
    final db = await database;
    if (userId != null && firmId != null && tableName != null) {
      return await db.query('audit_log',
        where: 'firm_id = ? AND table_name = ? AND user_id = ?',
        whereArgs: [firmId, tableName, userId],
        orderBy: 'timestamp DESC'
      );
    } else if (firmId != null && tableName != null) {
      return await db.query('audit_log', 
        where: 'firm_id = ? AND table_name = ?', 
        whereArgs: [firmId, tableName],
        orderBy: 'timestamp DESC'
      );
    } else if (firmId != null) {
      return await db.query('audit_log', 
        where: 'firm_id = ?', 
        whereArgs: [firmId],
        orderBy: 'timestamp DESC'
      );
    }
    return await db.query('audit_log', orderBy: 'timestamp DESC');
  }
  
  // Reports
  Future<List<Map<String, dynamic>>> getSalesReport(String startDate, String endDate) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT date, SUM(finalAmount) as revenue, SUM(totalPax) as pax, COUNT(*) as orders
      FROM orders
      WHERE date BETWEEN ? AND ? AND (isCancelled IS NULL OR isCancelled = 0)
      GROUP BY date
      ORDER BY date
    ''', [startDate, endDate]);
  }
  
  Future<List<Map<String, dynamic>>> getVendorPurchaseReport(String startDate, String endDate) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT s.name as supplier, SUM(so.totalAmount) as total
      FROM supplier_orders so
      JOIN suppliers s ON so.supplierId = s.id
      WHERE so.date BETWEEN ? AND ?
      GROUP BY s.id
      ORDER BY total DESC
    ''', [startDate, endDate]);
  }
  
  Future<List<Map<String, dynamic>>> getStaffAttendanceReport(String startDate, String endDate) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT s.name, COUNT(*) as days_present
      FROM attendance a
      JOIN staff s ON a.staffId = s.id
      WHERE a.date BETWEEN ? AND ? AND a.status = 'Present'
      GROUP BY s.id
      ORDER BY s.name
    ''', [startDate, endDate]);
  }
  
  // ============== PAYROLL & HR REPORTS ==============
  
  
  // ============== (Migrated to OperationRepository) ==============
  


  
  /// Get HR attendance report with hours and OT
  Future<List<Map<String, dynamic>>> getHRAttendanceReport(String startDate, String endDate) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        s.id,
        s.name,
        s.role,
        s.staffType,
        COUNT(a.id) as daysPresent,
        COALESCE(SUM(a.hoursWorked), 0) as totalHours,
        COALESCE(SUM(a.overtime), 0) as totalOvertime,
        SUM(CASE WHEN a.isWithinGeoFence = 1 THEN 1 ELSE 0 END) as geoFenceCompliant
      FROM staff s
      LEFT JOIN attendance a ON s.id = a.staffId 
        AND a.date BETWEEN ? AND ? 
        AND a.status = 'Present'
      WHERE s.isActive = 1
      GROUP BY s.id
      ORDER BY daysPresent DESC, s.name
    ''', [startDate, endDate]);
  }
  
  /// Get overtime summary report
  Future<List<Map<String, dynamic>>> getHROvertimeReport(String startDate, String endDate) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        s.id,
        s.name,
        s.hourlyRate,
        COALESCE(SUM(a.overtime), 0) as totalOT,
        COALESCE(SUM(a.overtime), 0) * COALESCE(s.hourlyRate, 0) as otPay
      FROM staff s
      LEFT JOIN attendance a ON s.id = a.staffId 
        AND a.date BETWEEN ? AND ? 
        AND a.overtime > 0
      WHERE s.isActive = 1
      GROUP BY s.id
      HAVING totalOT > 0
      ORDER BY totalOT DESC
    ''', [startDate, endDate]);
  }

  /// Get attendance records for a specific staff member
  Future<List<Map<String, dynamic>>> getAttendanceForStaff(int staffId, String startDate, String endDate) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        date,
        checkIn,
        checkOut,
        hoursWorked,
        overtime,
        status,
        isWithinGeoFence
      FROM attendance
      WHERE staffId = ? AND date BETWEEN ? AND ?
      ORDER BY date DESC
    ''', [staffId, startDate, endDate]);
  }
  

  // ---------- STAFF ASSIGNMENTS moved to OperationRepository ----------

  
  // ============== COMPREHENSIVE REPORTS ==============
  

  // ---------- ORDER & KITCHEN REPORTS moved to OrderRepository ----------
  
  /// Daily Capacity Report
  Future<List<Map<String, dynamic>>> getDailyCapacityReport(String startDate, String endDate) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        date,
        SUM(totalPax) as totalPax,
        COUNT(*) as orderCount,
        SUM(CASE WHEN foodType = 'Veg' THEN totalPax ELSE 0 END) as vegPax,
        SUM(CASE WHEN foodType = 'Non-Veg' THEN totalPax ELSE 0 END) as nonVegPax
      FROM orders
      WHERE date BETWEEN ? AND ? AND (isCancelled = 0 OR isCancelled IS NULL)
      GROUP BY date
      ORDER BY date DESC
    ''', [startDate, endDate]);
  }

  // AWS Backup
  Future<Map<String, dynamic>> backupAllTablesToAWS() async {
    // Placeholder for AWS backup - returns success for now
    return {'success': true, 'message': 'Backup functionality coming soon'};
  }

  Future<String> backupToLocalFile() async {
    final db = await database;
    final data = <String, dynamic>{};
    
    // Dump core tables
    final tables = ['firms', 'orders', 'dishes', 'service_rates', 'users', 'authorized_mobiles', 'transactions', 'inventory', 'staff', 'suppliers'];
    for (final t in tables) {
      try {
        data[t] = await db.query(t);
      } catch (_) {}
    }
    
    final jsonStr = jsonEncode(data);
    final dir = await getApplicationDocumentsDirectory();
    final file = File(join(dir.path, 'ruchiserv_backup_${DateTime.now().millisecondsSinceEpoch}.json'));
    await file.writeAsString(jsonStr);
    return file.path;
  }
  
  // ========== MOBILE AUTHORIZATION METHODS ==========
  
  /// Check if mobile is authorized for a firm
  Future<bool> isMobileAuthorized(String firmId, String mobile) async {
    final db = await database;
    final result = await db.query(
      'authorized_mobiles',
      where: 'LOWER(firmId) = LOWER(?) AND mobile = ? AND isActive = 1',
      whereArgs: [firmId, mobile],
    );
    return result.isNotEmpty;
  }
  
  /// Get all authorized mobiles for a firm
  Future<List<Map<String, dynamic>>> getAuthorizedMobiles(String firmId, {String? type}) async {
    final db = await database;
    if (type != null) {
      return await db.query(
        'authorized_mobiles',
        where: 'firmId = ? AND type = ?',
        whereArgs: [firmId, type],
        orderBy: 'name ASC',
      );
    }
    return await db.query(
      'authorized_mobiles',
      where: 'firmId = ?',
whereArgs: [firmId],
      orderBy: 'name ASC',
    );
  }

  Future<Map<String, dynamic>?> getAuthorizedMobileByPhone(String firmId, String mobile) async {
    final db = await database;
    final results = await db.query(
      'authorized_mobiles',
      where: 'LOWER(firmId) = LOWER(?) AND mobile = ?',
      whereArgs: [firmId, mobile],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }
  
  /// Add authorized mobile
  Future<int> addAuthorizedMobile({
    required String firmId,
    required String mobile,
    required String type,
    required String name,
    String? addedBy,
  }) async {
    final db = await database;
    return await db.insert('authorized_mobiles', {
      'firmId': firmId,
      'mobile': mobile,
      'type': type,
      'name': name,
      'isActive': 1,
      'addedBy': addedBy ?? 'ADMIN',
      'addedAt': DateTime.now().toIso8601String(),
    });
  }
  
  /// Toggle mobile authorization status
  Future<int> toggleAuthorizedMobile(int id, bool isActive) async {
    final db = await database;
    return await db.update(
      'authorized_mobiles',
      {'isActive': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  /// Delete authorized mobile (hard delete)
  Future<int> deleteAuthorizedMobile(int id) async {
    final db = await database;
    return await db.delete(
      'authorized_mobiles',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  // Service Rate Methods
  Future<double> getLastServiceRate(String firmId, String rateType) async {
    final db = await database;
    // 1. Try dedicated table first
    final res = await db.query(
      'service_rates',
      columns: ['rate'],
      where: 'firmId = ? AND rateType = ?',
      whereArgs: [firmId, rateType],
      limit: 1,
    );
    if (res.isNotEmpty) {
      return (res.first['rate'] as num).toDouble();
    }
    
    // 2. Fallback to last successful order (for immediate utility)
    try {
      final column = (rateType == 'STAFF') ? 'staffRate' : 'counterSetupRate';
      final res2 = await db.query(
        'orders',
        columns: [column],
        where: 'firmId = ? AND $column > 0',
        whereArgs: [firmId],
        orderBy: 'id DESC',
        limit: 1,
      );
      if (res2.isNotEmpty) {
        return (res2.first[column] as num).toDouble();
      }
    } catch (_) {
      // Column might not exist if v6 upgrade failed partially
    }

    return 0.0;
  }

  Future<void> upsertServiceRate(String firmId, String rateType, double rate) async {
    final db = await database;
    await db.insert(
      'service_rates',
      {
        'firmId': firmId,
        'rateType': rateType,
        'rate': rate,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Firm Profile Methods
  Future<Map<String, dynamic>?> getFirmDetails(String firmId) async {
    final db = await database;
    final res = await db.query(
      'firms',
      where: 'firmId = ?',
      whereArgs: [firmId],
      limit: 1,
    );
    if (res.isNotEmpty) return res.first;
    return null;
  }

  Future<int> updateFirmDetails(String firmId, Map<String, dynamic> data) async {
    final db = await database;
    final exists = await getFirmDetails(firmId);
    
    // Ensure data doesn't contain ID (primary key)
    final updateData = Map<String, dynamic>.from(data);
    updateData.remove('id');
    updateData['updatedAt'] = DateTime.now().toIso8601String();

    int result;
    if (exists == null) {
      updateData['firmId'] = firmId; // Ensure firmId is set
      updateData['createdAt'] = DateTime.now().toIso8601String();
      result = await db.insert('firms', updateData);
    } else {
      result = await db.update(
        'firms',
        updateData,
        where: 'firmId = ?',
        whereArgs: [firmId],
      );
    }
    
    // v38: Trigger cloud sync for cross-device firm profile sync
    await _syncOrQueue(
      table: 'firms',
      data: {...updateData, 'firmId': firmId, 'id': exists?['id'] ?? result},
      action: exists == null ? 'INSERT' : 'UPDATE',
      filters: {'firmId': firmId},
    );
    
    return result;
  }

  // ========== DISH METHODS FOR INVENTORY ==========
  
  /// Gets all dishes from Master Table (for BOM management)
  Future<List<Map<String, dynamic>>> getAllDishes(String firmId) async {
    final db = await database;
    
    // 1. Get Firm Specific Data
    final firmData = await db.query(
      'dish_master',
      where: 'firmId = ?',
      whereArgs: [firmId],
      orderBy: 'category, name',
    );

    // 2. Get Seed Data (excluding overridden)
    bool showUniversal = await getFirmUniversalDataVisibility(firmId);
    if (!showUniversal) {
       return firmData;
    }

    // Collect both baseIds and names from firm data to properly exclude duplicates
    final customizedBaseIds = firmData.map((r) => r['baseId']).where((id) => id != null).toList();
    final firmDishNames = firmData.map((r) => (r['name'] as String?)?.toLowerCase()).where((n) => n != null).toSet();
    
    String seedWhere = "firmId = 'SEED'";
    if (customizedBaseIds.isNotEmpty) {
      seedWhere += " AND baseId NOT IN (${customizedBaseIds.join(',')})";
    }
    
    final seedData = await db.rawQuery(
      'SELECT * FROM dish_master WHERE $seedWhere ORDER BY category, name',
    );
    
    // Also filter out SEED dishes whose names match firm dishes (case-insensitive)
    final filteredSeedData = seedData.where((sd) {
      final seedName = (sd['name'] as String?)?.toLowerCase();
      return seedName == null || !firmDishNames.contains(seedName);
    }).toList();
    
    final combined = [...firmData, ...filteredSeedData];
    combined.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    
    return combined;
  }

// === VISIBILITY SETTINGS ===
Future<bool> getFirmUniversalDataVisibility(String firmId) async {
  final db = await database;
  final res = await db.query(
    'firms',
    columns: ['showUniversalData'],
    where: 'firmId = ?',
    whereArgs: [firmId],
  );
  if (res.isNotEmpty) {
    return (res.first['showUniversalData'] as int? ?? 1) == 1;
  }
  return true; // Default to true
}

Future<void> setFirmUniversalDataVisibility(String firmId, bool isVisible) async {
    final db = await database;
    await db.update(
      'firms',
      {'showUniversalData': isVisible ? 1 : 0},
      where: 'firmId = ?',
      whereArgs: [firmId],
    );
    // Auto Sync
    await _syncOrQueue(
      table: 'firms',
      data: {'firmId': firmId, 'showUniversalData': isVisible ? 1 : 0},
      action: 'UPDATE',
      filters: {'firmId': firmId}
    );
}
  // ========== INVENTORY MODULE HELPERS ==========

  // --- INGREDIENTS ---

  // ---------- INVENTORY & RECIPES moved to InventoryRepository ----------

// --- SUPPLIERS ---
  Future<List<Map<String, dynamic>>> getAllSuppliers(String firmId) async {
    final db = await database;
    return await db.query('suppliers',
      where: 'firmId = ? AND isActive = 1',
      whereArgs: [firmId],
      orderBy: 'name',
    );
  }

  Future<int?> insertSupplier(Map<String, dynamic> data) async {
    final cloudSync = CloudSyncService();
    data['createdAt'] = DateTime.now().toIso8601String();
    data['uuid'] = data['uuid'] ?? _generateUuid();
    final id = await cloudSync.awsFirstWrite(table: 'suppliers', data: data);
    AppLogger.success('✅ [Suppliers] Created supplier #$id (AWS-first)');
    return id;
  }

  Future<bool> updateSupplier(int id, Map<String, dynamic> data) async {
    final cloudSync = CloudSyncService();
    data['id'] = id;
    data['updatedAt'] = DateTime.now().toIso8601String();
    final success = await cloudSync.awsFirstUpdate(table: 'suppliers', recordId: id, data: data);
    AppLogger.success('✅ [Suppliers] Updated supplier #$id (AWS-first)');
    return success;
  }


  // --- PURCHASE ORDERS ---
  // --- CUSTOMERS ---
  Future<List<Map<String, dynamic>>> getAllCustomers(String firmId) async {
    final db = await database;
    return await db.query('customers',
      where: 'firmId = ?',
      whereArgs: [firmId],
      orderBy: 'name',
    );
  }

  Future<int?> insertCustomer(Map<String, dynamic> data) async {
    final cloudSync = CloudSyncService();
    data['createdAt'] = DateTime.now().toIso8601String();
    data['uuid'] = data['uuid'] ?? _generateUuid();
    final id = await cloudSync.awsFirstWrite(table: 'customers', data: data);
    AppLogger.success('✅ [Customers] Created customer #$id (AWS-first)');
    return id;
  }

  // --- SUBCONTRACTORS ---
  Future<List<Map<String, dynamic>>> getAllSubcontractors(String firmId) async {
    final db = await database;
    return await db.query('subcontractors',
      where: 'firmId = ? AND isActive = 1',
      whereArgs: [firmId],
      orderBy: 'name',
    );
  }

  Future<int?> insertSubcontractor(Map<String, dynamic> data) async {
    final cloudSync = CloudSyncService();
    data['createdAt'] = DateTime.now().toIso8601String();
    data['isActive'] = 1; // Ensure new subcontractors are active by default
    data['uuid'] = data['uuid'] ?? _generateUuid();
    final id = await cloudSync.awsFirstWrite(table: 'subcontractors', data: data);
    AppLogger.success('✅ [Subcontractors] Created subcontractor #$id (AWS-first)');
    return id;
  }

  Future<bool> updateSubcontractor(int id, Map<String, dynamic> data) async {
    final cloudSync = CloudSyncService();
    data['id'] = id;
    data['updatedAt'] = DateTime.now().toIso8601String();
    final success = await cloudSync.awsFirstUpdate(table: 'subcontractors', recordId: id, data: data);
    AppLogger.success('✅ [Subcontractors] Updated subcontractor #$id (AWS-first)');
    return success;
  }

  // --- MRP ---
  /// Creates a new MRP run with auto-generated runName like "Dec-1", "Dec-2", etc.
  /// runNumber resets to 1 at the start of each month
  Future<int?> createMrpRun(Map<String, dynamic> data) async {
    final db = await database;
    final cloudSync = CloudSyncService();
    final now = DateTime.now();
    data['createdAt'] = now.toIso8601String();
    
    // Get firmId from data
    final firmId = data['firmId'] as String?;
    
    // Calculate the run number for this month
    final monthStart = DateTime(now.year, now.month, 1).toIso8601String().substring(0, 10);
    final monthEnd = DateTime(now.year, now.month + 1, 0).toIso8601String().substring(0, 10);
    
    final existingRuns = await db.rawQuery('''
      SELECT MAX(runNumber) as maxNum 
      FROM mrp_runs 
      WHERE firmId = ? 
        AND date(runDate) >= date(?)
        AND date(runDate) <= date(?)
    ''', [firmId, monthStart, monthEnd]);
    
    int runNumber = 1;
    if (existingRuns.isNotEmpty && existingRuns.first['maxNum'] != null) {
      runNumber = (existingRuns.first['maxNum'] as int) + 1;
    }
    
    // Generate month abbreviation
    const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final runName = '${monthNames[now.month - 1]}-$runNumber';
    
    data['runNumber'] = runNumber;
    data['runName'] = runName;
    data['uuid'] = data['uuid'] ?? _generateUuid();
    
    final id = await cloudSync.awsFirstWrite(table: 'mrp_runs', data: data);
    AppLogger.success('✅ [MRP] Created MRP run #$id "$runName" (AWS-first)');
    return id;
  }

  Future<List<Map<String, dynamic>>> getMrpRuns(String firmId) async {
    final db = await database;
    return await db.query('mrp_runs',
      where: 'firmId = ?',
      whereArgs: [firmId],
      orderBy: 'createdAt DESC',
    );
  }

  Future<void> addOrdersToMrpRun(int mrpRunId, List<Map<String, dynamic>> orders) async {
    final db = await database;
    final batch = db.batch();
    for (var order in orders) {
      batch.insert('mrp_run_orders', {
        'mrpRunId': mrpRunId,
        'orderId': order['orderId'],
        'pax': order['pax'],
        'isSubcontracted': order['isSubcontracted'] ?? 0,
        'subcontractorId': order['subcontractorId'],
        'uuid': order['uuid'] ?? _generateUuid(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> saveMrpOutput(int mrpRunId, List<Map<String, dynamic>> output) async {
    final db = await database;
    await db.delete('mrp_output', where: 'mrpRunId = ?', whereArgs: [mrpRunId]);
    final batch = db.batch();
    for (var item in output) {
      batch.insert('mrp_output', {
        'mrpRunId': mrpRunId,
        ...item,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getMrpOutput(int mrpRunId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT mo.*, 
             i.name as ingredientName,
             COALESCE(i.cost_per_unit, 0) as rate,
             (mo.requiredQty * COALESCE(i.cost_per_unit, 0)) as totalCost,
             s.name as supplierName
      FROM mrp_output mo
      JOIN ingredients_master i ON mo.ingredientId = i.id
      LEFT JOIN suppliers s ON mo.supplierId = s.id
      WHERE mo.mrpRunId = ?
      ORDER BY mo.category, i.name
    ''', [mrpRunId]);
  }

  /// Get MRP output for allotment screen - only shows PENDING and ALLOCATED items (not already PO'd)
  Future<List<Map<String, dynamic>>> getMrpOutputForAllotment(int mrpRunId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT mo.*, 
             i.name as ingredientName,
             COALESCE(i.cost_per_unit, 0) as rate,
             (mo.requiredQty * COALESCE(i.cost_per_unit, 0)) as totalCost,
             s.name as supplierName
      FROM mrp_output mo
      JOIN ingredients_master i ON mo.ingredientId = i.id
      LEFT JOIN suppliers s ON mo.supplierId = s.id
      WHERE mo.mrpRunId = ? 
        AND (mo.allocationStatus IS NULL OR mo.allocationStatus != 'PO_SENT')
      ORDER BY mo.category, i.name
    ''', [mrpRunId]);
  }

  /// Update allocation for a single ingredient in MRP output
  Future<void> updateMrpOutputAllocation(int mrpOutputId, int? supplierId) async {
    final db = await database;
    await db.update('mrp_output', {
      'supplierId': supplierId,
      'allocationStatus': supplierId != null ? 'ALLOCATED' : 'PENDING',
      'allocatedQty': supplierId != null 
          ? (await db.query('mrp_output', where: 'id = ?', whereArgs: [mrpOutputId])).first['requiredQty']
          : 0,
    }, where: 'id = ?', whereArgs: [mrpOutputId]);
  }

  /// Bulk update allocations - called when user toggles suppliers in allotment screen
  Future<void> updateMrpOutputAllocations(int mrpRunId, Map<int, int?> allocations) async {
    final db = await database;
    final batch = db.batch();
    
    for (var entry in allocations.entries) {
      final ingredientId = entry.key;
      final supplierId = entry.value;
      
      // Find the mrp_output record for this ingredient in this run
      final outputs = await db.query('mrp_output', 
        where: 'mrpRunId = ? AND ingredientId = ?', 
        whereArgs: [mrpRunId, ingredientId],
      );
      
      if (outputs.isNotEmpty) {
        final outputId = outputs.first['id'] as int;
        final requiredQty = outputs.first['requiredQty'];
        
        batch.update('mrp_output', {
          'supplierId': supplierId,
          'allocationStatus': supplierId != null ? 'ALLOCATED' : 'PENDING',
          'allocatedQty': supplierId != null ? requiredQty : 0,
        }, where: 'id = ?', whereArgs: [outputId]);
      }
    }
    
    await batch.commit(noResult: true);
  }

  /// Mark MRP output items as PO_SENT after PO generation - links to the PO and prevents re-processing
  Future<void> markMrpOutputAsPOSent(int mrpRunId, int poId, List<int> ingredientIds) async {
    final db = await database;
    for (var ingredientId in ingredientIds) {
      await db.update('mrp_output', {
        'allocationStatus': 'PO_SENT',
        'poId': poId,
        'purchaseQty': (await db.query('mrp_output', 
          columns: ['requiredQty'],
          where: 'mrpRunId = ? AND ingredientId = ?', 
          whereArgs: [mrpRunId, ingredientId],
        )).firstOrNull?['requiredQty'] ?? 0,
      }, where: 'mrpRunId = ? AND ingredientId = ?', whereArgs: [mrpRunId, ingredientId]);
    }
  }

  /// Get existing allocations for an MRP run (for restoring state in AllotmentScreen)
  Future<Map<int, int?>> getExistingAllocations(int mrpRunId) async {
    final db = await database;
    final results = await db.query('mrp_output',
      columns: ['ingredientId', 'supplierId'],
      where: 'mrpRunId = ? AND supplierId IS NOT NULL',
      whereArgs: [mrpRunId],
    );
    
    return Map.fromEntries(
      results.map((r) => MapEntry(r['ingredientId'] as int, r['supplierId'] as int?)),
    );
  }

  /// Lock orders for MRP - only sets mrpRunId if not already set
  /// This prevents overwriting when user accidentally re-runs MRP
  Future<void> lockOrdersForMrp(int mrpRunId, List<int> orderIds) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    for (var orderId in orderIds) {
      // Check if order already has an mrpRunId
      final existing = await db.query('orders', 
        columns: ['mrpRunId', 'mrpStatus'],
        where: 'id = ?', 
        whereArgs: [orderId],
      );
      
      if (existing.isNotEmpty) {
        final currentMrpRunId = existing.first['mrpRunId'];
        final currentStatus = existing.first['mrpStatus'];
        
        // Only update if order doesn't already have an MRP run assigned
        // OR if it's still in PENDING status
        if (currentMrpRunId == null || currentStatus == 'PENDING' || currentStatus == null) {
          await db.update('orders', {
            'mrpRunId': mrpRunId,
            'mrpStatus': 'MRP_DONE',
            'isLocked': 1,
            'lockedAt': now,
          }, where: 'id = ?', whereArgs: [orderId]);
        }
        // If already has mrpRunId, don't overwrite - just ensure it's locked
        else {
          await db.update('orders', {
            'isLocked': 1,
            'lockedAt': now,
          }, where: 'id = ?', whereArgs: [orderId]);
        }
      }
    }
  }

  /// Update order status to PO_SENT only when ALL ingredients for that order's MRP run have been PO'd
  Future<void> updateOrderStatusIfAllItemsPOd(int mrpRunId) async {
    final db = await database;
    
    // Check if there are any items still not PO_SENT for this run
    final pendingItems = await db.query('mrp_output',
      where: "mrpRunId = ? AND (allocationStatus IS NULL OR allocationStatus != 'PO_SENT')",
      whereArgs: [mrpRunId],
    );
    
    // If all items are PO_SENT, update orders and MRP run status
    if (pendingItems.isEmpty) {
      // Get all orders linked to this MRP run
      final runOrders = await db.query('mrp_run_orders', 
        columns: ['orderId'],
        where: 'mrpRunId = ?', 
        whereArgs: [mrpRunId],
      );
      
      // Update each order to PO_SENT
      for (var ro in runOrders) {
        await db.update('orders', {
          'mrpStatus': 'PO_SENT',
        }, where: 'id = ?', whereArgs: [ro['orderId']]);
      }
      
      // Update MRP run status
      await db.update('mrp_runs', {
        'status': 'PO_SENT',
        'completedAt': DateTime.now().toIso8601String(),
      }, where: 'id = ?', whereArgs: [mrpRunId]);
    }
  }

  // =====================================================
  // MRP HARDENING FIXES (Critical for Production)
  // =====================================================

  /// Valid status constants for validation
  static const validOrderMrpStatuses = ['PENDING', 'MRP_DONE', 'PO_SENT', 'CANCELLED'];
  static const validMrpRunStatuses = ['DRAFT', 'MRP_DONE', 'PO_SENT', 'FAILED', 'CANCELLED'];
  static const validMrpOutputStatuses = ['PENDING', 'ALLOCATED', 'PO_SENT', 'CANCELLED'];

  /// Unit normalization - converts to canonical unit
  /// Canonical units: KG for weight, LITRE for volume, NOS for count
  double normalizeToCanonicalUnit(double qty, String fromUnit, String toUnit) {
    if (fromUnit.toLowerCase() == toUnit.toLowerCase()) return qty;
    
    final from = fromUnit.toLowerCase();
    final to = toUnit.toLowerCase();
    
    // Weight conversions (canonical: KG)
    const weightToKg = {
      'g': 0.001,
      'gm': 0.001,
      'gram': 0.001,
      'kg': 1.0,
      'kgs': 1.0,
    };
    
    // Volume conversions (canonical: LITRE)
    const volumeToLitre = {
      'ml': 0.001,
      'l': 1.0,
      'litre': 1.0,
      'liter': 1.0,
    };
    
    // Weight normalization
    if (weightToKg.containsKey(from) && weightToKg.containsKey(to)) {
      return qty * weightToKg[from]! / weightToKg[to]!;
    }
    
    // Volume normalization
    if (volumeToLitre.containsKey(from) && volumeToLitre.containsKey(to)) {
      return qty * volumeToLitre[from]! / volumeToLitre[to]!;
    }
    
    // No conversion possible - return as-is
    return qty;
  }

  /// Round quantity based on ingredient category (called after aggregation)
  double roundByCategory(double qty, String? category) {
    final cat = (category ?? 'other').toLowerCase();
    switch (cat) {
      case 'spices':
      case 'masalas':
      case 'flavoring':
        return double.parse(qty.toStringAsFixed(3)); // 3 decimal places
      case 'vegetables':
      case 'fruits':
      case 'meat':
      case 'seafood':
      case 'grocery':
        return double.parse(qty.toStringAsFixed(2)); // 2 decimal places
      case 'oil':
      case 'liquid':
      case 'dairy':
        return double.parse(qty.toStringAsFixed(3)); // 3 decimal places
      default:
        return double.parse(qty.toStringAsFixed(2)); // Default 2 decimals
    }
  }

  /// Get recipe by dish master ID (preferred over name-based lookup)
  Future<List<Map<String, dynamic>>> getRecipeForDishById(int dishMasterId, int paxQty) async {
    final db = await database;
    
    final dish = await db.query('dish_master',
      columns: ['id', 'base_pax', 'firmId'],
      where: 'id = ?',
      whereArgs: [dishMasterId],
      limit: 1,
    );
    
    if (dish.isEmpty) {
      AppLogger.error('❌ [BOM] Dish ID $dishMasterId not found');
      return [];
    }
    
    final basePax = (dish.first['base_pax'] as int?) ?? 1;
    
    AppLogger.info('🔍 [BOM-ID] Looking up recipe for dish ID: $dishMasterId (pax: $paxQty, basePax: $basePax)');
    
    return db.rawQuery('''
      SELECT rd.*, 
             i.name as ingredientName,
             i.id as ing_id,
             i.category,
             i.unit_of_measure as canonical_unit,
             COALESCE(i.cost_per_unit, 0) as cost_per_unit,
             COALESCE(rd.unit_override, i.unit_of_measure) as unit,
             (rd.quantity_per_base_pax * ? / ?) as scaledQuantity
      FROM recipe_detail rd
      JOIN ingredients_master i ON rd.ing_id = i.id
      WHERE rd.dish_id = ?
      ORDER BY i.category, i.name
    ''', [paxQty, basePax, dishMasterId]);
  }

  /// SAFE Reset for MRP re-run - checks for existing POs first
  /// Returns false if reset is blocked due to active POs
  Future<bool> safeResetOrderForMRP(int orderId) async {
    final db = await database;
    
    // 1. Get order's MRP run ID
    final order = await db.query('orders',
      columns: ['mrpRunId', 'mrpStatus'],
      where: 'id = ?',
      whereArgs: [orderId],
    );
    
    if (order.isEmpty) {
      AppLogger.error('❌ [MRP Reset] Order $orderId not found');
      return false;
    }
    
    final mrpRunId = order.first['mrpRunId'];
    
    if (mrpRunId != null) {
      // 2. Check for active POs (not cancelled)
      final activePOs = await db.query('purchase_orders',
        where: "mrpRunId = ? AND status != 'CANCELLED'",
        whereArgs: [mrpRunId],
      );
      
      if (activePOs.isNotEmpty) {
        AppLogger.error('❌ [MRP Reset] Cannot reset order $orderId - ${activePOs.length} active POs exist');
        return false; // Block reset
      }
      
      // 3. Mark MRP output as CANCELLED (preserve for audit, don't delete)
      await db.update('mrp_output', {
        'allocationStatus': 'CANCELLED',
      }, where: 'mrpRunId = ?', whereArgs: [mrpRunId]);
      
      // 4. Remove link from mrp_run_orders
      await db.delete('mrp_run_orders', 
        where: 'orderId = ?', 
        whereArgs: [orderId]);
    }
    
    // 5. Reset order status
    await db.update('orders', {
      'mrpStatus': 'PENDING',
      'mrpRunId': null,
      'isLocked': 0,
      'lockedAt': null,
    }, where: 'id = ?', whereArgs: [orderId]);
    
    AppLogger.success('✅ [MRP Reset] Order $orderId safely reset for re-run');
    return true;
  }

  /// Cancel order after MRP - marks as CANCELLED with reason
  Future<void> cancelOrderAfterMRP(int orderId, String reason) async {
    final db = await database;
    
    await db.update('orders', {
      'mrpStatus': 'CANCELLED',
      'cancelReason': reason,
      'cancelledAt': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [orderId]);
    
    AppLogger.info('📦 [DB] Cancelled order $orderId after MRP: $reason');
  }

  /// Transaction-wrapped MRP execution for race condition prevention
  /// This is the SAFE way to run MRP - ensures atomicity
  Future<int?> runMrpInTransaction({
    required String firmId,
    required String targetDate,
    required List<int> orderIds,
    required Future<Map<int, Map<String, dynamic>>> Function(List<int> orderIds) calculateOutput,
  }) async {
    final db = await database;
    
    try {
      final result = await db.transaction((txn) async {
        final now = DateTime.now();
        
        // 1. ATOMIC CHECK: Re-verify all orders are still PENDING
        for (var orderId in orderIds) {
          final check = await txn.query('orders',
            columns: ['mrpStatus', 'mrpRunId'],
            where: 'id = ?',
            whereArgs: [orderId],
          );
          
          if (check.isEmpty) {
            throw Exception('Order $orderId not found');
          }
          
          final status = check.first['mrpStatus'];
          final existingRunId = check.first['mrpRunId'];
          
          if (status != null && status != 'PENDING' && existingRunId != null) {
            throw Exception('Order $orderId already processed in run #$existingRunId');
          }
        }
        
        // 2. Create MRP Run
        final monthStart = DateTime(now.year, now.month, 1).toIso8601String().substring(0, 10);
        final monthEnd = DateTime(now.year, now.month + 1, 0).toIso8601String().substring(0, 10);
        
        final existingRuns = await txn.rawQuery('''
          SELECT MAX(runNumber) as maxNum 
          FROM mrp_runs 
          WHERE firmId = ? AND date(runDate) >= date(?) AND date(runDate) <= date(?)
        ''', [firmId, monthStart, monthEnd]);
        
        int runNumber = 1;
        if (existingRuns.isNotEmpty && existingRuns.first['maxNum'] != null) {
          runNumber = (existingRuns.first['maxNum'] as int) + 1;
        }
        
        const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        final runName = '${monthNames[now.month - 1]}-$runNumber';
        
        final mrpRunId = await txn.insert('mrp_runs', {
          'firmId': firmId,
          'runDate': now.toIso8601String(),
          'targetDate': targetDate,
          'status': 'DRAFT',
          'runNumber': runNumber,
          'runName': runName,
          'totalOrders': orderIds.length,
          'createdAt': now.toIso8601String(),
        });
        
        // 3. Link orders to run (with unique constraint protection)
        for (var orderId in orderIds) {
          await txn.insert('mrp_run_orders', {
            'mrpRunId': mrpRunId,
            'orderId': orderId,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
        
        // 4. Calculate output (callback provided by caller)
        final output = await calculateOutput(orderIds);
        
        // 5. Apply rounding and save output
        final batch = txn.batch();
        for (var entry in output.entries) {
          final item = entry.value;
          final category = item['category'] as String?;
          final qty = (item['requiredQty'] as num?)?.toDouble() ?? 0;
          item['requiredQty'] = roundByCategory(qty, category);
          
          batch.insert('mrp_output', {
            'mrpRunId': mrpRunId,
            ...item,
          });
        }
        await batch.commit(noResult: true);
        
        // 6. Lock orders
        final lockNow = now.toIso8601String();
        for (var orderId in orderIds) {
          await txn.update('orders', {
            'mrpRunId': mrpRunId,
            'mrpStatus': 'MRP_DONE',
            'isLocked': 1,
            'lockedAt': lockNow,
          }, where: 'id = ?', whereArgs: [orderId]);
        }
        
        AppLogger.success('✅ [MRP Transaction] Run #$mrpRunId completed for ${orderIds.length} orders');
        return mrpRunId;
      });
      
      // SYNC: Post-transaction sync (outside txn to avoid locking)
      final mrpRunId = result;
        
        // 1. Sync MRP Run
        final runData = await db.query('mrp_runs', where: 'id = ?', whereArgs: [mrpRunId], limit: 1);
        if (runData.isNotEmpty) {
           await _syncOrQueue(table: 'mrp_runs', data: runData.first, action: 'INSERT');
        }
        
        // 2. Sync MRP Run Orders
        final runOrders = await db.query('mrp_run_orders', where: 'mrpRunId = ?', whereArgs: [mrpRunId]);
        for (var ro in runOrders) {
          await _syncOrQueue(table: 'mrp_run_orders', data: ro, action: 'INSERT');
        }
        
        // 3. Sync MRP Output
        final runOutput = await db.query('mrp_output', where: 'mrpRunId = ?', whereArgs: [mrpRunId]);
        for (var out in runOutput) {
          await _syncOrQueue(table: 'mrp_output', data: out, action: 'INSERT');
        }
        
        // 4. Sync Updated Orders status
        for (var orderId in orderIds) {
          await _syncOrQueue(
            table: 'orders', 
            data: {
              'id': orderId,
              'mrpRunId': mrpRunId,
              'mrpStatus': 'MRP_DONE',
              'isLocked': 1,
              'lockedAt': DateTime.now().toIso8601String(), // approx
            }, 
            action: 'UPDATE',
            filters: {'id': orderId}
          );
        }
      return result;
    } catch (e) {
      AppLogger.error('❌ [MRP Transaction] Failed: $e');
      return null;
    }
  }

  Future<int?> createPurchaseOrder(Map<String, dynamic> data) async {
    final cloudSync = CloudSyncService();
    data['createdAt'] = DateTime.now().toIso8601String();
    data['sentAt'] = DateTime.now().toIso8601String();
    data['uuid'] = data['uuid'] ?? _generateUuid();
    final id = await cloudSync.awsFirstWrite(table: 'purchase_orders', data: data);
    AppLogger.success('✅ [PO] Created purchase order #$id (AWS-first)');
    return id;
  }

  Future<void> addPoItems(int poId, List<Map<String, dynamic>> items) async {
    final db = await database;
    final batch = db.batch();
    for (var item in items) {
      batch.insert('po_items', {
        'poId': poId,
        ...item,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getPurchaseOrders(String firmId, {String? status}) async {
    final db = await database;
    String where = 'firmId = ?';
    List<dynamic> args = [firmId];
    if (status != null) {
      where += ' AND status = ?';
      args.add(status);
    }
    return await db.query('purchase_orders',
      where: where,
      whereArgs: args,
      orderBy: 'createdAt DESC',
    );
  }

  // --- TRANSACTIONAL EMAIL HELPERS ---

  Future<Map<String, dynamic>?> getSupplierById(int id) async {
    final db = await database;
    final res = await db.query('suppliers', where: 'id = ?', whereArgs: [id]);
    if (res.isNotEmpty) return res.first;
    return null;
  }

  Future<List<Map<String, dynamic>>> getPoItems(int poId) async {
    final db = await database;
    return await db.query('po_items', where: 'poId = ?', whereArgs: [poId]);
  }

  /// Get purchase orders for a specific MRP run (for Allotment Screen Summary)
  Future<List<Map<String, dynamic>>> getPurchaseOrdersByMrpRun(int mrpRunId) async {
    final db = await database;
    return await db.query('purchase_orders',
      where: 'mrpRunId = ?',
      whereArgs: [mrpRunId],
      orderBy: 'createdAt DESC',
    );
  }

  Future<int> updatePoStatus(int poId, String status) async {
    final db = await database;
    final statusTimeField = {
      'ACCEPTED': 'acceptedAt',
      'DISPATCHED': 'dispatchedAt',
      'DELIVERED': 'deliveredAt',
    };
    final updateData = <String, dynamic>{'status': status};
    if (statusTimeField.containsKey(status)) {
      updateData[statusTimeField[status]!] = DateTime.now().toIso8601String();
    }
    return await db.update('purchase_orders', updateData, where: 'id = ?', whereArgs: [poId]);
  }

  // --- INVOICES (v35: Full Invoice Management) ---
  
  /// Generate invoice number in format: inv-YYYY-MM-NNN
  Future<String> generateInvoiceNumber(String firmId) async {
    final db = await database;
    final now = DateTime.now();
    final yearMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final prefix = 'inv-$yearMonth-';
    
    final countResult = await db.rawQuery(
      "SELECT COUNT(*) as cnt FROM invoices WHERE firmId = ? AND invoiceNumber LIKE ?",
      [firmId, '$prefix%'],
    );
    final count = (countResult.first['cnt'] as int?) ?? 0;
    return '$prefix${(count + 1).toString().padLeft(3, '0')}';
  }

  /// Create invoice with items (returns invoice ID)
  Future<int?> insertInvoice(Map<String, dynamic> data, {List<Map<String, dynamic>>? items}) async {
    final cloudSync = CloudSyncService();
    final now = DateTime.now().toIso8601String();
    data['createdAt'] = now;
    data['updatedAt'] = now;
    data['uuid'] = data['uuid'] ?? _generateUuid();
    
    // Auto-generate invoice number if not provided
    if (data['invoiceNumber'] == null) {
      data['invoiceNumber'] = await generateInvoiceNumber(data['firmId']);
    }
    
    // Calculate due date (invoice date + 7 days)
    if (data['dueDate'] == null && data['invoiceDate'] != null) {
      final invoiceDate = DateTime.parse(data['invoiceDate']);
      data['dueDate'] = invoiceDate.add(const Duration(days: 7)).toIso8601String().substring(0, 10);
    }
    
    // Calculate balance due
    data['balanceDue'] = (data['totalAmount'] ?? 0) - (data['amountPaid'] ?? 0);
    
    // AWS-First: Write invoice to cloud first
    final invoiceId = await cloudSync.awsFirstWrite(table: 'invoices', data: data);
    
    if (invoiceId == null) {
      AppLogger.error('❌ [Invoice] Failed to create invoice');
      return null;
    }
    
    // Insert items if provided
    if (items != null && items.isNotEmpty) {
      await insertInvoiceItems(invoiceId, items);
    }
    
    AppLogger.success('✅ [Invoice] Created invoice #$invoiceId (AWS-first)');
    return invoiceId;
  }

  /// Insert invoice line items
  Future<void> insertInvoiceItems(int invoiceId, List<Map<String, dynamic>> items) async {
    final db = await database;
    final batch = db.batch();
    for (var item in items) {
      item['invoiceId'] = invoiceId;
      // Calculate item totals
      final qty = (item['quantity'] ?? 1) as num;
      final rate = (item['rate'] ?? 0) as num;
      final amount = qty * rate;
      final gstRate = (item['gstRate'] ?? 18) as num;
      final gstAmount = amount * gstRate / 100;
      
      // For now, assume intra-state (CGST+SGST). TODO: Add state logic for IGST
      item['amount'] = amount;
      item['cgst'] = gstAmount / 2;
      item['sgst'] = gstAmount / 2;
      item['igst'] = 0;
      item['totalAmount'] = amount + gstAmount;
      item['uuid'] = item['uuid'] ?? _generateUuid();
      
      batch.insert('invoice_items', item);
    }
    await batch.commit(noResult: true);
  }

  /// Get all invoices with optional filters
  Future<List<Map<String, dynamic>>> getInvoices(String firmId, {
    String? status,
    String? startDate,
    String? endDate,
    int? customerId,
  }) async {
    final db = await database;
    String where = 'firmId = ?';
    List<dynamic> args = [firmId];
    
    if (status != null) {
      where += ' AND status = ?';
      args.add(status);
    }
    if (startDate != null && endDate != null) {
      where += ' AND invoiceDate BETWEEN ? AND ?';
      args.addAll([startDate, endDate]);
    }
    if (customerId != null) {
      where += ' AND customerId = ?';
      args.add(customerId);
    }
    
    return await db.query('invoices',
      where: where,
      whereArgs: args,
      orderBy: 'invoiceDate DESC, id DESC',
    );
  }

  /// Get invoice with items
  Future<Map<String, dynamic>?> getInvoiceWithItems(int invoiceId) async {
    final db = await database;
    final invoices = await db.query('invoices', where: 'id = ?', whereArgs: [invoiceId]);
    if (invoices.isEmpty) return null;
    
    final items = await db.query('invoice_items', where: 'invoiceId = ?', whereArgs: [invoiceId]);
    return {
      ...invoices.first,
      'items': items,
    };
  }

  /// Update invoice
  Future<bool> updateInvoice(int id, Map<String, dynamic> data) async {
    final db = await database;
    final cloudSync = CloudSyncService();
    data['id'] = id;
    data['updatedAt'] = DateTime.now().toIso8601String();
    
    // Recalculate balance due if payment updated
    if (data.containsKey('amountPaid')) {
      final invoice = await db.query('invoices', where: 'id = ?', whereArgs: [id]);
      if (invoice.isNotEmpty) {
        final totalAmount = (invoice.first['totalAmount'] as num?) ?? 0;
        final amountPaid = (data['amountPaid'] as num?) ?? 0;
        data['balanceDue'] = totalAmount - amountPaid;
        
        // Auto-update status based on payment
        if (amountPaid >= totalAmount) {
          data['status'] = 'PAID';
        } else if (amountPaid > 0) {
          data['status'] = 'PARTIAL';
        }
      }
    }
    
    final success = await cloudSync.awsFirstUpdate(table: 'invoices', recordId: id, data: data);
    AppLogger.success('✅ [Invoice] Updated invoice #$id (AWS-first)');
    return success;
  }

  /// Record payment against invoice and create transaction
  Future<void> recordInvoicePayment(int invoiceId, double amount, String paymentMode, {String? notes}) async {
    final db = await database;
    final invoice = await db.query('invoices', where: 'id = ?', whereArgs: [invoiceId]);
    if (invoice.isEmpty) return;
    
    final inv = invoice.first;
    final currentPaid = (inv['amountPaid'] as num?) ?? 0;
    final newPaid = currentPaid + amount;
    
    // Update invoice
    await updateInvoice(invoiceId, {
      'amountPaid': newPaid,
      'paymentMode': paymentMode,
    });
    
    // Create income transaction
    await insertTransaction({
      'firmId': inv['firmId'],
      'date': DateTime.now().toIso8601String().substring(0, 10),
      'type': 'INCOME',
      'amount': amount,
      'category': 'Invoice Payment',
      'description': 'Payment for ${inv['invoiceNumber']}${notes != null ? ' - $notes' : ''}',
      'mode': paymentMode,
      'relatedEntityType': 'INVOICE',
      'relatedEntityId': invoiceId,
      'partyName': inv['customerName'],
    });
  }

  /// Generate invoice from order
  /// Returns invoice ID
  Future<int?> createInvoiceFromOrder(int orderId, String firmId) async {
    final db = await database;
    
    // Get order details
    final orders = await db.query('orders', where: 'id = ?', whereArgs: [orderId]);
    if (orders.isEmpty) throw Exception('Order not found');
    final order = orders.first;
    
    // Get order dishes
    final dishes = await db.query('dishes', where: 'orderId = ?', whereArgs: [orderId]);
    
    // Get customer details
    final customerId = order['customerId'] as int? ?? 0;
    Map<String, dynamic>? customer;
    if (customerId > 0) {
      final customers = await db.query('customers', where: 'id = ?', whereArgs: [customerId]);
      if (customers.isNotEmpty) customer = customers.first;
    }
    
    // Calculate totals
    double subtotal = 0;
    List<Map<String, dynamic>> items = [];
    
    for (var dish in dishes) {
      final pax = (dish['pax'] as int?) ?? 1;
      final rate = (dish['pricePerPlate'] as num?) ?? 0;
      final amount = pax * rate;
      subtotal += amount;
      
      items.add({
        'description': dish['dishName'] ?? 'Item',
        'quantity': pax,
        'unit': 'plates',
        'rate': rate,
        'gstRate': 5, // Food is typically 5% GST
        'hsnCode': '996331', // Catering services HSN code
      });
    }
    
    // Calculate GST (assuming intra-state for now)
    final gstRate = 0.05; // 5% for catering
    final gstAmount = subtotal * gstRate;
    final totalAmount = subtotal + gstAmount;
    
    // Create invoice - logic handled inside insertInvoice (including AWS sync first)
    final invoiceId = await insertInvoice({
      'firmId': firmId,
      'orderId': orderId,
      'customerId': customerId,
      'customerName': order['customerName'] ?? customer?['name'] ?? 'Customer',
      'customerAddress': customer?['address'],
      'customerMobile': order['mobile'] ?? customer?['mobile'],
      'customerGstin': customer?['gstin'],
      'invoiceDate': DateTime.now().toIso8601String().substring(0, 10),
      'subtotal': subtotal,
      'cgst': gstAmount / 2,
      'sgst': gstAmount / 2,
      'igst': 0,
      'totalAmount': totalAmount,
      'amountPaid': (order['advanceAmount'] as num?) ?? 0,
      'status': 'UNPAID',
      'notes': 'Event: ${order['date']} at ${order['location'] ?? 'Venue'}',
    }, items: items);

    return invoiceId;
  }

  // --- ACCOUNTS RECEIVABLE (AR) ---
  
  /// Get customer outstanding balance
  Future<double> getCustomerOutstanding(int customerId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(balanceDue), 0) as outstanding
      FROM invoices
      WHERE customerId = ? AND status != 'PAID' AND status != 'CANCELLED'
    ''', [customerId]);
    return (result.first['outstanding'] as num?)?.toDouble() ?? 0;
  }

  /// Get total AR for firm
  Future<double> getTotalAR(String firmId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(balanceDue), 0) as totalAR
      FROM invoices
      WHERE firmId = ? AND status != 'PAID' AND status != 'CANCELLED'
    ''', [firmId]);
    return (result.first['totalAR'] as num?)?.toDouble() ?? 0;
  }

  /// Get AR aging report (30/60/90 days)
  Future<Map<String, dynamic>> getARAgingReport(String firmId) async {
    final db = await database;
    final now = DateTime.now();
    final today = now.toIso8601String().substring(0, 10);
    final days30 = now.subtract(const Duration(days: 30)).toIso8601String().substring(0, 10);
    final days60 = now.subtract(const Duration(days: 60)).toIso8601String().substring(0, 10);
    
    final result = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(CASE WHEN dueDate >= ? THEN balanceDue ELSE 0 END), 0) as current,
        COALESCE(SUM(CASE WHEN dueDate < ? AND dueDate >= ? THEN balanceDue ELSE 0 END), 0) as days30,
        COALESCE(SUM(CASE WHEN dueDate < ? AND dueDate >= ? THEN balanceDue ELSE 0 END), 0) as days60,
        COALESCE(SUM(CASE WHEN dueDate < ? THEN balanceDue ELSE 0 END), 0) as days90Plus
      FROM invoices
      WHERE firmId = ? AND status != 'PAID' AND status != 'CANCELLED'
    ''', [today, today, days30, days30, days60, days60, firmId]);
    
    // Get customer-wise breakdown
    final customers = await db.rawQuery('''
      SELECT customerId, customerName, 
             SUM(balanceDue) as outstanding,
             MIN(dueDate) as oldestDue
      FROM invoices
      WHERE firmId = ? AND status != 'PAID' AND status != 'CANCELLED'
      GROUP BY customerId
      ORDER BY outstanding DESC
    ''', [firmId]);
    
    return {
      'summary': result.isNotEmpty ? result.first : {},
      'customers': customers,
    };
  }

  // --- ACCOUNTS PAYABLE (AP) ---
  
  /// Get supplier outstanding (PO total - payments made)
  Future<double> getSupplierOutstanding(int supplierId, String firmId) async {
    final db = await database;
    
    // Total PO value
    final poTotal = await db.rawQuery('''
      SELECT COALESCE(SUM(totalAmount), 0) as total
      FROM purchase_orders
      WHERE vendorId = ? AND firmId = ? AND status != 'CANCELLED'
    ''', [supplierId, firmId]);
    
    // Total payments made (from transactions)
    final payments = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM transactions
      WHERE relatedEntityType = 'SUPPLIER' AND relatedEntityId = ? AND type = 'EXPENSE'
    ''', [supplierId]);
    
    final po = (poTotal.first['total'] as num?)?.toDouble() ?? 0;
    final paid = (payments.first['total'] as num?)?.toDouble() ?? 0;
    
    return po - paid;
  }

  /// Get total AP for firm
  Future<double> getTotalAP(String firmId) async {
    final suppliers = await getAllSuppliers(firmId);
    double totalAP = 0;
    
    for (var supplier in suppliers) {
      totalAP += await getSupplierOutstanding(supplier['id'] as int, firmId);
    }
    return totalAP;
  }

  // --- PROFIT & LOSS ---
  
  /// Get P&L summary with expense grouping
  Future<Map<String, dynamic>> getProfitLossSummary(String firmId, String startDate, String endDate) async {
    final db = await database;
    
    // Income by category
    final income = await db.rawQuery('''
      SELECT category, COALESCE(SUM(amount), 0) as total
      FROM transactions
      WHERE firmId = ? AND type = 'INCOME' AND date BETWEEN ? AND ?
      GROUP BY category
      ORDER BY total DESC
    ''', [firmId, startDate, endDate]);
    
    // Expenses by standard P&L categories
    final expenses = await db.rawQuery('''
      SELECT 
        CASE 
          WHEN category IN ('Raw Materials', 'Ingredients', 'Groceries', 'Supplies', 'Purchase') THEN 'Raw Materials'
          WHEN category IN ('Salary', 'Wages', 'Overtime', 'Advance', 'Staff Payment') THEN 'Staff Costs'
          WHEN category IN ('Transport', 'Fuel', 'Vehicle', 'Driver', 'Logistics') THEN 'Transport'
          WHEN category IN ('Subcontract', 'Outsourcing', 'External Catering') THEN 'Subcontracting'
          WHEN category IN ('Rent', 'Electricity', 'Gas', 'Water', 'Utilities') THEN 'Utilities'
          WHEN category IN ('Marketing', 'Advertising', 'Promotion') THEN 'Marketing'
          ELSE 'Other'
        END as expenseGroup,
        COALESCE(SUM(amount), 0) as total
      FROM transactions
      WHERE firmId = ? AND type = 'EXPENSE' AND date BETWEEN ? AND ?
      GROUP BY expenseGroup
      ORDER BY total DESC
    ''', [firmId, startDate, endDate]);
    
    // Calculate totals
    double totalIncome = 0;
    for (var i in income) {
      totalIncome += (i['total'] as num?)?.toDouble() ?? 0;
    }
    
    double totalExpense = 0;
    for (var e in expenses) {
      totalExpense += (e['total'] as num?)?.toDouble() ?? 0;
    }
    
    return {
      'income': income,
      'expenses': expenses,
      'totalIncome': totalIncome,
      'totalExpense': totalExpense,
      'netProfit': totalIncome - totalExpense,
      'profitMargin': totalIncome > 0 ? ((totalIncome - totalExpense) / totalIncome * 100) : 0,
    };
  }

  // --- BALANCE SHEET (Simplified) ---
  
  /// Get simplified Balance Sheet data as of a specific date
  /// Assets: Cash, AR, Inventory
  /// Liabilities: AP, GST Payable
  Future<Map<String, dynamic>> getBalanceSheetData(String firmId, String asOfDate) async {
    final db = await database;
    
    // ASSETS
    
    // 1. Cash: Net of all income - expenses up to asOfDate
    final cashResult = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(CASE WHEN type = 'INCOME' THEN amount ELSE 0 END), 0) -
        COALESCE(SUM(CASE WHEN type = 'EXPENSE' THEN amount ELSE 0 END), 0) as cash
      FROM transactions
      WHERE firmId = ? AND date <= ?
    ''', [firmId, asOfDate]);
    final cash = (cashResult.first['cash'] as num?)?.toDouble() ?? 0;
    
    // 2. Accounts Receivable: Unpaid invoices
    final ar = await getTotalAR(firmId);
    
    // 3. Inventory: Sum of (stock * rate) from ingredients
    final inventoryResult = await db.rawQuery('''
      SELECT COALESCE(SUM(stock * rate), 0) as inventory
      FROM ingredients
      WHERE firmId = ?
    ''', [firmId]);
    final inventory = (inventoryResult.first['inventory'] as num?)?.toDouble() ?? 0;
    
    final totalAssets = cash + ar + inventory;
    
    // LIABILITIES
    
    // 1. Accounts Payable: Outstanding supplier balances
    final ap = await getTotalAP(firmId);
    
    // 2. GST Payable: GST from unpaid invoices
    final gstResult = await db.rawQuery('''
      SELECT COALESCE(SUM(cgst + sgst + igst), 0) as gstPayable
      FROM invoices
      WHERE firmId = ? AND status != 'PAID' AND status != 'CANCELLED'
    ''', [firmId]);
    final gstPayable = (gstResult.first['gstPayable'] as num?)?.toDouble() ?? 0;
    
    final totalLiabilities = ap + gstPayable;
    
    // NET WORTH
    final netWorth = totalAssets - totalLiabilities;
    
    return {
      'asOfDate': asOfDate,
      'assets': {
        'cash': cash,
        'accountsReceivable': ar,
        'inventory': inventory,
        'total': totalAssets,
      },
      'liabilities': {
        'accountsPayable': ap,
        'gstPayable': gstPayable,
        'total': totalLiabilities,
      },
      'netWorth': netWorth,
    };
  }

  // --- CASH FLOW STATEMENT (Operating Only) ---
  
  /// Get operating cash flow for a period
  Future<Map<String, dynamic>> getCashFlowData(String firmId, String startDate, String endDate) async {
    final db = await database;
    
    // Opening Balance: Cash as of day before startDate
    final openingDate = DateTime.parse(startDate).subtract(const Duration(days: 1));
    final openingDateStr = openingDate.toIso8601String().substring(0, 10);
    
    final openingResult = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(CASE WHEN type = 'INCOME' THEN amount ELSE 0 END), 0) -
        COALESCE(SUM(CASE WHEN type = 'EXPENSE' THEN amount ELSE 0 END), 0) as balance
      FROM transactions
      WHERE firmId = ? AND date <= ?
    ''', [firmId, openingDateStr]);
    final openingBalance = (openingResult.first['balance'] as num?)?.toDouble() ?? 0;
    
    // Cash Inflows (by category)
    final inflows = await db.rawQuery('''
      SELECT category, COALESCE(SUM(amount), 0) as total
      FROM transactions
      WHERE firmId = ? AND type = 'INCOME' AND date BETWEEN ? AND ?
      GROUP BY category
      ORDER BY total DESC
    ''', [firmId, startDate, endDate]);
    
    double totalInflow = 0;
    for (var i in inflows) {
      totalInflow += (i['total'] as num?)?.toDouble() ?? 0;
    }
    
    // Cash Outflows (grouped by P&L categories)
    final outflows = await db.rawQuery('''
      SELECT 
        CASE 
          WHEN category IN ('Raw Materials', 'Ingredients', 'Groceries', 'Supplies', 'Purchase') THEN 'Supplier Payments'
          WHEN category IN ('Salary', 'Wages', 'Overtime', 'Advance', 'Staff Payment') THEN 'Staff Payments'
          WHEN category IN ('Transport', 'Fuel', 'Vehicle', 'Driver', 'Logistics') THEN 'Transport'
          WHEN category IN ('Rent', 'Electricity', 'Gas', 'Water', 'Utilities') THEN 'Utilities'
          ELSE 'Other Operating'
        END as expenseGroup,
        COALESCE(SUM(amount), 0) as total
      FROM transactions
      WHERE firmId = ? AND type = 'EXPENSE' AND date BETWEEN ? AND ?
      GROUP BY expenseGroup
      ORDER BY total DESC
    ''', [firmId, startDate, endDate]);
    
    double totalOutflow = 0;
    for (var o in outflows) {
      totalOutflow += (o['total'] as num?)?.toDouble() ?? 0;
    }
    
    // Net Cash Flow
    final netCashFlow = totalInflow - totalOutflow;
    
    // Closing Balance
    final closingBalance = openingBalance + netCashFlow;
    
    return {
      'period': {'start': startDate, 'end': endDate},
      'openingBalance': openingBalance,
      'inflows': inflows,
      'totalInflow': totalInflow,
      'outflows': outflows,
      'totalOutflow': totalOutflow,
      'netCashFlow': netCashFlow,
      'closingBalance': closingBalance,
    };
  }

  // --- KPI DASHBOARD DATA ---
  
  /// Get KPI data for dashboard (Revenue, Margin, Order Count, Avg Order Value)
  Future<Map<String, dynamic>> getKPIData(String firmId, String startDate, String endDate) async {
    final db = await database;
    
    // Revenue (total income)
    final revenueResult = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as revenue
      FROM transactions
      WHERE firmId = ? AND type = 'INCOME' AND date BETWEEN ? AND ?
    ''', [firmId, startDate, endDate]);
    final revenue = (revenueResult.first['revenue'] as num?)?.toDouble() ?? 0;
    
    // COGS (Raw Materials expenses)
    final cogsResult = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as cogs
      FROM transactions
      WHERE firmId = ? AND type = 'EXPENSE' AND date BETWEEN ? AND ?
        AND category IN ('Raw Materials', 'Ingredients', 'Groceries', 'Supplies', 'Purchase')
    ''', [firmId, startDate, endDate]);
    final cogs = (cogsResult.first['cogs'] as num?)?.toDouble() ?? 0;
    
    // Gross Margin
    final grossProfit = revenue - cogs;
    final grossMargin = revenue > 0 ? (grossProfit / revenue * 100) : 0;
    
    // Order Count
    final orderResult = await db.rawQuery('''
      SELECT COUNT(*) as orderCount, COALESCE(SUM(totalPax), 0) as totalPax
      FROM orders
      WHERE firmId = ? AND date BETWEEN ? AND ? AND status != 'CANCELLED'
    ''', [firmId, startDate, endDate]);
    final orderCount = (orderResult.first['orderCount'] as num?)?.toInt() ?? 0;
    final totalPax = (orderResult.first['totalPax'] as num?)?.toInt() ?? 0;
    
    // Average Order Value
    final avgOrderValue = orderCount > 0 ? revenue / orderCount : 0;
    
    return {
      'period': {'start': startDate, 'end': endDate},
      'revenue': revenue,
      'cogs': cogs,
      'grossProfit': grossProfit,
      'grossMargin': grossMargin,
      'orderCount': orderCount,
      'totalPax': totalPax,
      'avgOrderValue': avgOrderValue,
    };
  }
  
  /// Get KPI comparison data (current vs previous period)
  Future<Map<String, dynamic>> getKPIComparison(String firmId, String startDate, String endDate) async {
    final current = await getKPIData(firmId, startDate, endDate);
    
    // Calculate previous period (same duration before startDate)
    final start = DateTime.parse(startDate);
    final end = DateTime.parse(endDate);
    final duration = end.difference(start);
    final prevStart = start.subtract(duration).subtract(const Duration(days: 1));
    final prevEnd = start.subtract(const Duration(days: 1));
    
    final previous = await getKPIData(
      firmId, 
      prevStart.toIso8601String().substring(0, 10),
      prevEnd.toIso8601String().substring(0, 10),
    );
    
    // Calculate change percentages
    double calcChange(double current, double previous) {
      if (previous == 0) return current > 0 ? 100 : 0;
      return ((current - previous) / previous * 100);
    }
    
    return {
      'current': current,
      'previous': previous,
      'changes': {
        'revenue': calcChange(current['revenue'] as double, previous['revenue'] as double),
        'grossMargin': (current['grossMargin'] as double) - (previous['grossMargin'] as double),
        'orderCount': calcChange((current['orderCount'] as int).toDouble(), (previous['orderCount'] as int).toDouble()),
        'avgOrderValue': calcChange(current['avgOrderValue'] as double, previous['avgOrderValue'] as double),
      },
    };
  }

  /// Get daily profitability trend (Revenue, Cost, Expense)
  Future<List<Map<String, dynamic>>> getProfitabilityTrend(String firmId, String startDate, String endDate) async {
    final db = await database;
    
    // Get daily income
    final incomeTrend = await db.rawQuery('''
      SELECT date, COALESCE(SUM(amount), 0) as income
      FROM transactions
      WHERE firmId = ? AND type = 'INCOME' AND date BETWEEN ? AND ?
      GROUP BY date
      ORDER BY date
    ''', [firmId, startDate, endDate]);
    
    // Get daily material costs (COGS categories)
    final cogsTrend = await db.rawQuery('''
      SELECT date, COALESCE(SUM(amount), 0) as cost
      FROM transactions
      WHERE firmId = ? AND type = 'EXPENSE' AND date BETWEEN ? AND ?
        AND category IN ('Raw Materials', 'Ingredients', 'Groceries', 'Supplies', 'Purchase')
      GROUP BY date
      ORDER BY date
    ''', [firmId, startDate, endDate]);
    
    // Get daily other expenses
    final expenseTrend = await db.rawQuery('''
      SELECT date, COALESCE(SUM(amount), 0) as expense
      FROM transactions
      WHERE firmId = ? AND type = 'EXPENSE' AND date BETWEEN ? AND ?
        AND category NOT IN ('Raw Materials', 'Ingredients', 'Groceries', 'Supplies', 'Purchase')
      GROUP BY date
      ORDER BY date
    ''', [firmId, startDate, endDate]);
    
    // Merge into a single timeline
    final Map<String, Map<String, double>> timeline = {};
    
    for (var row in incomeTrend) {
      final date = row['date'] as String;
      timeline[date] = timeline[date] ?? {'income': 0, 'cost': 0, 'expense': 0};
      timeline[date]!['income'] = (row['income'] as num).toDouble();
    }
    
    for (var row in cogsTrend) {
      final date = row['date'] as String;
      timeline[date] = timeline[date] ?? {'income': 0, 'cost': 0, 'expense': 0};
      timeline[date]!['cost'] = (row['cost'] as num).toDouble();
    }
    
    for (var row in expenseTrend) {
      final date = row['date'] as String;
      timeline[date] = timeline[date] ?? {'income': 0, 'cost': 0, 'expense': 0};
      timeline[date]!['expense'] = (row['expense'] as num).toDouble();
    }
    
    final sortedDates = timeline.keys.toList()..sort();
    return sortedDates.map((date) => {
      'date': date,
      'income': timeline[date]!['income'],
      'cost': timeline[date]!['cost'],
      'expense': timeline[date]!['expense'],
      'profit': timeline[date]!['income']! - (timeline[date]!['cost']! + timeline[date]!['expense']!),
    }).toList();
  }

  /// Get expense breakdown by category group
  Future<List<Map<String, dynamic>>> getExpenseBreakdown(String firmId, String startDate, String endDate) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        CASE 
          WHEN category IN ('Raw Materials', 'Ingredients', 'Groceries', 'Supplies', 'Purchase') THEN 'Materials'
          WHEN category IN ('Salary', 'Wages', 'Overtime', 'Advance', 'Staff Payment') THEN 'Staff'
          WHEN category IN ('Transport', 'Fuel', 'Vehicle', 'Driver', 'Logistics') THEN 'Logistics'
          WHEN category IN ('Rent', 'Electricity', 'Gas', 'Water', 'Utilities') THEN 'Utilities'
          ELSE 'Other'
        END as groupName,
        COALESCE(SUM(amount), 0) as total
      FROM transactions
      WHERE firmId = ? AND type = 'EXPENSE' AND date BETWEEN ? AND ?
      GROUP BY groupName
      ORDER BY total DESC
    ''', [firmId, startDate, endDate]);
  }

  /// Get event/order profitability



  // ============== (Migrated to FinanceRepository) ==============
  


  // --- MRP RE-RUN SUPPORT ---
  
  /// Cancel all POs for a specific order (soft-delete with status = 'CANCELLED')
/// Returns list of cancelled PO IDs for notification purposes
Future<List<Map<String, dynamic>>> cancelPOsForOrder(int orderId) async {
  final db = await database;
  final cloudSync = CloudSyncService();
  
  // Find all POs that include this order
  final allPOs = await db.query('purchase_orders');
  final cancelledPOs = <Map<String, dynamic>>[];
  
  for (final po in allPOs) {
    final orderIds = po['orderIds']?.toString() ?? '';
    if (orderIds.split(',').map((s) => s.trim()).contains(orderId.toString())) {
      // Skip already cancelled POs
      if (po['status'] == 'CANCELLED') continue;
      
      final poId = po['id'] as int;
      final updates = {
        'id': poId,
        'status': 'CANCELLED',
        'cancelledAt': DateTime.now().toIso8601String(),
        'cancelReason': 'Order updated - MRP re-run required',
      };
      await cloudSync.awsFirstUpdate(table: 'purchase_orders', recordId: poId, data: updates);
      
      cancelledPOs.add(po);
    }
  }
  
  AppLogger.info('📦 [DB] Cancelled ${cancelledPOs.length} POs for order $orderId (AWS-first)');
  return cancelledPOs;
}

/// Reset order MRP status to allow re-running MRP
Future<void> resetOrderForMRP(int orderId) async {
  final cloudSync = CloudSyncService();
  
  final updates = {
    'id': orderId,
    'mrpStatus': 'PENDING',
    'mrpRunId': null,
    'isLocked': 0,
    'lockedAt': null,
  };
  await cloudSync.awsFirstUpdate(table: 'orders', recordId: orderId, data: updates);
  
  AppLogger.info('📦 [DB] Reset order $orderId for MRP re-run (AWS-first)');
}

  /// Get all POs for an order (both active and cancelled) for history view
  Future<List<Map<String, dynamic>>> getPurchaseOrdersForOrder(int orderId) async {
    final db = await database;
    final allPOs = await db.query('purchase_orders', orderBy: 'createdAt DESC');
    
    return allPOs.where((po) {
      final orderIds = po['orderIds']?.toString() ?? '';
      return orderIds.split(',').map((s) => s.trim()).contains(orderId.toString());
    }).toList();
  }

  // =====================================================
  // DRIVER PORTAL HELPERS (v34)
  // =====================================================

  /// Get pending dispatch assignments for a driver
  Future<List<Map<String, dynamic>>> getDriverPendingAssignments(int driverId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT d.*, o.customerName, o.location, o.date, o.time, o.totalPax, o.mobile as customerMobile,
             (SELECT COUNT(*) FROM dishes WHERE orderId = o.id) as dishCount
      FROM dispatches d
      JOIN orders o ON o.id = d.orderId
      WHERE d.driverId = ? AND d.assignmentStatus = 'PENDING'
      ORDER BY o.date ASC, o.time ASC
    ''', [driverId]);
  }

  /// Get driver's active dispatch (in progress)
  Future<Map<String, dynamic>?> getDriverActiveDispatch(int driverId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT d.*, o.customerName, o.location, o.date, o.time, o.totalPax, o.mobile as customerMobile,
                 v.vehicleNumber, v.vehicleType
      FROM dispatches d
      JOIN orders o ON o.id = d.orderId
      LEFT JOIN vehicles v ON v.id = d.vehicleId
      WHERE d.driverId = ? AND d.assignmentStatus = 'ACCEPTED' 
        AND d.dispatchStatus IN ('PENDING', 'LOADING', 'DISPATCHED', 'DELIVERED')
      ORDER BY d.dispatchTime DESC
      LIMIT 1
    ''', [driverId]);
    return result.isNotEmpty ? result.first : null;
  }

  /// Update dispatch assignment status (accept/reject)
  Future<void> updateDispatchAssignment(int dispatchId, String status, {String? rejectionReason}) async {
    final cloudSync = CloudSyncService();
    final now = DateTime.now().toIso8601String();
    
    Map<String, dynamic> updates = {'id': dispatchId, 'assignmentStatus': status};
    if (status == 'ACCEPTED') {
      updates['acceptedAt'] = now;
    } else if (status == 'REJECTED') {
      updates['rejectedAt'] = now;
      updates['rejectionReason'] = rejectionReason;
      updates['driverId'] = null; // Unassign so admin can reassign
    }
    
    await cloudSync.awsFirstUpdate(table: 'dispatches', recordId: dispatchId, data: updates);
    AppLogger.success('✅ [Dispatch] Updated assignment #$dispatchId to $status (AWS-first)');
  }

  /// Update dispatch km tracking and earnings
  Future<void> updateDispatchKmAndEarnings(int dispatchId, {
    double? kmForward,
    double? kmReturn,
    double? driverShare,
  }) async {
    final cloudSync = CloudSyncService();
    Map<String, dynamic> updates = {'id': dispatchId, 'updatedAt': DateTime.now().toIso8601String()};
    if (kmForward != null) updates['kmForward'] = kmForward;
    if (kmReturn != null) updates['kmReturn'] = kmReturn;
    if (driverShare != null) updates['driverShare'] = driverShare;
    
    await cloudSync.awsFirstUpdate(table: 'dispatches', recordId: dispatchId, data: updates);
    AppLogger.success('✅ [Dispatch] Updated km/earnings for #$dispatchId (AWS-first)');
  }

  /// Get driver earnings report for date range
  Future<Map<String, dynamic>> getDriverEarningsReport(int driverId, String startDate, String endDate) async {
    final db = await database;
    
    final summary = await db.rawQuery('''
      SELECT 
        COUNT(*) as tripCount,
        COALESCE(SUM(kmForward), 0) as totalKmForward,
        COALESCE(SUM(kmReturn), 0) as totalKmReturn,
        COALESCE(SUM(driverShare), 0) as totalEarnings,
        SUM(CASE WHEN isPaid = 1 THEN driverShare ELSE 0 END) as paidAmount,
        SUM(CASE WHEN isPaid = 0 THEN driverShare ELSE 0 END) as pendingAmount
      FROM dispatches
      WHERE driverId = ? AND DATE(dispatchTime) BETWEEN ? AND ?
        AND dispatchStatus IN ('DELIVERED', 'COMPLETED', 'RETURNING')
    ''', [driverId, startDate, endDate]);
    
    final trips = await db.rawQuery('''
      SELECT d.*, o.customerName, o.location, o.date, o.time
      FROM dispatches d
      JOIN orders o ON o.id = d.orderId
      WHERE d.driverId = ? AND DATE(d.dispatchTime) BETWEEN ? AND ?
        AND d.dispatchStatus IN ('DELIVERED', 'COMPLETED', 'RETURNING')
      ORDER BY d.dispatchTime DESC
    ''', [driverId, startDate, endDate]);
    
    return {
      'summary': summary.isNotEmpty ? summary.first : {},
      'trips': trips,
    };
  }

  // =====================================================
  // SUBCONTRACTOR PORTAL HELPERS (v34)
  // =====================================================

  /// Get orders assigned to subcontractor for a date
  Future<List<Map<String, dynamic>>> getSubcontractorOrders(int subcontractorId, String date) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT DISTINCT o.*, 
             (SELECT SUM(d2.pax) FROM dishes d2 WHERE d2.orderId = o.id AND d2.isSubcontracted = 1 AND d2.subcontractorId = ?) as assignedPax,
             (SELECT COUNT(*) FROM dishes d3 WHERE d3.orderId = o.id AND d3.isSubcontracted = 1 AND d3.subcontractorId = ?) as dishCount
      FROM orders o
      JOIN dishes d ON d.orderId = o.id
      WHERE d.isSubcontracted = 1 AND d.subcontractorId = ? AND o.date = ?
      ORDER BY o.time ASC
    ''', [subcontractorId, subcontractorId, subcontractorId, date]);
  }

  /// Get dishes assigned to subcontractor for an order
  Future<List<Map<String, dynamic>>> getSubcontractorDishes(int subcontractorId, int orderId) async {
    final db = await database;
    return await db.query('dishes',
      where: 'orderId = ? AND isSubcontracted = 1 AND subcontractorId = ?',
      whereArgs: [orderId, subcontractorId],
    );
  }

  /// Get subcontractor ledger transactions
  Future<List<Map<String, dynamic>>> getSubcontractorLedger(String subcontractorName, String startDate, String endDate) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT * FROM finance
      WHERE partyName LIKE ? AND date BETWEEN ? AND ?
      ORDER BY date DESC
    ''', ['%$subcontractorName%', startDate, endDate]);
  }

  // =====================================================
  // SUPPLIER PORTAL HELPERS (v34)
  // =====================================================

  /// Get purchase orders for supplier by status
  Future<List<Map<String, dynamic>>> getSupplierPOs(int supplierId, {String? status}) async {
    final db = await database;
    if (status != null) {
      return await db.query('purchase_orders',
        where: 'vendorId = ? AND status = ?',
        whereArgs: [supplierId, status],
        orderBy: 'createdAt DESC',
      );
    }
    return await db.query('purchase_orders',
      where: 'vendorId = ?',
      whereArgs: [supplierId],
      orderBy: 'createdAt DESC',
    );
  }

  /// Update PO status (accept/dispatch/deliver)
  Future<void> updateSupplierPOStatus(int poId, String status) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    
    Map<String, dynamic> updates = {'status': status};
    if (status == 'ACCEPTED') {
      updates['acceptedAt'] = now;
    } else if (status == 'DISPATCHED') {
      updates['dispatchedAt'] = now;
    } else if (status == 'DELIVERED') {
      updates['deliveredAt'] = now;
    }
    
    await db.update('purchase_orders', updates, where: 'id = ?', whereArgs: [poId]);
  }

  /// Get supplier ledger (payments and PO values)
  Future<Map<String, dynamic>> getSupplierLedger(int supplierId, String supplierName, String startDate, String endDate) async {
    final db = await database;
    
    final transactions = await db.rawQuery('''
      SELECT * FROM finance
      WHERE partyName LIKE ? AND date BETWEEN ? AND ?
      ORDER BY date DESC
    ''', ['%$supplierName%', startDate, endDate]);
    
    final poSummary = await db.rawQuery('''
      SELECT SUM(totalAmount) as totalInvoiced
      FROM purchase_orders 
      WHERE vendorId = ? AND DATE(createdAt) BETWEEN ? AND ?
    ''', [supplierId, startDate, endDate]);
    
    return {
      'transactions': transactions,
      'totalInvoiced': poSummary.isNotEmpty ? poSummary.first['totalInvoiced'] ?? 0 : 0,
    };
  }

  /// Assign driver to dispatch and send notification
  Future<void> assignDriverToDispatch(int dispatchId, int driverId) async {
    final db = await database;
    await db.update('dispatches', {
      'driverId': driverId,
      'assignmentStatus': 'PENDING',
      'assignedAt': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [dispatchId]);
  }
  
  // Get orders in an MRP run that require service or counter setup
  Future<List<Map<String, dynamic>>> getServiceRequirementsForMrpRun(int mrpRunId) async {
    final db = await database;
    
    // Join mrp_run_orders with orders to get service requirements
    // Returns orders where serviceRequired=1 OR counterSetupRequired=1
    return await db.rawQuery('''
      SELECT 
        o.id as orderId,
        o.customerName,
        o.date,
        o.time,
        o.serviceRequired,
        o.serviceType,
        o.counterSetupRequired,
        o.serviceSubcontractorId,
        o.counterSubcontractorId,
        mo.pax,
        subS.name as serviceSubcontractorName,
        subC.name as counterSubcontractorName
      FROM mrp_run_orders mo
      JOIN orders o ON o.id = mo.orderId
      LEFT JOIN subcontractors subS ON subS.id = o.serviceSubcontractorId
      LEFT JOIN subcontractors subC ON subC.id = o.counterSubcontractorId
      WHERE mo.mrpRunId = ? AND (o.serviceRequired = 1 OR o.counterSetupRequired = 1)
      ORDER BY o.date ASC, o.time ASC
    ''', [mrpRunId]);
  }

  // Update order service assignments
  Future<void> updateOrderServiceAssignment(int orderId, {int? serviceSubId, int? counterSubId}) async {
    final cloudSync = CloudSyncService();
    final updates = <String, dynamic>{'id': orderId};
    if (serviceSubId != -1) updates['serviceSubcontractorId'] = serviceSubId; // -1 means no change check passed
    if (counterSubId != -1) updates['counterSubcontractorId'] = counterSubId;
    
    if (updates.length > 1) { // More than just 'id'
      await cloudSync.awsFirstUpdate(table: 'orders', recordId: orderId, data: updates);
      AppLogger.success('✅ [Orders] Updated service assignments for order #$orderId (AWS-first)');
    }
  }


}
