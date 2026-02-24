import 'package:ruchiserv/core/app_logger.dart';
import 'package:ruchiserv/db/database_helper.dart';
import 'package:ruchiserv/db/sync_event.dart';
import 'package:ruchiserv/repositories/inventory_repository.dart';
import 'package:ruchiserv/services/cloud_sync_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class FinanceRepository {
  static final FinanceRepository _instance = FinanceRepository._internal();
  factory FinanceRepository() => _instance;
  FinanceRepository._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int?> insertSupplier(Map<String, dynamic> data) async {
    final cloudSync = CloudSyncService();
    data['updatedAt'] = DateTime.now().toIso8601String();
    data['uuid'] = data['uuid'] ?? const Uuid().v4();
    final id = await cloudSync.awsFirstWrite(table: 'suppliers', data: data);
    AppLogger.success('✅ [Finance] Created supplier #$id (AWS-first)');
    return id;
  }

  String _generateUuid() => const Uuid().v4();

  // ---------- TRANSACTIONS ----------

  Future<int> insertTransaction(Map<String, dynamic> data) async {
    final db = await _dbHelper.database;
    data['uuid'] = data['uuid'] ?? _generateUuid();
    data['createdAt'] = DateTime.now().toIso8601String();
    data['updatedAt'] = DateTime.now().toIso8601String();
    final id = await db.insert('transactions', data);

    // Auto Sync via DatabaseHelper bridge (staying consistent with existing sync mechanism)
    _dbHelper.syncStreamController.add(SyncEvent(
        table: 'transactions', data: {...data, 'id': id}, action: 'INSERT'));
    return id;
  }

  Future<int> updateTransaction(int id, Map<String, dynamic> data) async {
    data['updatedAt'] = DateTime.now().toIso8601String();
    final success = await _dbHelper.updateRecord('transactions', id, data);
    return success ? 1 : 0;
  }

  Future<int> deleteTransaction(int id) async {
    final db = await _dbHelper.database;
    final rows =
        await db.delete('transactions', where: 'id = ?', whereArgs: [id]);

    _dbHelper.syncStreamController.add(SyncEvent(
        table: 'transactions',
        data: {'id': id},
        action: 'DELETE',
        filters: {'id': id}));
    return rows;
  }

  Future<List<Map<String, dynamic>>> getTransactions(
      {String? firmId,
      String? startDate,
      String? endDate,
      String? type,
      String? category,
      String? relatedEntityType,
      int? relatedEntityId,
      String? searchText,
      int? limit}) async {
    final db = await _dbHelper.database;
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
    final db = await _dbHelper.database;
    final res = await db.rawQuery('''
      SELECT SUM(CASE WHEN type = 'INCOME' THEN amount ELSE -amount END) as balance
      FROM transactions
      WHERE relatedEntityType = ? AND relatedEntityId = ? AND date < ?
      ${firmId != null ? 'AND firmId = ?' : ''}
    ''',
        [relatedEntityType, relatedEntityId, date, if (firmId != null) firmId]);

    return (res.first['balance'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getClosingBalance({
    required String relatedEntityType,
    required int relatedEntityId,
    required String date,
    String? firmId,
  }) async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery('''
      SELECT SUM(CASE WHEN type = 'INCOME' THEN amount ELSE -amount END) as balance
      FROM transactions
      WHERE relatedEntityType = ? AND relatedEntityId = ? AND date <= ?
      ${firmId != null ? 'AND firmId = ?' : ''}
    ''',
        [relatedEntityType, relatedEntityId, date, if (firmId != null) firmId]);

    return (res.first['balance'] as num?)?.toDouble() ?? 0.0;
  }

  Future<Map<String, double>> getFinanceSummary(
      String firmId, String startDate, String endDate,
      {String? relatedEntityType}) async {
    final db = await _dbHelper.database;
    String entityClause = relatedEntityType != null
        ? "AND relatedEntityType = '$relatedEntityType'"
        : "";

    final incomeRes = await db.rawQuery('''
      SELECT SUM(amount) as total FROM finance 
      WHERE firmId = ? AND type = 'INCOME' AND date BETWEEN ? AND ? $entityClause
    ''', [firmId, startDate, endDate]);

    final expenseRes = await db.rawQuery('''
      SELECT SUM(amount) as total FROM finance 
      WHERE firmId = ? AND type = 'EXPENSE' AND date BETWEEN ? AND ? $entityClause
    ''', [firmId, startDate, endDate]);

    return {
      'income': (incomeRes.first['total'] as num?)?.toDouble() ?? 0.0,
      'expense': (expenseRes.first['total'] as num?)?.toDouble() ?? 0.0,
    };
  }

  Future<List<Map<String, dynamic>>> getSummaryByPeriod(
      String firmId, String startDate, String endDate, String groupBy) async {
    final db = await _dbHelper.database;
    final dateFormat = groupBy == 'month' ? '%Y-%m' : '%Y-%m-%d';
    return await db.rawQuery('''
      SELECT strftime(?, date) as period,
             SUM(CASE WHEN type = 'INCOME' THEN amount ELSE 0 END) as income,
             SUM(CASE WHEN type = 'EXPENSE' THEN amount ELSE 0 END) as expense
      FROM transactions
      WHERE firmId = ? AND date BETWEEN ? AND ?
      GROUP BY period ORDER BY period ASC
    ''', [dateFormat, firmId, startDate, endDate]);
  }

  // ---------- SUPPLIER ORDERS & POs ----------

  Future<List<Map<String, dynamic>>> getSupplierOrders() async {
    final db = await _dbHelper.database;
    return await db.query('supplier_orders', orderBy: 'date DESC');
  }

  Future<int> insertSupplierOrder(Map<String, dynamic> data,
      [List<Map<String, dynamic>>? items]) async {
    final cloudSync = CloudSyncService();
    data['uuid'] = data['uuid'] ?? _generateUuid();
    final orderId =
        await cloudSync.awsFirstWrite(table: 'supplier_orders', data: data);

    if (items != null && items.isNotEmpty) {
      for (var item in items) {
        item['orderId'] = orderId;
        item['uuid'] = item['uuid'] ?? _generateUuid();
        await cloudSync.awsFirstWrite(
            table: 'supplier_order_items', data: item);
      }
    }
    return orderId ?? 0;
  }

  Future<bool> updatePurchaseOrderFields(
      int id, Map<String, dynamic> updates) async {
    return await _dbHelper.updateRecord('purchase_orders', id, updates);
  }

  // ---------- MASTER DATA (FINANCIAL ENTITIES) ----------

  Future<bool> deleteSupplier(int id) async {
    final success = await CloudSyncService()
        .awsFirstDelete(table: 'suppliers', recordId: id);
    AppLogger.success('✅ [Finance] Deleted supplier #$id (AWS-first)');
    return success;
  }

  Future<bool> deleteSubcontractor(int id) async {
    final success = await CloudSyncService()
        .awsFirstDelete(table: 'subcontractors', recordId: id);
    AppLogger.success('✅ [Finance] Deleted subcontractor #$id (AWS-first)');
    return success;
  }

  Future<List<Map<String, dynamic>>> getAllSuppliers(String firmId) async {
    final db = await _dbHelper.database;
    return await db.query('suppliers',
        where: 'firmId = ? AND isActive = 1',
        whereArgs: [firmId],
        orderBy: 'name');
  }

  // ---------- SUBSCRIPTIONS ----------

  Future<void> upsertFirmSubscription(
      {required String firmId,
      required String status,
      required String startIso,
      required String endIso}) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final data = {
      'firmId': firmId,
      'subscriptionStatus': status,
      'subscriptionStart': startIso.isNotEmpty ? startIso : null,
      'subscriptionEnd': endIso.isNotEmpty ? endIso : null,
      'updatedAt': now,
    };
    final count = await db
        .update('firms', data, where: 'firmId = ?', whereArgs: [firmId]);
    if (count == 0) {
      data['firmName'] = 'Unknown';
      data['createdAt'] = now;
      await db.insert('firms', data,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> updateFirmSubscription(
      {required String firmId,
      required String plan,
      required String endDate,
      required String status,
      String? txnId}) async {
    final db = await _dbHelper.database;
    // v44: firms table uses firmId as pk, but our updateRecord expects int id.
    // However, firms table DOES have an autoincrement id.
    final res = await db.query('firms',
        columns: ['id'], where: 'firmId = ?', whereArgs: [firmId]);
    if (res.isEmpty) return;
    final id = res.first['id'] as int;

    final data = {
      'subscriptionPlan': plan,
      'subscriptionEnd': endDate,
      'subscriptionStatus': status,
      if (txnId != null) 'lastRenewalTxnId': txnId,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    await _dbHelper.updateRecord('firms', id, data);
  }

  // --- SUBCONTRACTORS ---
  Future<List<Map<String, dynamic>>> getAllSubcontractors(String firmId) async {
    final db = await _dbHelper.database;
    return await db.query('subcontractors',
        where: 'firmId = ? AND isActive = 1',
        whereArgs: [firmId],
        orderBy: 'name');
  }

  Future<int?> insertSubcontractor(Map<String, dynamic> data) async {
    final cloudSync = CloudSyncService();
    data['createdAt'] = DateTime.now().toIso8601String();
    data['isActive'] = 1;
    data['uuid'] = data['uuid'] ?? _generateUuid();
    final id =
        await cloudSync.awsFirstWrite(table: 'subcontractors', data: data);
    AppLogger.success(
        '✅ [Subcontractors] Created subcontractor #$id (AWS-first)');
    return id;
  }

  // --- INVOICES ---

  Future<String> generateInvoiceNumber(String firmId) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final ym = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final prefix = 'inv-$ym-';
    final res = await db.rawQuery(
        "SELECT COUNT(*) as cnt FROM invoices WHERE firmId = ? AND invoiceNumber LIKE ?",
        [firmId, '$prefix%']);
    return '$prefix${((res.first['cnt'] as int?) ?? 0 + 1).toString().padLeft(3, '0')}';
  }

  Future<int?> insertInvoice(Map<String, dynamic> data,
      {List<Map<String, dynamic>>? items}) async {
    final cloudSync = CloudSyncService();
    final now = DateTime.now().toIso8601String();
    data['createdAt'] = now;
    data['updatedAt'] = now;
    data['uuid'] = data['uuid'] ?? _generateUuid();
    if (data['invoiceNumber'] == null) {
      data['invoiceNumber'] = await generateInvoiceNumber(data['firmId']);
    }
    if (data['dueDate'] == null && data['invoiceDate'] != null) {
      data['dueDate'] = DateTime.parse(data['invoiceDate'])
          .add(const Duration(days: 7))
          .toIso8601String()
          .substring(0, 10);
    }
    data['balanceDue'] = (data['totalAmount'] ?? 0) - (data['amountPaid'] ?? 0);
    final id = await cloudSync.awsFirstWrite(table: 'invoices', data: data);
    if (id != null && items != null && items.isNotEmpty) {
      await insertInvoiceItems(id, items);
    }
    return id;
  }

  Future<void> insertInvoiceItems(
      int invoiceId, List<Map<String, dynamic>> items) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (var item in items) {
      item['invoiceId'] = invoiceId;
      final qty = (item['quantity'] ?? 1) as num;
      final rate = (item['rate'] ?? 0) as num;
      final amount = qty * rate;
      final gst = (item['gstRate'] ?? 18) as num;
      final gstAmt = amount * gst / 100;
      item['amount'] = amount;
      item['cgst'] = gstAmt / 2;
      item['sgst'] = gstAmt / 2;
      item['igst'] = 0;
      item['totalAmount'] = amount + gstAmt;
      item['uuid'] = item['uuid'] ?? _generateUuid();
      batch.insert('invoice_items', item);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getInvoices(String firmId,
      {String? status,
      String? startDate,
      String? endDate,
      int? customerId}) async {
    final db = await _dbHelper.database;
    String where = 'firmId = ?';
    List<dynamic> args = [firmId];
    if (status != null) {
      where += ' AND status = ?';
      args.add(status);
    }
    if (startDate != null && endDate != null) {
      where += ' AND invoiceDate BETWEEN ? AND ?';
      args.add(startDate);
      args.add(endDate);
    }
    if (customerId != null) {
      where += ' AND customerId = ?';
      args.add(customerId);
    }
    return await db.query('invoices',
        where: where, whereArgs: args, orderBy: 'invoiceDate DESC');
  }

  // --- PROFITABILITY & COSTS ---

  Future<double> getOrderMaterialCost(int orderId, String firmId) async {
    final db = await _dbHelper.database;
    final dishes =
        await db.query('dishes', where: 'orderId = ?', whereArgs: [orderId]);
    final inventory = InventoryRepository();
    double totalMaterialCost = 0;
    for (var dish in dishes) {
      final dishMasterId = dish['dishMasterId'] as int?;
      final dishName = (dish['dishName'] ?? dish['name']) as String?;
      final pax = (dish['pax'] as int?) ?? 0;
      if (dishName == null) continue;

      List<Map<String, dynamic>> recipe;
      if (dishMasterId != null && dishMasterId != 0) {
        recipe = await inventory.getRecipeForDishById(dishMasterId, pax);
      } else {
        recipe = await inventory.getRecipeForDishByName(dishName, pax);
      }

      for (var ing in recipe) {
        final cost = (ing['cost_per_unit'] as num?)?.toDouble() ?? 0;
        final qty = (ing['scaledQuantity'] as num?)?.toDouble() ?? 0;
        totalMaterialCost += cost * qty;
      }
    }
    return totalMaterialCost;
  }

  Future<int> getMonthlyPax(String firmId, String monthYear) async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery(
        "SELECT SUM(totalPax) as total FROM orders WHERE firmId = ? AND (date LIKE ? OR eventDate LIKE ?) AND (isCancelled = 0 OR isCancelled IS NULL)",
        [firmId, '$monthYear%', '$monthYear%']);
    return (res.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<double> getMonthlyFixedCosts(String firmId, String monthYear) async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery(
        "SELECT SUM(amount) as total FROM transactions WHERE firmId = ? AND type = 'EXPENSE' AND date LIKE ? AND category IN ('Salary', 'Wages', 'Overtime', 'Advance', 'Staff Payment', 'Rent', 'Electricity', 'Gas', 'Water', 'Utilities', 'Consumables')",
        [firmId, '$monthYear%']);
    return (res.first['total'] as num?)?.toDouble() ?? 0;
  }

  // --- PURCHASE ORDERS & SUPPLIER PORTAL ---

  Future<String> generatePoNumber(String firmId) async {
    final db = await _dbHelper.database;
    final today = DateTime.now();
    final prefix =
        'PO${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';
    final count = Sqflite.firstIntValue(await db.rawQuery(
            "SELECT COUNT(*) FROM purchase_orders WHERE firmId = ? AND poNumber LIKE ?",
            [firmId, '$prefix%'])) ??
        0;
    return '$prefix-${(count + 1).toString().padLeft(3, '0')}';
  }

  Future<int?> createPurchaseOrder(Map<String, dynamic> data) async {
    final cloudSync = CloudSyncService();
    data['createdAt'] = DateTime.now().toIso8601String();
    data['sentAt'] = DateTime.now().toIso8601String();
    data['uuid'] = data['uuid'] ?? _generateUuid();
    return await cloudSync.awsFirstWrite(table: 'purchase_orders', data: data);
  }

  Future<void> addPoItems(int poId, List<Map<String, dynamic>> items) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (var item in items) {
      batch.insert('po_items',
          {'poId': poId, ...item, 'uuid': item['uuid'] ?? _generateUuid()});
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getPurchaseOrders(String firmId,
      {String? status}) async {
    final db = await _dbHelper.database;
    String where = 'firmId = ?';
    List<dynamic> args = [firmId];
    if (status != null) {
      where += ' AND status = ?';
      args.add(status);
    }
    return await db.query('purchase_orders',
        where: where, whereArgs: args, orderBy: 'createdAt DESC');
  }

  Future<List<Map<String, dynamic>>> getPoItems(int poId) async {
    final db = await _dbHelper.database;
    return await db.query('po_items', where: 'poId = ?', whereArgs: [poId]);
  }

  Future<Map<String, dynamic>?> getSupplierById(int id) async {
    final db = await _dbHelper.database;
    final res = await db.query('suppliers', where: 'id = ?', whereArgs: [id]);
    return res.isNotEmpty ? res.first : null;
  }

  Future<List<Map<String, dynamic>>> getSupplierPOs(int supplierId,
      {String? status}) async {
    final db = await _dbHelper.database;
    if (status != null) {
      return await db.query('purchase_orders',
          where: 'vendorId = ? AND status = ?',
          whereArgs: [supplierId, status],
          orderBy: 'createdAt DESC');
    }
    return await db.query('purchase_orders',
        where: 'vendorId = ?',
        whereArgs: [supplierId],
        orderBy: 'createdAt DESC');
  }

  Future<void> updateSupplierPOStatus(int poId, String status) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    Map<String, dynamic> up = {'status': status};
    if (status == 'ACCEPTED') {
      up['acceptedAt'] = now;
    } else if (status == 'DISPATCHED')
      up['dispatchedAt'] = now;
    else if (status == 'DELIVERED') up['deliveredAt'] = now;
    await db.update('purchase_orders', up, where: 'id = ?', whereArgs: [poId]);
  }

  Future<Map<String, dynamic>> getSupplierLedger(int supplierId,
      String supplierName, String startDate, String endDate) async {
    final db = await _dbHelper.database;
    final txs = await db.rawQuery(
        "SELECT * FROM finance WHERE partyName LIKE ? AND date BETWEEN ? AND ? ORDER BY date DESC",
        ['%$supplierName%', startDate, endDate]);
    final sum = await db.rawQuery(
        "SELECT SUM(totalAmount) as totalInvoiced FROM purchase_orders WHERE vendorId = ? AND DATE(createdAt) BETWEEN ? AND ?",
        [supplierId, startDate, endDate]);
    return {
      'transactions': txs,
      'totalInvoiced': sum.isNotEmpty ? sum.first['totalInvoiced'] ?? 0 : 0
    };
  }

  Future<List<Map<String, dynamic>>> getPurchaseOrdersByMrpRun(
      int mrpRunId) async {
    final db = await _dbHelper.database;
    return await db.query('purchase_orders',
        where: 'mrpRunId = ?',
        whereArgs: [mrpRunId],
        orderBy: 'createdAt DESC');
  }

  Future<int> updatePoStatus(int poId, String status) async {
    final db = await _dbHelper.database;
    final map = {
      'ACCEPTED': 'acceptedAt',
      'DISPATCHED': 'dispatchedAt',
      'DELIVERED': 'deliveredAt'
    };
    final up = <String, dynamic>{'status': status};
    if (map.containsKey(status)) {
      up[map[status]!] = DateTime.now().toIso8601String();
    }
    return await db
        .update('purchase_orders', up, where: 'id = ?', whereArgs: [poId]);
  }

  Future<List<Map<String, dynamic>>> cancelPOsForOrder(int orderId) async {
    final db = await _dbHelper.database;
    final cloudSync = CloudSyncService();
    final allPOs = await db.query('purchase_orders');
    final cancelled = <Map<String, dynamic>>[];
    for (final po in allPOs) {
      final ids = po['orderIds']?.toString() ?? '';
      if (ids.split(',').map((s) => s.trim()).contains(orderId.toString()) &&
          po['status'] != 'CANCELLED') {
        final up = {
          'status': 'CANCELLED',
          'cancelledAt': DateTime.now().toIso8601String(),
          'cancelReason': 'Order updated - MRP re-run required'
        };
        await _dbHelper.updateRecord('purchase_orders', po['id'] as int, up);
        cancelled.add(po);
      }
    }
    return cancelled;
  }

  Future<Map<String, dynamic>> getKPIComparison(
      String firmId, String startDate, String endDate) async {
    final db = await _dbHelper.database;
    final current = await db.rawQuery('''
      SELECT SUM(CASE WHEN type = 'INCOME' THEN amount ELSE 0 END) as revenue,
             SUM(CASE WHEN type = 'EXPENSE' AND category = 'Materials' THEN amount ELSE 0 END) as cogs,
             SUM(CASE WHEN type = 'EXPENSE' THEN amount ELSE 0 END) as totalExpense
      FROM transactions WHERE firmId = ? AND date BETWEEN ? AND ?
    ''', [firmId, startDate, endDate]);
    final data = current.first;
    final revenue = (data['revenue'] as num?)?.toDouble() ?? 0.0;
    final cogs = (data['cogs'] as num?)?.toDouble() ?? 0.0;
    final totalExpense = (data['totalExpense'] as num?)?.toDouble() ?? 0.0;
    return {
      'current': {
        'revenue': revenue,
        'cogs': cogs,
        'totalExpense': totalExpense,
        'grossProfit': revenue - cogs,
        'netProfit': revenue - totalExpense,
      }
    };
  }

  Future<List<Map<String, dynamic>>> getProfitabilityTrend(
      String firmId, String startDate, String endDate) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT date, SUM(CASE WHEN type = 'INCOME' THEN amount ELSE 0 END) as income,
             SUM(CASE WHEN type = 'EXPENSE' AND category = 'Materials' THEN amount ELSE 0 END) as cost,
             SUM(CASE WHEN type = 'INCOME' THEN amount ELSE 0 END) - SUM(CASE WHEN type = 'EXPENSE' AND category = 'Materials' THEN amount ELSE 0 END) as profit
      FROM transactions WHERE firmId = ? AND date BETWEEN ? AND ? GROUP BY date ORDER BY date ASC
    ''', [firmId, startDate, endDate]);
  }

  Future<List<Map<String, dynamic>>> getExpenseBreakdown(
      String firmId, String startDate, String endDate) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT category as groupName, SUM(amount) as total
      FROM transactions WHERE firmId = ? AND type = 'EXPENSE' AND date BETWEEN ? AND ?
      GROUP BY category ORDER BY total DESC
    ''', [firmId, startDate, endDate]);
  }

  Future<int?> createInvoiceFromOrder(int orderId, String firmId) async {
    final cloudSync = CloudSyncService();
    final db = await _dbHelper.database;
    final orderRes =
        await db.query('orders', where: 'id = ?', whereArgs: [orderId]);
    if (orderRes.isEmpty) return null;
    final order = orderRes.first;

    final invData = {
      'firmId': firmId,
      'orderId': orderId,
      'invoiceNumber': 'INV-${DateTime.now().millisecondsSinceEpoch % 100000}',
      'customerName': order['customerName'],
      'invoiceDate': DateTime.now().toString().split(' ')[0],
      'totalAmount': order['finalAmount'],
      'paidAmount': 0.0,
      'balanceDue': order['finalAmount'],
      'status': 'UNPAID',
      'createdAt': DateTime.now().toIso8601String(),
      'uuid': _generateUuid(),
    };

    final id = await cloudSync.awsFirstWrite(table: 'invoices', data: invData);
    AppLogger.success('✅ [Finance] Created invoice #$id from order #$orderId');
    return id;
  }

  Future<Map<String, dynamic>?> getInvoiceWithItems(int invoiceId) async {
    final db = await _dbHelper.database;
    final res =
        await db.query('invoices', where: 'id = ?', whereArgs: [invoiceId]);
    if (res.isEmpty) return null;
    final invoice = Map<String, dynamic>.from(res.first);
    final items = await db
        .query('invoice_items', where: 'invoiceId = ?', whereArgs: [invoiceId]);
    return {...invoice, 'items': items};
  }

  Future<bool> recordInvoicePayment(
      int invoiceId, double amount, String method) async {
    final db = await _dbHelper.database;
    final cloudSync = CloudSyncService();
    final res =
        await db.query('invoices', where: 'id = ?', whereArgs: [invoiceId]);
    if (res.isEmpty) return false;
    final inv = Map<String, dynamic>.from(res.first);
    final paid = (inv['amountPaid'] as num?)?.toDouble() ?? 0.0;
    final total = (inv['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final newPaid = paid + amount;
    final status = newPaid >= total ? 'PAID' : 'PARTIAL';

    await _dbHelper.updateRecord('invoices', invoiceId, {
      'amountPaid': newPaid,
      'status': status,
      'updatedAt': DateTime.now().toIso8601String(),
    });

    // Also record a transaction
    await insertTransaction({
      'firmId': inv['firmId'],
      'amount': amount,
      'type': 'INCOME',
      'category': 'Payment',
      'description': 'Payment for invoice #$invoiceId',
      'date': DateTime.now().toString().split(' ')[0],
      'paymentMode': method,
    });

    return true;
  }

  Future<Map<String, dynamic>> getEventProfitability(
      int orderId, String firmId) async {
    final db = await _dbHelper.database;

    // Get order revenue and basic info
    final order =
        await db.query('orders', where: 'id = ?', whereArgs: [orderId]);
    if (order.isEmpty) return {};

    final orderData = order.first;
    final revenue = (orderData['grandTotal'] as num?)?.toDouble() ??
        (orderData['totalAmount'] as num?)?.toDouble() ??
        0;
    final orderPax = (orderData['totalPax'] as num?)?.toInt() ??
        (orderData['pax'] as num?)?.toInt() ??
        0;
    final orderDate = orderData['date']?.toString() ??
        orderData['eventDate']?.toString() ??
        '';

    // 1. Calculate Material Cost from BOM
    final materialCost = await getOrderMaterialCost(orderId, firmId);

    // 2. Calculate Allocated Fixed Costs (Per plate basis)
    double allocatedFixedCost = 0;
    double perPlateOperational = 0;

    if (orderDate.length >= 7) {
      final monthYear = orderDate.substring(0, 7); // YYYY-MM
      final monthlyPax = await getMonthlyPax(firmId, monthYear);
      final monthlyFixedCosts = await getMonthlyFixedCosts(firmId, monthYear);

      if (monthlyPax > 0) {
        perPlateOperational = monthlyFixedCosts / monthlyPax;
        allocatedFixedCost = perPlateOperational * orderPax;
      }
    }

    // 3. Get Labor and Logistics Costs from Finance table (transactions)
    final otherCostsRes = await db.rawQuery('''
      SELECT category, SUM(amount) as total 
      FROM transactions 
      WHERE relatedEntityType = 'Order' AND relatedEntityId = ? 
      AND category IN ('Labor', 'Logistics', 'Transport', 'Rentals', 'Other')
      GROUP BY category
    ''', [orderId]);

    double totalOtherCosts = 0;
    final Map<String, double> costBreakdown = {
      'Material': materialCost,
      'Fixed Share': allocatedFixedCost
    };

    for (var cost in otherCostsRes) {
      final cat = cost['category'] as String;
      final amt = (cost['total'] as num?)?.toDouble() ?? 0;
      costBreakdown[cat] = amt;
      totalOtherCosts += amt;
    }

    final totalCost = materialCost + allocatedFixedCost + totalOtherCosts;
    final netProfit = revenue - totalCost;

    return {
      'revenue': revenue,
      'materialCost': materialCost,
      'allocatedFixedCost': allocatedFixedCost,
      'perPlateOperational': perPlateOperational,
      'otherCosts': totalOtherCosts,
      'totalCost': totalCost,
      'grossProfit': revenue - materialCost,
      'netProfit': netProfit,
      'profit': netProfit,
      'margin': revenue > 0 ? (netProfit / revenue) * 100 : 0,
      'breakdown': costBreakdown,
      'pax': orderPax,
      'perPlateProfit': orderPax > 0 ? netProfit / orderPax : 0,
    };
  }
}
