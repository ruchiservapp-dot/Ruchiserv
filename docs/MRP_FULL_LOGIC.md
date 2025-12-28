# RuchiServ MRP (Material Requirements Planning) - Complete Logic & Code

## Overview

MRP calculates raw material requirements for catering orders based on:
- **Orders** for a target date
- **Dishes** in each order (with pax quantity)
- **BOM (Bill of Materials)** - ingredients per dish
- **Scaling** based on order pax count

---

## Database Schema (Key Tables)

```sql
-- Orders Table (relevant columns)
orders (
  id INTEGER PRIMARY KEY,
  firmId TEXT,
  customerName TEXT,
  date TEXT,
  totalPax INTEGER,
  mrpStatus TEXT,        -- NULL, 'PENDING', 'MRP_DONE', 'PO_SENT'
  mrpRunId INTEGER,      -- Links to mrp_runs.id
  isLocked INTEGER,      -- 1 = locked, 0 = editable
  lockedAt TEXT
)

-- Dishes Table (line items per order)
dishes (
  id INTEGER PRIMARY KEY,
  orderId INTEGER,
  name TEXT,
  pax INTEGER,
  rate REAL,
  productionType TEXT,   -- 'INTERNAL' or 'SUBCONTRACT'
  subcontractorId INTEGER
)

-- MRP Runs Table
mrp_runs (
  id INTEGER PRIMARY KEY,
  firmId TEXT,
  runDate TEXT,
  targetDate TEXT,
  runNumber INTEGER,
  runName TEXT,          -- e.g., 'Dec-1', 'Dec-2'
  status TEXT,           -- 'DRAFT', 'MRP_DONE', 'PO_SENT'
  totalOrders INTEGER,
  totalPax INTEGER,
  createdAt TEXT,
  completedAt TEXT
)

-- MRP Run Orders (links orders to runs)
mrp_run_orders (
  id INTEGER PRIMARY KEY,
  mrpRunId INTEGER,
  orderId INTEGER,
  pax INTEGER,
  isSubcontracted INTEGER,
  subcontractorId INTEGER
)

-- MRP Output (calculated ingredients)
mrp_output (
  id INTEGER PRIMARY KEY,
  mrpRunId INTEGER,
  ingredientId INTEGER,
  requiredQty REAL,
  unit TEXT,
  category TEXT,
  supplierId INTEGER,
  allocationStatus TEXT,  -- NULL, 'PENDING', 'ALLOCATED', 'PO_SENT'
  allocatedQty REAL,
  poId INTEGER
)

-- Recipe Detail (BOM - Bill of Materials)
recipe_detail (
  id INTEGER PRIMARY KEY,
  firmId TEXT,
  dish_id INTEGER,
  ing_id INTEGER,
  quantity_per_base_pax REAL,  -- qty for 1 person
  unit_override TEXT
)

-- Ingredients Master
ingredients_master (
  id INTEGER PRIMARY KEY,
  firmId TEXT,
  name TEXT,
  sku_name TEXT,
  unit_of_measure TEXT,
  cost_per_unit REAL,
  category TEXT
)

-- Purchase Orders
purchase_orders (
  id INTEGER PRIMARY KEY,
  firmId TEXT,
  mrpRunId INTEGER,
  poNumber TEXT,
  type TEXT,
  vendorId INTEGER,
  vendorName TEXT,
  totalItems INTEGER,
  totalAmount REAL,
  status TEXT,
  createdAt TEXT
)
```

---

## MRP Workflow

