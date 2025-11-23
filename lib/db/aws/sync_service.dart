// lib/db/aws/sync_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'aws_api.dart';

/// Lightweight offline queue that persists to SharedPreferences.
/// (You already have a local DB; this avoids adding new tables right now.)
///
/// Each item is something like:
/// { "type":"DB", "payload": { "method":"CREATE", "table":"orders", "data":{...} } }
/// or
/// { "type":"REST", "payload": { "path":"/otp/send", "method":"POST", "body":{...} } }
///
/// Use: await SyncService.enqueueDb(...); await SyncService.tryFlush();
class SyncService {
  static const String _key = 'sync_queue_v1';

  static Future<List<Map<String, dynamic>>> _loadQueue() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw);
      if (list is List) {
        return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveQueue(List<Map<String, dynamic>> queue) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, jsonEncode(queue));
  }

  // ---- Enqueue helpers ---- //

  static Future<void> enqueueDb({
    required String method,
    required String table,
    Map<String, dynamic>? data,
    Map<String, dynamic>? where,
  }) async {
    final item = {
      'type': 'DB',
      'payload': {
        'method': method,
        'table': table,
        if (data != null) 'data': data,
        if (where != null) 'where': where,
      },
    };
    final q = await _loadQueue();
    q.add(item);
    await _saveQueue(q);
  }

  static Future<void> enqueueRest({
    required String path,
    required String httpMethod, // GET/POST/PUT/DELETE
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
  }) async {
    final item = {
      'type': 'REST',
      'payload': {
        'path': path,
        'httpMethod': httpMethod,
        if (body != null) 'body': body,
        if (query != null) 'query': query,
      },
    };
    final q = await _loadQueue();
    q.add(item);
    await _saveQueue(q);
  }

  // ---- Flush ---- //

  /// Try to flush the queue. Stop on first failure (keep remaining for later).
  static Future<void> tryFlush() async {
    final q = await _loadQueue();
    if (q.isEmpty) return;

    final remaining = <Map<String, dynamic>>[];
    for (final item in q) {
      final type = (item['type'] ?? '').toString();
      final payload = Map<String, dynamic>.from(item['payload'] ?? {});

      try {
        if (type == 'DB') {
          await AwsApi.db(
            method: (payload['method'] ?? '').toString(),
            table: (payload['table'] ?? '').toString(),
            data: payload['data'] == null ? null : Map<String, dynamic>.from(payload['data']),
            where: payload['where'] == null ? null : Map<String, dynamic>.from(payload['where']),
          );
        } else if (type == 'REST') {
          final path = (payload['path'] ?? '').toString();
          final method = (payload['httpMethod'] ?? 'POST').toString().toUpperCase();
          final body = payload['body'] == null ? null : Map<String, dynamic>.from(payload['body']);
          final query = payload['query'] == null ? null : Map<String, dynamic>.from(payload['query']);

          switch (method) {
            case 'GET':
              await AwsApi.get(path, query: query);
              break;
            case 'PUT':
              await AwsApi.put(path, body ?? <String, dynamic>{}, query: query);
              break;
            case 'DELETE':
              await AwsApi.delete(path, query: query, body: body);
              break;
            case 'POST':
            default:
              await AwsApi.post(path, body ?? <String, dynamic>{}, query: query);
          }
        } else {
          // Unknown type → skip
        }
      } catch (_) {
        // Keep this and all remaining items for next attempt
        remaining.add(item);
        remaining.addAll(q.skip(q.indexOf(item) + 1));
        break;
      }
    }

    await _saveQueue(remaining);
  }
}
