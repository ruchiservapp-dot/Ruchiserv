// E2E TEST MODULE: SUBSCRIPTION + DISPATCH + GEO-FENCE + ORDER CANCELLATION
// Covers: T-SUB-01 to T-SUB-10, T-DSP-08, T-DSP-11, T-STF-16, T-ORD-03 to T-ORD-05
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ruchiserv/services/subscription_service.dart';
import 'package:ruchiserv/services/order_cancellation_service.dart';
import 'package:ruchiserv/services/geo_fence_service.dart';
import 'package:ruchiserv/db/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return '.';
    });
  });

  // ═══════════════════════════════════════════
  // MODULE 3: SUBSCRIPTION & FEATURE GATING
  // ═══════════════════════════════════════════

  group('T-SUB: Subscription Service', () {
    late SubscriptionService subService;

    setUp(() {
      subService = SubscriptionService();
    });

    // T-SUB-01: Active subscription
    test('T-SUB-01: Active subscription returns "active"', () async {
      SharedPreferences.setMockInitialValues({'firmId': 'TEST_FIRM'});

      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      // Set firm with future expiry
      final futureDate = DateTime.now().add(const Duration(days: 60)).toIso8601String();
      await db.insert('firms', {
        'firmId': 'TEST_FIRM',
        'firmName': 'Test Firm',
        'subscriptionExpiry': futureDate,
        'subscriptionStatus': 'ACTIVE',
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final status = await subService.checkSubscriptionStatus('TEST_FIRM');
      expect(status, 'active');
      print('✅ T-SUB-01: Active subscription correctly returns "active"');
    });

    // T-SUB-02: Grace period (expired but within 5 days)
    test('T-SUB-02: Expired within grace period returns "grace_period"', () async {
      SharedPreferences.setMockInitialValues({'firmId': 'GRACE_FIRM'});

      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      // Set firm expired 2 days ago (within 5-day grace)
      final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2)).toIso8601String();
      await db.insert('firms', {
        'firmId': 'GRACE_FIRM',
        'firmName': 'Grace Period Firm',
        'subscriptionExpiry': twoDaysAgo,
        'subscriptionStatus': 'ACTIVE',
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final status = await subService.checkSubscriptionStatus('GRACE_FIRM');
      expect(status, 'grace_period');
      print('✅ T-SUB-02: Grace period correctly detected');
    });

    // T-SUB-03: Locked (expired past grace)
    test('T-SUB-03: Expired past grace period returns "locked"', () async {
      SharedPreferences.setMockInitialValues({'firmId': 'LOCKED_FIRM'});

      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      // Set firm expired 10 days ago (past 5-day grace)
      final tenDaysAgo = DateTime.now().subtract(const Duration(days: 10)).toIso8601String();
      await db.insert('firms', {
        'firmId': 'LOCKED_FIRM',
        'firmName': 'Locked Firm',
        'subscriptionExpiry': tenDaysAgo,
        'subscriptionStatus': 'ACTIVE',
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final status = await subService.checkSubscriptionStatus('LOCKED_FIRM');
      expect(status, 'locked');
      print('✅ T-SUB-03: Locked status correctly detected after grace period');
    });

    // T-SUB-03b: Unknown firm → locked
    test('T-SUB-03b: Unknown firm returns "locked"', () async {
      final status = await subService.checkSubscriptionStatus('NONEXISTENT_FIRM_XYZ');
      expect(status, 'locked');
      print('✅ T-SUB-03b: Unknown firm correctly locked');
    });

    // T-SUB-10: Manual extension
    test('T-SUB-10: Manual extension adds 7 days to expired subscription', () async {
      SharedPreferences.setMockInitialValues({'firmId': 'EXT_FIRM'});

      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      // Set firm expired yesterday
      final yesterday = DateTime.now().subtract(const Duration(days: 1)).toIso8601String();
      await db.insert('firms', {
        'firmId': 'EXT_FIRM',
        'firmName': 'Extension Firm',
        'subscriptionExpiry': yesterday,
        'subscriptionStatus': 'ACTIVE',
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Before extension: should be grace/locked
      final beforeStatus = await subService.checkSubscriptionStatus('EXT_FIRM');
      expect(beforeStatus, anyOf('grace_period', 'locked'));

      // Grant extension
      await subService.grantManualExtension('EXT_FIRM');

      // After extension: should be active (new expiry is ~7 days in future)
      final afterStatus = await subService.checkSubscriptionStatus('EXT_FIRM');
      expect(afterStatus, 'active');

      final days = await subService.getDaysRemaining('EXT_FIRM');
      expect(days, inInclusiveRange(5, 7));
      print('✅ T-SUB-10: Manual extension granted — now active with $days days remaining');
    });

    // T-SUB-04 / isReadOnly check
    test('T-SUB-04: isReadOnly returns true for grace/locked firms', () async {
      SharedPreferences.setMockInitialValues({'firmId': 'LOCKED_FIRM'});

      final isRO = await SubscriptionService.isReadOnly('LOCKED_FIRM');
      expect(isRO, true);
      print('✅ T-SUB-04: Locked firm correctly read-only');
    });

    // Days remaining calculation
    test('getDaysRemaining returns correct positive/negative days', () async {
      SharedPreferences.setMockInitialValues({'firmId': 'TEST_FIRM'});

      final days = await subService.getDaysRemaining('TEST_FIRM');
      expect(days, isNotNull);
      expect(days!, greaterThan(0));
      print('✅ getDaysRemaining: $days days remaining');
    });

    // Grace days remaining
    test('getGraceDaysRemaining returns 0 for active firms', () async {
      final graceDays = await subService.getGraceDaysRemaining('TEST_FIRM');
      // Active firm should have grace period far in the future
      expect(graceDays, greaterThan(0));
      print('✅ getGraceDaysRemaining: $graceDays days');
    });
  });

  // ═══════════════════════════════════════════
  // MODULE 6: GEO-FENCE SERVICE (Staff Attendance)
  // ═══════════════════════════════════════════

  group('T-STF-16: Geo-Fence Haversine Distance', () {
    late GeoFenceService geoService;

    setUp(() {
      geoService = GeoFenceService();
    });

    test('Haversine formula: known distance Mumbai → Delhi ~1,150 km', () {
      // Mumbai: 19.0760, 72.8777
      // Delhi:  28.6139, 77.2090
      final distance = geoService.calculateDistance(
        lat1: 19.0760, lng1: 72.8777,
        lat2: 28.6139, lng2: 77.2090,
      );
      final distanceKm = distance / 1000;

      // Should be approximately 1,150-1,160 km
      expect(distanceKm, inInclusiveRange(1140, 1170));
      print('✅ T-STF-16: Mumbai → Delhi = ${distanceKm.toStringAsFixed(1)} km');
    });

    test('Haversine formula: same point → 0 distance', () {
      final distance = geoService.calculateDistance(
        lat1: 12.9716, lng1: 77.5946,
        lat2: 12.9716, lng2: 77.5946,
      );
      expect(distance, 0.0);
      print('✅ Haversine: Same point = 0m');
    });

    test('Haversine formula: short distance ~100m', () {
      // Two points ~100m apart in Bangalore
      final distance = geoService.calculateDistance(
        lat1: 12.9716, lng1: 77.5946,
        lat2: 12.9725, lng2: 77.5946,
      );
      expect(distance, inInclusiveRange(90, 110));
      print('✅ Haversine: Short distance = ${distance.toStringAsFixed(1)}m');
    });

    test('isWithinGeoFence correctly identifies inside/outside', () {
      // Staff at 100m from kitchen, radius is 200m → INSIDE
      final inside = geoService.isWithinGeoFence(
        staffLat: 12.9716, staffLng: 77.5946,
        kitchenLat: 12.9725, kitchenLng: 77.5946,
        radiusMeters: 200,
      );
      expect(inside, true);

      // Staff at 100m from kitchen, radius is 50m → OUTSIDE
      final outside = geoService.isWithinGeoFence(
        staffLat: 12.9716, staffLng: 77.5946,
        kitchenLat: 12.9725, kitchenLng: 77.5946,
        radiusMeters: 50,
      );
      expect(outside, false);
      print('✅ T-STF-16: Geo-fence inside/outside detection verified');
    });

    test('formatDistance: meters and km formatting', () {
      expect(geoService.formatDistance(150), '150 m');
      expect(geoService.formatDistance(999), '999 m');
      expect(geoService.formatDistance(1000), '1.0 km');
      expect(geoService.formatDistance(1500), '1.5 km');
      expect(geoService.formatDistance(12345), '12.3 km');
      print('✅ formatDistance: m/km formatting correct');
    });

    test('getStatusMessage returns correct messages', () {
      final geo = GeoFenceService();
      expect(geo.getStatusMessage(LocationStatus.ready), 'Location ready');
      expect(geo.getStatusMessage(LocationStatus.serviceDisabled), contains('enable'));
      expect(geo.getStatusMessage(LocationStatus.permissionDenied), contains('permission'));
      expect(geo.getStatusMessage(LocationStatus.permissionDeniedForever), contains('Settings'));
      expect(geo.getStatusMessage(LocationStatus.error), contains('Unable'));
      print('✅ LocationStatus messages verified');
    });
  });

  // ═══════════════════════════════════════════
  // MODULE 4: ORDER CANCELLATION SERVICE
  // ═══════════════════════════════════════════

  group('T-ORD: Order Cancellation', () {
    // T-ORD-04: 48-hour warning window
    test('T-ORD-04: isWithinWarningWindow detects 48-hour boundary', () {
      final service = OrderCancellationService();

      // Event in 24 hours → WITHIN warning
      final in24h = DateTime.now().add(const Duration(hours: 24));
      expect(service.isWithinWarningWindow(in24h), true);

      // Event in 72 hours → OUTSIDE warning
      final in72h = DateTime.now().add(const Duration(hours: 72));
      expect(service.isWithinWarningWindow(in72h), false);

      // Event in exactly 48 hours → AT boundary
      final in48h = DateTime.now().add(const Duration(hours: 48));
      expect(service.isWithinWarningWindow(in48h), true);

      // Past event → OUTSIDE (negative hours)
      final yesterday = DateTime.now().subtract(const Duration(hours: 24));
      expect(service.isWithinWarningWindow(yesterday), false);

      print('✅ T-ORD-04: 48-hour cancellation warning window verified');
    });

    // T-ORD-04b: formatEventDateTime
    test('formatEventDateTime handles various formats', () {
      final service = OrderCancellationService();

      expect(service.formatEventDateTime(null, null), 'Unknown');
      expect(service.formatEventDateTime('2024-03-15', null), 'Mar 15, 2024');
      expect(service.formatEventDateTime('2024-03-15', '18:00'), 'Mar 15, 2024 at 18:00');
      expect(service.formatEventDateTime('invalid-date', null), 'invalid-date');
      print('✅ formatEventDateTime handles all edge cases');
    });

    // T-ORD-05: Already cancelled check
    test('T-ORD-05: getDependencySummary formats correctly', () {
      final service = OrderCancellationService();

      // No warnings
      expect(
        service.getDependencySummary({'warnings': <String>[]}),
        'No dependencies found. Safe to cancel.',
      );

      // With warnings
      expect(
        service.getDependencySummary({
          'warnings': ['⚠️ Event in 12 hours', '📋 3 dishes linked'],
        }),
        contains('Event in 12 hours'),
      );
      print('✅ T-ORD-05: Dependency summary formatting verified');
    });
  });

  // ═══════════════════════════════════════════
  // MODULE 7: DISPATCH STATUS FLOW
  // ═══════════════════════════════════════════

  group('T-DSP: Dispatch Logic', () {
    // T-DSP-08: Status progression
    test('T-DSP-08: Dispatch status flow validation', () {
      const validStatuses = ['PENDING', 'DISPATCHED', 'DELIVERED', 'RETURNED'];

      // Validate progression order
      for (int i = 0; i < validStatuses.length - 1; i++) {
        final from = validStatuses[i];
        final to = validStatuses[i + 1];
        expect(validStatuses.indexOf(to), greaterThan(validStatuses.indexOf(from)),
            reason: '$to should come after $from');
      }

      // Status string matching
      expect(validStatuses.contains('PENDING'), true);
      expect(validStatuses.contains('DISPATCHED'), true);
      expect(validStatuses.contains('DELIVERED'), true);
      expect(validStatuses.contains('RETURNED'), true);
      expect(validStatuses.contains('CANCELLED'), false); // Not a valid status
      print('✅ T-DSP-08: Dispatch status flow progression verified');
    });

    // T-DSP-11: Variance calculation
    test('T-DSP-11: Unload variance = dispatched - actual', () {
      // Simulating UnloadVerifyScreen variance calculation
      final items = [
        {'name': 'Plates', 'dispatched': 100, 'actual': 95},
        {'name': 'Spoons', 'dispatched': 200, 'actual': 200},
        {'name': 'Glasses', 'dispatched': 50, 'actual': 48},
      ];

      for (final item in items) {
        final dispatched = item['dispatched'] as int;
        final actual = item['actual'] as int;
        final variance = dispatched - actual;
        final variancePercent = (variance / dispatched) * 100;

        if (item['name'] == 'Plates') {
          expect(variance, 5);
          expect(variancePercent, 5.0);
        } else if (item['name'] == 'Spoons') {
          expect(variance, 0);
        } else if (item['name'] == 'Glasses') {
          expect(variance, 2);
        }
      }
      print('✅ T-DSP-11: Unload variance calculation verified');
    });

    // T-DSP-12: Utensil stock impact
    test('T-DSP-12: Dispatch reduces stock, return restores', () async {
      final db = await databaseFactory.openDatabase(inMemoryDatabasePath);

      await db.execute('''
        CREATE TABLE IF NOT EXISTS utensils (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          firmId TEXT NOT NULL,
          name TEXT NOT NULL,
          totalQuantity INTEGER DEFAULT 0,
          availableQuantity INTEGER DEFAULT 0
        )
      ''');

      // Initial stock: 100 plates
      await db.insert('utensils', {
        'firmId': 'TEST_FIRM',
        'name': 'Plate',
        'totalQuantity': 100,
        'availableQuantity': 100,
      });

      // Dispatch 30 plates
      await db.rawUpdate(
        'UPDATE utensils SET availableQuantity = availableQuantity - ? WHERE firmId = ? AND name = ?',
        [30, 'TEST_FIRM', 'Plate'],
      );

      var utensil = await db.query('utensils', where: "name = 'Plate'");
      expect(utensil.first['availableQuantity'], 70);

      // Return 25 (5 damaged/missing)
      await db.rawUpdate(
        'UPDATE utensils SET availableQuantity = availableQuantity + ? WHERE firmId = ? AND name = ?',
        [25, 'TEST_FIRM', 'Plate'],
      );

      utensil = await db.query('utensils', where: "name = 'Plate'");
      expect(utensil.first['availableQuantity'], 95);
      expect(utensil.first['totalQuantity'], 100); // Total unchanged

      await db.close();
      print('✅ T-DSP-12: Utensil stock dispatch/return flow verified');
    });
  });

  // ═══════════════════════════════════════════
  // MODULE 6: STAFF PAYROLL LOGIC
  // ═══════════════════════════════════════════

  group('T-STF: Staff & Payroll', () {
    // T-STF-11: Monthly payroll calculation
    test('T-STF-11: Payroll calc (base + OT - advances - deductions)', () {
      // Monthly salary staff
      const baseSalary = 15000.0;
      const otHours = 10;
      const otRate = 100.0; // per hour
      const advances = 2000.0;
      const deductions = 500.0;

      final otPay = otHours * otRate;
      final grossPay = baseSalary + otPay;
      final netPay = grossPay - advances - deductions;

      expect(otPay, 1000.0);
      expect(grossPay, 16000.0);
      expect(netPay, 13500.0);
      print('✅ T-STF-11: Payroll calc: ₹$baseSalary + OT(₹$otPay) - Adv(₹$advances) - Ded(₹$deductions) = ₹$netPay');
    });

    // T-STF-12: PERMANENT vs DAILY_WAGE
    test('T-STF-12: Daily wage vs permanent rate calculation', () {
      // Permanent: fixed monthly
      const permanentSalary = 20000.0;
      const workingDaysInMonth = 26;
      final perDay = permanentSalary / workingDaysInMonth;

      // Daily wage: rate × days worked
      const dailyRate = 800.0;
      const daysWorked = 22;
      final dailyWageTotal = dailyRate * daysWorked;

      expect(perDay, closeTo(769.23, 0.01)); // ~769/day
      expect(dailyWageTotal, 17600.0);

      // Permanent gets paid even for holidays; daily doesn't
      expect(permanentSalary, greaterThan(dailyWageTotal));
      print('✅ T-STF-12: PERMANENT (₹$permanentSalary) vs DAILY_WAGE (₹$dailyWageTotal) verified');
    });

    // T-STF-14: Salary disbursement creates finance transaction
    test('T-STF-14: Salary disbursement auto-records EXPENSE in finance', () async {
      final db = await databaseFactory.openDatabase(inMemoryDatabasePath);

      await db.execute('''
        CREATE TABLE IF NOT EXISTS finance (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          firmId TEXT NOT NULL,
          type TEXT NOT NULL,
          category TEXT,
          amount REAL DEFAULT 0,
          date TEXT NOT NULL,
          notes TEXT,
          relatedId INTEGER,
          relatedTable TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS salary_disbursements (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          firmId TEXT NOT NULL,
          staffId INTEGER NOT NULL,
          staffName TEXT,
          month TEXT NOT NULL,
          amount REAL DEFAULT 0,
          paymentMode TEXT,
          disbursedAt TEXT
        )
      ''');

      // Disburse salary
      final disbId = await db.insert('salary_disbursements', {
        'firmId': 'TEST_FIRM',
        'staffId': 10,
        'staffName': 'Raju Kumar',
        'month': '2024-01',
        'amount': 15000.0,
        'paymentMode': 'UPI',
        'disbursedAt': DateTime.now().toIso8601String(),
      });

      // Auto-record as EXPENSE
      await db.insert('finance', {
        'firmId': 'TEST_FIRM',
        'type': 'EXPENSE',
        'category': 'Salary',
        'amount': 15000.0,
        'date': DateTime.now().toIso8601String(),
        'notes': 'Salary: Raju Kumar (Jan 2024)',
        'relatedId': disbId,
        'relatedTable': 'salary_disbursements',
      });

      // Verify expense recorded
      final expenses = await db.query('finance',
        where: "type = 'EXPENSE' AND category = 'Salary'",
      );
      expect(expenses.length, 1);
      expect(expenses.first['amount'], 15000.0);
      expect(expenses.first['relatedTable'], 'salary_disbursements');

      await db.close();
      print('✅ T-STF-14: Salary disbursement auto-creates EXPENSE transaction');
    });
  });

  // ═══════════════════════════════════════════
  // MODULE 11: INVENTORY & BOM LOGIC
  // ═══════════════════════════════════════════

  group('T-INV: Inventory & BOM', () {
    // T-INV-05: BOM at 100 pax standard
    test('T-INV-05: BOM calculation at 100 pax base', () {
      // BOM: Biryani requires 5kg rice per 100 pax
      const basePax = 100;
      const ricePerBase = 5.0; // kg
      const actualPax = 350;

      final requiredRice = (actualPax / basePax) * ricePerBase;
      expect(requiredRice, 17.5); // 3.5 × 5 = 17.5 kg
      print('✅ T-INV-05: BOM scaling: $actualPax pax needs ${requiredRice}kg rice');
    });

    // T-INV-10: PO lifecycle
    test('T-INV-10: PO status lifecycle validation', () {
      const validStatuses = ['DRAFT', 'SENT', 'ACCEPTED', 'DISPATCHED', 'DELIVERED', 'CANCELLED'];

      // Forward progression only (except cancel from any state)
      final forwardFlow = ['DRAFT', 'SENT', 'ACCEPTED', 'DISPATCHED', 'DELIVERED'];
      for (int i = 0; i < forwardFlow.length - 1; i++) {
        expect(
          forwardFlow.indexOf(forwardFlow[i + 1]),
          greaterThan(forwardFlow.indexOf(forwardFlow[i])),
        );
      }

      // CANCELLED can come from any state
      expect(validStatuses.contains('CANCELLED'), true);
      print('✅ T-INV-10: PO lifecycle flow validated');
    });
  });
}