```
┌─────────────────────────────────────────────────────────────┐
│                     MRP WORKFLOW                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. SELECT TARGET DATE                                      │
│       ↓                                                     │
│  2. FETCH PENDING ORDERS (mrpStatus = NULL/PENDING)         │
│       ↓                                                     │
│  3. FOR EACH ORDER → FOR EACH DISH                          │
│       ├─ Skip if productionType = 'SUBCONTRACT'             │
│       └─ Get BOM (recipe_detail) for dish                   │
│           ↓                                                 │
│  4. SCALE INGREDIENTS: qty_per_pax × dishPax                │
│           ↓                                                 │
│  5. AGGREGATE: Sum same ingredients across all dishes       │
│           ↓                                                 │
│  6. SAVE TO mrp_output TABLE                                │
│           ↓                                                 │
│  7. LOCK ORDERS (mrpStatus = 'MRP_DONE', isLocked = 1)      │
│           ↓                                                 │
│  8. ALLOTMENT: Assign suppliers to ingredients              │
│           ↓                                                 │
│  9. GENERATE POs: Group by supplier → Create purchase_orders│
│           ↓                                                 │
│  10. MARK COMPLETE: When ALL items have POs → PO_SENT       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Code: MRP Run Screen (`4.3_mrp_run_screen.dart`)

### Core MRP Calculation Function

```dart
Future<void> _runMrp() async {
  if (_orders.isEmpty) return;

  setState(() => _isCalculating = true);

  try {
    // VERIFY: Check if any orders already have MRP runs
    final db = await DatabaseHelper().database;
    for (var order in _orders) {
      final orderId = order['id'] as int;
      final check = await db.query('orders', 
        columns: ['mrpStatus', 'mrpRunId'],
        where: 'id = ?', 
        whereArgs: [orderId],
      );
      if (check.isNotEmpty) {
        final status = check.first['mrpStatus'];
        final existingRunId = check.first['mrpRunId'];
        if (status != null && status != 'PENDING' && existingRunId != null) {
          // Order already has an MRP run - offer to view it instead
          setState(() => _isCalculating = false);
          if (mounted) {
            final goToExisting = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Order Already Processed'),
                content: Text('This order was already included in MRP Run #$existingRunId.\n\nWould you like to view that run instead?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('View Run')),
                ],
              ),
            );
            if (goToExisting == true) {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => MrpOutputScreen(mrpRunId: existingRunId as int, firmId: _firmId!),
              ));
            }
            await _loadData(); // Refresh to remove the order from list
          }
          return;
        }
      }
    }

    // Create MRP Run
    final mrpRunId = await DatabaseHelper().createMrpRun({
      'firmId': _firmId,
      'runDate': DateTime.now().toIso8601String(),
      'targetDate': DateFormat('yyyy-MM-dd').format(_selectedDate),
      'status': 'DRAFT',
      'totalOrders': _orders.length,
      'totalPax': _totalPax,
    });

    // Add orders to MRP run
    final orderRecords = _orders.map((o) {
      return {
        'orderId': o['id'],
        'pax': o['totalPax'] ?? 0,
        'isSubcontracted': 0,
        'subcontractorId': null,
      };
    }).toList();
    await DatabaseHelper().addOrdersToMrpRun(mrpRunId, orderRecords);

    // Calculate ingredient requirements
    final output = <int, Map<String, dynamic>>{}; 
    
    print('📊 [MRP] Starting ingredient calculation for ${_orders.length} orders');
    
    for (var order in _orders) {
      final orderId = order['id'] as int;
      final dishes = _orderDishes[orderId] ?? [];
      
      for (var dish in dishes) {
        // ⭐ SKIP SUBCONTRACTED DISHES
        if (dish['productionType'] == 'SUBCONTRACT') {
          print('📊 [MRP] Skipping subcontracted dish: ${dish['name']}');
          continue;
        }

        final dishName = dish['name'] as String?;
        if (dishName == null || dishName.isEmpty) continue;
        
        final dishQty = (dish['pax'] as num?)?.toInt() ?? 1;
        final excludedIds = dish['excludedIngredientIds'] as Set<int>? ?? {};
        
        // ⭐ LOOK UP BOM (Bill of Materials)
        final bom = await DatabaseHelper().getRecipeForDishByName(dishName, dishQty);
        
        for (var bomItem in bom) {
          final ingredientId = bomItem['ing_id'] as int?;
          if (ingredientId == null) continue;
          
          // Check exclusion
          if (excludedIds.contains(ingredientId)) {
             print('❌ [MRP] Skipping excluded ingredient ID: $ingredientId for dish: $dishName');
             continue;
          }
          
          final scaledQty = (bomItem['scaledQuantity'] as num?)?.toDouble() ?? 0;
          final unit = bomItem['unit'] ?? 'kg';
          final category = bomItem['category'] ?? 'Other';
          
          // ⭐ AGGREGATE SAME INGREDIENTS
          if (output.containsKey(ingredientId)) {
            output[ingredientId]!['requiredQty'] += scaledQty;
          } else {
            output[ingredientId] = {
              'ingredientId': ingredientId,
              'requiredQty': scaledQty,
              'unit': unit,
              'category': category,
            };
          }
        }
      }
    }
    
    // Save output
    await DatabaseHelper().saveMrpOutput(mrpRunId, output.values.toList());

    // Lock Orders
    await DatabaseHelper().lockOrdersForMrp(mrpRunId, _orders.map((o) => o['id'] as int).toList());

    setState(() => _isCalculating = false);

    if (mounted) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => MrpOutputScreen(mrpRunId: mrpRunId, firmId: _firmId!),
      ));
    }
  } catch (e) {
    setState(() => _isCalculating = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
    );
  }
}
```

---

## Code: Database Helper Functions (`database_helper.dart`)

### 1. Get Pending Orders for MRP

```dart
/// Get orders eligible for MRP Run (STRICT: Only PENDING status)
Future<List<Map<String, dynamic>>> getPendingOrdersForMrp(String date) async {
  final db = await database;
  return db.query(
    'orders',
    where: "date = ? AND (mrpStatus IS NULL OR mrpStatus = 'PENDING')",
    whereArgs: [date],
    orderBy: 'time ASC',
  );
}
```

### 2. Get Processed Orders (Read-Only Display)

```dart
/// Get already processed orders (for display only - not selectable for MRP)
Future<List<Map<String, dynamic>>> getProcessedOrdersForMrp(String date) async {
  final db = await database;
  return db.query(
    'orders',
    where: "date = ? AND mrpStatus IS NOT NULL AND mrpStatus != 'PENDING'",
    whereArgs: [date],
    orderBy: 'time ASC',
  );
}
```

### 3. Create MRP Run (Auto-names like "Dec-1", "Dec-2")

```dart
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
  
  return await db.insert('mrp_runs', data);
}
```

### 4. Add Orders to MRP Run

```dart
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
```

### 5. Get Recipe/BOM for Dish (⭐ CORE CALCULATION)

```dart
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
  // Try FIRM-SPECIFIC first
  var dishQuery = await db.query('dish_master',
    columns: ['id', 'base_pax'],
    where: "name = ? AND firmId = ?",
    whereArgs: [dishName, firmId],
    limit: 1,
  );
  
  // If not found and showUniversal is true, try SEED
  if (dishQuery.isEmpty && showUniversal) {
    dishQuery = await db.query('dish_master',
      columns: ['id', 'base_pax'],
      where: "name = ? AND firmId = 'SEED'",
      whereArgs: [dishName],
      limit: 1,
    );
  }
  
  if (dishQuery.isEmpty) {
    print('❌ [BOM] Dish not found in master: "$dishName"');
    return [];
  }

  final dishId = dishQuery.first['id'] as int;
  final basePax = (dishQuery.first['base_pax'] as int?) ?? 1;
  
  print('✅ [BOM] Found dish id=$dishId, basePax=$basePax');

  // Step 2: Get recipe_detail for this dish
  // ⭐ SCALING FORMULA: (quantity_per_base_pax * paxQty / basePax)
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
  
  // If empty and showUniversal, try SEED
  if (recipe.isEmpty && showUniversal) {
    // Check if dish has a baseId linking to SEED
    final seedDish = await db.query('dish_master',
      columns: ['baseId', 'base_pax'],
      where: "name = ? AND firmId = 'SEED'",
      whereArgs: [dishName],
      limit: 1,
    );
    
    if (seedDish.isNotEmpty) {
      final seedBaseId = seedDish.first['baseId'] ?? seedDish.first['id'];
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
      }
    }
  }
  
  print('📊 [BOM] Found ${recipe.length} ingredients for "$dishName"');
  return recipe;
}
```

### 6. Save MRP Output

```dart
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
```

### 7. Lock Orders for MRP (⭐ PREVENTS OVERWRITE)

```dart
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
      
      // ⭐ ONLY set mrpRunId if currently null/PENDING
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
```

### 8. Get MRP Output

```dart
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
```

### 9. Get MRP Output for Allotment (Excludes Already PO'd)

```dart
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
```

### 10. Mark MRP Output Items as PO Sent

```dart
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
```

### 11. Update Order Status When All Items PO'd

```dart
/// Update order status to PO_SENT only when ALL ingredients for that order's MRP run have been PO'd
Future<void> updateOrderStatusIfAllItemsPOd(int mrpRunId) async {
  final db = await database;
  
  // Check if there are any items still not PO_SENT for this run
  final pendingItems = await db.query('mrp_output',
    where: "mrpRunId = ? AND (allocationStatus IS NULL OR allocationStatus != 'PO_SENT')",
    whereArgs: [mrpRunId],
  );
  
  // ⭐ ONLY if ALL items are PO_SENT, update orders and MRP run status
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
```

### 12. Reset Order for MRP Re-run

```dart
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
```

---

## Code: Allotment Screen (`4.5_allotment_screen.dart`)

### Generate POs Function

```dart
Future<void> _generatePOs() async {
  try {
    // Group allocations by supplier
    final supplierGroups = <int, List<Map<String, dynamic>>>{};
    
    for (var item in _mrpOutput) {
      final ingredientId = item['ingredientId'] as int;
      final supplierId = _allocations[ingredientId];
      
      if (supplierId != null) {
        supplierGroups.putIfAbsent(supplierId, () => []).add(item);
      }
    }

    if (supplierGroups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.allocateIngredientsFirst), backgroundColor: Colors.orange),
      );
      return;
    }

    // Create PO for each supplier
    for (var entry in supplierGroups.entries) {
      final supplierId = entry.key;
      final items = entry.value;
      final supplier = _suppliers.firstWhere((s) => s['id'] == supplierId, orElse: () => {});
      
      // Calculate total amount for this PO
      double totalAmount = 0;
      for (var i in items) {
        final rate = (i['rate'] as num?)?.toDouble() ?? 0;
        final qty = (i['requiredQty'] as num?)?.toDouble() ?? 0;
        totalAmount += rate * qty;
      }
      
      final poNumber = await DatabaseHelper().generatePoNumber(widget.firmId);
      final poId = await DatabaseHelper().createPurchaseOrder({
        'firmId': widget.firmId,
        'mrpRunId': widget.mrpRunId,
        'poNumber': poNumber,
        'type': 'SUPPLIER',
        'vendorId': supplierId,
        'vendorName': supplier['name'] ?? AppLocalizations.of(context)!.unknown,
        'totalItems': items.length,
        'totalAmount': totalAmount,
        'status': 'SENT',
      });

      // Add PO items with rate and amount
      await DatabaseHelper().addPoItems(poId, items.map((i) {
        final rate = (i['rate'] as num?)?.toDouble() ?? 0;
        final qty = (i['requiredQty'] as num?)?.toDouble() ?? 0;
        return {
          'itemId': i['ingredientId'],
          'itemName': i['ingredientName'],
          'quantity': qty,
          'unit': i['unit'] ?? 'kg',
          'rate': rate,
          'amount': rate * qty,
        };
      }).toList());
      
      // Mark MRP output items as PO_SENT to prevent re-processing
      final ingredientIds = items.map((i) => i['ingredientId'] as int).toList();
      await DatabaseHelper().markMrpOutputAsPOSent(widget.mrpRunId, poId, ingredientIds);
    }

    // ⭐ Check if ALL items are now PO'd - only then update order/run status
    await DatabaseHelper().updateOrderStatusIfAllItemsPOd(widget.mrpRunId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.posGeneratedSuccess(supplierGroups.length)), 
          backgroundColor: Colors.green,
        ),
      );
      
      // Reload data to show remaining items (if any)
      await _loadData();
      
      // If no more items to allocate, go back
      if (_mrpOutput.isEmpty) {
        Navigator.pop(context);
        Navigator.pop(context); // Go back to MRP Run
      }
    }
  } catch (e) {
    print('ERROR Generating POs: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating POs: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
```

---

## Key Logic Summary

| Step | Function | File | Key Logic |
|------|----------|------|-----------|
| 1 | `getPendingOrdersForMrp()` | database_helper.dart | `mrpStatus IS NULL OR mrpStatus = 'PENDING'` |
| 2 | `getRecipeForDishByName()` | database_helper.dart | `qty_per_base_pax × paxQty ÷ basePax` |
| 3 | `_runMrp()` | 4.3_mrp_run_screen.dart | Skip `productionType = 'SUBCONTRACT'` |
| 4 | `saveMrpOutput()` | database_helper.dart | Aggregate same ingredients by ID |
| 5 | `lockOrdersForMrp()` | database_helper.dart | Set `mrpStatus='MRP_DONE'`, `isLocked=1` |
| 6 | `getMrpOutputForAllotment()` | database_helper.dart | Exclude `allocationStatus = 'PO_SENT'` |
| 7 | `_generatePOs()` | 4.5_allotment_screen.dart | Group by supplier → Create POs |
| 8 | `markMrpOutputAsPOSent()` | database_helper.dart | Mark items as `PO_SENT` with `poId` |
| 9 | `updateOrderStatusIfAllItemsPOd()` | database_helper.dart | Only when ALL items PO'd → `PO_SENT` |
| 10 | `resetOrderForMRP()` | database_helper.dart | Clear `mrpRunId`, set `mrpStatus='PENDING'` |

---

## Status Transitions

```
Order.mrpStatus:
  NULL/PENDING  ──[Run MRP]──▶  MRP_DONE  ──[All POs Generated]──▶  PO_SENT

MRP Output.allocationStatus:
  NULL/PENDING  ──[Assign Supplier]──▶  ALLOCATED  ──[Generate PO]──▶  PO_SENT
```

---

*Last Updated: 2025-12-17*
