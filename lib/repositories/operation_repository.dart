import 'package:ruchiserv/core/app_logger.dart';
import 'package:ruchiserv/db/database_helper.dart';
import 'package:ruchiserv/services/cloud_sync_service.dart';
import 'package:uuid/uuid.dart';

class OperationRepository {
  static final OperationRepository _instance = OperationRepository._internal();
  factory OperationRepository() => _instance;
  OperationRepository._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();

  // ---------- STAFF & ATTENDANCE ----------

  Future<List<Map<String, dynamic>>> getAllStaff(
      {bool onlyActive = true}) async {
    final db = await _dbHelper.database;
    if (onlyActive) {
      return await db.query('staff', where: 'isActive = 1', orderBy: 'name');
    }
    return await db.query('staff', orderBy: 'name');
  }

  Future<Map<String, dynamic>?> getStaffByMobile(String mobile,
      {String? firmId}) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'staff',
      where: firmId != null
          ? 'mobile = ? AND firmId = ? AND isActive = 1'
          : 'mobile = ? AND isActive = 1',
      whereArgs: firmId != null ? [mobile, firmId] : [mobile],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> updateAttendance(int staffId, String date, String status,
      {double? overtime}) async {
    final db = await _dbHelper.database;
    final cloudSync = CloudSyncService();
    final data = {
      'staffId': staffId,
      'date': date,
      'status': status,
      'overtime': overtime ?? 0.0,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    // Check if record exists
    final existing = await db.query('attendance',
        where: 'staffId = ? AND date = ?', whereArgs: [staffId, date]);
    if (existing.isNotEmpty) {
      await _dbHelper.updateRecord(
          'attendance', existing.first['id'] as int, data);
    } else {
      data['uuid'] = const Uuid().v4();
      await cloudSync.awsFirstWrite(table: 'attendance', data: data);
    }
  }

  // ---------- UTENSILS & WAREHOUSE ----------

  Future<List<Map<String, dynamic>>> getAllUtensils() async {
    final db = await _dbHelper.database;
    return await db.query('utensils', orderBy: 'name');
  }

  String _generateUuid() => const Uuid().v4();

  // ---------- STAFF MANAGEMENT ----------

  Future<List<Map<String, dynamic>>> getDrivers(String firmId) async {
    final db = await _dbHelper.database;
    return await db.query('users',
        where: 'role = ? AND firmId = ?', whereArgs: ['Driver', firmId]);
  }

  Future<int?> insertStaff(Map<String, dynamic> data) async {
    final cloudSync = CloudSyncService();
    data['uuid'] = data['uuid'] ?? _generateUuid();
    final id = await cloudSync.awsFirstWrite(table: 'staff', data: data);
    AppLogger.success('✅ [Operation] Created staff member #$id (AWS-first)');
    return id;
  }

  Future<bool> updateStaffFields(int id, Map<String, dynamic> updates) async {
    updates['updatedAt'] = DateTime.now().toIso8601String();
    return await _dbHelper.updateRecord('staff', id, updates);
  }

  Future<bool> deleteStaff(int id) async {
    final cloudSync = CloudSyncService();
    final success =
        await cloudSync.awsFirstDelete(table: 'staff', recordId: id);
    AppLogger.success('✅ [Operation] Deleted staff #$id (AWS-first)');
    return success;
  }

  // ---------- ATTENDANCE ----------

  Future<int?> insertAttendance(Map<String, dynamic> data) async {
    final cloudSync = CloudSyncService();
    data['uuid'] = data['uuid'] ?? _generateUuid();
    final id = await cloudSync.awsFirstWrite(table: 'attendance', data: data);
    AppLogger.success('✅ [Operation] Recorded attendance #$id (AWS-first)');
    return id;
  }

  Future<bool> updateAttendanceRecord(
      int id, Map<String, dynamic> updates) async {
    return await _dbHelper.updateRecord('attendance', id, updates);
  }

  Future<List<Map<String, dynamic>>> getAttendanceForStaff(
      int staffId, DateTime startDate, DateTime endDate) async {
    final db = await _dbHelper.database;
    final startStr = startDate.toIso8601String().substring(0, 10);
    final endStr = endDate.toIso8601String().substring(0, 10);
    return await db.rawQuery('''
      SELECT date, punchInTime, punchOutTime, overtimeHours, status
      FROM attendance
      WHERE staffId = ? AND date BETWEEN ? AND ?
      ORDER BY date DESC
    ''', [staffId, startStr, endStr]);
  }

  Future<List<Map<String, dynamic>>> getHRAttendanceReport(
      String startDate, String endDate, String firmId) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT s.id, s.name, s.role, s.staffType, COUNT(a.id) as daysPresent,
             0 as totalHours, COALESCE(SUM(a.overtimeHours), 0) as totalOvertime,
             0 as geoFenceCompliant
      FROM staff s LEFT JOIN attendance a ON s.id = a.staffId AND a.date BETWEEN ? AND ? AND a.status = 'Present'
      WHERE s.isActive = 1 AND s.firmId = ? GROUP BY s.id ORDER BY daysPresent DESC, s.name
    ''', [startDate, endDate, firmId]);
  }

  Future<List<Map<String, dynamic>>> getHROvertimeReport(
      String startDate, String endDate, String firmId) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT s.id, s.name, s.hourlyRate, COALESCE(SUM(a.overtimeHours), 0) as totalOT,
             COALESCE(SUM(a.overtimeHours), 0) * COALESCE(s.hourlyRate, 0) as otPay
      FROM staff s LEFT JOIN attendance a ON s.id = a.staffId AND a.date BETWEEN ? AND ? AND a.overtimeHours > 0
      WHERE s.isActive = 1 AND s.firmId = ? GROUP BY s.id HAVING totalOT > 0 ORDER BY totalOT DESC
    ''', [startDate, endDate, firmId]);
  }

  Future<List<Map<String, dynamic>>> getDispatchReport(
      String startDate, String endDate, String firmId) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT o.date,
             COUNT(d.id) as totalDispatches,
             SUM(CASE WHEN d.dispatchStatus = 'DELIVERED' OR d.dispatchStatus = 'COMPLETED' THEN 1 ELSE 0 END) as delivered,
             SUM(CASE WHEN d.dispatchStatus = 'DISPATCHED' THEN 1 ELSE 0 END) as inTransit,
             SUM(CASE WHEN d.dispatchStatus IS NULL OR d.dispatchStatus = 'PENDING' OR d.dispatchStatus = 'LOADING' THEN 1 ELSE 0 END) as pending,
             SUM(COALESCE(d.kmForward, 0) + COALESCE(d.kmReturn, 0)) as totalKm,
             COUNT(DISTINCT d.orderId) as ordersCount
      FROM dispatches d
      JOIN orders o ON d.orderId = o.id
      WHERE o.date BETWEEN ? AND ? AND o.firmId = ?
      GROUP BY o.date
      ORDER BY o.date DESC
    ''', [startDate, endDate, firmId]);
  }

  Future<List<Map<String, dynamic>>> getDispatchesForDate(String date) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT d.*, o.customerName, o.location
      FROM dispatches d
      JOIN orders o ON d.orderId = o.id
      WHERE o.date = ?
    ''', [date]);
  }

  // ---------- STAFF ASSIGNMENTS ----------

  Future<int> assignStaffToOrder(int orderId, int staffId, String role) async {
    final db = await _dbHelper.database;
    return await db.insert('staff_assignments', {
      'orderId': orderId,
      'staffId': staffId,
      'role': role,
      'assignedAt': DateTime.now().toIso8601String(),
      'status': 'ASSIGNED',
    });
  }

  Future<List<Map<String, dynamic>>> getOrderStaffAssignments(
      int orderId) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT sa.*, s.name, s.mobile, s.role as staffRole
      FROM staff_assignments sa
      JOIN staff s ON sa.staffId = s.id
      WHERE sa.orderId = ?
    ''', [orderId]);
  }

  Future<int> removeStaffAssignment(int assignmentId) async {
    final db = await _dbHelper.database;
    return await db.delete('staff_assignments',
        where: 'id = ?', whereArgs: [assignmentId]);
  }

  Future<List<Map<String, dynamic>>> getAvailableStaff(String date) async {
    final db = await _dbHelper.database;
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

  // ---------- LOGISTICS (VEHICLES & UTENSILS) ----------

  Future<int?> insertUtensil(Map<String, dynamic> data) async {
    final cloudSync = CloudSyncService();
    data['uuid'] = data['uuid'] ?? _generateUuid();
    final id = await cloudSync.awsFirstWrite(table: 'utensils', data: data);
    AppLogger.success('✅ [Operation] Added utensil #$id (AWS-first)');
    return id;
  }

  Future<bool> toggleDishSubcontract(int dishId, bool isSubcontracted) async {
    final cloudSync = CloudSyncService();

    final data = {
      'id': dishId,
      'isSubcontracted': isSubcontracted ? 1 : 0,
      'productionType': isSubcontracted ? 'SUBCONTRACT' : 'INTERNAL',
      'updatedAt': DateTime.now().toIso8601String(),
    };

    return await _dbHelper.updateRecord('dishes', dishId, data);
  }

  Future<bool> updateUtensil(int id, Map<String, dynamic> data) async {
    return await _dbHelper.updateRecord('utensils', id, data);
  }

  Future<bool> deleteUtensil(int id) async {
    final cloudSync = CloudSyncService();
    final success =
        await cloudSync.awsFirstDelete(table: 'utensils', recordId: id);
    AppLogger.success('✅ [Operation] Deleted utensil #$id (AWS-first)');
    return success;
  }

  Future<void> reduceUtensilStock(String name, int qty) async {
    final db = await _dbHelper.database;
    await db.rawUpdate('''
      UPDATE utensils 
      SET availableStock = MAX(0, availableStock - ?) 
      WHERE name = ?
    ''', [qty, name]);
    AppLogger.info('📉 [Operation] Reduced stock for "$name" by $qty');
  }

  Future<int?> insertVehicle(Map<String, dynamic> data) async {
    final cloudSync = CloudSyncService();
    data['uuid'] = data['uuid'] ?? _generateUuid();
    data['createdAt'] = DateTime.now().toIso8601String();
    final id = await cloudSync.awsFirstWrite(table: 'vehicles', data: data);
    AppLogger.success('✅ [Operation] Created vehicle #$id (AWS-first)');
    return id;
  }

  Future<bool> updateVehicle(int id, Map<String, dynamic> data) async {
    data['updatedAt'] = DateTime.now().toIso8601String();
    return await _dbHelper.updateRecord('vehicles', id, data);
  }

  Future<bool> deleteVehicle(int id) async {
    final cloudSync = CloudSyncService();
    final success =
        await cloudSync.awsFirstDelete(table: 'vehicles', recordId: id);
    AppLogger.success('✅ [Operation] Deleted vehicle #$id (AWS-first)');
    return success;
  }

  Future<List<Map<String, dynamic>>> getAllVehicles(
      {bool onlyActive = true}) async {
    final db = await _dbHelper.database;
    if (onlyActive) {
      return await db.query('vehicles',
          where: 'isActive = 1', orderBy: 'vehicleNumber');
    }
    return await db.query('vehicles', orderBy: 'vehicleNumber');
  }

  // ---------- DISPATCH ----------

  Future<List<Map<String, dynamic>>> getPendingDispatches() async {
    final db = await _dbHelper.database;
    return await db.query('dispatch', where: "status = 'Pending'");
  }

  Future<List<Map<String, dynamic>>> getOrdersWithoutDispatch(
      String date) async {
    final db = await _dbHelper.database;
    return await db.rawQuery(
        "SELECT * FROM orders WHERE date = ? AND id NOT IN (SELECT orderId FROM dispatch)",
        [date]);
  }

  Future<int?> insertDispatch(Map<String, dynamic> data) async {
    final cloudSync = CloudSyncService();
    data['uuid'] = data['uuid'] ?? _generateUuid();
    final id = await cloudSync.awsFirstWrite(table: 'dispatches', data: data);
    AppLogger.success('✅ [Operation] Created dispatch #$id (AWS-first)');
    return id;
  }

  Future<int?> insertDispatchItem(Map<String, dynamic> data) async {
    final cloudSync = CloudSyncService();
    data['uuid'] = data['uuid'] ?? _generateUuid();
    final id =
        await cloudSync.awsFirstWrite(table: 'dispatch_items', data: data);
    AppLogger.success('✅ [Operation] Created dispatch item #$id (AWS-first)');
    return id;
  }

  // ---------- DRIVER PORTAL HELPERS ----------

  Future<List<Map<String, dynamic>>> getDriverPendingAssignments(
      int driverId) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT d.*, o.customerName, o.location, o.date, o.time, o.totalPax, o.mobile as customerMobile,
             (SELECT COUNT(*) FROM dishes WHERE orderId = o.id) as dishCount
      FROM dispatches d JOIN orders o ON o.id = d.orderId
      WHERE d.driverId = ? AND d.assignmentStatus = 'PENDING' ORDER BY o.date ASC, o.time ASC
    ''', [driverId]);
  }

  Future<Map<String, dynamic>?> getDriverActiveDispatch(int driverId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT d.*, o.customerName, o.location, o.date, o.time, o.totalPax, o.mobile as customerMobile,
                 v.vehicleNumber, v.vehicleType
      FROM dispatches d JOIN orders o ON o.id = d.orderId
      LEFT JOIN vehicles v ON v.id = d.vehicleId
      WHERE d.driverId = ? AND d.assignmentStatus = 'ACCEPTED' 
        AND d.dispatchStatus IN ('PENDING', 'LOADING', 'DISPATCHED', 'DELIVERED')
      ORDER BY d.dispatchTime DESC LIMIT 1
    ''', [driverId]);
  }

  Future<void> updateDispatchKmAndEarnings(int dispatchId,
      {double? kmForward, double? kmReturn, double? driverShare}) async {
    Map<String, dynamic> updates = {
      'updatedAt': DateTime.now().toIso8601String()
    };
    if (kmForward != null) updates['kmForward'] = kmForward;
    if (kmReturn != null) updates['kmReturn'] = kmReturn;
    if (driverShare != null) updates['driverShare'] = driverShare;
    await _dbHelper.updateRecord('dispatches', dispatchId, updates);
  }

  Future<Map<String, dynamic>> getDriverEarningsReport(
      int driverId, String startDate, String endDate) async {
    final db = await _dbHelper.database;
    final summary = await db.rawQuery('''
      SELECT COUNT(*) as tripCount, COALESCE(SUM(kmForward), 0) as totalKmForward, COALESCE(SUM(kmReturn), 0) as totalKmReturn,
             COALESCE(SUM(driverShare), 0) as totalEarnings, SUM(CASE WHEN isPaid = 1 THEN driverShare ELSE 0 END) as paidAmount,
             SUM(CASE WHEN isPaid = 0 THEN driverShare ELSE 0 END) as pendingAmount
      FROM dispatches WHERE driverId = ? AND DATE(dispatchTime) BETWEEN ? AND ?
        AND dispatchStatus IN ('DELIVERED', 'COMPLETED', 'RETURNING')
    ''', [driverId, startDate, endDate]);
    final trips = await db.rawQuery('''
      SELECT d.*, o.customerName, o.location, o.date, o.time FROM dispatches d JOIN orders o ON o.id = d.orderId
      WHERE d.driverId = ? AND DATE(d.dispatchTime) BETWEEN ? AND ?
        AND d.dispatchStatus IN ('DELIVERED', 'COMPLETED', 'RETURNING') ORDER BY d.dispatchTime DESC
    ''', [driverId, startDate, endDate]);
    return {'summary': summary.isNotEmpty ? summary.first : {}, 'trips': trips};
  }

  // ---------- SUBCONTRACTOR PORTAL HELPERS ----------

  Future<List<Map<String, dynamic>>> getSubcontractorOrders(
      int subcontractorId, String date) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT DISTINCT o.*, 
             (SELECT SUM(d2.pax) FROM dishes d2 WHERE d2.orderId = o.id AND d2.isSubcontracted = 1 AND d2.subcontractorId = ?) as assignedPax,
             (SELECT COUNT(*) FROM dishes d3 WHERE d3.orderId = o.id AND d3.isSubcontracted = 1 AND d3.subcontractorId = ?) as dishCount
      FROM orders o JOIN dishes d ON d.orderId = o.id
      WHERE d.isSubcontracted = 1 AND d.subcontractorId = ? AND o.date = ? ORDER BY o.time ASC
    ''', [subcontractorId, subcontractorId, subcontractorId, date]);
  }

  Future<List<Map<String, dynamic>>> getSubcontractorDishes(
      int subcontractorId, int orderId) async {
    final db = await _dbHelper.database;
    return await db.query('dishes',
        where: 'orderId = ? AND isSubcontracted = 1 AND subcontractorId = ?',
        whereArgs: [orderId, subcontractorId]);
  }

  Future<List<Map<String, dynamic>>> getSubcontractorLedger(
      String subcontractorName, String startDate, String endDate) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT * FROM finance WHERE partyName LIKE ? AND date BETWEEN ? AND ? ORDER BY date DESC
    ''', ['%$subcontractorName%', startDate, endDate]);
  }

  // ---------- SERVICE REQUIREMENTS ----------

  Future<List<Map<String, dynamic>>> getServiceRequirementsForMrpRun(
      int mrpRunId) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT o.id as orderId, o.customerName, o.date, o.time, o.serviceRequired, o.serviceType, o.counterSetupRequired,
             o.serviceSubcontractorId, o.counterSubcontractorId, mo.pax, subS.name as serviceSubcontractorName,
             subC.name as counterSubcontractorName
      FROM mrp_run_orders mo JOIN orders o ON o.id = mo.orderId
      LEFT JOIN subcontractors subS ON subS.id = o.serviceSubcontractorId
      LEFT JOIN subcontractors subC ON subC.id = o.counterSubcontractorId
      WHERE mo.mrpRunId = ? AND (o.serviceRequired = 1 OR o.counterSetupRequired = 1) ORDER BY o.date ASC, o.time ASC
    ''', [mrpRunId]);
  }

  Future<void> updateOrderServiceAssignment(int orderId,
      {int? serviceSubId, int? counterSubId}) async {
    final updates = <String, dynamic>{
      'updatedAt': DateTime.now().toIso8601String(),
    };
    if (serviceSubId != null) updates['serviceSubcontractorId'] = serviceSubId;
    if (counterSubId != null) updates['counterSubcontractorId'] = counterSubId;

    if (updates.length > 1) {
      await _dbHelper.updateRecord('orders', orderId, updates);
    }
  }

  Future<void> assignDriverToDispatch(int dispatchId, int driverId) async {
    await _dbHelper.updateRecord('dispatches', dispatchId, {
      'driverId': driverId,
      'assignmentStatus': 'PENDING',
      'assignedAt': DateTime.now().toIso8601String()
    });
  }

  Future<bool> updateDispatchItem(int id, Map<String, dynamic> data) async {
    return await _dbHelper.updateRecord('dispatch_items', id, data);
  }

  Future<bool> updateUtensilByName(
      String name, Map<String, dynamic> data) async {
    final db = await _dbHelper.database;
    final res =
        await db.query('utensils', where: 'name = ?', whereArgs: [name]);
    if (res.isEmpty) return false;
    final id = res.first['id'] as int;
    final cloudSync = CloudSyncService();
    return await _dbHelper.updateRecord('utensils', id, data);
  }

  Future<bool> updateDispatch(int id, Map<String, dynamic> data) async {
    return await _dbHelper.updateRecord('dispatches', id, data);
  }

  // ---------- DISPATCH HUB SPECIALIZED QUERIES ----------

  Future<List<Map<String, dynamic>>> getDispatchHubPending(String date) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT o.*, 
             (SELECT COUNT(*) FROM dishes d WHERE d.orderId = o.id AND d.productionType = 'INTERNAL') as internalCount,
             (SELECT COUNT(*) FROM dishes d WHERE d.orderId = o.id AND d.productionType = 'INTERNAL' AND d.productionStatus = 'COMPLETED') as internalReadyCount,
             dp.dispatchStatus as currentDispatchStatus,
             dp.id as dispatchId
      FROM orders o
      LEFT JOIN dispatches dp ON dp.orderId = o.id
      WHERE o.date = ? AND (dp.dispatchStatus IS NULL OR dp.dispatchStatus = 'PENDING' OR dp.dispatchStatus = 'LOADING')
      ORDER BY o.time ASC
    ''', [date]);
  }

  Future<List<Map<String, dynamic>>> getDispatchHubActive() async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT d.*, o.customerName, o.location, o.time, o.date, o.mobile, o.totalPax,
             v.vehicleNumber, v.vehicleType, v.driverName, v.driverMobile
      FROM dispatches d
      JOIN orders o ON o.id = d.orderId
      LEFT JOIN vehicles v ON v.id = d.vehicleId
      WHERE d.dispatchStatus IN ('DISPATCHED', 'DELIVERED')
      ORDER BY d.dispatchTime DESC
      LIMIT 50
    ''');
  }

  Future<List<Map<String, dynamic>>> getDispatchHubReturns() async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT d.*, o.customerName, o.location, o.date, o.mobile
      FROM dispatches d
      JOIN orders o ON o.id = d.orderId
      WHERE d.dispatchStatus IN ('DISPATCHED', 'DELIVERED', 'RETURNING')
      ORDER BY d.dispatchTime DESC
      LIMIT 50
    ''');
  }

  Future<List<Map<String, dynamic>>> getDispatchHubUnloads() async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT d.*, o.customerName, o.location, o.date
      FROM dispatches d
      JOIN orders o ON o.id = d.orderId
      WHERE d.dispatchStatus = 'RETURNING'
      ORDER BY d.returnTime DESC
      LIMIT 50
    ''');
  }

  Future<List<Map<String, dynamic>>> getDispatchItems(int dispatchId) async {
    final db = await _dbHelper.database;
    return await db.query('dispatch_items',
        where: 'dispatchId = ?', whereArgs: [dispatchId]);
  }

  // --- PAYROLL & SALARY METHODS ---

  Future<Map<String, dynamic>?> getFirmDetails(String firmId) async {
    final db = await _dbHelper.database;
    final results =
        await db.query('firms', where: 'firmId = ?', whereArgs: [firmId]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>> getMonthlyAttendanceSummary(
      int staffId, String monthYear) async {
    final db = await _dbHelper.database;
    final startDate = '$monthYear-01';
    final endDate = '$monthYear-31';

    final result = await db.rawQuery('''
      SELECT 
        COUNT(*) as daysPresent,
        0 as totalHours,
        COALESCE(SUM(overtimeHours), 0) as totalOvertime,
        0 as daysWithinGeoFence
      FROM attendance
      WHERE staffId = ? AND date BETWEEN ? AND ? AND status = 'Present'
    ''', [staffId, startDate, endDate]);

    return result.isNotEmpty
        ? result.first
        : {
            'daysPresent': 0,
            'totalHours': 0.0,
            'totalOvertime': 0.0,
            'daysWithinGeoFence': 0,
          };
  }

  Future<double> getPendingAdvances(int staffId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM staff_advances
      WHERE staffId = ? AND deductedFromPayroll = 0
    ''', [staffId]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<void> markAdvancesDeducted(int staffId, String payrollMonth) async {
    final db = await _dbHelper.database;
    await db.update(
      'staff_advances',
      {'deductedFromPayroll': 1, 'payrollMonth': payrollMonth},
      where: 'staffId = ? AND deductedFromPayroll = 0',
      whereArgs: [staffId],
    );
  }

  Future<List<Map<String, dynamic>>> getMonthlyPayrollSummary(
      String monthYear) async {
    final db = await _dbHelper.database;
    final startDate = '$monthYear-01';
    final endDate = '$monthYear-31';

    return await db.rawQuery('''
      SELECT 
        s.id, s.name, s.staffType, s.salary, s.dailyWageRate, s.hourlyRate, s.payoutFrequency,
        COUNT(a.id) as daysPresent,
        0 as totalHours,
        COALESCE(SUM(a.overtimeHours), 0) as totalOvertime,
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

  Future<Map<String, dynamic>?> getSalarySlipData(
      int staffId, String monthYear) async {
    final db = await _dbHelper.database;
    final startDate = '$monthYear-01';
    final endDate = '$monthYear-31';

    final staffList = await db.query('staff',
        where: 'id = ?', whereArgs: [staffId], limit: 1);
    if (staffList.isEmpty) return null;
    final staff = staffList.first;

    final firmId = staff['firmId'] as String?;
    Map<String, dynamic>? firm;
    if (firmId != null) {
      firm = await getFirmDetails(firmId);
    }

    final attendance = await db.rawQuery('''
      SELECT COUNT(*) as daysPresent, 0 as totalHours, COALESCE(SUM(overtimeHours), 0) as totalOvertime
      FROM attendance
      WHERE staffId = ? AND date BETWEEN ? AND ? AND status = 'Present'
    ''', [staffId, startDate, endDate]);

    final advances = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM staff_advances WHERE staffId = ? AND deductedFromPayroll = 0
    ''', [staffId]);

    final disbursement = await db.query('salary_disbursements',
        where: 'staffId = ? AND monthYear = ?',
        whereArgs: [staffId, monthYear],
        limit: 1);

    return {
      'staff': staff,
      'firm': firm,
      'monthYear': monthYear,
      'attendance': attendance.first,
      'pendingAdvances': (advances.first['total'] as num?)?.toDouble() ?? 0,
      'disbursement': disbursement.isNotEmpty ? disbursement.first : null,
    };
  }

  Future<List<Map<String, dynamic>>> getStaffSalaryHistory(int staffId,
      {int limit = 12}) async {
    final db = await _dbHelper.database;
    return await db.query('salary_disbursements',
        where: 'staffId = ?',
        whereArgs: [staffId],
        orderBy: 'monthYear DESC',
        limit: limit);
  }

  Future<List<Map<String, dynamic>>> getPendingDisbursements(
      String firmId, String monthYear) async {
    final db = await _dbHelper.database;
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
        0 as totalHours,
        COALESCE(SUM(a.overtimeHours), 0) as totalOvertime,
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

  Future<void> disburseSalary(Map<String, dynamic> data) async {
    final cloudSync = CloudSyncService();
    // Use awsFirstWrite to ensure sync
    await cloudSync.awsFirstWrite(table: 'salary_disbursements', data: {
      ...data,
      'status': 'PAID',
      'paidAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }
}
