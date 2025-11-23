import '../database_helper.dart';
import 'dart:convert';

class LocalDbHelper {
  static final _db = DatabaseHelper();

  // Optional: active branch/kitchen id (null if not set)
  static Future<int?> getActiveBranchId() async {
    // Adjust when you implement settings storage
    return null;
  }

  // === Orders (day-level) ===
  static Future<List<Map<String, dynamic>>> getOrdersByDate(String date) async {
    return await _db.getOrdersByDate(date);
  }

  static Future<bool> deleteOrder(int orderId) async {
    return await _db.deleteOrder(orderId);
  }

  static Future<void> upsertOrders(List<Map<String, dynamic>> rows) async {
    // Simple strategy: clear & insert only for the day you’re viewing is safer,
    // but since we receive already-filtered date lists from API, just insert/replace here.
    // You can improve to a per-date reconcile later.
    for (final row in rows) {
      final dishes = (row['dishes'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final order = Map<String, dynamic>.from(row)..remove('dishes');

      if (order['id'] is int) {
        // Try update; if fails (no row), do insert.
        try {
          await _db.updateOrder(order['id'] as int, order, dishes);
        } catch (_) {
          await _db.insertOrder(order, dishes);
        }
      } else {
        await _db.insertOrder(order, dishes);
      }
    }
  }

  // Pending sync queue
  static Future<void> queuePendingSync({
    required String table,
    required Map<String, dynamic> data,
    required String action, // 'INSERT' | 'UPDATE' | 'DELETE'
  }) async {
    await _db.rawInsertPendingSync({
      'table_name': table,
      'data': jsonEncode(data),
      'action': action,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // Dishes summary by date
  static Future<List<Map<String, dynamic>>> getDishesSummaryByDate(String date) async {
    return await _db.getDishesSummaryByDate(date);
  }
}
