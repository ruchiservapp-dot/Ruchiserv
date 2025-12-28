// lib/db/database_helper.dart
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

// Optional but useful if you already added these in your project
// If not present, you can safely remove these two imports.
import '../services/connectivity_service.dart';
import '../db/aws/aws_api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'schema_manager.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String fileName = 'ruchiserv.db';
    
    Database db;
      if (kIsWeb) {
      // Web initialization
      databaseFactory = databaseFactoryFfiWeb;
      db = await openDatabase(
        fileName,
        version: 35, // v35: UPI Subscription Fields
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } else {
      // Mobile/Desktop initialization
      final dir = await getApplicationDocumentsDirectory();
      final path = join(dir.path, fileName);
      db = await openDatabase(
        path,
        version: 35, // v35: UPI Subscription Fields
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    }
    
    // Always sync schema on startup to ensure all columns exist
    // This fixes "missing column" issues even if version didn't change (e.g. dev builds)
    await SchemaManager.syncSchema(db);
    
    return db;
  }

  Future<void> _onCreate(Database db, int version) async {
    print('📦 [DB] Creating new database with version $version');
    
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
          vehicleNo TEXT NOT NULL,
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
      // Remove duplicates - keep only the first occurrence of each vehicleNo
      await db.rawDelete('''
        DELETE FROM vehicles 
        WHERE id NOT IN (
          SELECT MIN(id) FROM vehicles GROUP BY vehicleNo
        )
      ''');
      
      // Insert only if not exists (check by vehicleNo)
      final existingCustomerVehicle = await db.query('vehicles', where: "vehicleNo = 'Customer Vehicle'", limit: 1);
      if (existingCustomerVehicle.isEmpty) {
        await db.insert('vehicles', {
          'firmId': 'SEED',
          'vehicleNo': 'Customer Vehicle',
          'vehicleType': 'OTHER',
          'status': 'AVAILABLE',
          'driverName': 'Customer Arranged',
          'isActive': 1,
          'isModified': 0,
          'createdAt': now,
        });
      }
      
      final existingOwnVehicle = await db.query('vehicles', where: "vehicleNo = 'Own Vehicle'", limit: 1);
      if (existingOwnVehicle.isEmpty) {
        await db.insert('vehicles', {
          'firmId': 'SEED',
          'vehicleNo': 'Own Vehicle',
          'vehicleType': 'OTHER',
          'status': 'AVAILABLE',
          'driverName': 'Company Driver',
          'isActive': 1,
          'isModified': 0,
          'createdAt': now,
        });
      }
    } catch (_) {}
    
    await SchemaManager.syncSchema(db);
  }

  // ---------- SEED DATA LOADER ----------
  Future<void> _loadSeeds(Database db) async {
    print('🌱 Loading Seed Data for v22 (multi-tenant)...');
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
      print('✅ Seed Data Loaded Successfully!');
    } catch (e) {
      print('❌ Error loading seeds: $e');
    }
  }

  // ---------- BASIC UTILS ----------
  Future<void> testDB() async {
    final db = await database;
    // ignore: avoid_print
    print('✅ Database initialized at ${db.path}');
  }

  // ---------- AWS SYNC HELPER ----------
  /// Syncs data to AWS if online. Fails silently to prioritize local-first.
  // Deprecated: Use _syncOrQueue instead which handles both
  Future<void> _syncToAws({
    required String method,
    required String table,
    Map<String, dynamic>? data,
    Map<String, dynamic>? filters,
  }) async {
    // Forward to new logic for backward compatibility if called directly
    return _syncOrQueue(
      table: table,
      data: data ?? filters ?? {},
      action: method == 'POST' ? 'INSERT' : (method == 'PUT' ? 'UPDATE' : 'DELETE'),
      filters: filters,
    );
  }

  /// Unified Sync Helper: Tries online sync, falls back to queue.
  /// Uses DynamoDB structure: PK=firmId, SK=table#id for multi-tenancy
  Future<void> _syncOrQueue({
    required String table,
    required Map<String, dynamic> data,
    required String action, // 'INSERT', 'UPDATE', 'DELETE'
    Map<String, dynamic>? filters,
  }) async {
    // Get firmId for multi-tenant partitioning
    final sp = await SharedPreferences.getInstance();
    final firmId = sp.getString('last_firm') ?? 'DEFAULT';
    final recordId = data['id']?.toString() ?? '0';
    
    // 1. Try Online Sync
    bool synced = false;
    try {
      if (await ConnectivityService().isOnline()) {
        if (action == 'DELETE') {
          // Delete operation
          final resp = await AwsApi.callDbHandler(
            method: 'DELETE',
            table: 'ruchiserv_data',
            filters: {
              'pk': firmId,
              'sk': '$table#$recordId',
            },
          );
          synced = resp['error'] == null;
        } else {
          // INSERT or UPDATE - use PUT (upsert)
          final awsData = Map<String, dynamic>.from(data);
          awsData['pk'] = firmId;
          awsData['sk'] = '$table#$recordId';
          awsData['table_name'] = table;
          awsData['local_id'] = data['id'];
          awsData['firmId'] = firmId;
          awsData['synced_at'] = DateTime.now().toIso8601String();
          
          final resp = await AwsApi.callDbHandler(
            method: 'PUT',
            table: 'ruchiserv_data',
            data: awsData,
          );
          synced = resp['error'] == null;
        }
        
        if (synced) {
          // print('✅ [AWS Sync] $action $table#$recordId success');
        }
      }
    } catch (e) {
      // print('🔶 [AWS Sync] Network error: $e');
    }

    // 2. Queue if failed or offline
    if (!synced) {
      // print('📥 [AWS Sync] Queuing for offline sync: $action $table');
      await queuePendingSync(table: table, data: data, action: action);
    }
  }


  // ---------- ORDERS CRUD (LOCAL + AWS SYNC) ----------
  Future<int?> insertOrder(
    Map<String, dynamic> order,
    List<Map<String, dynamic>> dishes, {
    bool queueIfOffline = false, // Deprecated param, always auto-queues now
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    // Normalize
    order['createdAt'] = order['createdAt'] ?? now;
    order['updatedAt'] = now;
    order['totalPax'] = order['totalPax'] ?? 0;
    order['isLocked'] = order['isLocked'] ?? 0;

    // Insert order
    final orderId = await db.insert('orders', order);

    // Insert dishes local
    for (final dish in dishes) {
      dish['orderId'] = orderId; // Ensure link
      dish['createdAt'] = now;
      await db.insert('dishes', dish);
    }

    // Automatic Sync/Queue
    // Sync Order
    await _syncOrQueue(
      table: 'orders', 
      data: {...order, 'id': orderId}, 
      action: 'INSERT'
    );
    
    // Sync Dishes
    for (var dish in dishes) {
      await _syncOrQueue(
        table: 'dishes', 
        data: {...dish, 'orderId': orderId}, 
        action: 'INSERT'
      );
    }

    return orderId;
  }

  Future<bool> updateOrder(
    int orderId,
    Map<String, dynamic> order,
    List<Map<String, dynamic>> dishes, {
    bool queueIfOffline = false,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    order['updatedAt'] = now;
    order['totalPax'] = order['totalPax'] ?? 0;

    await db.update('orders', order, where: 'id = ?', whereArgs: [orderId]);

    // Replace all dishes for the order
    await db.delete('dishes', where: 'orderId = ?', whereArgs: [orderId]);
    for (final dish in dishes) {
      dish['orderId'] = orderId;
      dish['createdAt'] = now; 
      await db.insert('dishes', dish);
    }

    // Auto Sync
    // Update Order
    await _syncOrQueue(
      table: 'orders',
      data: {...order, 'id': orderId},
      action: 'UPDATE',
      filters: {'id': orderId}
    );
    
    // Dish Sync Strategy: Delete All + Insert All (Simplest for sync)
    await _syncOrQueue(
      table: 'dishes',
      data: {'orderId': orderId},
      action: 'DELETE',
      filters: {'orderId': orderId}
    );
    
    for (var dish in dishes) {
      await _syncOrQueue(
        table: 'dishes',
        data: {...dish, 'orderId': orderId},
        action: 'INSERT'
      );
    }

    return true;
  }

  Future<bool> deleteOrder(
    int orderId, {
    bool queueIfOffline = false,
  }) async {
    final db = await database;
    final result = await db.delete('orders', where: 'id = ?', whereArgs: [orderId]);
    await db.delete('dishes', where: 'orderId = ?', whereArgs: [orderId]);

    // Auto Sync
    await _syncOrQueue(
      table: 'orders',
      data: {'id': orderId},
      action: 'DELETE',
      filters: {'id': orderId}
    );
    await _syncOrQueue(
      table: 'dishes',
      data: {'orderId': orderId},
      action: 'DELETE',
      filters: {'orderId': orderId}
    );

    return result > 0;
  }

  Future<List<Map<String, dynamic>>> getOrdersWithPax(String date) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT o.*, IFNULL(o.totalPax, 0) AS pax
      FROM orders o
      WHERE o.date = ?
      ORDER BY o.time ASC
    ''', [date]);
  }

  Future<List<Map<String, dynamic>>> getDishesForOrder(int orderId) async {
    final db = await database;
    return await db.query(
      'dishes',
      where: "orderId = ? AND name IS NOT NULL AND name != '' AND name != 'Unnamed'",
      whereArgs: [orderId],
      orderBy: 'id ASC',
    );
  }

  /// Toggle subcontract status for a specific dish
  Future<bool> toggleDishSubcontract(int dishId, bool isSubcontracted, {int? subcontractorId}) async {
    if (await isDishLocked(dishId)) return false;

    final db = await database;
    await db.update(
      'dishes',
      {
        'isSubcontracted': isSubcontracted ? 1 : 0,
        'subcontractorId': isSubcontracted ? subcontractorId : null,
        'productionType': isSubcontracted ? 'SUBCONTRACT' : 'INTERNAL',
      },
      where: 'id = ?',
      whereArgs: [dishId],
    );
    
    // Auto Sync
    await _syncOrQueue(
      table: 'dishes',
      data: {
        'id': dishId, 
        'isSubcontracted': isSubcontracted ? 1 : 0, 
        'subcontractorId': subcontractorId,
        'productionType': isSubcontracted ? 'SUBCONTRACT' : 'INTERNAL',
      },
      action: 'UPDATE',
      filters: {'id': dishId}
    );
    
    return true;
  }

  /// Check if a dish is locked (via its order being locked for MRP/PO)
  Future<bool> isDishLocked(int dishId) async {
    final db = await database;
    // Join dishes -> orders to check lock status
    final res = await db.rawQuery('''
      SELECT o.isLocked 
      FROM dishes d
      JOIN orders o ON d.orderId = o.id
      WHERE d.id = ?
    ''', [dishId]);
    
    if (res.isEmpty) return false;
    return (res.first['isLocked'] as int?) == 1;
  }


  Future<Map<String, int>> getTotalPaxForDate(String date) async {
    try {
      final db = await database;
      final result = await db
          .rawQuery('SELECT IFNULL(SUM(totalPax), 0) as total FROM orders WHERE date = ?', [date]);
      final totalPax = (result.first['total'] as int?) ?? 0;
      // Simple split; adjust if you store per-dish foodType for totals
      return {'total': totalPax, 'veg': totalPax ~/ 2, 'nonVeg': totalPax ~/ 2};
    } catch (_) {
      return {'total': 0, 'veg': 0, 'nonVeg': 0};
    }
  }

  Future<List<Map<String, dynamic>>> getAllOrdersWithPax() async {
  final db = await database;
  // Fixed: Sum BOTH 'pax' (new schema) and 'totalPax' (legacy schema) to support all data
  // Using COALESCE to handle NULLs safely
  // Added: hasMrpRun flag for calendar indicators
  return await db.rawQuery('''
    SELECT 
      o.date,
      0 AS vegPax,
      0 AS nonVegPax,
      SUM(COALESCE(o.pax, 0) + COALESCE(o.totalPax, 0)) AS totalPax,
      MAX(CASE WHEN o.mrpRunId IS NOT NULL THEN 1 ELSE 0 END) AS hasMrpRun,
      MAX(CASE WHEN o.mrpStatus = 'PO_SENT' THEN 1 ELSE 0 END) AS hasPOSent
    FROM orders o
    WHERE o.date IS NOT NULL
    GROUP BY o.date
    ORDER BY o.date ASC
  ''');
}

  // Simple getter for all orders by date (used by your UI)
  Future<List<Map<String, dynamic>>> getOrdersByDate(String date) async {
    final db = await database;
    return db.query(
      'orders',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'eventTime ASC',
    );
  }

  /// Get orders eligible for MRP Run (STRICT: Only PENDING status)
  Future<List<Map<String, dynamic>>> getPendingOrdersForMrp(String date) async {
    final db = await database;
    return db.query(
      'orders',
      where: "date = ? AND (mrpStatus IS NULL OR mrpStatus = 'PENDING')",
      whereArgs: [date],
      orderBy: 'eventTime ASC',
    );
  }

  /// Get already processed orders (for display only - not selectable for MRP)
  Future<List<Map<String, dynamic>>> getProcessedOrdersForMrp(String date) async {
    final db = await database;
    return db.query(
      'orders',
      where: "date = ? AND mrpStatus IS NOT NULL AND mrpStatus != 'PENDING'",
      whereArgs: [date],
      orderBy: 'eventTime ASC',
    );
  }

  /// Get order with its dependencies for cancellation validation
  Future<Map<String, dynamic>> getOrderDependencies(int orderId, String firmId) async {
    final db = await database;
    
    // Get order
    final orders = await db.query('orders', where: 'id = ? AND firmId = ?', whereArgs: [orderId, firmId]);
    if (orders.isEmpty) {
      return {'error': 'Order not found'};
    }
    
    final order = orders.first;
    
    // Get dish count
    final dishes = await db.query('dishes', where: 'orderId = ?', whereArgs: [orderId]);
    final dishCount = dishes.length;
    
    // Check for dispatch records (if table exists)
    int dispatchCount = 0;
    bool hasDispatch = false;
    try {
      final dispatches = await db.query('dispatch', where: 'orderId = ?', whereArgs: [orderId]);
      dispatchCount = dispatches.length;
      hasDispatch = dispatchCount > 0;
    } catch (_) {
      // dispatch table might not exist
    }
    
    return {
      'order': order,
      'dishCount': dishCount,
      'hasDispatch': hasDispatch,
      'dispatchCount': dispatchCount,
    };
  }

  /// Cancel an order (soft delete)
  Future<bool> cancelOrder(int orderId, {required String firmId, required String userId}) async {
    try {
      final db = await database;
      final now = DateTime.now().toIso8601String();
      
      await db.update(
        'orders',
        {
          'isCancelled': 1,
          'cancelledAt': now,
          'cancelledBy': userId,
          'status': 'CANCELLED',
          'updatedAt': now,
        },
        where: 'id = ? AND firmId = ?',
        whereArgs: [orderId, firmId],
      );
      
      return true;
    } catch (e) {
      return false;
    }
  }

  // Dish summary for a date (used by your Summary screen)
  Future<List<Map<String, dynamic>>> getDishesSummaryByDate(String date) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT d.name,
             COALESCE(d.foodType, 'Veg') AS foodType,
             COALESCE(o.mealType, 'Snacks/Others') AS mealType,
             SUM(COALESCE(d.pax, 0)) AS totalPax,
             SUM(COALESCE(d.cost, 0)) AS totalCost
      FROM dishes d
      JOIN orders o ON o.id = d.orderId
      WHERE o.date = ?
      GROUP BY d.name, d.foodType, o.mealType
      ORDER BY o.mealType, d.name
    ''', [date]);
  }

  // Get all dishes for a date with status (for Reports)
  Future<List<Map<String, dynamic>>> getDishesForDate(String date) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT d.*, o.customerName, o.status as orderStatus, o.time
      FROM dishes d
      JOIN orders o ON d.orderId = o.id
      WHERE o.date = ?
      ORDER BY o.time, o.id
    ''', [date]);
  }

  // Get dispatches for a date (for Reports)
  Future<List<Map<String, dynamic>>> getDispatchesForDate(String date) async {
    final db = await database;
    // Check if dispatch table exists first (defensive)
    try {
      return await db.rawQuery('''
        SELECT d.*, o.customerName, o.totalPax, o.location
        FROM dispatch d
        JOIN orders o ON d.orderId = o.id
        WHERE d.date = ?
        ORDER BY d.timeOut
      ''', [date]);
    } catch (_) {
      return [];
    }
  }

  // ---------- DISH MASTER (Autocomplete Suggestions) ----------
  /// Get all saved dishes for a category (for autocomplete)
/// Maps UI categories to DB categories using pattern matching
Future<List<Map<String, dynamic>>> getDishSuggestions(String? category) async {
  try {
    final db = await database;
    final sp = await SharedPreferences.getInstance();
    final firmId = sp.getString('last_firm') ?? 'DEFAULT';
    final showUniversal = await getFirmUniversalDataVisibility(firmId);

    String whereClause = "(firmId = ? ${showUniversal ? "OR firmId = 'SEED'" : ""})";
    List<dynamic> args = [firmId];

    if (category != null && category.isNotEmpty) {
      // Map UI category names to DB category patterns
      // UI uses: 'Starters', 'Main Course', 'Desserts', 'Beverages', 'Specialties'
      // DB has: 'Starter', 'Starter/Main', 'Main Course', 'Dessert', 'Beverage', 'Specialty', etc.
      String pattern;
      switch (category) {
        case 'Starters':
          pattern = 'Starter%';
          break;
        case 'Main Course':
          pattern = 'Main Course%'; // Or 'Main%' but might be too broad
          break;
        case 'Desserts':
          pattern = 'Dessert%';
          break;
        case 'Beverages':
          pattern = 'Beverage%';
          break;
        case 'Specialties':
          pattern = 'Special%'; // Matches Special, Specialty
          break;
        default:
          pattern = '$category%'; // For 'Main Course' etc.
      }
      whereClause += " AND category LIKE ?";
      args.add(pattern);
      
      return await db.query(
        'dish_master',
        where: whereClause,
        whereArgs: args,
        orderBy: 'name ASC',
      );
    }
    return await db.query('dish_master', where: whereClause, whereArgs: args, orderBy: 'category, name ASC');
  } catch (_) {
    // Return empty list if table doesn't exist or other error
    return [];
  }
}
  

  /// Upsert a dish to the master table (called when order is saved)
  /// Uses Check-Update-Insert to preserve IDs (Critical for BOM integrity)
  /// V22: Implements Copy-On-Write logic for Multi-Tenancy (Seed -> Firm)
  Future<void> upsertDishMaster({
    required String name,
    required String category,
    required int rate,
    String foodType = 'Veg',
  }) async {
    if (name.trim().isEmpty) return;
    
    final db = await database;
    final now = DateTime.now().toIso8601String();
    
    final sp = await SharedPreferences.getInstance();
    final firmId = sp.getString('last_firm');

    // If no firmId, we can't save legally.
    if (firmId == null) return; 

    try {
      // 1. Check for Firm-Specific Version
      final firmDish = await db.query(
        'dish_master',
        where: 'name = ? AND category = ? AND firmId = ?',
        whereArgs: [name.trim(), category, firmId],
        limit: 1,
      );

      if (firmDish.isNotEmpty) {
        // Update Firm Dish
        await db.update(
          'dish_master',
          {
            'rate': rate,
            'foodType': foodType,
            'updatedAt': now,
            'isModified': 1,
          },
          where: 'id = ?',
          whereArgs: [firmDish.first['id']],
        );
      } else {
        // 2. Check for Seed Version
        final seedDish = await db.query(
          'dish_master',
          where: 'name = ? AND category = ? AND firmId = ?',
          whereArgs: [name.trim(), category, 'SEED'],
          limit: 1,
        );

        if (seedDish.isNotEmpty) {
          // Found Seed Dish. Check if values differ.
          final s = seedDish.first;
          final currentRate = (s['rate'] as num).toInt();
          final currentType = s['foodType'] as String;

          if (currentRate != rate || currentType != foodType) {
            // Values changed! Copy-On-Write.
            await db.insert(
              'dish_master',
              {
                'firmId': firmId,
                'baseId': s['id'], // Link to seed
                'name': name.trim(),
                'category': category,
                'rate': rate, // New rate
                'foodType': foodType, // New type
                'createdAt': now,
                'updatedAt': now,
                'isModified': 1,
              },
            );
          }
          // Else: Seed is fine, no need to duplicate.
        } else {
          // 3. New Dish entirely
          await db.insert(
            'dish_master',
            {
              'firmId': firmId,
              'name': name.trim(),
              'category': category,
              'rate': rate,
              'foodType': foodType,
              'createdAt': now,
              'updatedAt': now,
              'isModified': 1,
            },
          );
        }
      }
    } catch (_) {
      // Ignore errors (e.g., constraint violations)
    }
  }

  // ---------- FIRMS & USERS (LOCAL) ----------
  Future<int?> insertFirm(Map<String, dynamic> firm) async {
    final db = await database;
    return await db.insert('firms', firm);
  }

  Future<List<Map<String, dynamic>>> getAllFirms() async {
    final db = await database;
    return await db.query('firms', orderBy: 'firmName ASC');
  }

  Future<int?> insertUser(Map<String, dynamic> user) async {
    final db = await database;
    return await db.insert('users', user);
  }

  Future<List<Map<String, dynamic>>> getUsersByFirm(String firmId) async {
    final db = await database;
    return await db.query('users', where: 'firmId = ?', whereArgs: [firmId]);
  }

  Future<bool> verifyUserEligibility(String firmId, String mobile) async {
    try {
      final db = await database;
      final result = await db.query(
        'users',
        where: 'firmId = ? AND mobile = ?',
        whereArgs: [firmId, mobile],
      );
      return result.isNotEmpty;
    } catch (_) {
      return false;
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
      print("🟢 Local user cached: ${user['username']}");
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error caching local user: $e');
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
        print("🟠 Offline login success for $username");
        return result.first;
      }
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('❌ Offline login check failed: $e');
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

        if (action == 'INSERT') {
          // POST
          resp = await AwsApi.callDbHandler(
            method: 'POST',
            table: table,
            data: data,
          );
        } else if (action == 'UPDATE') {
          // PUT (expects an id in data)
          final idVal = data['id'];
          resp = await AwsApi.callDbHandler(
            method: 'PUT',
            table: table,
            data: data,
            filters: (idVal != null) ? {'id': idVal} : null,
          );
        } else if (action == 'DELETE') {
          // DELETE (prefers filters for id)
          final idVal = data['id'];
          resp = await AwsApi.callDbHandler(
            method: 'DELETE',
            table: table,
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
    print('🗑️ All firms deleted from local DB');
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

    return await db.query(
      'transactions',
      where: where,
      whereArgs: args,
      orderBy: 'date DESC, id DESC',
      limit: limit,
    );
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
    final db = await database;
    final orderId = await db.insert('supplier_orders', data);
    
    await _syncOrQueue(table: 'supplier_orders', data: {...data, 'id': orderId}, action: 'INSERT');

    if (items != null && items.isNotEmpty) {
      for (var item in items) {
        item['orderId'] = orderId;
        final itemId = await db.insert('supplier_order_items', item);
        await _syncOrQueue(table: 'supplier_order_items', data: {...item, 'id': itemId}, action: 'INSERT');
      }
    }
    
    return orderId;
  }
  
  // Operations Module  
  Future<List<Map<String, dynamic>>> getAllStaff() async {
    final db = await database;
    return await db.query('staff');
  }
  
  Future<int> insertStaff(Map<String, dynamic> data) async {
    final db = await database;
    final id = await db.insert('staff', data);
    await _syncOrQueue(table: 'staff', data: {...data, 'id': id}, action: 'INSERT');
    return id;
  }
  
  Future<int> insertAttendance(Map<String, dynamic> data) async {
    final db = await database;
    final id = await db.insert('attendance', data);
    await _syncOrQueue(table: 'attendance', data: {...data, 'id': id}, action: 'INSERT');
    return id;
  }
  
  Future<List<Map<String, dynamic>>> getPendingDispatches() async {
    final db = await database;
    return await db.query('dispatch', where: "status = 'Pending'");
  }
  
  Future<List<Map<String, dynamic>>> getOrdersWithoutDispatch(String date) async {
    final db = await database;
    return await db.rawQuery(
      "SELECT * FROM orders WHERE date = ? AND id NOT IN (SELECT orderId FROM dispatch)",
      [date]
    );
  }
  
  Future<int> insertDispatch(Map<String, dynamic> data) async {
    final db = await database;
    final id = await db.insert('dispatch', data);
    await _syncOrQueue(table: 'dispatch', data: {...data, 'id': id}, action: 'INSERT');
    return id;
  }
  
  Future<List<Map<String, dynamic>>> getAllUtensils() async {
    final db = await database;
    return await db.query('utensils');
  }
  
  Future<int> insertUtensil(Map<String, dynamic> data) async {
    final db = await database;
    final id = await db.insert('utensils', data);
    await _syncOrQueue(table: 'utensils', data: {...data, 'id': id}, action: 'INSERT');
    return id;
  }

  Future<int> updateUtensil(Map<String, dynamic> data) async {
    final db = await database;
    final rows = await db.update('utensils', data, where: 'id = ?', whereArgs: [data['id']]);
    await _syncOrQueue(table: 'utensils', data: data, action: 'UPDATE', filters: {'id': data['id']});
    return rows;
  }

  Future<int> deleteUtensil(int id) async {
    final db = await database;
    final rows = await db.delete('utensils', where: 'id = ?', whereArgs: [id]);
    await _syncOrQueue(table: 'utensils', data: {'id': id}, action: 'DELETE', filters: {'id': id});
    return rows;
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

  Future<int> updateUser(Map<String, dynamic> user) async {
    final db = await database;
    final rows = await db.update(
      'users',
      user,
      where: 'id = ?',
      whereArgs: [user['id']],
    );
    await _syncOrQueue(table: 'users', data: user, action: 'UPDATE', filters: {'id': user['id']});
    return rows;
  }
  
  Future<int> deleteUser(int id) async {
    final db = await database;
    final rows = await db.delete('users', where: 'id = ?', whereArgs: [id]);
    await _syncOrQueue(table: 'users', data: {'id': id}, action: 'DELETE', filters: {'id': id});
    return rows;
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
  
  /// Get monthly attendance summary for a staff member
  Future<Map<String, dynamic>> getMonthlyAttendanceSummary(int staffId, String monthYear) async {
    final db = await database;
    // monthYear format: 'YYYY-MM'
    final startDate = '$monthYear-01';
    final endDate = '$monthYear-31'; // Will work for any month
    
    final result = await db.rawQuery('''
      SELECT 
        COUNT(*) as daysPresent,
        COALESCE(SUM(hoursWorked), 0) as totalHours,
        COALESCE(SUM(overtime), 0) as totalOvertime,
        SUM(CASE WHEN isWithinGeoFence = 1 THEN 1 ELSE 0 END) as daysWithinGeoFence
      FROM attendance
      WHERE staffId = ? AND date BETWEEN ? AND ? AND status = 'Present'
    ''', [staffId, startDate, endDate]);
    
    return result.isNotEmpty ? result.first : {
      'daysPresent': 0,
      'totalHours': 0.0,
      'totalOvertime': 0.0,
      'daysWithinGeoFence': 0,
    };
  }
  
  /// Get pending (not yet deducted) advances for a staff member
  Future<double> getPendingAdvances(int staffId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM staff_advances
      WHERE staffId = ? AND deductedFromPayroll = 0
    ''', [staffId]);
    
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }
  
  /// Mark advances as deducted for a payroll month
  Future<void> markAdvancesDeducted(int staffId, String payrollMonth) async {
    final db = await database;
    await db.update(
      'staff_advances',
      {'deductedFromPayroll': 1, 'payrollMonth': payrollMonth},
      where: 'staffId = ? AND deductedFromPayroll = 0',
      whereArgs: [staffId],
    );
  }
  
  /// Get all staff with their payroll summary for a month
  Future<List<Map<String, dynamic>>> getMonthlyPayrollSummary(String monthYear) async {
    final db = await database;
    final startDate = '$monthYear-01';
    final endDate = '$monthYear-31';
    
    return await db.rawQuery('''
      SELECT 
        s.id,
        s.name,
        s.staffType,
        s.salary,
        s.dailyWageRate,
        s.hourlyRate,
        s.payoutFrequency,
        COUNT(a.id) as daysPresent,
        COALESCE(SUM(a.hoursWorked), 0) as totalHours,
        COALESCE(SUM(a.overtime), 0) as totalOvertime,
        (SELECT COALESCE(SUM(amount), 0) FROM staff_advances 
         WHERE staffId = s.id AND deductedFromPayroll = 0) as pendingAdvances
      FROM staff s
      LEFT JOIN attendance a ON s.id = a.staffId 
        AND a.date BETWEEN ? AND ? 
        AND a.status = 'Present'
      WHERE s.isActive = 1
      GROUP BY s.id
      ORDER BY s.name
    ''', [startDate, endDate]);
  }
  
  // === SALARY DISBURSEMENT METHODS ===
  
  /// Get complete salary slip data for an employee
  Future<Map<String, dynamic>?> getSalarySlipData(int staffId, String monthYear) async {
    final db = await database;
    final startDate = '$monthYear-01';
    final endDate = '$monthYear-31';
    
    // Get staff details
    final staffList = await db.query('staff', where: 'id = ?', whereArgs: [staffId], limit: 1);
    if (staffList.isEmpty) return null;
    final staff = staffList.first;
    
    // Get firm details for header
    final firmId = staff['firmId'] as String?;
    Map<String, dynamic>? firm;
    if (firmId != null) {
      firm = await getFirmDetails(firmId);
    }
    
    // Get attendance summary
    final attendance = await db.rawQuery('''
      SELECT 
        COUNT(*) as daysPresent,
        COALESCE(SUM(hoursWorked), 0) as totalHours,
        COALESCE(SUM(overtime), 0) as totalOvertime
      FROM attendance
      WHERE staffId = ? AND date BETWEEN ? AND ? AND status = 'Present'
    ''', [staffId, startDate, endDate]);
    
    // Get pending advances
    final advances = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM staff_advances
      WHERE staffId = ? AND deductedFromPayroll = 0
    ''', [staffId]);
    
    // Get disbursement status if exists
    final disbursement = await db.query(
      'salary_disbursements',
      where: 'staffId = ? AND monthYear = ?',
      whereArgs: [staffId, monthYear],
      limit: 1,
    );
    
    return {
      'staff': staff,
      'firm': firm,
      'monthYear': monthYear,
      'attendance': attendance.first,
      'pendingAdvances': (advances.first['total'] as num?)?.toDouble() ?? 0,
      'disbursement': disbursement.isNotEmpty ? disbursement.first : null,
    };
  }
  
  /// Get salary disbursement record
  Future<Map<String, dynamic>?> getSalaryDisbursement(int staffId, String monthYear) async {
    final db = await database;
    final result = await db.query(
      'salary_disbursements',
      where: 'staffId = ? AND monthYear = ?',
      whereArgs: [staffId, monthYear],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }
  
  /// Disburse salary and create ledger entry
  Future<int> disburseSalary({
    required String firmId,
    required int staffId,
    required String monthYear,
    required double basePay,
    required double otPay,
    required double deductions,
    required double netPay,
    required String paymentMode,
    String? paymentRef,
    String? paidBy,
    String? notes,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    
    // Insert or update disbursement record
    final existing = await getSalaryDisbursement(staffId, monthYear);
    
    int id;
    if (existing != null) {
      await db.update(
        'salary_disbursements',
        {
          'basePay': basePay,
          'otPay': otPay,
          'deductions': deductions,
          'netPay': netPay,
          'status': 'PAID',
          'paymentMode': paymentMode,
          'paymentRef': paymentRef,
          'paidAt': now,
          'paidBy': paidBy,
          'notes': notes,
          'updatedAt': now,
        },
        where: 'id = ?',
        whereArgs: [existing['id']],
      );
      id = existing['id'] as int;
    } else {
      id = await db.insert('salary_disbursements', {
        'firmId': firmId,
        'staffId': staffId,
        'monthYear': monthYear,
        'basePay': basePay,
        'otPay': otPay,
        'deductions': deductions,
        'netPay': netPay,
        'status': 'PAID',
        'paymentMode': paymentMode,
        'paymentRef': paymentRef,
        'paidAt': now,
        'paidBy': paidBy,
        'notes': notes,
        'createdAt': now,
        'updatedAt': now,
      });
    }
    
    // Get staff name for transaction
    final staff = await db.query('staff', where: 'id = ?', whereArgs: [staffId], limit: 1);
    final staffName = (staff.isNotEmpty ? staff.first['name'] : 'Staff') as String;
    
    // Create ledger transaction (expense)
    await db.insert('transactions', {
      'firmId': firmId,
      'type': 'EXPENSE',
      'category': 'Salary',
      'amount': netPay,
      'date': now.substring(0, 10),
      'description': 'Salary for $staffName - $monthYear',
      'paymentMode': paymentMode,
      'referenceId': 'SAL-$monthYear-$staffId',
      'createdAt': now,
    });
    
    // Mark advances as deducted if any
    if (deductions > 0) {
      await markAdvancesDeducted(staffId, monthYear);
    }
    
    return id;
  }
  
  /// Get all pending disbursements for a month
  Future<List<Map<String, dynamic>>> getPendingDisbursements(String firmId, String monthYear) async {
    final db = await database;
    final startDate = '$monthYear-01';
    final endDate = '$monthYear-31';
    
    return await db.rawQuery('''
      SELECT 
        s.id,
        s.name,
        s.staffType,
        s.salary,
        s.dailyWageRate,
        s.hourlyRate,
        COUNT(a.id) as daysPresent,
        COALESCE(SUM(a.hoursWorked), 0) as totalHours,
        COALESCE(SUM(a.overtime), 0) as totalOvertime,
        (SELECT COALESCE(SUM(amount), 0) FROM staff_advances 
         WHERE staffId = s.id AND deductedFromPayroll = 0) as pendingAdvances,
        sd.status as disbursementStatus,
        sd.paidAt,
        sd.paymentMode,
        sd.netPay as paidAmount
      FROM staff s
      LEFT JOIN attendance a ON s.id = a.staffId 
        AND a.date BETWEEN ? AND ? 
        AND a.status = 'Present'
      LEFT JOIN salary_disbursements sd ON s.id = sd.staffId AND sd.monthYear = ?
      WHERE s.isActive = 1 AND s.firmId = ?
      GROUP BY s.id
      ORDER BY sd.status ASC, s.name
    ''', [startDate, endDate, monthYear, firmId]);
  }
  
  /// Get staff salary history
  Future<List<Map<String, dynamic>>> getStaffSalaryHistory(int staffId, {int limit = 12}) async {
    final db = await database;
    return await db.query(
      'salary_disbursements',
      where: 'staffId = ?',
      whereArgs: [staffId],
      orderBy: 'monthYear DESC',
      limit: limit,
    );
  }

  
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
  
  // ============== STAFF ASSIGNMENTS ==============
  
  /// Assign staff to an order
  Future<int> assignStaffToOrder(int orderId, int staffId, String role) async {
    final db = await database;
    return await db.insert('staff_assignments', {
      'orderId': orderId,
      'staffId': staffId,
      'role': role,
      'assignedAt': DateTime.now().toIso8601String(),
      'status': 'ASSIGNED',
    });
  }
  
  /// Get staff assigned to an order
  Future<List<Map<String, dynamic>>> getOrderStaffAssignments(int orderId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT sa.*, s.name, s.mobile, s.role as staffRole
      FROM staff_assignments sa
      JOIN staff s ON sa.staffId = s.id
      WHERE sa.orderId = ?
    ''', [orderId]);
  }
  
  /// Remove staff assignment
  Future<int> removeStaffAssignment(int assignmentId) async {
    final db = await database;
    return await db.delete('staff_assignments', where: 'id = ?', whereArgs: [assignmentId]);
  }
  
  /// Get available staff (not assigned to orders on a date)
  Future<List<Map<String, dynamic>>> getAvailableStaff(String date) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT s.*
      FROM staff s
      WHERE s.isActive = 1
        AND s.id NOT IN (
          SELECT sa.staffId FROM staff_assignments sa
          JOIN orders o ON sa.orderId = o.id
          WHERE o.date = ?
        )
      ORDER BY s.name
    ''', [date]);
  }

  
  // ============== COMPREHENSIVE REPORTS ==============
  
  /// Order Summary Report - Orders by status
  Future<List<Map<String, dynamic>>> getOrderStatusReport(String startDate, String endDate) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        date,
        COUNT(*) as totalOrders,
        SUM(CASE WHEN status = 'Confirmed' THEN 1 ELSE 0 END) as confirmed,
        SUM(CASE WHEN status = 'Completed' THEN 1 ELSE 0 END) as completed,
        SUM(CASE WHEN isCancelled = 1 THEN 1 ELSE 0 END) as cancelled,
        SUM(totalPax) as totalPax,
        SUM(CASE WHEN isCancelled = 0 OR isCancelled IS NULL THEN finalAmount ELSE 0 END) as revenue
      FROM orders
      WHERE date BETWEEN ? AND ?
      GROUP BY date
      ORDER BY date DESC
    ''', [startDate, endDate]);
  }
  
  /// Order by Food Type Report
  Future<List<Map<String, dynamic>>> getOrdersByFoodTypeReport(String startDate, String endDate) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        foodType,
        COUNT(*) as orderCount,
        SUM(totalPax) as totalPax,
        SUM(CASE WHEN isCancelled = 0 OR isCancelled IS NULL THEN finalAmount ELSE 0 END) as revenue
      FROM orders
      WHERE date BETWEEN ? AND ? AND (isCancelled = 0 OR isCancelled IS NULL)
      GROUP BY foodType
      ORDER BY orderCount DESC
    ''', [startDate, endDate]);
  }
  
  /// Order by Meal Type Report
  Future<List<Map<String, dynamic>>> getOrdersByMealTypeReport(String startDate, String endDate) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        mealType,
        COUNT(*) as orderCount,
        SUM(totalPax) as totalPax,
        SUM(CASE WHEN isCancelled = 0 OR isCancelled IS NULL THEN finalAmount ELSE 0 END) as revenue
      FROM orders
      WHERE date BETWEEN ? AND ? AND (isCancelled = 0 OR isCancelled IS NULL)
      GROUP BY mealType
      ORDER BY orderCount DESC
    ''', [startDate, endDate]);
  }
  
  /// Kitchen Production Report - Dishes by status
  Future<List<Map<String, dynamic>>> getKitchenProductionReport(String startDate, String endDate) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        o.date,
        COUNT(d.id) as totalDishes,
        SUM(CASE WHEN d.productionStatus = 'COMPLETED' THEN 1 ELSE 0 END) as completed,
        SUM(CASE WHEN d.productionStatus = 'IN_PROGRESS' THEN 1 ELSE 0 END) as inProgress,
        SUM(CASE WHEN d.productionStatus IS NULL OR d.productionStatus = 'PENDING' THEN 1 ELSE 0 END) as pending,
        SUM(COALESCE(d.pax, 0)) as totalPax
      FROM dishes d
      JOIN orders o ON d.orderId = o.id
      WHERE o.date BETWEEN ? AND ?
      GROUP BY o.date
      ORDER BY o.date DESC
    ''', [startDate, endDate]);
  }
  
  /// Top Dishes Report
  Future<List<Map<String, dynamic>>> getTopDishesReport(String startDate, String endDate, {int limit = 10}) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        d.name,
        d.category,
        COUNT(*) as orderCount,
        SUM(COALESCE(d.pax, 0)) as totalPax,
        SUM(COALESCE(d.cost, 0)) as totalRevenue
      FROM dishes d
      JOIN orders o ON d.orderId = o.id
      WHERE o.date BETWEEN ? AND ? AND (o.isCancelled = 0 OR o.isCancelled IS NULL)
      GROUP BY d.name
      ORDER BY orderCount DESC
      LIMIT ?
    ''', [startDate, endDate, limit]);
  }
  
  /// Dishes by Category Report
  Future<List<Map<String, dynamic>>> getDishesByCategoryReport(String startDate, String endDate) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        COALESCE(d.category, 'Uncategorized') as category,
        COUNT(*) as dishCount,
        SUM(COALESCE(d.pax, 0)) as totalPax,
        SUM(COALESCE(d.cost, 0)) as totalRevenue
      FROM dishes d
      JOIN orders o ON d.orderId = o.id
      WHERE o.date BETWEEN ? AND ? AND (o.isCancelled = 0 OR o.isCancelled IS NULL)
      GROUP BY d.category
      ORDER BY dishCount DESC
    ''', [startDate, endDate]);
  }
  
  /// Dispatch Performance Report
  Future<List<Map<String, dynamic>>> getDispatchReport(String startDate, String endDate) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        o.date,
        COUNT(DISTINCT d.id) as totalDispatches,
        SUM(CASE WHEN d.dispatchStatus = 'DELIVERED' THEN 1 ELSE 0 END) as delivered,
        SUM(CASE WHEN d.dispatchStatus = 'DISPATCHED' THEN 1 ELSE 0 END) as inTransit,
        SUM(CASE WHEN d.dispatchStatus = 'PENDING' OR d.dispatchStatus IS NULL THEN 1 ELSE 0 END) as pending,
        COUNT(DISTINCT o.id) as ordersCount
      FROM dispatches d
      JOIN orders o ON d.orderId = o.id
      WHERE o.date BETWEEN ? AND ?
      GROUP BY o.date
      ORDER BY o.date DESC
    ''', [startDate, endDate]);
  }
  
  /// Delivery by Time Slot Report
  Future<List<Map<String, dynamic>>> getDeliveryTimeReport(String startDate, String endDate) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        CASE 
          WHEN CAST(SUBSTR(o.time, 1, 2) AS INTEGER) < 12 THEN 'Morning (6-12)'
          WHEN CAST(SUBSTR(o.time, 1, 2) AS INTEGER) < 17 THEN 'Afternoon (12-5)'
          ELSE 'Evening (5-10)'
        END as timeSlot,
        COUNT(*) as orderCount,
        SUM(totalPax) as totalPax
      FROM orders o
      WHERE o.date BETWEEN ? AND ? AND (o.isCancelled = 0 OR o.isCancelled IS NULL)
      GROUP BY timeSlot
      ORDER BY 
        CASE timeSlot
          WHEN 'Morning (6-12)' THEN 1
          WHEN 'Afternoon (12-5)' THEN 2
          ELSE 3
        END
    ''', [startDate, endDate]);
  }
  
  /// Revenue by Location Report
  Future<List<Map<String, dynamic>>> getRevenueByLocationReport(String startDate, String endDate) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        COALESCE(location, venue, 'Unknown') as location,
        COUNT(*) as orderCount,
        SUM(totalPax) as totalPax,
        SUM(CASE WHEN isCancelled = 0 OR isCancelled IS NULL THEN finalAmount ELSE 0 END) as revenue
      FROM orders
      WHERE date BETWEEN ? AND ?
      GROUP BY location
      ORDER BY revenue DESC
      LIMIT 10
    ''', [startDate, endDate]);
  }
  
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
      where: 'firmId = ? AND mobile = ? AND isActive = 1',
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

    if (exists == null) {
      updateData['firmId'] = firmId; // Ensure firmId is set
      updateData['createdAt'] = DateTime.now().toIso8601String();
      return await db.insert('firms', updateData);
    } else {
      return await db.update(
        'firms',
        updateData,
        where: 'firmId = ?',
        whereArgs: [firmId],
      );
    }
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
  Future<List<Map<String, dynamic>>> getAllIngredients(String firmId) async {
    final db = await database;
    
    // 1. Get Firm Specific Data
    final firmData = await db.query(
      'ingredients_master',
      where: 'firmId = ?',
      whereArgs: [firmId],
      orderBy: 'category, name',
    );

    // 2. Get Seed Data (excluding overridden)
    // Check if firm allows universal data
    bool showUniversal = await getFirmUniversalDataVisibility(firmId);
    if (!showUniversal) {
      // If not showing universal, just return firm data
      return firmData;
    }

    // Collect both baseIds and names from firm data to properly exclude duplicates
    final customizedBaseIds = firmData.map((r) => r['baseId']).where((id) => id != null).toList();
    final firmIngNames = firmData.map((r) => (r['name'] as String?)?.toLowerCase()).where((n) => n != null).toSet();
    
    String seedWhere = "firmId = 'SEED'";
    if (customizedBaseIds.isNotEmpty) {
      seedWhere += " AND baseId NOT IN (${customizedBaseIds.join(',')})";
    }

    final seedData = await db.rawQuery(
      'SELECT * FROM ingredients_master WHERE $seedWhere ORDER BY category, name',
    );
    
    // Also filter out SEED ingredients whose names match firm ingredients (case-insensitive)
    final filteredSeedData = seedData.where((sd) {
      final seedName = (sd['name'] as String?)?.toLowerCase();
      return seedName == null || !firmIngNames.contains(seedName);
    }).toList();
    
    // 3. Merge & Sort
    final combined = [...firmData, ...filteredSeedData];
    combined.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    
    return combined;
  }

  Future<int> insertIngredient(Map<String, dynamic> data) async {
    final db = await database;
    
    if (data['firmId'] == null) {
       final sp = await SharedPreferences.getInstance();
       final fid = sp.getString('last_firm');
       if (fid != null) data['firmId'] = fid;
    }

    data['createdAt'] = DateTime.now().toIso8601String();
    data['updatedAt'] = DateTime.now().toIso8601String();
    // Use master table
    return await db.insert('ingredients_master', data);
  }

  Future<int> updateIngredient(int id, Map<String, dynamic> data) async {
    final db = await database;
    data['updatedAt'] = DateTime.now().toIso8601String();
    return await db.update('ingredients_master', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> seedIngredientsFromJson(String firmId, List<Map<String, dynamic>> ingredients) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    for (var ing in ingredients) {
      batch.insert('ingredients', {
        ...ing,
        'firmId': firmId,
        'isSystemPreloaded': 1,
        'isActive': 1,
        'createdAt': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  // --- BOM ---
  Future<List<Map<String, dynamic>>> getBomForDish(String firmId, int dishId) async {
    final db = await database;
    
    // First try firm-specific BOM (uses actual dish_id)
    var result = await db.rawQuery('''
      SELECT rd.*, 
             i.name as ingredientName, 
             i.category, 
             COALESCE(rd.unit_override, i.unit_of_measure) as unit,
             (rd.quantity_per_base_pax * 100) as quantityPer100Pax
      FROM recipe_detail rd
      JOIN ingredients_master i ON rd.ing_id = i.id
      WHERE rd.dish_id = ? AND rd.firmId = ?
      ORDER BY i.category, i.name
    ''', [dishId, firmId]);
    
    // If no firm-specific BOM, fallback to SEED data
    // NOTE: SEED BOM uses baseId values for dish_id and ing_id, NOT auto-generated ids
    if (result.isEmpty) {
      // Get the dish's baseId (if it's a seed dish)
      final dish = await db.query('dish_master', where: 'id = ?', whereArgs: [dishId]);
      if (dish.isNotEmpty) {
        final baseId = dish.first['baseId'];
        if (baseId != null) {
          // Query SEED BOM using baseId and join ingredients by baseId
          result = await db.rawQuery('''
            SELECT rd.*, 
                   i.name as ingredientName, 
                   i.category, 
                   COALESCE(rd.unit_override, i.unit_of_measure) as unit,
                   (rd.quantity_per_base_pax * 100) as quantityPer100Pax
            FROM recipe_detail rd
            JOIN ingredients_master i ON rd.ing_id = i.baseId AND i.firmId = 'SEED'
            WHERE rd.dish_id = ? AND rd.firmId = 'SEED'
            ORDER BY i.category, i.name
          ''', [baseId]);
        }
      }
    }
    
    return result;
  }

  /// Get recipe ingredients for a dish by NAME (for Kitchen Production view)
/// Returns empty list if dish not in master or has no recipe.
Future<List<Map<String, dynamic>>> getRecipeForDishByName(String dishName, int paxQty) async {
  final db = await database;

  // Get Context
  final sp = await SharedPreferences.getInstance();
  final firmId = sp.getString('last_firm') ?? 'DEFAULT';
  final showUniversal = await getFirmUniversalDataVisibility(firmId);
  
  print('🔍 [BOM] Looking up recipe for: "$dishName" (pax: $paxQty, firmId: $firmId, showUniversal: $showUniversal)');
  
  // Step 1: Find dish_master by name
  // Prioritize FIRM specific dish over SEED dish
  // First try exact match, then fallback to LIKE match
  var where = "name = ? AND (firmId = ? ${showUniversal ? "OR firmId = 'SEED'" : ""})";
  var args = <Object>[dishName.trim(), firmId];

  var dishMaster = await db.query(
    'dish_master',
    columns: ['id', 'baseId', 'base_pax', 'firmId', 'name'],
    where: where,
    whereArgs: args,
    orderBy: "CASE WHEN firmId = '$firmId' THEN 0 ELSE 1 END", // Firm first
    limit: 1,
  );
  
  print('🔍 [BOM] Exact match query: $where, args: $args');
  print('🔍 [BOM] Exact match result: ${dishMaster.length} dishes found');
  
  // Fallback: Try case-insensitive LIKE match if exact match fails
  if (dishMaster.isEmpty) {
    where = "name LIKE ? AND (firmId = ? ${showUniversal ? "OR firmId = 'SEED'" : ""})";
    args = ['%${dishName.trim()}%', firmId];
    dishMaster = await db.query(
      'dish_master',
      columns: ['id', 'baseId', 'base_pax', 'firmId', 'name'],
      where: where,
      whereArgs: args,
      orderBy: "CASE WHEN firmId = '$firmId' THEN 0 ELSE 1 END",
      limit: 1,
    );
    print('🔍 [BOM] LIKE match query: $where, args: $args');
    print('🔍 [BOM] LIKE match result: ${dishMaster.length} dishes found');
  }

  if (dishMaster.isEmpty) {
    print('❌ [BOM] No dish found in dish_master for "$dishName"');
    return [];
  }
  
  final dishId = dishMaster.first['id'] as int;
  final baseId = dishMaster.first['baseId'];
  final basePax = (dishMaster.first['base_pax'] as int?) ?? 1;
  final isSeedDish = dishMaster.first['firmId'] == 'SEED';
  final foundName = dishMaster.first['name'] as String;
  
  print('✅ [BOM] Found dish: id=$dishId, baseId=$baseId, basePax=$basePax, isSeed=$isSeedDish, name="$foundName"');
  
  // Step 2: First try firm-specific BOM
  var recipe = await db.rawQuery('''
    SELECT rd.*, 
           i.name as ingredientName, 
           i.id as ing_id,
           i.category, 
           COALESCE(i.cost_per_unit, 0) as cost_per_unit,
           COALESCE(rd.unit_override, i.unit_of_measure) as unit,
           (rd.quantity_per_base_pax * ? / ?) as scaledQuantity
    FROM recipe_detail rd
    JOIN ingredients_master i ON rd.ing_id = i.id
    WHERE rd.dish_id = ? AND rd.firmId = ?
    ORDER BY i.category, i.name
  ''', [paxQty, basePax, dishId, firmId]);
  
  print('🔍 [BOM] Firm-specific BOM query (dish_id=$dishId, firmId=$firmId): ${recipe.length} ingredients');
  
  // Step 3: If no firm-specific BOM, try SEED BOM
  if (recipe.isEmpty) {
    // First, if it's a SEED dish with baseId, use that
    if (isSeedDish && baseId != null) {
      print('🔍 [BOM] Trying SEED BOM with baseId=$baseId');
      recipe = await db.rawQuery('''
        SELECT rd.*, 
               i.name as ingredientName, 
               i.id as ing_id,
               i.category, 
               COALESCE(i.cost_per_unit, 0) as cost_per_unit,
               COALESCE(rd.unit_override, i.unit_of_measure) as unit,
               (rd.quantity_per_base_pax * ? / ?) as scaledQuantity
        FROM recipe_detail rd
        JOIN ingredients_master i ON rd.ing_id = i.baseId AND i.firmId = 'SEED'
        WHERE rd.dish_id = ? AND rd.firmId = 'SEED'
        ORDER BY i.category, i.name
      ''', [paxQty, basePax, baseId]);
      print('🔍 [BOM] SEED BOM query result: ${recipe.length} ingredients');
    }
    
    // If still empty AND it's a firm dish, try finding SEED dish by name
    if (recipe.isEmpty && !isSeedDish && showUniversal) {
      print('🔍 [BOM] Firm dish has no BOM, trying to find SEED dish by name...');
      // Look for a SEED dish with the same name
      final seedDish = await db.query(
        'dish_master',
        columns: ['id', 'baseId', 'base_pax'],
        where: "name = ? AND firmId = 'SEED'",
        whereArgs: [foundName.trim()],
        limit: 1,
      );
      
      if (seedDish.isNotEmpty) {
        final seedBaseId = seedDish.first['baseId'];
        final seedBasePax = (seedDish.first['base_pax'] as int?) ?? 1;
        print('✅ [BOM] Found SEED dish with baseId=$seedBaseId');
        
        if (seedBaseId != null) {
          recipe = await db.rawQuery('''
            SELECT rd.*, 
                   i.name as ingredientName, 
                   i.id as ing_id,
                   i.category, 
                   COALESCE(i.cost_per_unit, 0) as cost_per_unit,
                   COALESCE(rd.unit_override, i.unit_of_measure) as unit,
                   (rd.quantity_per_base_pax * ? / ?) as scaledQuantity
            FROM recipe_detail rd
            JOIN ingredients_master i ON rd.ing_id = i.baseId AND i.firmId = 'SEED'
            WHERE rd.dish_id = ? AND rd.firmId = 'SEED'
            ORDER BY i.category, i.name
          ''', [paxQty, seedBasePax, seedBaseId]);
          print('🔍 [BOM] SEED BOM (by name) query result: ${recipe.length} ingredients');
        }
      } else {
        print('⚠️ [BOM] No SEED dish found with name "$foundName"');
      }
    }
  }
  
  if (recipe.isEmpty) {
    print('⚠️ [BOM] No ingredients found for "$dishName"');
  } else {
    print('✅ [BOM] Found ${recipe.length} ingredients for "$dishName"');
  }
  
  return recipe;
}

  Future<int> insertBomItem(Map<String, dynamic> data) async {
    final db = await database;
    // Map old 'bom' fields to 'recipe_detail' fields if necessary
    // data: { firmId, dishId, ingredientId, quantityPer100Pax, unit }
    // recipe_detail: { firmId, dish_id, ing_id, quantity_per_base_pax, unit_override }
    // Note: BOM screen inputs "Quantity for 100 pax".
    // recipe_detail stores "quantity_per_base_pax". dish_master base_pax is usually 1.
    // For V19, let's store per-pax. So input / 100.
    
    return await db.insert('recipe_detail', {
      'firmId': data['firmId'] ?? 'SEED', // Include firmId for proper firm-specific BOM
      'dish_id': data['dishId'],
      'ing_id': data['ingredientId'],
      'quantity_per_base_pax': (data['quantityPer100Pax'] as num) / 100.0, // Normalize to 1 pax
      'unit_override': data['unit'], 
      'isModified': 1, // Mark as modified for sync
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteBomItem(int id) async {
    final db = await database;
    await db.delete('recipe_detail', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateBomItem(int id, Map<String, dynamic> data) async {
    final db = await database;
    await db.update('recipe_detail', data, where: 'id = ?', whereArgs: [id]);
  }

  // --- SUPPLIERS ---
  Future<List<Map<String, dynamic>>> getAllSuppliers(String firmId) async {
    final db = await database;
    return await db.query('suppliers',
      where: 'firmId = ? AND isActive = 1',
      whereArgs: [firmId],
      orderBy: 'name',
    );
  }

  Future<int> insertSupplier(Map<String, dynamic> data) async {
    final db = await database;
    data['createdAt'] = DateTime.now().toIso8601String();
    final id = await db.insert('suppliers', data);
    await _syncOrQueue(table: 'suppliers', data: {...data, 'id': id}, action: 'INSERT');
    return id;
  }

  Future<int> updateSupplier(int id, Map<String, dynamic> data) async {
    final db = await database;
    data['updatedAt'] = DateTime.now().toIso8601String();
    final result = await db.update('suppliers', data, where: 'id = ?', whereArgs: [id]);
    await _syncOrQueue(table: 'suppliers', data: {...data, 'id': id}, action: 'UPDATE');
    return result;
  }

  // --- CUSTOMERS ---
  Future<List<Map<String, dynamic>>> getAllCustomers(String firmId) async {
    final db = await database;
    return await db.query('customers',
      where: 'firmId = ?',
      whereArgs: [firmId],
      orderBy: 'name',
    );
  }

  Future<int> insertCustomer(Map<String, dynamic> data) async {
    final db = await database;
    data['createdAt'] = DateTime.now().toIso8601String();
    final id = await db.insert('customers', data);
    await _syncOrQueue(table: 'customers', data: {...data, 'id': id}, action: 'INSERT');
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

  Future<int> insertSubcontractor(Map<String, dynamic> data) async {
    final db = await database;
    data['createdAt'] = DateTime.now().toIso8601String();
    data['isActive'] = 1; // Ensure new subcontractors are active by default
    final id = await db.insert('subcontractors', data);
    await _syncOrQueue(table: 'subcontractors', data: {...data, 'id': id}, action: 'INSERT');
    return id;
  }

  Future<int> updateSubcontractor(int id, Map<String, dynamic> data) async {
    final db = await database;
    data['updatedAt'] = DateTime.now().toIso8601String();
    final result = await db.update('subcontractors', data, where: 'id = ?', whereArgs: [id]);
    await _syncOrQueue(table: 'subcontractors', data: {...data, 'id': id}, action: 'UPDATE');
    return result;
  }

  // --- MRP ---
  /// Creates a new MRP run with auto-generated runName like "Dec-1", "Dec-2", etc.
  /// runNumber resets to 1 at the start of each month
  Future<int> createMrpRun(Map<String, dynamic> data) async {
    final db = await database;
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
    
    final id = await db.insert('mrp_runs', data);
    await _syncOrQueue(table: 'mrp_runs', data: {...data, 'id': id}, action: 'INSERT');
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
      print('❌ [BOM] Dish ID $dishMasterId not found');
      return [];
    }
    
    final basePax = (dish.first['base_pax'] as int?) ?? 1;
    final firmId = dish.first['firmId'] as String?;
    
    print('🔍 [BOM-ID] Looking up recipe for dish ID: $dishMasterId (pax: $paxQty, basePax: $basePax)');
    
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
      print('❌ [MRP Reset] Order $orderId not found');
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
        print('❌ [MRP Reset] Cannot reset order $orderId - ${activePOs.length} active POs exist');
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
    
    print('✅ [MRP Reset] Order $orderId safely reset for re-run');
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
    
    print('📦 [DB] Cancelled order $orderId after MRP: $reason');
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
      return await db.transaction((txn) async {
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
        
        print('✅ [MRP Transaction] Run #$mrpRunId completed for ${orderIds.length} orders');
        return mrpRunId;
      });
    } catch (e) {
      print('❌ [MRP Transaction] Failed: $e');
      return null;
    }
  }

  // --- PURCHASE ORDERS ---
  Future<int> createPurchaseOrder(Map<String, dynamic> data) async {
    final db = await database;
    data['createdAt'] = DateTime.now().toIso8601String();
    data['sentAt'] = DateTime.now().toIso8601String();
    final id = await db.insert('purchase_orders', data);
    await _syncOrQueue(table: 'purchase_orders', data: {...data, 'id': id}, action: 'INSERT');
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
  Future<int> insertInvoice(Map<String, dynamic> data, {List<Map<String, dynamic>>? items}) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    data['createdAt'] = now;
    data['updatedAt'] = now;
    
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
    
    final invoiceId = await db.insert('invoices', data);
    
    // Insert items if provided
    if (items != null && items.isNotEmpty) {
      await insertInvoiceItems(invoiceId, items);
    }
    
    // Sync to AWS
    await _syncOrQueue(table: 'invoices', data: {...data, 'id': invoiceId}, action: 'INSERT');
    
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
  Future<int> updateInvoice(int id, Map<String, dynamic> data) async {
    final db = await database;
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
    
    final rows = await db.update('invoices', data, where: 'id = ?', whereArgs: [id]);
    await _syncOrQueue(table: 'invoices', data: {...data, 'id': id}, action: 'UPDATE', filters: {'id': id});
    return rows;
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

  /// Auto-create invoice from order
  Future<int> createInvoiceFromOrder(int orderId, String firmId) async {
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
    
    // Create invoice
    return await insertInvoice({
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
    final days90 = now.subtract(const Duration(days: 90)).toIso8601String().substring(0, 10);
    
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
    final db = await database;
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

  /// Get event/order profitability

  Future<Map<String, dynamic>> getEventProfitability(int orderId, String firmId) async {
    final db = await database;
    
    // Get order revenue
    final order = await db.query('orders', where: 'id = ?', whereArgs: [orderId]);
    if (order.isEmpty) return {};
    
    final orderData = order.first;
    final revenue = (orderData['grandTotal'] as num?)?.toDouble() ?? 
                   (orderData['totalAmount'] as num?)?.toDouble() ?? 0;
    
    // Get linked expenses
    final expenses = await db.rawQuery('''
      SELECT category, COALESCE(SUM(amount), 0) as total
      FROM transactions
      WHERE relatedEntityType = 'ORDER' AND relatedEntityId = ? AND type = 'EXPENSE'
      GROUP BY category
    ''', [orderId]);
    
    double totalCost = 0;
    for (var e in expenses) {
      totalCost += (e['total'] as num?)?.toDouble() ?? 0;
    }
    
    return {
      'orderId': orderId,
      'revenue': revenue,
      'costs': expenses,
      'totalCost': totalCost,
      'profit': revenue - totalCost,
      'margin': revenue > 0 ? ((revenue - totalCost) / revenue * 100) : 0,
    };
  }

  // Generate PO Number
  Future<String> generatePoNumber(String firmId) async {
    final db = await database;
    final today = DateTime.now();
    final prefix = 'PO${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';
    final count = Sqflite.firstIntValue(await db.rawQuery(
      "SELECT COUNT(*) FROM purchase_orders WHERE firmId = ? AND poNumber LIKE ?",
      [firmId, '$prefix%'],
    )) ?? 0;
    return '$prefix-${(count + 1).toString().padLeft(3, '0')}';
  }

  // --- MRP RE-RUN SUPPORT ---
  
  /// Cancel all POs for a specific order (soft-delete with status = 'CANCELLED')
  /// Returns list of cancelled PO IDs for notification purposes
  Future<List<Map<String, dynamic>>> cancelPOsForOrder(int orderId) async {
    final db = await database;
    
    // Find all POs that include this order
    final allPOs = await db.query('purchase_orders');
    final cancelledPOs = <Map<String, dynamic>>[];
    
    for (final po in allPOs) {
      final orderIds = po['orderIds']?.toString() ?? '';
      if (orderIds.split(',').map((s) => s.trim()).contains(orderId.toString())) {
        // Skip already cancelled POs
        if (po['status'] == 'CANCELLED') continue;
        
        // Update PO status to CANCELLED
        await db.update(
          'purchase_orders',
          {
            'status': 'CANCELLED',
            'cancelledAt': DateTime.now().toIso8601String(),
            'cancelReason': 'Order updated - MRP re-run required',
          },
          where: 'id = ?',
          whereArgs: [po['id']],
        );
        
        cancelledPOs.add(po);
      }
    }
    
    print('📦 [DB] Cancelled ${cancelledPOs.length} POs for order $orderId');
    return cancelledPOs;
  }

  /// Reset order MRP status to allow re-running MRP
  Future<void> resetOrderForMRP(int orderId) async {
    final db = await database;
    
    await db.update(
      'orders',
      {
        'mrpStatus': 'PENDING',
        'mrpRunId': null,
        'isLocked': 0,
        'lockedAt': null,
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );
    
    print('📦 [DB] Reset order $orderId for MRP re-run');
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
             v.vehicleNo, v.vehicleType
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
    final db = await database;
    final now = DateTime.now().toIso8601String();
    
    Map<String, dynamic> updates = {'assignmentStatus': status};
    if (status == 'ACCEPTED') {
      updates['acceptedAt'] = now;
    } else if (status == 'REJECTED') {
      updates['rejectedAt'] = now;
      updates['rejectionReason'] = rejectionReason;
      updates['driverId'] = null; // Unassign so admin can reassign
    }
    
    await db.update('dispatches', updates, where: 'id = ?', whereArgs: [dispatchId]);
  }

  /// Update dispatch km tracking and earnings
  Future<void> updateDispatchKmAndEarnings(int dispatchId, {
    double? kmForward,
    double? kmReturn,
    double? driverShare,
  }) async {
    final db = await database;
    Map<String, dynamic> updates = {'updatedAt': DateTime.now().toIso8601String()};
    if (kmForward != null) updates['kmForward'] = kmForward;
    if (kmReturn != null) updates['kmReturn'] = kmReturn;
    if (driverShare != null) updates['driverShare'] = driverShare;
    
    await db.update('dispatches', updates, where: 'id = ?', whereArgs: [dispatchId]);
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
    if (status == 'ACCEPTED') updates['acceptedAt'] = now;
    else if (status == 'DISPATCHED') updates['dispatchedAt'] = now;
    else if (status == 'DELIVERED') updates['deliveredAt'] = now;
    
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

}

