// lib/db/sync_event.dart
// @locked

/// Represents a database mutation that needs to be synchronized with the cloud.
class SyncEvent {
  final String table;
  final Map<String, dynamic> data;
  final String action; // 'INSERT', 'UPDATE', 'DELETE'
  final Map<String, dynamic>? filters;

  SyncEvent({
    required this.table,
    required this.data,
    required this.action,
    this.filters,
  });

  @override
  String toString() => 'SyncEvent(table: $table, action: $action, data: $data)';
}
