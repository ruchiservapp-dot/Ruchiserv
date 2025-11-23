import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../db/aws/aws_api.dart';
import '../../db/local/local_db_helper.dart';
import '../../core/app_logger.dart';


// BEFORE (example of what triggers the warning)
// if (results == ConnectivityResult.mobile || results == ConnectivityResult.wifi) { ... }

// AFTER
final results = await Connectivity().checkConnectivity();
final isOnline = results != ConnectivityResult.none;
// ...use isOnline in your logic

class DataService {
  static Future<bool> _isOnline() async {
    try {
      final r = await Connectivity().checkConnectivity();
      return r == ConnectivityResult.mobile || r == ConnectivityResult.wifi;
    } catch (_) {
      return false;
    }
    
  }
ConnectivityService.connectivityStream.listen((list) {
  final isOnline = list.isNotEmpty && list.first != ConnectivityResult.none;
  // ...
});

  // ---------------- FIRMS ----------------

  static Future<Map<String, dynamic>> addFirm(Map<String, dynamic> firm) async {
    // local-first
    await LocalDbHelper.insertFirm({
      "firmName": firm['firm_name'] ?? firm['firmName'] ?? '',
      "contactPerson": firm['contact_person'] ?? firm['contactPerson'] ?? '',
      "primaryEmail": firm['primary_email'] ?? firm['primaryEmail'] ?? '',
      "primaryMobile": firm['primary_mobile'] ?? firm['primaryMobile'] ?? '',
      "createdAt": DateTime.now().toIso8601String(),
      "updatedAt": DateTime.now().toIso8601String(),
    });

    await LocalDbHelper.queuePendingSync(
      table: 'firms',
      data: firm,
      action: 'INSERT',
    );

    if (await _isOnline()) _syncPendingSilently();

    return {"status": "success", "message": "Saved locally, will sync."};
  }

  static Future<List<Map<String, dynamic>>> getFirms() async {
    return await LocalDbHelper.getCachedFirms();
  }

  // ---------------- ORDERS ----------------

  static Future<Map<String, dynamic>> addOrder({
    required Map<String, dynamic> order,
    required List<Map<String, dynamic>> dishes,
  }) async {
    final id = await LocalDbHelper.insertOrder(order, dishes);

    await LocalDbHelper.queuePendingSync(
      table: 'orders',
      data: {"order": order, "dishes": dishes, if (id != null) "id": id},
      action: 'INSERT',
    );

    if (await _isOnline()) _syncPendingSilently();

    return {"status": "success", "localId": id};
  }

  static Future<Map<String, dynamic>> updateOrder({
    required int id,
    required Map<String, dynamic> order,
    required List<Map<String, dynamic>> dishes,
  }) async {
    await LocalDbHelper.updateOrder(id, order, dishes);

    await LocalDbHelper.queuePendingSync(
      table: 'orders',
      data: {"id": id, "order": order, "dishes": dishes},
      action: 'UPDATE',
    );

    if (await _isOnline()) _syncPendingSilently();

    return {"status": "success"};
  }

  static Future<Map<String, dynamic>> deleteOrder(int id) async {
    await LocalDbHelper.deleteOrder(id);

    await LocalDbHelper.queuePendingSync(
      table: 'orders',
      data: {"id": id},
      action: 'DELETE',
    );

    if (await _isOnline()) _syncPendingSilently();

    return {"status": "success"};
  }

  static Future<List<Map<String, dynamic>>> getOrders({required String date}) {
    return LocalDbHelper.getOrdersByDate(date);
  }

  // ---------------- SYNC ----------------

  static Future<void> _syncPendingSilently() async {
    try {
      final pending = await LocalDbHelper.getPendingSync();
      for (final row in pending) {
        final int pendingId = (row['id'] as int);
        final String table = (row['table_name'] as String);
        final String action = (row['action'] as String);
        final Map<String, dynamic> data = jsonDecode(row['data'] as String);

        final method = switch (action) {
          'INSERT' => 'POST',
          'UPDATE' => 'PUT',
          'DELETE' => 'DELETE',
          _ => 'POST',
        };

        final resp = await AwsApi.callDbHandler(
          method: method,
          table: table,
          data: data,
        );

        if ((resp['status']?.toString().toLowerCase() == 'success')) {
          await LocalDbHelper.markSynced(pendingId);
          AppLogger.success("Synced $table (#$pendingId)");
        } else {
          AppLogger.error("Sync failed for $table (#$pendingId): ${resp['message']}");
        }
      }
    } catch (e) {
      AppLogger.error("Sync exception: $e");
    }
  }
}
