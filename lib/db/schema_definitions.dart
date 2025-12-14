class TableSchema {
  final String tableName;
  final Map<String, String> columns; // ColumnName -> Definition (e.g., "TEXT NOT NULL")
  final List<String> constraints; // UNIQUE, FOREIGN KEY, etc.

  const TableSchema({
    required this.tableName,
    required this.columns,
    this.constraints = const [],
  });

  String get createTableSql {
    final colDefs = columns.entries.map((e) => '${e.key} ${e.value}').toList();
    final allDefs = [...colDefs, ...constraints].join(',\n  ');
    return 'CREATE TABLE IF NOT EXISTS $tableName (\n  $allDefs\n);';
  }
}

class AppSchema {
  static const List<TableSchema> tables = [
    // 1. Firms (Multi-tenancy)
    TableSchema(
      tableName: 'firms',
      columns: {
        'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
        'firmId': 'TEXT NOT NULL UNIQUE',
        'name': 'TEXT NOT NULL DEFAULT "My Firm"',
        'mobile': 'TEXT',
        'address': 'TEXT',
        'gstin': 'TEXT',
        'logoUrl': 'TEXT',
        'subscriptionStatus': 'TEXT DEFAULT "ACTIVE"',
        'subscriptionPlan': 'TEXT DEFAULT "FREE"',
        'subscriptionExpiry': 'TEXT',
        'createdAt': 'TEXT',
        'updatedAt': 'TEXT',
        'showUniversalData': 'INTEGER DEFAULT 1', // v23
      },
    ),

    // 2. Users (App Access)
    TableSchema(
      tableName: 'users',
      columns: {
        'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
        'userId': 'TEXT NOT NULL UNIQUE',
        'firmId': 'TEXT NOT NULL',
        'name': 'TEXT NOT NULL DEFAULT "User"',
        'mobile': 'TEXT NOT NULL',
        'role': 'TEXT NOT NULL', // ADMIN, MANAGER, STAFF
        'permissions': 'TEXT', // JSON array of permissions
        'isActive': 'INTEGER DEFAULT 1',
        'lastLogin': 'TEXT',
        'createdAt': 'TEXT',
        'updatedAt': 'TEXT',
      },
    ),

    // 3. Authorized Mobiles (Login allowlist)
    TableSchema(
      tableName: 'authorized_mobiles',
      columns: {
        'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
        'firmId': 'TEXT NOT NULL',
        'mobile': 'TEXT NOT NULL',
        'role': 'TEXT',
        'name': 'TEXT',
        'addedBy': 'TEXT',
        'addedAt': 'TEXT',
      },
      constraints: ['UNIQUE(firmId, mobile)'],
    ),
    
    // 4. Staff (HR/Payroll)
    TableSchema(
        tableName: 'staff',
        columns: {
          'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
          'firmId': 'TEXT NOT NULL',
          'name': 'TEXT NOT NULL',
          'role': 'TEXT',
          'mobile': 'TEXT',
          'email': 'TEXT',
          'salary': 'REAL DEFAULT 0',
          'joinDate': 'TEXT',
          'isActive': 'INTEGER DEFAULT 1',
          'staffType': 'TEXT DEFAULT \'PERMANENT\'',
          'dailyWageRate': 'REAL DEFAULT 0',
          'hourlyRate': 'REAL DEFAULT 0',
          'payoutFrequency': 'TEXT DEFAULT \'MONTHLY\'',
          'bankAccountNo': 'TEXT',
          'bankIfsc': 'TEXT',
          'bankName': 'TEXT',
          'aadharNumber': 'TEXT',
          'emergencyContact': 'TEXT',
          'emergencyContactName': 'TEXT',
          'address': 'TEXT',
          'photoUrl': 'TEXT',
          'createdAt': 'TEXT',
          'updatedAt': 'TEXT',
        }
    ),

    // 5. Attendance
    TableSchema(
        tableName: 'attendance',
        columns: {
          'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
          'staffId': 'INTEGER NOT NULL',
          'date': 'TEXT NOT NULL',
          'punchInTime': 'TEXT',
          'punchOutTime': 'TEXT',
          'punchInLat': 'REAL',
          'punchInLng': 'REAL',
          'punchOutLat': 'REAL',
          'punchOutLng': 'REAL',
          'status': 'TEXT DEFAULT \'PRESENT\'',
          'overtimeHours': 'REAL DEFAULT 0',
          'notes': 'TEXT',
          'lockedAt': 'TEXT',
          'mrpRunId': 'INTEGER',
          'isLocked': 'INTEGER DEFAULT 0',
        },
        constraints: ['UNIQUE(staffId, date)']
    ),

    // 6. Customers (Clients)
    TableSchema(
      tableName: 'customers',
      columns: {
        'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
        'firmId': 'TEXT NOT NULL',
        'name': 'TEXT NOT NULL',
        'mobile': 'TEXT',
        'email': 'TEXT',
        'address': 'TEXT',
        'gstin': 'TEXT',
        'notes': 'TEXT',
        'createdAt': 'TEXT',
        'updatedAt': 'TEXT',
      },
    ),

    // 7. Orders (Catering Orders)
    TableSchema(
      tableName: 'orders',
      columns: {
        'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
        'firmId': 'TEXT NOT NULL',
        'customerId': 'INTEGER NOT NULL DEFAULT 0',
        'eventDate': 'TEXT NOT NULL DEFAULT ""',
        'eventTime': 'TEXT',
        'venue': 'TEXT', // v30
        'pax': 'INTEGER NOT NULL DEFAULT 0',
        'totalAmount': 'REAL DEFAULT 0',
        'advanceAmount': 'REAL DEFAULT 0',
        'status': 'TEXT DEFAULT "CONFIRMED"', // v30
        'notes': 'TEXT',
        'isCancelled': 'INTEGER DEFAULT 0', // v30
        'dispatchStatus': 'TEXT DEFAULT "PENDING"', // Fixed: Used in code
        'dispatchedAt': 'TEXT',
        'returnedAt': 'TEXT', // v26
        'createdAt': 'TEXT',
        'updatedAt': 'TEXT',
        'lockedAt': 'TEXT',
        'mrpRunId': 'INTEGER',
        'mrpStatus': 'TEXT DEFAULT "PENDING"', // PENDING, MRP_DONE, PO_SENT, PROCESSED
        'isLocked': 'INTEGER DEFAULT 0',
        
        // Legacy Columns (Active in Code)
        'date': 'TEXT', 
        'customerName': 'TEXT', 
        'mobile': 'TEXT', 
        'totalPax': 'INTEGER DEFAULT 0',
        'foodType': 'TEXT',
        'mealType': 'TEXT',
        'location': 'TEXT',
        'grandTotal': 'REAL DEFAULT 0',
      },
    ),

    // 8. Order Dishes (Menu)
    TableSchema(
      tableName: 'dishes', // Corrected to match existing code usage
      columns: {
        'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
        'orderId': 'INTEGER NOT NULL',
        'dishId': 'INTEGER', // Optional/Deprecated in favor of name?
        'dishName': 'TEXT NOT NULL DEFAULT "Dish"',
        'category': 'TEXT',
        'pax': 'INTEGER',
        'pricePerPlate': 'REAL',
        'isSubcontracted': 'INTEGER DEFAULT 0', // v31
        'subcontractorId': 'INTEGER', // v31
        'productionType': 'TEXT DEFAULT "INTERNAL"', // v32 - INTERNAL, SUBCONTRACT, LIVE
        'productionStatus': 'TEXT DEFAULT "PENDING"', // v32 - PENDING, QUEUED, COMPLETED
        'notes': 'TEXT',
      },
    ),

    // 9. Finance (Transactions)
    TableSchema(
      tableName: 'finance',
      columns: {
        'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
        'firmId': 'TEXT NOT NULL',
        'type': 'TEXT NOT NULL', // INCOME, EXPENSE
        'category': 'TEXT NOT NULL',
        'amount': 'REAL NOT NULL',
        'date': 'TEXT NOT NULL',
        'description': 'TEXT',
        'paymentMode': 'TEXT',
        'partyName': 'TEXT',
        'referenceId': 'TEXT', // For tying to OrderID/BillID
        'imageUrl': 'TEXT',
        'createdBy': 'TEXT',
        'createdAt': 'TEXT',
      },
    ),

    // 10. Utensils (Inventory)
    TableSchema(
      tableName: 'utensils',
      columns: {
        'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
        'firmId': 'TEXT NOT NULL',
        'name': 'TEXT NOT NULL',
        'totalStock': 'INTEGER DEFAULT 0',
        'availableStock': 'INTEGER DEFAULT 0',
        'category': 'TEXT',
        'imageUrl': 'TEXT',
        'unit': 'TEXT DEFAULT "pcs"', // v17
        'createdAt': 'TEXT', // v17
        'updatedAt': 'TEXT', // v17
        'isModified': 'INTEGER DEFAULT 0', // v26
      },
    ),

    // 11. Dispatch (Utensil movement)
    TableSchema(
      tableName: 'dispatch',
      columns: {
        'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
        'orderId': 'INTEGER NOT NULL',
        'utensilId': 'INTEGER NOT NULL',
        'dispatchedQty': 'INTEGER DEFAULT 0',
        'returnedQty': 'INTEGER DEFAULT 0',
        'missingQty': 'INTEGER DEFAULT 0',
        'dispatchedAt': 'TEXT',
        'returnedAt': 'TEXT',
        'status': 'TEXT', // DISPATCHED, RETURNED
      },
    ),
    
    // 12. Vehicles (Logistics)
    TableSchema(
      tableName: 'vehicles',
      columns: {
        'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
        'firmId': 'TEXT NOT NULL',
        'vehicleNumber': 'TEXT NOT NULL DEFAULT "Temp"',
        'driverName': 'TEXT',
        'driverMobile': 'TEXT',
        'vehicleType': 'TEXT', // TRUCK, VAN, AUTO
        'status': 'TEXT DEFAULT "AVAILABLE"',
        'notes': 'TEXT',
        'isModified': 'INTEGER DEFAULT 0', // v26
      },
      constraints: ['UNIQUE(firmId, vehicleNumber)'],
    ),

    // 13. Ingredients Master (Raw Materials)
    TableSchema(
      tableName: 'ingredients_master',
      columns: {
        'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
        'firmId': 'TEXT DEFAULT "SEED"', // v22
        'baseId': 'INTEGER', // v22
        'name': 'TEXT NOT NULL',
        'category': 'TEXT',
        'subcategory': 'TEXT',
        'unit_of_measure': 'TEXT DEFAULT "kg"', // Corrected from 'unit' to match usage
        'cost_per_unit': 'REAL DEFAULT 0', // Corrected from 'defaultPrice'
        'supplierId': 'INTEGER',
        'isActive': 'INTEGER DEFAULT 1',
        'isSystemPreloaded': 'INTEGER DEFAULT 0',
        'isModified': 'INTEGER DEFAULT 0', // v22
        'createdAt': 'TEXT',
        'updatedAt': 'TEXT',
      },
    ),

    // 14. Dish Master (Menu Items)
    TableSchema(
      tableName: 'dish_master', // Renamed from 'dishes' to match actual usage if verified
       // Note: The code often uses 'dish_master'. Checking usage...
       // Yes, getAllDishes uses 'dish_master'.
      columns: {
        'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
        'firmId': 'TEXT DEFAULT "SEED"', // v22
        'baseId': 'INTEGER', // v22
        'name': 'TEXT NOT NULL',
        'region': 'TEXT',
        'category': 'TEXT',
        'base_pax': 'INTEGER DEFAULT 1',
        'isModified': 'INTEGER DEFAULT 0', // v22
        'createdAt': 'TEXT',
        'updatedAt': 'TEXT',
        'readyAt': 'TEXT', // v24 (was added to 'dishes' in migration, assuming dish_master is the target)
      },
    ),

    // 15. Recipe Detail (BOM)
    TableSchema(
      tableName: 'recipe_detail', // Renamed from 'bom' to match actual usage
      columns: {
        'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
        'firmId': 'TEXT DEFAULT "SEED"', // v22
        'baseId': 'INTEGER', // v22
        'dish_id': 'INTEGER NOT NULL', // matches actual usage
        'ing_id': 'INTEGER NOT NULL', // matches actual usage
        'quantity_per_base_pax': 'REAL NOT NULL', // matches actual usage
        'unit_override': 'TEXT NOT NULL', // matches actual usage
        'isModified': 'INTEGER DEFAULT 0', // v22
        // 'notes': 'TEXT', // BOM table had notes, checking usage...
        // 'createdAt': 'TEXT',
        // 'updatedAt': 'TEXT',
      },
      // constraints: ['UNIQUE(firmId, dish_id, ing_id)'], // Optional, based on logic
    ),

    // 16. MRP Runs
    TableSchema(
      tableName: 'mrp_runs',
      columns: {
        'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
        'firmId': 'TEXT NOT NULL',
        'runDate': 'TEXT NOT NULL',
        'targetDate': 'TEXT NOT NULL',
        'status': 'TEXT DEFAULT "DRAFT"',
        'totalOrders': 'INTEGER DEFAULT 0',
        'totalPax': 'INTEGER DEFAULT 0',
        'createdBy': 'TEXT',
        'createdAt': 'TEXT',
        'completedAt': 'TEXT',
      },
    ),

    // 17. MRP Run Orders
    TableSchema(
      tableName: 'mrp_run_orders',
      columns: {
        'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
        'mrpRunId': 'INTEGER NOT NULL',
        'orderId': 'INTEGER NOT NULL',
        'pax': 'INTEGER NOT NULL',
        'isSubcontracted': 'INTEGER DEFAULT 0',
        'subcontractorId': 'INTEGER',
      },
      constraints: ['UNIQUE(mrpRunId, orderId)'],
    ),

    // 18. MRP Output
    TableSchema(
      tableName: 'mrp_output',
      columns: {
        'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
        'mrpRunId': 'INTEGER NOT NULL',
        'ingredientId': 'INTEGER NOT NULL',
        'requiredQty': 'REAL NOT NULL',
        'unit': 'TEXT NOT NULL',
        'category': 'TEXT',
        'subcategory': 'TEXT',
        'allocatedQty': 'REAL DEFAULT 0',
        'purchaseQty': 'REAL DEFAULT 0',
        'inStockQty': 'REAL DEFAULT 0', // v19
      },
    ),

    // 19. Suppliers
    TableSchema(
      tableName: 'suppliers',
      columns: {
        'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
        'firmId': 'TEXT NOT NULL',
        'name': 'TEXT NOT NULL',
        'contactPerson': 'TEXT',
        'mobile': 'TEXT',
        'email': 'TEXT',
        'address': 'TEXT',
        'gstin': 'TEXT',
        'category': 'TEXT',
        'notes': 'TEXT',
        'rating': 'REAL DEFAULT 0',
        'isActive': 'INTEGER DEFAULT 1',
        'createdAt': 'TEXT',
        'updatedAt': 'TEXT',
      },
    ),
    
    // 20. Subcontractors
    TableSchema(
      tableName: 'subcontractors',
      columns: {
        'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
        'firmId': 'TEXT NOT NULL',
        'name': 'TEXT NOT NULL',
        'contactPerson': 'TEXT',
        'mobile': 'TEXT',
        'email': 'TEXT',
        'address': 'TEXT',
        'specialty': 'TEXT',
        'rating': 'REAL DEFAULT 0',
        'isActive': 'INTEGER DEFAULT 1',
        'createdAt': 'TEXT',
        'updatedAt': 'TEXT',
      },
    ),

    // 21. Purchase Orders
    TableSchema(
      tableName: 'purchase_orders',
      columns: {
        'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
        'firmId': 'TEXT NOT NULL',
        'mrpRunId': 'INTEGER', // v25 - Fix that started this all
        'poNumber': 'TEXT NOT NULL',
        'type': 'TEXT NOT NULL',
        'vendorId': 'INTEGER NOT NULL',
        'vendorName': 'TEXT',
        'totalItems': 'INTEGER DEFAULT 0',
        'totalAmount': 'REAL DEFAULT 0',
        'status': 'TEXT DEFAULT "SENT"',
        'sentAt': 'TEXT',
        'acceptedAt': 'TEXT',
        'dispatchedAt': 'TEXT',
        'deliveredAt': 'TEXT',
        'notes': 'TEXT',
        'createdAt': 'TEXT',
      },
    ),

    // 22. PO Items
    TableSchema(
      tableName: 'po_items',
      columns: {
        'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
        'poId': 'INTEGER NOT NULL',
        'itemId': 'INTEGER NOT NULL',
        'itemName': 'TEXT NOT NULL',
        'quantity': 'REAL NOT NULL',
        'unit': 'TEXT NOT NULL',
        'pricePerUnit': 'REAL DEFAULT 0',
        'totalPrice': 'REAL DEFAULT 0',
        'receivedQty': 'REAL DEFAULT 0',
        'status': 'TEXT DEFAULT "PENDING"',
        'notes': 'TEXT',
      },
      constraints: ['FOREIGN KEY(poId) REFERENCES purchase_orders(id)'],
    ),
    
    // 23. Audit Log (v26)
    TableSchema(
      tableName: 'audit_log',
      columns: {
        'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
        'table_name': 'TEXT',
        'record_id': 'INTEGER',
        'action': 'TEXT',
        'user_id': 'TEXT',
        'firm_id': 'TEXT',
        'notes': 'TEXT',
        'timestamp': 'TEXT',
      },
    ),
  ];
}
