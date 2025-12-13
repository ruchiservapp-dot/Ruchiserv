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
import '../services/connectivity_service.dart';
import '../db/aws/aws_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDB("ruchiserv.db");
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    if (kIsWeb) {
      // Web-specific: Set global factory and use simple path
      databaseFactory = databaseFactoryFfiWeb;
      return await openDatabase(
        fileName,
        version: 28, // v28: Add all missing tables defensively
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } else {
      // Mobile/Desktop initialization
      final dir = await getApplicationDocumentsDirectory();
      final path = join(dir.path, fileName);
      return await openDatabase(
        path,
        version: 28, // v28: Add all missing tables defensively
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // === ORDERS ====================================================
    await db.execute('''
      CREATE TABLE IF NOT EXISTS orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firmId TEXT NOT NULL DEFAULT 'DEFAULT',
        date TEXT NOT NULL,
        customerName TEXT NOT NULL,
        mobile TEXT,
        email TEXT,
        location TEXT,
        mealType TEXT,
        foodType TEXT,
        time TEXT,
        notes TEXT,
        beforeDiscount REAL DEFAULT 0,
        discountPercent REAL DEFAULT 0,
        discountAmount REAL DEFAULT 0,
        finalAmount REAL DEFAULT 0,
        totalPax INTEGER DEFAULT 0,
        isLocked INTEGER DEFAULT 0,
        serviceRequired INTEGER DEFAULT 0,
        serviceType TEXT,
        counterCount INTEGER DEFAULT 1,
        staffCount INTEGER DEFAULT 0,
        staffRate REAL DEFAULT 0,
        counterSetupRequired INTEGER DEFAULT 0,
        counterSetupRate REAL DEFAULT 0,
        serviceCost REAL DEFAULT 0,
        counterSetupCost REAL DEFAULT 0,
        grandTotal REAL DEFAULT 0,
        dispatchStatus TEXT,
        dispatchedAt TEXT,
        createdAt TEXT,
        updatedAt TEXT
      );
    ''');

    // === LOCAL USERS (offline login cache) =========================
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        firm_id INTEGER,
        username TEXT,
        email TEXT,
        password TEXT,
        role TEXT,
        is_active INTEGER DEFAULT 1,
        last_login TEXT
      );
    ''');

    // === DISHES ====================================================
    await db.execute('''
      CREATE TABLE IF NOT EXISTS dishes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orderId INTEGER NOT NULL,
        name TEXT NOT NULL,
        foodType TEXT,
        pax INTEGER DEFAULT 0,
        rate INTEGER DEFAULT 0,
        manualCost INTEGER DEFAULT 0,
        cost INTEGER DEFAULT 0,
        category TEXT,
        productionStatus TEXT DEFAULT 'PENDING', -- PENDING, QUEUED, COMPLETED
        productionType TEXT DEFAULT 'INTERNAL', -- INTERNAL, SUBCONTRACT, LIVE
        subcontractorId TEXT,
        readyAt TEXT,
        createdAt TEXT,
        FOREIGN KEY(orderId) REFERENCES orders(id) ON DELETE CASCADE
      );
    ''');

    // === FIRMS =====================================================
    await db.execute('''
      CREATE TABLE IF NOT EXISTS firms(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firmId TEXT UNIQUE NOT NULL,
        firmName TEXT NOT NULL,
        contactPerson TEXT,
        mobile TEXT,
        primaryMobile TEXT,
        alternateMobile TEXT,
        email TEXT,
        primaryEmail TEXT,
        alternateEmail TEXT,
        address TEXT,
        gst TEXT,
        gstNumber TEXT,
        ownerName TEXT,
        website TEXT,
        subscriptionPlan TEXT,
        subscriptionTier TEXT DEFAULT 'BASIC',
        subscriptionStart TEXT,
        subscriptionEnd TEXT,
        subscriptionExpiry TEXT,
        subscriptionStatus TEXT DEFAULT 'Active',
        enabledFeatures TEXT,
        allowedModules TEXT,
        maxUsers INTEGER DEFAULT 5,
        capacity INTEGER DEFAULT 500,
        billingCycle TEXT,
        paymentMode TEXT,
        lastRenewalTxnId TEXT,
        kitchenLatitude REAL,
        kitchenLongitude REAL,
        geoFenceRadius INTEGER DEFAULT 100,
        otMultiplier REAL DEFAULT 1.5,
        showUniversalData INTEGER DEFAULT 1,
        createdAt TEXT,
        updatedAt TEXT
      );
    ''');

    // === USERS =====================================================
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firmId TEXT NOT NULL,
        userId TEXT UNIQUE NOT NULL,
        username TEXT NOT NULL,
        passwordHash TEXT NOT NULL,
        role TEXT DEFAULT 'User',
        permissions TEXT,
        moduleAccess TEXT,
        showRates INTEGER DEFAULT 1,
        mobile TEXT,
        email TEXT,
        isActive INTEGER DEFAULT 1,
        biometricEnabled INTEGER DEFAULT 0,
        lastLogin TEXT,
        createdAt TEXT,
        updatedAt TEXT,
        FOREIGN KEY(firmId) REFERENCES firms(firmId)
      );
    ''');

    // === AUTH LOGS =================================================
    await db.execute('''
      CREATE TABLE IF NOT EXISTS auth_logs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId TEXT NOT NULL,
        action TEXT,
        description TEXT,
        timestamp TEXT
      );
    ''');
    
    // === AUDIT LOG (v26) ===========================================
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

    // === PENDING SYNC (offline queue) ==============================
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_sync (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT,
        data TEXT,          -- JSON blob
        action TEXT,        -- INSERT | UPDATE | DELETE
        timestamp TEXT
      );
    ''');

    // === AUTHORIZED MOBILES (Mobile Authorization) ================
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

    // NOTE: dish_master is now defined later with v19 schema (includes region, base_pax)

    // === VEHICLES (for Dispatch module) ================================
    await db.execute('''
      CREATE TABLE IF NOT EXISTS vehicles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firmId TEXT NOT NULL,
        vehicleNo TEXT NOT NULL,
        vehicleType TEXT, -- Tempo, Van, Truck, Auto etc.
        type TEXT DEFAULT 'INHOUSE', -- INHOUSE / OUTSIDE
        driverName TEXT,
        driverMobile TEXT,
        capacity INTEGER DEFAULT 0,
        isActive INTEGER DEFAULT 1,
        isModified INTEGER DEFAULT 0,
        createdAt TEXT,
        updatedAt TEXT
      );
    ''');

    // === DISPATCHES ====================================================
    await db.execute('''
      CREATE TABLE IF NOT EXISTS dispatches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orderId INTEGER NOT NULL,
        vehicleId INTEGER,
        dispatchTime TEXT,
        dispatchStatus TEXT DEFAULT 'PENDING', -- PENDING, LOADING, DISPATCHED, DELIVERED, RETURNING, COMPLETED
        returnVehicleId INTEGER,
        returnTime TEXT,
        driverLat REAL,
        driverLng REAL,
        lastLocationUpdate TEXT,
        notes TEXT,
        createdAt TEXT,
        updatedAt TEXT,
        FOREIGN KEY(orderId) REFERENCES orders(id),
        FOREIGN KEY(vehicleId) REFERENCES vehicles(id)
      );
    ''');

    // === DISPATCH ITEMS (Dishes + Utensils + Consumables) ==============
    await db.execute('''
      CREATE TABLE IF NOT EXISTS dispatch_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dispatchId INTEGER NOT NULL,
        itemType TEXT NOT NULL, -- DISH, UTENSIL, CONSUMABLE
        itemName TEXT NOT NULL,
        quantity INTEGER DEFAULT 0,
        loadedQty INTEGER DEFAULT 0,
        returnedQty INTEGER DEFAULT 0,
        unloadedQty INTEGER DEFAULT 0,
        status TEXT DEFAULT 'PENDING', -- PENDING, LOADED, RETURNED, VERIFIED, MISSING
        notes TEXT,
        FOREIGN KEY(dispatchId) REFERENCES dispatches(id)
      );
    ''');

    // === UTENSILS MASTER ===============================================
    await db.execute('''
      CREATE TABLE IF NOT EXISTS utensils (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firmId TEXT NOT NULL,
        name TEXT NOT NULL,
        category TEXT DEFAULT 'SERVING', -- SERVING, COOKING, CUTLERY, CONSUMABLE
        totalStock INTEGER DEFAULT 0,
        availableStock INTEGER DEFAULT 0,
        isReturnable INTEGER DEFAULT 1,
        isModified INTEGER DEFAULT 0,
        createdAt TEXT,
        updatedAt TEXT,
        UNIQUE(firmId, name)
      );
    ''');

    // === STAFF MANAGEMENT ================================================
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

    // === ATTENDANCE ======================================================
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

    // === STAFF ASSIGNMENTS ===============================================
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

    // === STAFF ADVANCES ==================================================
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

    // === TRANSACTIONS (Finance Module) =================================
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

    // === INGREDIENTS MASTER (v22) ================================
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ingredients_master (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firmId TEXT NOT NULL DEFAULT 'SEED',
        baseId INTEGER,
        name TEXT NOT NULL,
        sku_name TEXT,
        unit_of_measure TEXT,
        cost_per_unit REAL DEFAULT 0,
        category TEXT,
        isModified INTEGER DEFAULT 0,
        createdAt TEXT,
        updatedAt TEXT
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ingredients_firmId ON ingredients_master(firmId);');

    // === DISH MASTER (v22) ================================
    await db.execute('''
      CREATE TABLE IF NOT EXISTS dish_master (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firmId TEXT NOT NULL DEFAULT 'SEED',
        baseId INTEGER,
        name TEXT NOT NULL,
        region TEXT,
        category TEXT,
        base_pax INTEGER DEFAULT 1,
        rate INTEGER DEFAULT 0,
        foodType TEXT DEFAULT 'Veg',
        isModified INTEGER DEFAULT 0,
        createdAt TEXT,
        updatedAt TEXT
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_dish_firmId ON dish_master(firmId);');

    // === RECIPE DETAIL / BOM (v22) ================================
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recipe_detail (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firmId TEXT NOT NULL DEFAULT 'SEED',
        baseId INTEGER,
        dish_id INTEGER NOT NULL,
        ing_id INTEGER NOT NULL,
        quantity_per_base_pax REAL NOT NULL,
        unit_override TEXT,
        isModified INTEGER DEFAULT 0,
        FOREIGN KEY(dish_id) REFERENCES dish_master(id),
        FOREIGN KEY(ing_id) REFERENCES ingredients_master(id)
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_recipe_firmId ON recipe_detail(firmId);');

    // === CONTENT TRANSLATIONS (v21) ================================
    await db.execute('''
      CREATE TABLE IF NOT EXISTS content_translations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id INTEGER NOT NULL,
        language_code TEXT NOT NULL,
        field_name TEXT DEFAULT 'name',
        translated_text TEXT NOT NULL,
        created_at TEXT,
        UNIQUE(entity_type, entity_id, language_code, field_name)
      );
    ''');
    
    // Load seed data (ingredients, dishes, BOM)
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
        } catch (_) {
          // Ignore duplicates
        }
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
  Future<void> _syncOrQueue({
    required String table,
    required Map<String, dynamic> data,
    required String action, // 'INSERT', 'UPDATE', 'DELETE'
    Map<String, dynamic>? filters,
  }) async {
    // 1. Try Online Sync
    bool synced = false;
    try {
      if (await ConnectivityService().isOnline()) {
         // Call AwsApi
         final method = action == 'INSERT' ? 'POST' : (action == 'UPDATE' ? 'PUT' : 'DELETE');
         
         final resp = await AwsApi.callDbHandler(
           method: method,
           table: table,
           data: data,
           filters: filters,
         );
         
         if ((resp['status']?.toString().toLowerCase() ?? '') == 'success') {
           synced = true;
           // print('✅ [AWS Sync] $action $table success');
         } else {
           // print('⚠️ [AWS Sync] $action $table failed: ${resp['message']}');
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
      where:
          "orderId = ? AND name IS NOT NULL AND name != '' AND name != 'Unnamed'",
      whereArgs: [orderId],
      orderBy: 'id ASC',
    );
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
    return await db.rawQuery('''
      SELECT 
        o.date,
        SUM(CASE WHEN o.foodType = 'Veg' THEN o.totalPax ELSE 0 END) AS vegPax,
        SUM(CASE WHEN o.foodType = 'Non-Veg' THEN o.totalPax ELSE 0 END) AS nonVegPax,
        SUM(o.totalPax) AS totalPax
      FROM orders o
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
      orderBy: 'time ASC',
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
        SUM(CASE WHEN d.status = 'Delivered' THEN 1 ELSE 0 END) as delivered,
        SUM(CASE WHEN d.status = 'In Transit' THEN 1 ELSE 0 END) as inTransit,
        SUM(CASE WHEN d.status = 'Pending' OR d.status IS NULL THEN 1 ELSE 0 END) as pending,
        COUNT(DISTINCT o.id) as ordersCount
      FROM dispatch d
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
        COALESCE(address, 'Unknown') as location,
        COUNT(*) as orderCount,
        SUM(totalPax) as totalPax,
        SUM(CASE WHEN isCancelled = 0 OR isCancelled IS NULL THEN finalAmount ELSE 0 END) as revenue
      FROM orders
      WHERE date BETWEEN ? AND ?
      GROUP BY address
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

  final customizedBaseIds = firmData.map((r) => r['baseId']).where((id) => id != null).toList();
  
  String seedWhere = "firmId = 'SEED'";
  if (customizedBaseIds.isNotEmpty) {
    seedWhere += " AND baseId NOT IN (${customizedBaseIds.join(',')})";
  }
  
  final seedData = await db.rawQuery(
    'SELECT * FROM dish_master WHERE $seedWhere ORDER BY category, name',
  );
  
  final combined = [...firmData, ...seedData];
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

  final customizedBaseIds = firmData.map((r) => r['baseId']).where((id) => id != null).toList();
  
  String seedWhere = "firmId = 'SEED'";
  if (customizedBaseIds.isNotEmpty) {
    seedWhere += " AND baseId NOT IN (${customizedBaseIds.join(',')})";
  }

  final seedData = await db.rawQuery(
    'SELECT * FROM ingredients_master WHERE $seedWhere ORDER BY category, name',
  );
  
  // 3. Merge & Sort
  final combined = [...firmData, ...seedData];
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
    // V19: Use recipe_detail joined with ingredients_master
    // Also return quantityPer100Pax for UI convenience
    return await db.rawQuery('''
      SELECT rd.*, 
             i.name as ingredientName, 
             i.category, 
             COALESCE(rd.unit_override, i.unit_of_measure) as unit,
             (rd.quantity_per_base_pax * 100) as quantityPer100Pax
      FROM recipe_detail rd
      JOIN ingredients_master i ON rd.ing_id = i.id
      WHERE rd.dish_id = ?
      ORDER BY i.category, i.name
    ''', [dishId]);
  }

  /// Get recipe ingredients for a dish by NAME (for Kitchen Production view)
/// Returns empty list if dish not in master or has no recipe.
Future<List<Map<String, dynamic>>> getRecipeForDishByName(String dishName, int paxQty) async {
  final db = await database;

  // Get Context
  final sp = await SharedPreferences.getInstance();
  final firmId = sp.getString('last_firm') ?? 'DEFAULT';
  final showUniversal = await getFirmUniversalDataVisibility(firmId);
  
  // Step 1: Find dish_master ID by name
  // Prioritize FIRM specific dish over SEED dish
  final where = "name = ? AND (firmId = ? ${showUniversal ? "OR firmId = 'SEED'" : ""})";
  final args = [dishName.trim(), firmId];

  final dishMaster = await db.query(
    'dish_master',
    columns: ['id', 'base_pax', 'firmId'],
    where: where,
    whereArgs: args,
    orderBy: "CASE WHEN firmId = '$firmId' THEN 0 ELSE 1 END", // Firm first
    limit: 1,
  );

  if (dishMaster.isEmpty) return [];
  
  final dishId = dishMaster.first['id'] as int;
  final basePax = (dishMaster.first['base_pax'] as int?) ?? 1;
  
  // Step 2: Get recipe_detail for this dish_id, scaled by paxQty
  final recipe = await db.rawQuery('''
    SELECT rd.*, 
           i.name as ingredientName, 
           i.category, 
           COALESCE(rd.unit_override, i.unit_of_measure) as unit,
           (rd.quantity_per_base_pax * ? / ?) as scaledQuantity
    FROM recipe_detail rd
    JOIN ingredients_master i ON rd.ing_id = i.id
    WHERE rd.dish_id = ?
    ORDER BY i.category, i.name
  ''', [paxQty, basePax, dishId]);
  
  return recipe;
}

  Future<int> insertBomItem(Map<String, dynamic> data) async {
    final db = await database;
    // Map old 'bom' fields to 'recipe_detail' fields if necessary
    // data: { dishId, ingredientId, quantityPer100Pax, unit }
    // recipe_detail: { dish_id, ing_id, quantity_per_base_pax, unit_override }
    // Note: BOM screen inputs "Quantity for 100 pax".
    // recipe_detail stores "quantity_per_base_pax". dish_master base_pax is usually 1.
    // If we want to store per 1 pax: data['quantityPer100Pax'] / 100.
    // However, the prompt/previous context implies 'quantity_per_base_pax' might be what's stored.
    // Let's assume for now we store exactly what is passed or normalized. 
    // Actually, looking at seed data, it's float quantities.
    // Let's standardise: The UI asks for "Quantity for 100 pax".
    // We should probably store it normalized or as is. 
    // Let's check `dish_master.base_pax`. Currently it defaults to 1.
    // To match legacy behavior where we might want per-pax or per-100-pax:
    // For V19, let's store per-pax. So input / 100.
    
    return await db.insert('recipe_detail', {
      'dish_id': data['dishId'],
      'ing_id': data['ingredientId'],
      'quantity_per_base_pax': (data['quantityPer100Pax'] as num) / 100.0, // Normalize to 1 pax
      'unit_override': data['unit'], 
      // 'id' is auto-increment or explicit. Here auto-increment.
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
    return await db.insert('suppliers', data);
  }

  Future<int> updateSupplier(int id, Map<String, dynamic> data) async {
    final db = await database;
    data['updatedAt'] = DateTime.now().toIso8601String();
    return await db.update('suppliers', data, where: 'id = ?', whereArgs: [id]);
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
    return await db.insert('subcontractors', data);
  }

  Future<int> updateSubcontractor(int id, Map<String, dynamic> data) async {
    final db = await database;
    data['updatedAt'] = DateTime.now().toIso8601String();
    return await db.update('subcontractors', data, where: 'id = ?', whereArgs: [id]);
  }

  // --- MRP ---
  Future<int> createMrpRun(Map<String, dynamic> data) async {
    final db = await database;
    data['createdAt'] = DateTime.now().toIso8601String();
    return await db.insert('mrp_runs', data);
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
      SELECT mo.*, i.name as ingredientName
      FROM mrp_output mo
      JOIN ingredients i ON mo.ingredientId = i.id
      WHERE mo.mrpRunId = ?
      ORDER BY mo.category, i.name
    ''', [mrpRunId]);
  }

  Future<void> lockOrdersForMrp(int mrpRunId, List<int> orderIds) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    for (var orderId in orderIds) {
      await db.update('orders', {
        'mrpRunId': mrpRunId,
        'isLocked': 1,
        'lockedAt': now,
      }, where: 'id = ?', whereArgs: [orderId]);
    }
  }

  // --- PURCHASE ORDERS ---
  Future<int> createPurchaseOrder(Map<String, dynamic> data) async {
    final db = await database;
    data['createdAt'] = DateTime.now().toIso8601String();
    data['sentAt'] = DateTime.now().toIso8601String();
    return await db.insert('purchase_orders', data);
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

  // --- INVOICES ---
  Future<int> insertInvoice(Map<String, dynamic> data) async {
    final db = await database;
    data['createdAt'] = DateTime.now().toIso8601String();
    return await db.insert('invoices', data);
  }

  Future<List<Map<String, dynamic>>> getInvoices(String firmId, {String? status}) async {
    final db = await database;
    String where = 'firmId = ?';
    List<dynamic> args = [firmId];
    if (status != null) {
      where += ' AND status = ?';
      args.add(status);
    }
    return await db.query('invoices',
      where: where,
      whereArgs: args,
      orderBy: 'createdAt DESC',
    );
  }

  Future<int> updateInvoice(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update('invoices', data, where: 'id = ?', whereArgs: [id]);
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
}
