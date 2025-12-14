import 'dart:math';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

/// Seeds comprehensive data for November 2025 to test Finance & Reports
Future<void> seedNovember2025Data() async {
  final db = DatabaseHelper();
  final database = await db.database;
  final firmId = 'RCHSRV';
  
  // 0. Ensure Vehicles exist (User Request: "Customer Vehicle" option)
  // Always try to insert these defaults, ignoring if they exist (UNIQUE constraint on vehicleNumber)
  await database.insert('vehicles', {
    'firmId': firmId,
    'vehicleNumber': 'Customer Vehicle',
    'vehicleType': 'OTHER',
    'status': 'AVAILABLE',
    'driverName': 'Customer',
  }, conflictAlgorithm: ConflictAlgorithm.ignore);

  await database.insert('vehicles', {
    'firmId': firmId,
    'vehicleNumber': 'Rent Vehicle',
    'vehicleType': 'OTHER',
    'status': 'AVAILABLE',
    'driverName': 'Rental',
  }, conflictAlgorithm: ConflictAlgorithm.ignore);

  // Only add company van if completely empty (optional)
  final vehicleCount = Sqflite.firstIntValue(await database.rawQuery('SELECT COUNT(*) FROM vehicles'));
  if ((vehicleCount ?? 0) < 3) {
      await database.insert('vehicles', {
      'firmId': firmId,
      'vehicleNumber': 'KA-01-AB-1234',
      'vehicleType': 'VAN',
      'status': 'AVAILABLE',
      'driverName': 'Raju',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // 1. Check if we already have November 2025 data
  // We check for orders in that month
  final existingCheck = await database.rawQuery(
    "SELECT COUNT(*) as count FROM orders WHERE firmId = ? AND eventDate LIKE '2025-11%'",
    [firmId]
  );
  
  if ((existingCheck.first['count'] as int) > 5) {
    print('⚠️ November 2025 data seems to already exist. Skipping seed.');
    return;
  }

  print('🌱 Seeding November 2025 Data...');
  final rng = Random();

  // === 1. STAFF (Ensure we have some staff) ===
  final staffIds = <int>[];
  // Get existing staff or create dummies
  final existingStaff = await database.query('staff', where: 'firmId = ?', whereArgs: [firmId]);
  if (existingStaff.isEmpty) {
    // Create 5 dummy staff
    for (int i = 1; i <= 5; i++) {
      final id = await database.insert('staff', {
        'firmId': firmId,
        'name': 'Staff Member $i',
        'role': i == 1 ? 'Chef' : 'Helper',
        'mobile': '987654320$i',
        'salary': 15000 + (rng.nextInt(5) * 1000),
        'staffType': 'PERMANENT',
        'isActive': 1,
        'joinDate': '2025-01-01',
        'createdAt': DateTime(2025, 1, 1).toIso8601String(),
      });
      staffIds.add(id);
    }
  } else {
    staffIds.addAll(existingStaff.map((e) => e['id'] as int));
  }

  // === 2. ORDERS & INCOME ===
  // Generate ~15 orders for Nov 2025
  final eventTypes = ['Wedding', 'Corporate', 'Birthday', 'Engagement', 'House Warming'];
  int totalOrders = 0;
  
  for (int day = 1; day <= 30; day++) {
    // 50% chance of an order on any given day
    if (rng.nextBool()) continue; 
    
    final dateStr = '2025-11-${day.toString().padLeft(2, '0')}';
    final eventType = eventTypes[rng.nextInt(eventTypes.length)];
    final pax = 50 + rng.nextInt(450); // 50-500 pax
    final ratePerPlate = 300 + rng.nextInt(500); // 300-800 per plate
    final amount = pax * ratePerPlate;
    
    // Create Customer
    final custName = 'Customer Nov $day';
    final custMobile = '99887766${day.toString().padLeft(2, '0')}';
    
    final customerId = await database.insert('customers', {
      'firmId': firmId,
      'name': custName,
      'mobile': custMobile,
      'notes': 'Test Customer',
      'createdAt': '${dateStr}T09:00:00',
      'updatedAt': '${dateStr}T09:00:00',
    });

    final orderId = await database.insert('orders', {
      'firmId': firmId,
      'customerId': customerId,
      'customerName': custName, // Legacy column
      'mobile': custMobile,     // Legacy column
      'notes': '$eventType (${day % 2 == 0 ? "Evening" : "Lunch"})', // Store event type in notes
      'eventDate': dateStr,
      'date': dateStr, // Legacy column required by DB constraint
      'eventTime': '12:00',
      'pax': pax,
      'totalAmount': amount, // Correct column name
      'advanceAmount': amount, // Fully paid
      'status': 'COMPLETED',
      // 'isPaid': 1, // field does not exist, status/advance handles it
      'createdAt': '${dateStr}T10:00:00',
      'updatedAt': '${dateStr}T22:00:00',
      'dispatchStatus': 'UNLOADED', // Fully processed
    });
    
    totalOrders++;

    // Add Income Transaction
    await database.insert('transactions', {
      'firmId': firmId,
      'date': dateStr,
      'type': 'INCOME',
      'amount': amount,
      'category': 'Event Revenue',
      'description': 'Payment for Order #$orderId ($eventType)',
      'mode': rng.nextBool() ? 'UPI' : 'Bank Transfer',
      'relatedEntityId': orderId,
      'relatedEntityType': 'ORDER',
      'createdAt': '${dateStr}T12:00:00',
    });
    
    // Add Dispatch & Return (Mocking Utensil movement)
    // 1. Dispatch
    final dispatchId = await database.insert('dispatches', {
      'orderId': orderId,
      'vehicleId': 1, // Assume vehicle 1 exists
      'dispatchStatus': 'UNLOADED',
      'dispatchTime': '${dateStr}T09:00:00',
      'returnTime': '${dateStr}T20:00:00',
      'createdAt': '${dateStr}T09:00:00',
    });
    
    // Add some random utensils
    final utensils = ['Spoon', 'Plate', 'Glass', 'Bowl'];
    for (var uName in utensils) {
      int qty = pax + rng.nextInt(20); // Pax + buffer
      await database.insert('dispatch_items', {
        'dispatchId': dispatchId,
        'itemType': 'UTENSIL',
        'itemName': uName,
        'quantity': qty,
        'loadedQty': qty,
        'returnedQty': qty - rng.nextInt(5), // Some missing?
        'unloadedQty': qty - rng.nextInt(5),
        'status': 'UNLOADED',
      });
    }
  }
  print('✅ Created $totalOrders orders with income transactions.');

  // === 3. EXPENSES ===
  // A. Daily/Weekly Procurement expenses
  for (int day = 1; day <= 30; day++) {
    if (day % 3 != 0) continue; // Every 3 days
    
    final dateStr = '2025-11-${day.toString().padLeft(2, '0')}';
    final expenseAmt = 5000 + rng.nextInt(15000);
    
    await database.insert('transactions', {
      'firmId': firmId,
      'date': dateStr,
      'type': 'EXPENSE',
      'amount': expenseAmt,
      'category': 'Procurement',
      'description': 'Grocery & Vegetables purchase',
      'mode': 'Cash',
      'createdAt': '${dateStr}T08:00:00',
    });
  }

  // B. Monthly Expenses (Rent, Fuel, etc)
  final fixedExpenses = {
    'Rent': 25000,
    'Electricity': 4500,
    'Fuel': 8000,
    'Maintenance': 2000,
  };
  
  fixedExpenses.forEach((cat, amt) async {
    await database.insert('transactions', {
      'firmId': firmId,
      'date': '2025-11-05',
      'type': 'EXPENSE',
      'amount': amt,
      'category': cat,
      'description': 'Monthly $cat bill',
      'mode': 'Bank Transfer',
      'createdAt': '2025-11-05T10:00:00',
    });
  });

  // C. Payroll (End of Month)
  for (final staffId in staffIds) {
    // Get staff details for salary
    final staff = (await database.query('staff', where: 'id = ?', whereArgs: [staffId])).first;
    final salary = staff['salary'] as num;
    
    await database.insert('transactions', {
      'firmId': firmId,
      'date': '2025-11-30',
      'type': 'EXPENSE', // Or 'PAYROLL' if you have that type? Standard is EXPENSE usually for finance
      'amount': salary,
      'category': 'Salary',
      'description': 'Salary for ${staff['name']}',
      'mode': 'Bank Transfer',
      'relatedEntityId': staffId,
      'relatedEntityType': 'STAFF',
      'createdAt': '2025-11-30T18:00:00',
    });
  }
  print('✅ Created expenses (Procurement, Fixed, Payroll).');

  // === 4. ATTENDANCE ===
  // Generate attendance for all staff
  for (int day = 1; day <= 30; day++) {
    final dateStr = '2025-11-${day.toString().padLeft(2, '0')}';
    final isSunday = DateTime(2025, 11, day).weekday == 7;
    
    if (isSunday) continue; // Skip Sundays usually? Or keep some.
    
    for (final staffId in staffIds) {
      // 90% attendance rate
      if (rng.nextDouble() > 0.9) {
         // Absent
         await database.insert('attendance', {
          'staffId': staffId,
          'date': dateStr,
          'status': 'Absent',
          'hoursWorked': 0,
          'createdAt': '${dateStr}T09:00:00',
         });
         continue;
      }
      
      // Present
      final inHour = 8 + rng.nextInt(2); // 8-10 AM
      final outHour = 17 + rng.nextInt(4); // 5-9 PM
      final hours = outHour - inHour;
      
      await database.insert('attendance', {
        'staffId': staffId,
        'date': dateStr,
        'punchInTime': '${dateStr}T${inHour.toString().padLeft(2,'0')}:00:00',
        'punchOutTime': '${dateStr}T${outHour.toString().padLeft(2,'0')}:00:00',
        'status': 'Present',
        'hoursWorked': hours,
        'createdAt': '${dateStr}T${inHour.toString().padLeft(2,'0')}:00:00',
      });
    }
  }
  print('✅ Created attendance records.');
  
  print('🎉 November 2025 Seeding Complete!');
}
